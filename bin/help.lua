-- help.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- list of available commands

local commands = dofile("/lib/commands.lua")
local args = { ... }

if args[1] then
    shell.run("/man.lua", args[1])
    return
end

term.setTextColor(colors.lightBlue)
print("AetherOS commands:")
term.setTextColor(colors.white)

for _, c in ipairs(commands) do
    term.setTextColor(colors.yellow)
    term.write(("%-12s"):format(c.name))
    term.setTextColor(colors.lightGray)
    print(c.desc)
end

term.setTextColor(colors.white)
print("")
print("Run 'man <command>' for usage details on a specific command.")
