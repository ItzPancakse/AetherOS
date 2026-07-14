-- reset.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- Resets AetherOS settings and shell history to defaults. Useful if a
-- bad config value (e.g. a broken accent color) is stopping things from
-- drawing correctly.

print("Reset AetherOS settings")
print("------------------------")
print("This will delete /etc/aether.cfg, restoring default settings")
print("(username, hostname, accent color, passwords, wallpaper).")
print("The first-boot setup wizard will run again on next boot.")
print("")
term.write("Proceed? (y/n): ")
local answer = read()

if answer:lower() ~= "y" and answer:lower() ~= "yes" then
    print("Cancelled.")
    return
end

if fs.exists("/etc/aether.cfg") then
    fs.delete("/etc/aether.cfg")
    term.setTextColor(colors.lime)
    print("Deleted /etc/aether.cfg.")
    term.setTextColor(colors.white)
else
    print("No config file was present.")
end

if fs.exists("/etc/aether.key") then
    fs.delete("/etc/aether.key")
    print("Deleted /etc/aether.key (a fresh one will be generated as needed).")
end

if fs.exists("/var/log.txt") then
    term.write("Also clear the boot/crash log? (y/n): ")
    local clearLog = read()
    if clearLog:lower() == "y" or clearLog:lower() == "yes" then
        fs.delete("/var/log.txt")
        print("Cleared /var/log.txt.")
    end
end

print("")
term.setTextColor(colors.lime)
print("Done. Reboot to apply.")
term.setTextColor(colors.white)
