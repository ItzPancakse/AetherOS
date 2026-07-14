-- netinstall.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- Downloads and installs AetherOS onto this computer from a GitHub repo.
-- Run with: wget run https://raw.githubusercontent.com/ItzPancakse/AetherOS/main/netinstall.lua
-- If you forked/renamed the repo, update BASE_URL below.

term.clear()
term.setCursorPos(1,1)
local version = require("version")

local BASE_URL = "https://raw.githubusercontent.com/ItzPancakse/AetherOS/main/"

if not http then
    print("HTTP API is disabled on this computer.")
    print("Ask a server admin to enable it in the CC:Tweaked config,")
    print("or copy the AetherOS files over manually.")
    return
end

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)
print("AetherOS network installer")
print("Version: " .. version)
print("")

local function progress(ratio, label)
    ratio = math.max(0, math.min(1, ratio))
    local w = term.getSize()
    local barWidth = math.min(40, w - 12)
    local filled = math.floor(ratio * barWidth + 0.5)
    local x, y = term.getCursorPos()
    term.setCursorPos(1, y)
    term.clearLine()
    term.write("[" .. string.rep("=", filled) .. string.rep(" ", barWidth - filled) .. "] " .. math.floor(ratio * 100) .. "%")
    if label then
        term.setCursorPos(barWidth + 5, y)
        term.write(label:sub(1, w - barWidth - 6))
    end
end

local response = http.get(BASE_URL .. "manifest.txt")
if not response then
    print("Failed to fetch manifest.txt - check your internet connection")
    print("and that BASE_URL points to a valid AetherOS repo.")
    return
end

local manifestText = response.readAll()
response.close()

local files = {}
for line in manifestText:gmatch("[^\r\n]+") do
    line = line:gsub("^%s+", ""):gsub("%s+$", "")
    if #line > 0 then
        table.insert(files, line)
    end
end

print(#files .. " files to install.")
print("")

local failed = {}
local _, startY = term.getCursorPos()

for i, file in ipairs(files) do
    progress((i - 1) / #files, file)

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
        else
            table.insert(failed, file .. " (couldn't open for writing)")
        end
    else
        table.insert(failed, file .. " (download failed)")
    end
end

progress(1, "done")
print("")
print("")

if #failed > 0 then
    term.setTextColor(colors.red)
    print(#failed .. " file(s) failed to install:")
    for _, f in ipairs(failed) do
        print("  - " .. f)
    end
    term.setTextColor(colors.white)
else
    term.setTextColor(colors.lime)
    print("AetherOS installed successfully.")
    term.setTextColor(colors.white)
end

local input

-- Prompt the user to restart the computer and repeat if its invalid
repeat
    write("Reboot your computer? (Y/N): ")
    input = string.upper(read())
    
    if input ~= "Y" and input ~= "y" and input ~= "N" and input ~= "n" then
        print("Invalid input. Please type Y or N.")
    end
until input == "Y" or input == "y" or input == "N" or input == "n" -- very messy system to do this lol 

-- Check the input
if input == "Y" or input == "y" then
    write("Rebooting now...")
    sleep(1)
    term.clear()
    sleep(0.5)
    os.reboot()
elseif input == "N" or input == "n" then
    print("To enter AetherOS manually run 'reboot' to restart the computer into AetherOS.")
else 
    print("Invalid input. Please try again.")
end
