-- cp.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- copy and pastes file
local args = { ... }
if #args < 2 then
    print("usage: cp <source> <destination>")
    return
end

local src = shell.resolve(args[1])
local dst = shell.resolve(args[2])

if not fs.exists(src) then
    print("cp: cannot stat '" .. args[1] .. "': no such file or directory")
    return
end

local ok, err = pcall(fs.copy, src, dst)
if not ok then
    print("cp: failed: " .. tostring(err))
end
