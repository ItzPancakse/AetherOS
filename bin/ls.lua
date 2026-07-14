-- ls.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- list directory contents

local args = { ... }
local target = args[1] or shell.dir()
local path = shell.resolve(target)

if not fs.exists(path) then
    print("ls: cannot access '" .. target .. "': no such file or directory")
    return
end

if not fs.isDir(path) then
    print(fs.getName(path))
    return
end

local items = fs.list(path)
table.sort(items, function(a, b) return a:lower() < b:lower() end)

if #items == 0 then
    return
end

local w = term.getSize()
local colWidth = 0
for _, name in ipairs(items) do
    colWidth = math.max(colWidth, #name + 2)
end
colWidth = math.min(colWidth, w)
local perRow = math.max(1, math.floor(w / colWidth))

local col = 0
for _, name in ipairs(items) do
    local full = fs.combine(path, name)
    if fs.isDir(full) then
        term.setTextColor(colors.lightBlue)
        term.write(name .. "/")
        term.setTextColor(colors.white)
        term.write(string.rep(" ", math.max(0, colWidth - #name - 1)))
    else
        term.write(name)
        term.write(string.rep(" ", math.max(0, colWidth - #name)))
    end
    col = col + 1
    if col >= perRow then
        col = 0
        print("")
    end
end
if col ~= 0 then print("") end
