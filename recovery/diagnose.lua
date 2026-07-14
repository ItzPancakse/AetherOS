-- diagnose.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- Detailed system check, run from the recovery shell. Uses /manifest.txt
-- when available (covers every installed file); falls back to a short
-- hardcoded list of critical files otherwise.

local CRITICAL_FALLBACK = {
    "/startup.lua", "/boot/init.lua", "/boot/logo.lua", "/boot/services.lua",
    "/kernel/kernel.lua", "/lib/util.lua", "/lib/filesystem.lua", "/lib/config.lua",
    "/lib/theme.lua", "/lib/ui.lua", "/lib/wm.lua", "/lib/desktop.lua",
    "/lib/create.lua", "/lib/commands.lua", "/shell.lua",
}

local function loadManifest()
    if not fs.exists("/manifest.txt") then return nil end
    local file = fs.open("/manifest.txt", "r")
    local text = file.readAll()
    file.close()
    local list = {}
    for line in text:gmatch("[^\r\n]+") do
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        if #line > 0 then
            table.insert(list, "/" .. line)
        end
    end
    return list
end

print("AetherOS system diagnostics")
print("---------------------------")
print("")

local files = loadManifest()
if files then
    print("Using /manifest.txt (" .. #files .. " files).")
else
    print("No /manifest.txt found - checking a short critical-file list.")
    files = CRITICAL_FALLBACK
end
print("")

local missing, empty, ok = {}, {}, 0

for _, path in ipairs(files) do
    if not fs.exists(path) then
        table.insert(missing, path)
        term.setTextColor(colors.red)
        print("[MISS ] " .. path)
    elseif not fs.isDir(path) and fs.getSize(path) == 0 then
        table.insert(empty, path)
        term.setTextColor(colors.orange)
        print("[EMPTY] " .. path)
    else
        ok = ok + 1
    end
end
term.setTextColor(colors.white)

print("")
print(ok .. " file(s) OK, " .. #missing .. " missing, " .. #empty .. " empty/corrupt.")
print("")

-- Free space check
local okFree, free = pcall(fs.getFreeSpace, "/")
if okFree then
    if free ~= nil and free < 4096 then
        term.setTextColor(colors.yellow)
        print("Warning: very little free space left (" .. free .. " bytes).")
        term.setTextColor(colors.white)
    end
end

-- Config sanity check
if fs.exists("/etc/aether.cfg") then
    local file = fs.open("/etc/aether.cfg", "r")
    local text = file.readAll()
    file.close()
    local okCfg = pcall(textutils.unserialize, text)
    if not okCfg then
        term.setTextColor(colors.red)
        print("/etc/aether.cfg is corrupt (fails to parse).")
        print("Use 'Reset settings to defaults' from the recovery menu.")
        term.setTextColor(colors.white)
    end
end

print("")
if #missing == 0 and #empty == 0 then
    term.setTextColor(colors.lime)
    print("System looks healthy. If it still won't boot, check /var/log.txt")
    print("(recovery menu option 5) for the actual crash error.")
else
    term.setTextColor(colors.yellow)
    print("Use 'Repair / reinstall AetherOS' from the recovery menu to fix")
    print("missing or empty files (requires the HTTP API to be enabled).")
end
term.setTextColor(colors.white)
