-- update.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- checks and isntalls updates

local updateLib = dofile("/lib/update.lua")
local args = { ... }

local function printBar(i, total, filename, ok)
    local w = term.getSize()
    term.setTextColor(ok and colors.lime or colors.red)
    term.write(ok and "OK  " or "FAIL")
    term.setTextColor(colors.white)
    print(" (" .. i .. "/" .. total .. ") " .. filename)
end

if args[1] == "check" or args[1] == nil then
    term.setTextColor(colors.lightBlue)
    print("Checking for updates...")
    term.setTextColor(colors.white)

    local ok, info = updateLib.check()
    if not ok then
        term.setTextColor(colors.red)
        print("Update check failed: " .. tostring(info))
        term.setTextColor(colors.white)
        return
    end

    print("Installed version: " .. info.localVersion)
    print("Latest version:     " .. info.remoteVersion)
    print("")

    if not info.available then
        term.setTextColor(colors.lime)
        print("AetherOS is up to date.")
        term.setTextColor(colors.white)
        return
    end

    term.setTextColor(colors.yellow)
    print("An update is available.")
    term.setTextColor(colors.white)
    print("Run 'update install' to download and apply it.")

elseif args[1] == "install" then
    term.setTextColor(colors.lightBlue)
    print("Downloading the latest AetherOS files...")
    term.setTextColor(colors.white)
    print("")

    local ok, result = updateLib.install(printBar)
    if not ok then
        term.setTextColor(colors.red)
        print("Update failed: " .. tostring(result))
        term.setTextColor(colors.white)
        return
    end

    print("")
    term.setTextColor(colors.lime)
    print(result.installed .. "/" .. result.total .. " files updated.")
    term.setTextColor(colors.white)

    if #result.failed > 0 then
        term.setTextColor(colors.red)
        print(#result.failed .. " file(s) failed:")
        for _, f in ipairs(result.failed) do
            print("  - " .. f)
        end
        term.setTextColor(colors.white)
    else
        local input
        repeat
            write("Reboot your computer? (Y/N): ")
            input = string.upper(read())

            if input ~= "Y" and input ~= "y" and input ~= "N" and input ~= "n" then
                print("Invalid input. Please type Y or N.")
            end
        until input == "Y" or input == "y" or input == "N" or input == "n"

        if input == "Y" or input == "y" then
            write("Rebooting now...")
            sleep(1)
            term.clear()
            sleep(0.5)
            os.reboot()
        elseif input == "N" or input == "n" then
            print("To complete installation of the update, run 'reboot' to restart the computer.")
        end
    end
else
    print("usage: update [check|install]")
end
