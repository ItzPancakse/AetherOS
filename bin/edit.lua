-- edit.lua - a small nano-like text editor.
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- Works both as a full CLI program and inside an AetherOS window (it only
-- ever uses the currently redirected `term`, so it doesn't care which).

local args = { ... }
local path = args[1] and shell.resolve(args[1]) or nil

local lines = { "" }
if path and fs.exists(path) and not fs.isDir(path) then
    local file = fs.open(path, "r")
    lines = {}
    local line = file.readLine()
    while line do
        table.insert(lines, line)
        line = file.readLine()
    end
    file.close()
    if #lines == 0 then lines = { "" } end
end

local cx, cy = 1, 1     -- cursor column/row (1-based, within `lines`)
local scrollY = 0
local dirty = false
local statusMsg = path and ("Editing " .. args[1]) or "New file (no path given)"

local function size()
    local w, h = term.getSize()
    return w, h - 1 -- reserve bottom row for status bar
end

local function clampCursor()
    cy = math.max(1, math.min(cy, #lines))
    cx = math.max(1, math.min(cx, #lines[cy] + 1))
end

local function draw()
    local w, textH = size()
    term.setBackgroundColor(colors.black)
    term.clear()

    if cy - scrollY > textH then scrollY = cy - textH end
    if cy - scrollY < 1 then scrollY = cy - 1 end
    scrollY = math.max(0, scrollY)

    for row = 1, textH do
        local lineIndex = row + scrollY
        term.setCursorPos(1, row)
        if lines[lineIndex] then
            term.setTextColor(colors.white)
            term.write(lines[lineIndex]:sub(1, w))
        end
    end

    local barY = textH + 1
    term.setCursorPos(1, barY)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.clearLine()
    local info = (path or "[No Name]") .. (dirty and " *" or "") .. "  Ctrl+S save  Ctrl+Q quit"
    term.write(info:sub(1, w))

    term.setBackgroundColor(colors.black)
    term.setCursorPos(cx, cy - scrollY)
end

local function save()
    if not path then
        statusMsg = "No file path - can't save."
        return
    end
    local file = fs.open(path, "w")
    if not file then
        statusMsg = "Failed to save " .. path
        return
    end
    for _, l in ipairs(lines) do
        file.writeLine(l)
    end
    file.close()
    dirty = false
    statusMsg = "Saved " .. path
end

term.setCursorBlink(true)
draw()

local ctrlDown = false

while true do
    local event, a, b, c = os.pullEvent()

    if event == "key" and (a == keys.leftCtrl or a == keys.rightCtrl) then
        ctrlDown = true
    elseif event == "key_up" and (a == keys.leftCtrl or a == keys.rightCtrl) then
        ctrlDown = false
    end

    if event == "char" then
        local line = lines[cy]
        lines[cy] = line:sub(1, cx - 1) .. a .. line:sub(cx)
        cx = cx + 1
        dirty = true
    elseif event == "key" then
        if a == keys.up then
            cy = cy - 1
        elseif a == keys.down then
            cy = cy + 1
        elseif a == keys.left then
            cx = cx - 1
            if cx < 1 and cy > 1 then
                cy = cy - 1
                cx = #lines[cy] + 1
            end
        elseif a == keys.right then
            cx = cx + 1
        elseif a == keys.home then
            cx = 1
        elseif a == keys["end"] then
            cx = #lines[cy] + 1
        elseif a == keys.enter then
            local line = lines[cy]
            local rest = line:sub(cx)
            lines[cy] = line:sub(1, cx - 1)
            table.insert(lines, cy + 1, rest)
            cy = cy + 1
            cx = 1
            dirty = true
        elseif a == keys.backspace then
            if cx > 1 then
                local line = lines[cy]
                lines[cy] = line:sub(1, cx - 2) .. line:sub(cx)
                cx = cx - 1
                dirty = true
            elseif cy > 1 then
                local prevLen = #lines[cy - 1]
                lines[cy - 1] = lines[cy - 1] .. lines[cy]
                table.remove(lines, cy)
                cy = cy - 1
                cx = prevLen + 1
                dirty = true
            end
        elseif a == keys.delete then
            local line = lines[cy]
            if cx <= #line then
                lines[cy] = line:sub(1, cx - 1) .. line:sub(cx + 1)
                dirty = true
            elseif lines[cy + 1] then
                lines[cy] = line .. lines[cy + 1]
                table.remove(lines, cy + 1)
                dirty = true
            end
        elseif a == keys.s and ctrlDown then
            save()
        elseif a == keys.q and ctrlDown then
            if dirty then
                statusMsg = "Unsaved changes - press Ctrl+Q again to quit without saving."
                draw()
                local ev2, a2 = os.pullEvent("key")
                if a2 == keys.q and ctrlDown then
                    break
                end
            else
                break
            end
        end
        clampCursor()
    elseif event == "mouse_click" then
        local mx, my = b, c
        local w, textH = size()
        if my <= textH then
            local lineIndex = my + scrollY
            if lines[lineIndex] then
                cy = lineIndex
                cx = math.min(mx, #lines[cy] + 1)
            end
        end
    elseif event == "mouse_scroll" then
        scrollY = math.max(0, scrollY + a)
    elseif event == "term_resize" then
        -- redraw next loop
    end

    clampCursor()
    draw()
end

term.setCursorBlink(false)
term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)
