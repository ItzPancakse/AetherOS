-- recovery.lua
-- AetherOS Recovery Shell.
--
-- Run this if AetherOS won't boot normally (missing/corrupt files, bad
-- config, etc). It's deliberately self-contained: it does NOT dofile
-- anything from /lib or /kernel, since those might be exactly what's
-- broken. It only uses native CC:Tweaked APIs (term/fs/os/http) plus the
-- small helper scripts in /recovery/, each of which is loaded safely and
-- has an inline fallback if missing.
--
-- Usage: just run "recovery" (or "recovery.lua") from any working shell,
-- or point the computer's startup at it temporarily, e.g:
--   > recovery

local W, H = term.getSize()

local function header()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.red)
    print("=========================================")
    print("        AetherOS RECOVERY SHELL")
    print("=========================================")
    term.setTextColor(colors.lightGray)
    print("Use this if the normal desktop or shell won't start.")
    print("")
    term.setTextColor(colors.white)
end

local function pause()
    term.setTextColor(colors.lightGray)
    print("")
    print("Press enter to continue...")
    term.setTextColor(colors.white)
    read()
end

-- Safely runs a helper script from /recovery/, falling back to `fallback`
-- (a zero-arg function) if the file is missing or errors out.
local function runHelper(path, fallback)
    if fs.exists(path) then
        local ok, err = pcall(dofile, path)
        if not ok then
            term.setTextColor(colors.red)
            print("Error running " .. path .. ":")
            print(tostring(err))
            term.setTextColor(colors.white)
        end
        return
    end
    if fallback then fallback() end
end

--------------------------------------------------------------------
-- Inline fallbacks (used only if the matching /recovery/*.lua is missing)
--------------------------------------------------------------------

local CORE_FILES = {
    "/startup.lua", "/boot/init.lua", "/boot/logo.lua", "/boot/services.lua",
    "/kernel/kernel.lua", "/lib/util.lua", "/lib/filesystem.lua", "/lib/config.lua",
    "/lib/theme.lua", "/lib/ui.lua", "/lib/wm.lua", "/lib/desktop.lua",
    "/lib/create.lua", "/lib/commands.lua", "/shell.lua",
}

local function fallbackDiagnose()
    print("Checking core files...")
    print("")
    local missing = 0
    for _, path in ipairs(CORE_FILES) do
        local ok = fs.exists(path)
        if ok then
            term.setTextColor(colors.lime)
            print("[ OK ] " .. path)
        else
            term.setTextColor(colors.red)
            print("[MISS] " .. path)
            missing = missing + 1
        end
    end
    term.setTextColor(colors.white)
    print("")
    if missing == 0 then
        term.setTextColor(colors.lime)
        print("All core files present.")
    else
        term.setTextColor(colors.yellow)
        print(missing .. " file(s) missing. Try option 3 (Repair) to fix.")
    end
    term.setTextColor(colors.white)
end

local function fallbackReset()
    if fs.exists("/etc/aether.cfg") then
        fs.delete("/etc/aether.cfg")
        term.setTextColor(colors.lime)
        print("Deleted /etc/aether.cfg - defaults will be used on next boot.")
    else
        print("No config file found - nothing to reset.")
    end
    term.setTextColor(colors.white)
end

local function fallbackRepair()
    if not http then
        term.setTextColor(colors.red)
        print("HTTP API is disabled - can't download repair files.")
        print("Ask a server admin to enable it, or copy files manually.")
        term.setTextColor(colors.white)
        return
    end
    if fs.exists("/netinstall.lua") then
        print("Running netinstall.lua to repair AetherOS...")
        shell.run("/netinstall.lua")
    else
        term.setTextColor(colors.red)
        print("/netinstall.lua and /recovery/repair.lua are both missing.")
        print("Manually re-download AetherOS. See the project README.")
        term.setTextColor(colors.white)
    end
end

local function viewLog()
    if not fs.exists("/var/log.txt") then
        print("No log file found at /var/log.txt.")
        return
    end
    local file = fs.open("/var/log.txt", "r")
    local text = file.readAll()
    file.close()
    term.setTextColor(colors.lightGray)
    print(text)
    term.setTextColor(colors.white)
end

--------------------------------------------------------------------
-- Menu
--------------------------------------------------------------------

local options = {
    { "Safe Shell (basic file commands, no dependencies)", function()
        runHelper("/recovery/safeshell.lua", function()
            print("/recovery/safeshell.lua is missing.")
            print("Falling back to the Lua prompt below (type 'exit' to leave).")
            pause()
            os.run({}, "rom/programs/lua.lua")
        end)
    end },
    { "Diagnose system (check core files)", function()
        runHelper("/recovery/diagnose.lua", fallbackDiagnose)
    end },
    { "Repair / reinstall AetherOS", function()
        runHelper("/recovery/repair.lua", fallbackRepair)
    end },
    { "Reset settings to defaults", function()
        runHelper("/recovery/reset.lua", fallbackReset)
    end },
    { "View crash / boot log", viewLog },
    { "Try normal AetherOS shell (/shell.lua)", function()
        if fs.exists("/shell.lua") then
            local ok, err = pcall(shell.run, "/shell.lua")
            if not ok then
                term.setTextColor(colors.red)
                print("Failed to start: " .. tostring(err))
                term.setTextColor(colors.white)
            end
        else
            print("/shell.lua is missing.")
        end
    end },
    { "Reboot", function() os.reboot() end },
    { "Shutdown", function() os.shutdown() end },
    { "Exit recovery", function() return "exit" end },
}

while true do
    header()
    for i, opt in ipairs(options) do
        term.setTextColor(colors.yellow)
        term.write(("%2d) "):format(i))
        term.setTextColor(colors.white)
        print(opt[1])
    end
    print("")
    term.setTextColor(colors.lightBlue)
    term.write("Choose an option (1-" .. #options .. "): ")
    term.setTextColor(colors.white)

    local choice = tonumber(read())
    local opt = choice and options[choice]

    if not opt then
        term.setTextColor(colors.red)
        print("Not a valid option.")
        term.setTextColor(colors.white)
        pause()
    else
        term.clear()
        term.setCursorPos(1, 1)
        local result = opt[2]()
        if result == "exit" then
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
            term.clear()
            term.setCursorPos(1, 1)
            print("Exiting recovery shell.")
            break
        end
        pause()
    end
end
