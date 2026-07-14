-- man.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- helps you lol

local commands = dofile("/lib/commands.lua")
local args = { ... }

if not args[1] then
    print("usage: man <command>")
    return
end

for _, c in ipairs(commands) do
    if c.name == args[1] then
        term.setTextColor(colors.yellow)
        print(c.name)
        term.setTextColor(colors.white)
        print("  " .. c.desc)
        term.setTextColor(colors.lightGray)
        print("  usage: " .. c.usage)
        term.setTextColor(colors.white)
        return
    end
end

print("man: no manual entry for '" .. args[1] .. "'")
