-- su.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- switches active user

local config = (aether and aether.config) or dofile("/lib/config.lua")
local args = { ... }

local users = config.get("users") or { "user" }

if not args[1] then
    print("Current user: " .. (config.get("username") or "user"))
    print("usage: su <name>")
    return
end

local name = args[1]
local found = false
for _, u in ipairs(users) do
    if u == name then found = true break end
end

if not found then
    print("su: no such user '" .. name .. "' (see 'users', or 'sudo mkuser " .. name .. "')")
    return
end

config.set("username", name)
print("Switched to user '" .. name .. "'.")
