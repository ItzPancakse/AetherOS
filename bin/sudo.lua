-- sudo.lua 
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- Like Linux. AetherOS has no real multi-user permissions, so this is mostly
-- about discoverability and (optionally) a password prompt - set one
-- with 'passwd' if you want the prompt.

local config = (aether and aether.config) or dofile("/lib/config.lua")
local args = { ... }

if #args == 0 then
    print("usage: sudo <command> [args...]")
    return
end

local pass = config.get("sudoPassword")
if aether and aether.isRoot then
    pass = nil -- already root, no need to re-authenticate
end
if pass and pass ~= "" then
    local cryptoOk, crypto = pcall(dofile, "/lib/crypto.lua")
    term.write("[sudo] password for " .. (config.get("username") or "user") .. ": ")
    local entered = read("*")
    local matches = cryptoOk and crypto.checkPassword(entered, pass) or (entered == pass)
    if not matches then
        term.setTextColor(colors.red)
        print("Sorry, try again.")
        term.setTextColor(colors.white)
        return
    end
end

local cmd = table.remove(args, 1)
local candidates = {
    "/s" .. cmd .. ".lua",
    "/" .. cmd .. ".lua",
    "/apps/" .. cmd .. ".lua",
}

for _, path in ipairs(candidates) do
    if fs.exists(path) and not fs.isDir(path) then
        local ok, err = pcall(shell.run, path, table.unpack(args))
        if not ok then
            term.setTextColor(colors.red)
            print("sudo: " .. tostring(err))
            term.setTextColor(colors.white)
        end
        return
    end
end

term.setTextColor(colors.red)
print("sudo: " .. cmd .. ": command not found")
term.setTextColor(colors.white)
