-- boot/init.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- AetherOS boot sequence: draws the splash screen, brings up core
-- libraries and the kernel, starts background services, then either
-- launches the desktop environment (on color/advanced terminals) or
-- falls back to the plain CLI shell.

-- Runs before anything else on a fresh install. The wizard reboots the
-- computer itself once it's done, so control normally never returns here
-- on a first boot.

do
    local ok, earlyConfig = pcall(dofile, "/lib/config.lua")
    if ok and earlyConfig.get("firstBoot") then
        if fs.exists("/boot/setup.lua") then
            dofile("/boot/setup.lua")
            return
        end
    end
end

local w, h = term.getSize()

local function centerX(text)
    return math.max(1, math.floor((w - #text) / 2) + 1)
end

local function drawLogo(logo, top)
    local startX = math.max(1, math.floor((w - logo.width) / 2) + 1)
    for row = 1, logo.height do
        local pixels = logo.rows[row]
        for col = 1, logo.width do
            local color = pixels[col]
            if color and color ~= 0 then
                term.setCursorPos(startX + col - 1, top + row - 1)
                term.setBackgroundColor(color)
                term.write(" ")
            end
        end
    end
    term.setBackgroundColor(colors.black)
end

local function bootProgress(ratio, label)
    ratio = math.max(0, math.min(1, ratio))
    local barWidth = math.min(40, w - 10)
    local x = math.max(1, math.floor((w - barWidth) / 2) + 1)
    local y = h - 1
    local filled = math.floor(ratio * barWidth + 0.5)

    term.setCursorPos(1, y)
    term.setBackgroundColor(colors.black)
    term.clearLine()
    term.setCursorPos(x, y)
    term.setTextColor(colors.lightGray)
    term.write("[")
    term.setBackgroundColor(colors.lightBlue)
    term.write(string.rep(" ", filled))
    term.setBackgroundColor(colors.gray)
    term.write(string.rep(" ", barWidth - filled))
    term.setBackgroundColor(colors.black)
    term.write("]")

    if label then
        term.setCursorPos(1, y + 1)
        term.clearLine()
        term.setTextColor(colors.lightGray)
        term.setCursorPos(centerX(label), y + 1)
        term.write(label)
    end
end

local function bootLine(ok, text)
    term.setTextColor(colors.white)
    if ok == nil then
        term.setTextColor(colors.yellow)
        term.write("[WAIT] ")
    elseif ok then
        term.setTextColor(colors.lime)
        term.write("[ OK ] ")
    else
        term.setTextColor(colors.red)
        term.write("[FAIL] ")
    end
    term.setTextColor(colors.white)
    print(text)
end

local isAdvanced = term.isColor()

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)

local logoOk, logo = pcall(dofile, "/boot/logo.lua")
if logoOk and logo and h > logo.height + 6 then
    drawLogo(logo, 2)
    term.setCursorPos(1, logo.height + 3)
else
    term.setCursorPos(1, 2)
end

local function printCentered(text)
    print(string.rep(" ", centerX(text) - 1) .. text)
end

term.setTextColor(colors.lightBlue)
printCentered("AetherOS")
term.setTextColor(colors.lightGray)
printCentered("a linux-like OS for CC:Tweaked")
print("")

local steps = {
    { 0.15, "Mounting root filesystem" },
    { 0.30, "Loading kernel" },
    { 0.45, "Loading core libraries" },
    { 0.60, "Reading configuration" },
    { 0.75, "Starting background services" },
    { 0.90, isAdvanced and "Starting display server" or "Preparing console" },
    { 1.00, "Welcome to AetherOS" },
}

for _, step in ipairs(steps) do
    bootProgress(step[1], step[2])
    sleep(0.12)
end

if fs.exists("/boot/login.lua") then
    local okLogin, loginErr = pcall(dofile, "/boot/login.lua")
    if not okLogin then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.yellow)
        print("")
        print("Login interrupted - continuing without authentication.")
        print("Run 'passwd' once logged in to change your password.")
        term.setTextColor(colors.white)
        sleep(1.5)
    end
end

term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)
term.setTextColor(colors.lightBlue)
print("AetherOS is starting...")
print("")

if not fs.exists("/etc") then fs.makeDir("/etc") end
bootLine(true, "Filesystem ready")

local kernelOk, KernelClass = pcall(dofile, "/kernel/kernel.lua")
if not kernelOk then
    bootLine(false, "Kernel failed to load: " .. tostring(KernelClass))
    return
end
bootLine(true, "Kernel loaded")

_G.aether = _G.aether or {}
aether.kernel = KernelClass.new()

local libOk, libErr = pcall(function()
    aether.util = dofile("/lib/util.lua")
    aether.fs = dofile("/lib/filesystem.lua")
    aether.config = dofile("/lib/config.lua")
    aether.theme = dofile("/lib/theme.lua")
    aether.ui = dofile("/lib/ui.lua")
end)
if not libOk then
    bootLine(false, "Library load failed: " .. tostring(libErr))
    return
end
bootLine(true, "Core libraries loaded")

aether.config.load()
bootLine(true, "Configuration read")
aether.version = aether.config.get("version") or "1.0.0"

if fs.exists("/boot/services.lua") then
    local ok, err = pcall(dofile, "/boot/services.lua")
    if ok then
        bootLine(true, "Background services started")
    else
        bootLine(false, "Services error: " .. tostring(err))
    end
else
    bootLine(false, "Services script missing")
end

sleep(0.2)

if aether.config.get("updateCheckOnBoot") then
    local ok, updateLib = pcall(dofile, "/lib/update.lua")
    if ok then
        local success, data = updateLib.check()
        if success and data.available then
            bootLine(nil, "Update available: " .. data.localVersion .. " -> " .. data.remoteVersion .. " (run 'update install')")
        elseif success then
            bootLine(true, "AetherOS is up to date")
        else
            bootLine(false, "Update check skipped: " .. tostring(data))
        end
    end
end

if isAdvanced then
    bootLine(true, "Advanced computer detected - launching desktop")
    sleep(0.3)
    local ok, err = pcall(dofile, "/lib/desktop.lua")
    if not ok then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.red)
        print("Desktop environment crashed: " .. tostring(err))
        print("Falling back to CLI shell.")
        term.setTextColor(colors.white)
        aether.kernel:spawn("shell", function() shell.run("/shell.lua") end, "system")
        aether.kernel:run()
    end
else
    bootLine(false, "No advanced computer/monitor - graphical desktop unavailable")
    print("")
    print("Type 'gui' to try launching the desktop anyway,")
    print("or 'help' for a list of commands.")
    print("")
    aether.kernel:spawn("shell", function() shell.run("/shell.lua") end, "system")
    aether.kernel:run()
end
