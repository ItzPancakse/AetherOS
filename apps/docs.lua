-- apps/docs.lua - AetherOS Docs: a markdown text editor with a real
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- rendered preview (Ctrl+P), built on the markdown.lua parser.
-- Documents are plain .md files - nothing proprietary, easy to move to
-- a floppy disk or read on any other computer.

local markdown = dofile("/lib/markdown.lua")
local htmlrender = dofile("/lib/htmlrender.lua")

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

local cx, cy = 1, 1
local scrollY = 0
local dirty = false
local mode = "edit" -- "edit" | "preview"
local statusMsg = path and ("Editing " .. args[1]) or "New document (no path given - Ctrl+S to name it)"

local realTerm = term.current()
local w, h = term.getSize()
local BODY_TOP = 2 -- row 1 is the header bar

local previewWin = nil
local previewLastLine = 0
local previewScroll = 0
local PREVIEW_BUFFER_HEIGHT = 500

local function clampCursor()
    cy = math.max(1, math.min(cy, #lines))
    cx = math.max(1, math.min(cx, #lines[cy] + 1))
end

local function drawHeader()
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.clearLine()
    local name = path or "[No Name]"
    local left = " " .. name .. (dirty and " *" or "") .. "  [" .. mode .. "]"
    term.write(left:sub(1, w))
    local hint = "^P preview  ^S save  ^Q quit "
    if #hint < w - #left then
        term.setCursorPos(w - #hint + 1, 1)
        term.write(hint)
    end
    term.setBackgroundColor(colors.black)
end

local function drawEdit()
    local textH = h - BODY_TOP + 1
    term.setBackgroundColor(colors.black)
    for row = 1, textH do
        term.setCursorPos(1, BODY_TOP + row - 1)
        term.clearLine()
    end

    if cy - scrollY > textH then scrollY = cy - textH end
    if cy - scrollY < 1 then scrollY = cy - 1 end
    scrollY = math.max(0, scrollY)

    for row = 1, textH do
        local lineIndex = row + scrollY
        if lines[lineIndex] then
            term.setCursorPos(1, BODY_TOP + row - 1)
            term.setTextColor(colors.white)
            term.write(lines[lineIndex]:sub(1, w))
        end
    end

    term.setCursorPos(cx, BODY_TOP + (cy - scrollY) - 1)
end

local function buildPreview()
    local text = table.concat(lines, "\n")
    local ok, html = pcall(markdown, text)
    if not ok then
        statusMsg = "Preview failed to render: " .. tostring(html)
        return false
    end

    previewWin = window.create(realTerm, 1, BODY_TOP, w, PREVIEW_BUFFER_HEIGHT, false)
    local prev = term.redirect(previewWin)
    previewWin.setBackgroundColor(colors.black)
    previewWin.setTextColor(colors.white)
    previewWin.clear()
    previewWin.setCursorPos(1, 1)
    pcall(htmlrender.html, html)
    local _, lastY = previewWin.getCursorPos()
    term.redirect(prev)

    previewLastLine = lastY
    previewScroll = 0
    return true
end

local function drawPreview()
    local textH = h - BODY_TOP + 1
    term.setBackgroundColor(colors.black)
    term.setCursorPos(1, BODY_TOP)
    for row = 1, textH do
        local sourceLine = row + previewScroll
        term.setCursorPos(1, BODY_TOP + row - 1)
        if previewWin and sourceLine <= previewLastLine then
            local text, fg, bg = previewWin.getLine(sourceLine)
            term.blit(text:sub(1, w), fg:sub(1, w), bg:sub(1, w))
        else
            term.clearLine()
        end
    end
    term.setCursorPos(1, h)
end

local function save()
    if not path then
        term.setCursorPos(1, h)
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.white)
        term.clearLine()
        term.write("Save as (path): ")
        local newPath = read()
        term.setBackgroundColor(colors.black)
        if not newPath or newPath == "" then
            statusMsg = "Save cancelled."
            return
        end
        path = shell.resolve(newPath)
        if not path:match("%.md$") then path = path .. ".md" end
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

local function draw()
    drawHeader()
    if mode == "edit" then
        drawEdit()
    else
        drawPreview()
    end
end

local function togglePreview()
    if mode == "edit" then
        if buildPreview() then
            mode = "preview"
            term.setCursorBlink(false)
        end
    else
        mode = "edit"
        term.setCursorBlink(true)
    end
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

    if event == "key" and a == keys.p and ctrlDown then
        togglePreview()
    elseif event == "key" and a == keys.s and ctrlDown then
        save()
    elseif event == "key" and a == keys.q and ctrlDown then
        break

    elseif mode == "edit" then
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
            end
            clampCursor()
        elseif event == "mouse_click" then
            local mx, my = b, c
            if my >= BODY_TOP then
                local lineIndex = (my - BODY_TOP) + 1 + scrollY
                if lines[lineIndex] then
                    cy = lineIndex
                    cx = math.min(mx, #lines[cy] + 1)
                end
            end
        elseif event == "mouse_scroll" then
            scrollY = math.max(0, scrollY + a)
        end

    else -- preview mode
        if event == "key" then
            if a == keys.up then
                previewScroll = math.max(0, previewScroll - 1)
            elseif a == keys.down then
                previewScroll = math.max(0, previewScroll + 1)
            elseif a == keys.pageUp then
                previewScroll = math.max(0, previewScroll - (h - BODY_TOP))
            elseif a == keys.pageDown then
                previewScroll = math.max(0, previewScroll + (h - BODY_TOP))
            end
        elseif event == "mouse_scroll" then
            previewScroll = math.max(0, previewScroll + a * 2)
        end
    end

    draw()
end

term.setCursorBlink(false)
term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)
