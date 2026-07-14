-- users.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- lists users on your computer
local config = (aether and aether.config) or dofile("/lib/config.lua")
local users = config.get("users") or { "user" }
local current = config.get("username")

for _, u in ipairs(users) do
    if u == current then
        term.setTextColor(colors.lime)
        print(u .. "  (active)")
    else
        term.setTextColor(colors.white)
        print(u)
    end
end
term.setTextColor(colors.white)
