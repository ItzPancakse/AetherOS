-- cat.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- print file contents

local args = { ... }
if #args == 0 then
    print("usage: cat <file> [file2 ...]")
    return
end

for _, name in ipairs(args) do
    local path = shell.resolve(name)
    if not fs.exists(path) then
        print("cat: " .. name .. ": no such file or directory")
    elseif fs.isDir(path) then
        print("cat: " .. name .. ": is a directory")
    else
        local file = fs.open(path, "r")
        if file then
            print(file.readAll())
            file.close()
        end
    end
end
