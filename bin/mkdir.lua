-- mkdir.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- creates a directory

local args = { ... }
if #args == 0 then
    print("usage: mkdir <directory>")
    return
end

for _, name in ipairs(args) do
    local path = shell.resolve(name)
    if fs.exists(path) then
        print("mkdir: cannot create directory '" .. name .. "': already exists")
    else
        fs.makeDir(path)
    end
end
