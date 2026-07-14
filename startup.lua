--startup.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause

local bootPath = "boot/init.lua"

local version = require("version")

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
