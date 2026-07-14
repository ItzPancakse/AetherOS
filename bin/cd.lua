-- cd.lua 
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- change working directory

local args = { ... }
local target = args[1] or "/"
local path = shell.resolve(target)

if not fs.exists(path) then
    print("cd: no such file or directory: " .. target)
    return
end

if not fs.isDir(path) then
    print("cd: not a directory: " .. target)
    return
end

shell.setDir(path)
