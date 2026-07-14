-- boot/setup.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- AetherOS first-boot setup wizard. Deliberately plain and keyboard-only
-- (looks like an old TTY login/setup session, no mouse needed) so it
-- works on any computer, advanced or not.
-- Creates the first user account, an optional login password for that
-- user, an optional root/admin password (used by `sudo`), lays down the
-- basic folder structure, pulls the latest files from the update
-- channel, then reboots into the freshly configured system.

local config = dofile("/lib/config.lua")

local W, H = term.getSize()

local function tty(text, color)
    term.setTextColor(color or colors.lime)
    print(text)
end

local function banner()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.lime)
    term.clear()
    term.setCursorPos(1, 1)
    print("AetherOS " .. (config.get("version") or "1.0.0") .. " - first boot setup")
    print(string.rep("-", math.min(W, 44)))
    print("")
end

local function ask(prompt, default)
    term.setTextColor(colors.lime)
    if default and default ~= "" then
        term.write(prompt .. " [" .. default .. "]: ")
    else
        term.write(prompt .. ": ")
    end
    term.setTextColor(colors.white)
    local answer = read()
    if (not answer or answer == "") and default then
        return default
    end
    return answer or ""
end

-- Prompts for a new password twice until both entries match. An empty
-- first entry skips straight through (password left unset).
local function askNewPassword(label)
    term.setTextColor(colors.lime)
    print("")
    print(label .. " (leave blank to skip):")
    while true do
        term.write("  Password: ")
        local p1 = read("*")
        print("")
        if p1 == "" then return "" end
        term.write("  Confirm:  ")
        local p2 = read("*")
        print("")
        if p1 == p2 then return p1 end
        term.setTextColor(colors.red)
        print("  Those didn't match - try again.")
        term.setTextColor(colors.lime)
    end
end

--------------------------------------------------------------------
-- Welcome
--------------------------------------------------------------------

banner()
tty("Welcome! Let's set up your new AetherOS install.")
tty("(Leave a field blank to accept the default shown in [brackets].)")
print("")

local hostname = ask("Hostname", "aether")

local username = ask("Username", "user")
while username == "" or not username:match("^[%w_%-]+$") do
    term.setTextColor(colors.red)
    print("Username must be letters/numbers/-/_ only, and can't be blank.")
    term.setTextColor(colors.lime)
    username = ask("Username", "user")
end

local userPassword = askNewPassword("Login password for '" .. username .. "'")
local rootPassword = askNewPassword("Root/admin password (used by 'sudo')")

--------------------------------------------------------------------
-- Confirm
--------------------------------------------------------------------

print("")
tty(string.rep("-", math.min(W, 44)))
tty("Summary:")
tty("  Hostname:       " .. hostname)
tty("  Username:       " .. username)
tty("  Login password: " .. (userPassword ~= "" and "set" or "none - boots straight in"))
tty("  Root password:  " .. (rootPassword ~= "" and "set" or "none - sudo won't prompt"))
print("")

local proceed = ask("Apply these settings and finish setup? (y/n)", "y")
if proceed:lower() ~= "y" and proceed:lower() ~= "yes" then
    tty("", colors.yellow)
    tty("Setup cancelled. Rebooting to try again...", colors.yellow)
    sleep(1.5)
    os.reboot()
    return
end

--------------------------------------------------------------------
-- Apply
--------------------------------------------------------------------

print("")
tty("Applying configuration...")

local okCrypto, crypto = pcall(dofile, "/lib/crypto.lua")

config.set("hostname", hostname)
config.set("username", username)
config.set("users", { username })
if okCrypto then
    config.set("userPasswords", { [username] = crypto.encryptPassword(userPassword) })
    config.set("sudoPassword", crypto.encryptPassword(rootPassword))
    tty("  [ok] passwords encrypted at rest")
else
    config.set("userPasswords", { [username] = userPassword })
    config.set("sudoPassword", rootPassword)
    tty("  [--] couldn't load crypto - passwords saved in plain text", colors.yellow)
end
tty("  [ok] configuration saved")

if not fs.exists("/etc") then fs.makeDir("/etc") end
if not fs.exists("/var") then fs.makeDir("/var") end
if not fs.exists("/home") then fs.makeDir("/home") end
local homeDir = "/home/" .. username
if not fs.exists(homeDir) then fs.makeDir(homeDir) end
tty("  [ok] created /etc, /var, and " .. homeDir)

--------------------------------------------------------------------
-- Pull the latest files
--------------------------------------------------------------------

print("")
tty("Checking for the latest AetherOS files...")

if not http then
    tty("  [--] HTTP API disabled - skipping update check", colors.yellow)
else
    local okLib, updateLib = pcall(dofile, "/lib/update.lua")
    if not okLib then
        tty("  [--] couldn't load the updater: " .. tostring(updateLib), colors.yellow)
    else
        local okCheck, info = updateLib.check()
        if not okCheck then
            tty("  [--] update check failed: " .. tostring(info), colors.yellow)
        elseif not info.available then
            tty("  [ok] already up to date (" .. info.localVersion .. ")")
        else
            tty("  Update available: " .. info.localVersion .. " -> " .. info.remoteVersion)
            tty("  Downloading...")
            local _, by = term.getCursorPos()
            local okInstall, result = updateLib.install(function(i, total, file, ok)
                term.setCursorPos(1, by)
                term.clearLine()
                term.setTextColor(colors.lime)
                term.write("  (" .. i .. "/" .. total .. ") " .. file)
            end)
            print("")
            if okInstall then
                tty("  [ok] " .. result.installed .. "/" .. result.total .. " files updated")
                if #result.failed > 0 then
                    tty("  [--] " .. #result.failed .. " file(s) failed to download", colors.yellow)
                end
            else
                tty("  [--] update failed: " .. tostring(result), colors.yellow)
            end
        end
    end
end

--------------------------------------------------------------------
-- Done
--------------------------------------------------------------------

config.set("firstBoot", false)

print("")
tty(string.rep("-", math.min(W, 44)))
tty("Setup complete! Rebooting into AetherOS as '" .. username .. "'...")
sleep(2)
os.reboot()
