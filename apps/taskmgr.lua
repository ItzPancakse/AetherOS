-- taskmgr.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- Task manager app

local ui = dofile("/lib/ui.lua")
local theme = dofile("/lib/theme.lua")
local util = dofile("/lib/util.lua")

theme.refresh()

local rows = {}
local selected = 1

local function refresh()
    rows = (aether and aether.kernel) and aether.kernel:list() or {}
    if selected > #rows then selected = #rows end
    if selected < 1 and #rows > 0 then selected = 1 end
end
refresh()

local killButton

local function draw()
    local w, h = term.getSize()
    ui.clear(theme.windowBg)

    ui.fillRect(1, 1, w, 1, theme.panelBg2)
    ui.text(1, 1, (" %-5s %-16s %-8s %-8s %s"):format("PID", "NAME", "KIND", "STATUS", "UPTIME"), colors.white, theme.panelBg2)

    for i, p in ipairs(rows) do
        local y = i + 1
        if y >= h - 1 then break end
        local isSel = (i == selected)
        local bg = isSel and theme.accent or theme.windowBg
        local fg = isSel and colors.black or colors.white
        ui.fillRect(1, y, w, 1, bg)
        ui.text(1, y, (" %-5d %-16s %-8s %-8s %ds"):format(p.pid, p.name:sub(1, 16), p.kind, p.status, math.floor(p.uptime)), fg, bg)
    end

    killButton = ui.button(1, h, 12, "Kill Task", { bg = colors.red, fg = colors.white, id = "kill" })
    ui.text(14, h, "Click a row to select", colors.lightGray, theme.panelBg2)
end

draw()

local timerId = os.startTimer(1)

while true do
    local event, a, b, c = os.pullEvent()

    if event == "mouse_click" then
        local mx, my = b, c
        local w, h = term.getSize()
        if my >= 2 and my < h - 1 then
            local idx = my - 1
            if rows[idx] then selected = idx end
        end
        local hit = killButton and ui.hit(killButton, mx, my)
        if hit and rows[selected] and aether and aether.kernel then
            local pid = rows[selected].pid
            if aether.wm then
                local win = aether.wm.findByPid(pid)
                if win then aether.wm.closeWindow(win.id) end
            end
            aether.kernel:kill(pid)
            refresh()
        end
        draw()
    elseif event == "key" then
        if a == keys.up then
            selected = math.max(1, selected - 1)
            draw()
        elseif a == keys.down then
            selected = math.min(#rows, selected + 1)
            draw()
        elseif a == keys.q then
            break
        end
    elseif event == "timer" and a == timerId then
        refresh()
        draw()
        timerId = os.startTimer(1)
    end
end
