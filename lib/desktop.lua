-- lib/desktop.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- The AetherOS desktop session: draws the wallpaper, desktop icons and
-- taskbar, and drives the window manager's event loop. This file is
-- dofile()'d once from boot/init.lua (or from `gui`) and only returns
-- when the user logs out / shuts down.

local wm = dofile("/lib/wm.lua")
local theme = dofile("/lib/theme.lua")
local ui = dofile("/lib/ui.lua")
local config = dofile("/lib/config.lua")

aether = aether or {}
aether.wm = wm

theme.refresh()
wm.bottomMargin = 1

local screenW, screenH = term.getSize()
local taskbarY = screenH

local icons = {
    { label = "Terminal", program = "/shell.lua", glyph = ">_", w = 42, h = 16 },
    { label = "Files", program = "/apps/files.lua", glyph = "[]", w = 40, h = 16 },
    { label = "Settings", program = "/apps/settings.lua", glyph = "*", w = 36, h = 14 },
    { label = "Create Ctl", program = "/apps/createctl.lua", glyph = "~", w = 46, h = 17 },
    { label = "Task Mgr", program = "/apps/taskmgr.lua", glyph = "#", w = 40, h = 14 },
    { label = "Text Edit", program = "/edit.lua", glyph = "Ab", w = 40, h = 16 },
}

local startMenuOpen = false

local function iconHitboxes()
    local boxes = {}
    local y = 2
    for i, icon in ipairs(icons) do
        table.insert(boxes, { x1 = 2, y1 = y, x2 = 2 + 10, y2 = y + 1, icon = icon })
        y = y + 4
    end
    return boxes
end

local function drawWallpaper()
    term.setBackgroundColor(theme.desktopBg)
    term.clear()
    -- subtle dotted pattern
    term.setTextColor(theme.panelBg)
    for y = 1, screenH - 1 do
        for x = 1, screenW do
            if (x + y) % 6 == 0 then
                term.setCursorPos(x, y)
                term.write(".")
            end
        end
    end
end

local function drawIcons()
    local y = 2
    for _, icon in ipairs(icons) do
        term.setBackgroundColor(theme.desktopBg)
        term.setTextColor(theme.text)
        term.setCursorPos(3, y)
        term.write(icon.glyph)
        term.setCursorPos(2, y + 1)
        term.write(icon.label)
        y = y + 4
    end
end

local function windowButtons()
    local boxes = {}
    local x = 14
    for _, win in ipairs(wm.windows) do
        local label = " " .. win.title:sub(1, 10) .. " "
        local w = #label
        if x + w < screenW - 10 then
            table.insert(boxes, { x1 = x, y1 = taskbarY, x2 = x + w - 1, y2 = taskbarY, win = win, label = label })
            x = x + w + 1
        end
    end
    return boxes
end

local function drawTaskbar()
    term.setCursorPos(1, taskbarY)
    term.setBackgroundColor(theme.taskbarBg)
    term.setTextColor(theme.text)
    term.clearLine()

    term.setCursorPos(1, taskbarY)
    term.setBackgroundColor(startMenuOpen and theme.accent or theme.taskbarBg)
    term.setTextColor(startMenuOpen and colors.black or theme.accent)
    term.write(" AetherOS ")

    for _, b in ipairs(windowButtons()) do
        local active = (b.win.id == wm.focusedId)
        term.setCursorPos(b.x1, taskbarY)
        term.setBackgroundColor(active and theme.accent or theme.taskbarBg)
        term.setTextColor(active and colors.black or theme.text)
        term.write(b.label)
    end

    local clock = textutils.formatTime(os.time(), true)
    term.setCursorPos(screenW - #clock, taskbarY)
    term.setBackgroundColor(theme.taskbarBg)
    term.setTextColor(theme.textDim)
    term.write(clock)
end

local startMenuBoxes = {}

local function drawStartMenu()
    if not startMenuOpen then return end
    local w = 18
    local h = #icons + 3
    local x = 1
    local y = taskbarY - h

    ui.panel(x, y, w, h, "Start", { bg = theme.panelBg, fg = theme.text })
    startMenuBoxes = {}
    for i, icon in ipairs(icons) do
        local row = y + i
        term.setCursorPos(x + 2, row)
        term.setBackgroundColor(theme.panelBg)
        term.setTextColor(theme.text)
        term.write(icon.label)
        table.insert(startMenuBoxes, { x1 = x + 1, y1 = row, x2 = x + w - 2, y2 = row, icon = icon })
    end

    local row = y + h - 2
    term.setCursorPos(x + 2, row)
    term.setTextColor(colors.red)
    term.write("Shutdown")
    table.insert(startMenuBoxes, { x1 = x + 1, y1 = row, x2 = x + w - 2, y2 = row, action = "shutdown" })

    row = row + 1
    term.setCursorPos(x + 2, row)
    term.setTextColor(colors.orange)
    term.write("Reboot")
    table.insert(startMenuBoxes, { x1 = x + 1, y1 = row, x2 = x + w - 2, y2 = row, action = "reboot" })
end

local function launch(icon)
    wm.spawnWindow(icon.program, {}, { title = icon.label, w = icon.w, h = icon.h })
end

local function redrawAll()
    drawWallpaper()
    drawIcons()
    wm.compositeAll()
    drawTaskbar()
    drawStartMenu()
end

redrawAll()

local kernel = aether.kernel

local function onEvent(event)
    local kind = event[1]
    local changed = false

    if kind == "mouse_click" then
        local mx, my = event[3], event[4]

        if startMenuOpen then
            local hit = ui.hitAny(startMenuBoxes, mx, my)
            startMenuOpen = false
            if hit then
                if hit.icon then
                    launch(hit.icon)
                elseif hit.action == "shutdown" then
                    os.shutdown()
                elseif hit.action == "reboot" then
                    os.reboot()
                end
            end
            changed = true
        elseif my == taskbarY then
            if mx <= 10 then
                startMenuOpen = true
                changed = true
            else
                for _, b in ipairs(windowButtons()) do
                    if ui.hit(b, mx, my) then
                        wm.focus(b.win.id)
                        changed = true
                    end
                end
            end
        else
            local windowHandled = wm.handleEvent(event)
            if windowHandled then
                changed = true
            else
                local hit = ui.hitAny(iconHitboxes(), mx, my)
                if hit then
                    launch(hit.icon)
                    changed = true
                end
            end
        end
    elseif kind == "term_resize" then
        screenW, screenH = term.getSize()
        taskbarY = screenH
        wm.screenW, wm.screenH = screenW, screenH
        changed = true
    else
        changed = wm.handleEvent(event) or changed
    end

    if wm.reapDead() then changed = true end
    if changed then redrawAll() end
end

kernel:run(onEvent)
