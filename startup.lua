--startup.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause

local bootPath = "boot/init.lua"

local function read_boot_mode()
    if not fs.exists("/etc/bootmode") then
        return nil
    end

    local file = fs.open("/etc/bootmode", "r")
    if not file then
        return nil
    end

    local mode = file.readAll()
    file.close()
    if mode then
        mode = mode:gsub("^%s+", ""):gsub("%s+$", "")
    end
    return mode ~= "" and mode or nil
end

local function clear_boot_mode()
    if fs.exists("/etc/bootmode") then
        fs.delete("/etc/bootmode")
    end
end

local function path_exists(path)
    if not path or path == "" then
        return true
    end
    path = path:gsub("^/", "")
    return fs.exists(path)
end

local function setBootMode(mode)
    if not fs.exists("/etc") then
        fs.makeDir("/etc")
    end

    if mode and mode ~= "" then
        local file = fs.open("/etc/bootmode", "w")
        if file then
            file.write(mode)
            file.close()
        end
    else
        clear_boot_mode()
    end
end

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

local bootMode = read_boot_mode()
if bootMode == "recovery" then
    clear_boot_mode()
    shell.run("/recovery.lua")
    return
elseif bootMode and bootMode ~= "normal" then
    clear_boot_mode()
end

local function missing_manifest_files()
    if not fs.exists("manifest.txt") then
        return { "manifest.txt" }
    end

    local file = fs.open("manifest.txt", "r")
    if not file then
        return { "manifest.txt" }
    end

    local missing = {}
    for line in file.readAll():gmatch("[^\r\n]+") do
        local path = line:gsub("^%s+", ""):gsub("%s+$", "")
        if path ~= "" and not path:match("^#") and not path_exists(path) then
            table.insert(missing, path)
        end
    end
    file.close()
    return missing
end

local missingFiles = missing_manifest_files()
if #missingFiles > 0 then
    term.setTextColor(colors.red)
    print("ERROR: Required files are missing:")
    for _, path in ipairs(missingFiles) do
        print("  - " .. path)
    end
    print("")
    print("Entering recovery mode...")
    sleep(1.5)
    setBootMode("recovery")
    shell.run("/recovery.lua")
    return
end

if not fs.exists(bootPath) then
    term.setTextColor(colors.red)
    print("ERROR: System could not boot:")
    print("Core boot script missing at " .. bootPath)
    print("Rebooting to recovery")
    sleep(2)
    setBootMode("recovery")
    os.reboot()
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
