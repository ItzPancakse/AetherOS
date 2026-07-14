-- touch.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- creates an empty file

local args = { ... }
if #args == 0 then
    print("usage: touch <file>")
    return
end

for _, name in ipairs(args) do
    local path = shell.resolve(name)
    if not fs.exists(path) then
        local file = fs.open(path, "w")
        if file then file.close() end
    end
end
