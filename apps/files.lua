-- files.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- Files app

local ui = dofile("/lib/ui.lua")
local theme = dofile("/lib/theme.lua")
local fsx = dofile("/lib/filesystem.lua")

theme.refresh()

local args = { ... }
local cwd = args[1] and shell.resolve(args[1]) or "/"
if not fs.isDir(cwd) then cwd = "/" end

local selected = 1
local scroll = 0
local entries = {}
local message = ""

local function refresh()
    entries = fsx.entries(cwd)
    if selected > #entries then selected = #entries end
    if selected < 1 and #entries > 0 then selected = 1 end
end
refresh()

local buttons = {}

local function draw()
    local w, h = term.getSize()
    ui.clear(theme.windowBg)

    ui.fillRect(1, 1, w, 1, theme.panelBg2)
    ui.text(1, 1, (" " .. cwd):sub(1, w), colors.white, theme.panelBg2)

    local listTop = 2
    local listH = h - 3
    if selected - scroll > listH then scroll = selected - listH end
    if selected - scroll < 1 then scroll = selected - 1 end
    scroll = math.max(0, scroll)

    for row = 1, listH do
        local idx = row + scroll
        local entry = entries[idx]
        local y = listTop + row - 1
        if entry then
            local isSel = (idx == selected)
            local bg = isSel and theme.accent or theme.windowBg
            local fg = isSel and colors.black or (entry.isDir and colors.lightBlue or colors.white)
            ui.fillRect(1, y, w, 1, bg)
            local label = entry.isDir and (entry.name .. "/") or entry.name
            local sizeStr = entry.isDir and "" or ("  " .. (entry.size or 0) .. "b")
            ui.text(2, y, label:sub(1, w - #sizeStr - 3), fg, bg)
            if sizeStr ~= "" then
                ui.text(w - #sizeStr, y, sizeStr, fg, bg)
            end
        end
    end

    ui.fillRect(1, h - 1, w, 1, theme.panelBg2)
    ui.text(1, h - 1, message:sub(1, w), colors.yellow, theme.panelBg2)

    buttons = {}
    local labels = { { "Open", 8 }, { "Edit", 8 }, { "New Dir", 10 }, { "Delete", 9 }, { "Up", 6 } }
    local x = 1
    for _, l in ipairs(labels) do
        table.insert(buttons, ui.button(x, h, l[2], l[1], { bg = colors.gray, fg = colors.white, id = l[1] }))
        x = x + l[2]
    end
end

local function selectedPath()
    local e = entries[selected]
    if not e then return nil end
    return fs.combine(cwd, e.name), e
end

local function openSelected()
    local path, e = selectedPath()
    if not path then return end
    if e.isDir then
        cwd = path
        selected, scroll = 1, 0
        refresh()
    else
        local ok, err = pcall(shell.run, "/edit.lua", path)
        if not ok then message = "Could not open: " .. tostring(err) end
        refresh()
    end
end

local function goUp()
    if cwd == "/" or cwd == "" then return end
    local parent = fs.getDir(cwd)
    if parent == "" then parent = "/" end
    cwd = parent
    selected, scroll = 1, 0
    refresh()
end

local function newDir()
    fs.makeDir(fs.combine(cwd, "New Folder"))
    refresh()
    message = "Created 'New Folder'"
end

local function deleteSelected()
    local path, e = selectedPath()
    if not path then return end
    if fs.isReadOnly(path) then
        message = "Cannot delete read-only path"
        return
    end
    fs.delete(path)
    message = "Deleted " .. e.name
    refresh()
end

draw()

while true do
    local event, a, b, c = os.pullEvent()

    if event == "mouse_click" then
        local mx, my = b, c
        local w, h = term.getSize()
        local hit = ui.hitAny(buttons, mx, my)
        if hit then
            message = ""
            if hit.id == "Open" then openSelected()
            elseif hit.id == "Edit" then
                local path = selectedPath()
                if path and not entries[selected].isDir then
                    pcall(shell.run, "/edit.lua", path)
                    refresh()
                end
            elseif hit.id == "New Dir" then newDir()
            elseif hit.id == "Delete" then deleteSelected()
            elseif hit.id == "Up" then goUp()
            end
        elseif my >= 2 and my <= h - 2 then
            local idx = my - 2 + 1 + scroll
            if entries[idx] then
                if idx == selected then
                    openSelected()
                else
                    selected = idx
                end
            end
        end
    elseif event == "key" then
        if a == keys.up then
            selected = math.max(1, selected - 1)
        elseif a == keys.down then
            selected = math.min(#entries, selected + 1)
        elseif a == keys.enter then
            openSelected()
        elseif a == keys.backspace then
            goUp()
        elseif a == keys.q then
            break
        end
    elseif event == "mouse_scroll" then
        scroll = math.max(0, scroll + a)
    end

    draw()
end
