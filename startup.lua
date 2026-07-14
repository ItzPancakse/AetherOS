--startup.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause

local bootPath = "boot/init.lua"

local function read_local_version()
    if fs.exists("version.lua") then
        local f = fs.open("version.lua", "r")
        if f then
            local chunk = f.readAll()
            f.close()
            local v = chunk:match('return%(%s*"(.-)"%s*%)') or chunk:match('return%s+"(.-)"')
            if v and #v > 0 then return v end
        end
    end
    if fs.exists("version.txt") then
        local f = fs.open("version.txt", "r")
        if f then
            local v = f.readLine()
            f.close()
            if v then v = v:match("^%s*(.-)%s*$") end
            if v and #v > 0 then return v end
        end
    end
    return nil
end

package.preload["version"] = package.preload["version"] or function()
    return read_local_version() or "unknown"
end

local ok, ver = pcall(require, "version")
local version = ok and ver or "unknown"

if not fs.exists(bootPath) then
    term.setTextColor(colors.red)
    print("ERROR: System could not boot:")
    print("Core boot script missing at " .. bootPath)
    print("Try running netinstall.lua to reinstall AetherOS.")
    return
end

term.clear()
term.setCursorPos(1,1)
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)

local success, err = pcall(function()
    print("Welcome to AetherOS")
    sleep(1)
    print("Version: " .. version)
    sleep(0.5)
    print("Booting...")
    sleep(1)
    shell.run(bootPath)
end)

if not success then
    term.setTextColor(colors.red)
    print("ERROR: System could not boot: ")
    print(tostring(err))
    print("")
    print("Going to recovery shell")
    term.setTextColor(colors.white)
    shell.run("recovery.lua")
end
