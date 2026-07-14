-- repair.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- Repairs a broken AetherOS install by re-downloading files from the
-- source repo. Offers a targeted repair (only missing/empty files) or a
-- full reinstall (everything, overwriting local changes).

local BASE_URL = "https://raw.githubusercontent.com/ItzPancakse/AetherOS/main/"

if not http then
    term.setTextColor(colors.red)
    print("HTTP API is disabled on this computer - can't download repair files.")
    print("Ask a server admin to enable it, or copy the files over manually.")
    term.setTextColor(colors.white)
    return
end

print("AetherOS repair")
print("----------------")
print("Source: " .. BASE_URL)
print("")
print("1) Targeted repair (only missing/empty files)")
print("2) Full reinstall (redownload everything)")
print("3) Cancel")
term.write("> ")
local choice = read()

if choice ~= "1" and choice ~= "2" then
    print("Cancelled.")
    return
end

print("")
print("Fetching manifest...")
local response = http.get(BASE_URL .. "manifest.txt")
if not response then
    term.setTextColor(colors.red)
    print("Failed to fetch manifest.txt - check your internet connection.")
    term.setTextColor(colors.white)
    return
end
local manifestText = response.readAll()
response.close()

local files = {}
for line in manifestText:gmatch("[^\r\n]+") do
    line = line:gsub("^%s+", ""):gsub("%s+$", "")
    if #line > 0 then table.insert(files, line) end
end

-- Also make sure the recovery tools and installer themselves can be repaired.
local extras = { "manifest.txt", "netinstall.lua", "recovery.lua",
    "recovery/diagnose.lua", "recovery/repair.lua",
    "recovery/reset.lua", "recovery/safeshell.lua" }
for _, e in ipairs(extras) do
    local found = false
    for _, f in ipairs(files) do if f == e then found = true break end end
    if not found then table.insert(files, e) end
end

local toFetch = {}
if choice == "2" then
    toFetch = files
else
    for _, file in ipairs(files) do
        local path = "/" .. file
        if not fs.exists(path) or (not fs.isDir(path) and fs.getSize(path) == 0) then
            table.insert(toFetch, file)
        end
    end
end

if #toFetch == 0 then
    term.setTextColor(colors.lime)
    print("Nothing to repair - all files already present.")
    term.setTextColor(colors.white)
    return
end

print(#toFetch .. " file(s) to download.")
print("")

local okCount, failed = 0, {}

for i, file in ipairs(toFetch) do
    term.write("(" .. i .. "/" .. #toFetch .. ") " .. file .. " ... ")
    local fileResponse = http.get(BASE_URL .. file)
    if fileResponse then
        local data = fileResponse.readAll()
        fileResponse.close()

        local dir = fs.getDir(file)
        if dir ~= "" and not fs.exists(dir) then
            fs.makeDir(dir)
        end

        local f = fs.open(file, "w")
        if f then
            f.write(data)
            f.close()
            okCount = okCount + 1
            term.setTextColor(colors.lime)
            print("OK")
            term.setTextColor(colors.white)
        else
            table.insert(failed, file)
            term.setTextColor(colors.red)
            print("write failed")
            term.setTextColor(colors.white)
        end
    else
        table.insert(failed, file)
        term.setTextColor(colors.red)
        print("download failed")
        term.setTextColor(colors.white)
    end
end

print("")
term.setTextColor(colors.lime)
print(okCount .. " file(s) repaired.")
term.setTextColor(colors.white)

if #failed > 0 then
    term.setTextColor(colors.red)
    print(#failed .. " file(s) failed:")
    for _, f in ipairs(failed) do print("  - " .. f) end
    term.setTextColor(colors.white)
else
    print("Reboot to try booting normally again.")
end
