-- history.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- show recent shell history

local hist = (aether and aether.shellHistory) or {}

if #hist == 0 then
    print("No history yet.")
    return
end

for i, line in ipairs(hist) do
    term.setTextColor(colors.lightGray)
    term.write(("%4d  "):format(i))
    term.setTextColor(colors.white)
    print(line)
end
