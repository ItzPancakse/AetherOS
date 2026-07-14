-- peripherals.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- lists all attached peripherals

local names = peripheral.getNames()

if #names == 0 then
    print("No peripherals attached.")
    return
end

term.setTextColor(colors.lightBlue)
print(("%-16s %s"):format("SIDE/NAME", "TYPE(S)"))
term.setTextColor(colors.white)

for _, name in ipairs(names) do
    local types = { peripheral.getType(name) }
    print(("%-16s %s"):format(name, table.concat(types, ", ")))
end
