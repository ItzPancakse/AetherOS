-- passwd.lua - set or clear a password
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- usage: passwd            change your own login password
--        passwd root       change the root/admin (sudo) password
--        passwd clear      remove your login password (no more prompt)
--        passwd root clear remove the root password

local config = (aether and aether.config) or dofile("/lib/config.lua")
local cryptoOk, crypto = pcall(dofile, "/lib/crypto.lua")
local args = { ... }

local target = "user"
local clear = false
for _, a in ipairs(args) do
    if a == "root" then target = "root"
    elseif a == "clear" then clear = true end
end

local username = (aether and aether.sessionUser) or config.get("username") or "user"
local label = (target == "root") and "root/admin (sudo) password" or ("login password for '" .. username .. "'")

local function encrypt(pass)
    if cryptoOk then return crypto.encryptPassword(pass) end
    return pass
end

local function setUserPassword(pass)
    local passwords = config.get("userPasswords") or {}
    passwords[username] = pass
    config.set("userPasswords", passwords)
end

if clear then
    if target == "root" then
        config.set("sudoPassword", "")
    else
        setUserPassword("")
    end
    print(label:sub(1, 1):upper() .. label:sub(2) .. " cleared.")
    return
end

term.write("New " .. label .. " (blank to disable): ")
local pass = read("*")
print("")

if pass and pass ~= "" then
    term.write("Confirm: ")
    local confirm = read("*")
    print("")
    if pass ~= confirm then
        term.setTextColor(colors.red)
        print("Passwords didn't match - nothing changed.")
        term.setTextColor(colors.white)
        return
    end
end

local stored = encrypt(pass or "")

if target == "root" then
    config.set("sudoPassword", stored)
else
    setUserPassword(stored)
end

if pass and pass ~= "" then
    print(label:sub(1, 1):upper() .. label:sub(2) .. " set" .. (cryptoOk and " (encrypted at rest)." or "."))
else
    print(label:sub(1, 1):upper() .. label:sub(2) .. " cleared.")
end
