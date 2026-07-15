-- bin/view.lua - a simple read-only pager for viewing any text file
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- without risk of accidentally editing it. Arrow keys/Page Up/Page
-- Down/mouse scroll to move, q to quit.
local args = { ... }
if not args[1] then
    print("usage: view <file>")
    return
end

local path = shell.resolve(args[1])
if not fs.exists(path) or fs.isDir(path) then
    print("view: no such file: " .. args[1])
    return
end

local lines = {}
do
    local file = fs.open(path, "r")
    local line = file.readLine()
    while line do
        table.insert(lines, line)
        line = file.readLine()
    end
    file.close()
end
if #lines == 0 then lines = { "(empty file)" } end

local scrollY = 0
local w, h = term.getSize()
local textH = h - 1

local function draw()
    term.setBackgroundColor(colors.black)
    term.clear()
    for row = 1, textH do
        local lineIndex = row + scrollY
        if lines[lineIndex] then
            term.setCursorPos(1, row)
            term.setTextColor(colors.white)
            term.write(lines[lineIndex]:sub(1, w))
        end
    end
    term.setCursorPos(1, h)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.clearLine()
    local pct = #lines > textH and math.floor(math.min(100, (scrollY + textH) / #lines * 100)) or 100
    term.write((" " .. path .. "  [" .. pct .. "%]  q to quit, arrows/space to scroll"):sub(1, w))
    term.setBackgroundColor(colors.black)
end

local function maxScroll()
    return math.max(0, #lines - textH)
end

draw()
while true do
    local event, a, b, c = os.pullEvent()
    if event == "key" then
        if a == keys.up then scrollY = math.max(0, scrollY - 1)
        elseif a == keys.down then scrollY = math.min(maxScroll(), scrollY + 1)
        elseif a == keys.pageUp then scrollY = math.max(0, scrollY - textH)
        elseif a == keys.pageDown or a == keys.space then scrollY = math.min(maxScroll(), scrollY + textH)
        elseif a == keys.home then scrollY = 0
        elseif a == keys["end"] then scrollY = maxScroll()
        elseif a == keys.q then break end
        draw()
    elseif event == "mouse_scroll" then
        scrollY = math.max(0, math.min(maxScroll(), scrollY + a))
        draw()
    end
end

term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)
