-- rmuser.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- deletes a user
local config = (aether and aether.config) or dofile("/lib/config.lua")
local args = { ... }

local name = args[1]
if not name then
    print("usage: rmuser <name> [--keep-home]")
    return
end

local users = config.get("users") or {}
local idx = nil
for i, u in ipairs(users) do
    if u == name then idx = i break end
end

if not idx then
    print("rmuser: no such user '" .. name .. "'")
    return
end

if #users <= 1 then
    print("rmuser: refusing to delete the last remaining user")
    return
end

term.write("Delete user '" .. name .. "'? (y/n): ")
local answer = read()
if answer:lower() ~= "y" and answer:lower() ~= "yes" then
    print("Cancelled.")
    return
end

table.remove(users, idx)
config.set("users", users)

local passwords = config.get("userPasswords") or {}
passwords[name] = nil
config.set("userPasswords", passwords)

-- if the removed user was active, switch to whoever's left
if config.get("username") == name then
    config.set("username", users[1])
    print("Active user was deleted - switched to '" .. users[1] .. "'.")
end

local keepHome = false
for _, a in ipairs(args) do
    if a == "--keep-home" then keepHome = true end
end

local homeDir = "/home/" .. name
if not keepHome and fs.exists(homeDir) then
    fs.delete(homeDir)
    print("Removed " .. homeDir)
end

term.setTextColor(colors.lime)
print("Deleted user '" .. name .. "'.")
term.setTextColor(colors.white)
