-- rm.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- removes a file

local args = { ... }
if #args == 0 then
    print("usage: rm <path> [path2 ...]")
    return
end

for _, name in ipairs(args) do
    local path = shell.resolve(name)
    if not fs.exists(path) then
        print("rm: cannot remove '" .. name .. "': no such file or directory")
    elseif fs.isReadOnly(path) then
        print("rm: cannot remove '" .. name .. "': read-only")
    else
        fs.delete(path)
    end
end
