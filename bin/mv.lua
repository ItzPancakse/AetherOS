-- mv.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- moves a file

local args = { ... }
if #args < 2 then
    print("usage: mv <source> <destination>")
    return
end

local src = shell.resolve(args[1])
local dst = shell.resolve(args[2])

if not fs.exists(src) then
    print("mv: cannot stat '" .. args[1] .. "': no such file or directory")
    return
end

local ok, err = pcall(fs.move, src, dst)
if not ok then
    print("mv: failed: " .. tostring(err))
end
