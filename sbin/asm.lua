-- asm.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- Package manager for AetherOS.
-- usage: asm install <user/repo>[@branch]
--        asm remove <package>
--        asm update
--        asm upgrade [package]
--        asm list
--        asm info <package>

local asmLib = dofile("/lib/asm.lua")
local args = { ... }
local sub = args[1]

local function log(msg)
    print(msg)
end

local function printUsage()
    print("AetherOS package manager")
    print("")
    print("usage:")
    print("  asm install <user/repo>[@branch]   install a package (+ dependencies)")
    print("  asm remove <package>               remove an installed package")
    print("  asm update                         check all installed packages for updates")
    print("  asm upgrade [package]               upgrade one package, or all of them")
    print("  asm list                           list installed packages")
    print("  asm info <package>                 show details about an installed package")
    print("")
    print("Packages are plain GitHub repos - 'asm install afonya2/hello-world'")
    print("fetches manifest.json + files straight from the repo. Only install")
    print("packages you trust; asm runs whatever code they contain, same as")
    print("apt/pip/npm would.")
end

if sub == "install" then
    if not args[2] then
        print("usage: asm install <user/repo>[@branch]")
        return
    end
    local ok, result = asmLib.installPackage(args[2], log)
    if ok then
        term.setTextColor(colors.lime)
        print("Done.")
        term.setTextColor(colors.white)
    else
        term.setTextColor(colors.red)
        print("Install failed: " .. tostring(result))
        term.setTextColor(colors.white)
    end

elseif sub == "remove" then
    if not args[2] then
        print("usage: asm remove <package>")
        return
    end
    term.write("Remove package '" .. args[2] .. "'? (y/n): ")
    local answer = read()
    if answer:lower() ~= "y" and answer:lower() ~= "yes" then
        print("Cancelled.")
        return
    end
    local ok, result = asmLib.removePackage(args[2], log)
    term.setTextColor(ok and colors.lime or colors.red)
    print(result)
    term.setTextColor(colors.white)

elseif sub == "update" then
    local ok, cache = asmLib.checkUpdates(log)
    print("")
    local count = 0
    for name, info in pairs(cache) do
        if info.available then
            count = count + 1
            term.setTextColor(colors.yellow)
            print("  " .. name .. ": " .. info.installed .. " -> " .. info.latest)
            term.setTextColor(colors.white)
        end
    end
    if count == 0 then
        term.setTextColor(colors.lime)
        print("Everything is up to date.")
        term.setTextColor(colors.white)
    else
        print(count .. " package(s) can be upgraded. Run 'asm upgrade' to install them.")
    end

elseif sub == "upgrade" then
    if args[2] then
        local ok, result = asmLib.upgradePackage(args[2], log)
        term.setTextColor(ok and colors.lime or colors.red)
        print(ok and ("Upgraded " .. args[2] .. ".") or ("Upgrade failed: " .. tostring(result)))
        term.setTextColor(colors.white)
    else
        local results = asmLib.upgradeAll(log)
        if #results == 0 then
            print("No packages installed.")
            return
        end
        print("")
        for _, r in ipairs(results) do
            term.setTextColor(r.ok and colors.lime or colors.red)
            print((r.ok and "  [ok] " or "  [--] ") .. r.name .. (r.ok and "" or (": " .. tostring(r.err))))
            term.setTextColor(colors.white)
        end
    end

elseif sub == "list" then
    local db = asmLib.loadDB()
    local names = {}
    for name in pairs(db) do table.insert(names, name) end
    table.sort(names)
    if #names == 0 then
        print("No packages installed.")
        return
    end
    term.setTextColor(colors.lightBlue)
    print(("%-16s %-10s %-16s %s"):format("NAME", "VERSION", "AUTHOR", "REPO"))
    term.setTextColor(colors.white)
    for _, name in ipairs(names) do
        local e = db[name]
        print(("%-16s %-10s %-16s %s"):format(name, e.version, e.author or "?", e.repo))
    end

elseif sub == "info" then
    if not args[2] then print("usage: asm info <package>") return end
    local db = asmLib.loadDB()
    local e = db[args[2]]
    if not e then print("asm: no such package: " .. args[2]) return end
    term.setTextColor(colors.lightBlue)
    print(e.name .. " " .. e.version)
    term.setTextColor(colors.white)
    print("Author:       " .. (e.author or "?"))
    print("Description:  " .. (e.description or "(none)"))
    print("Source:       " .. e.repo .. " (" .. e.branch .. ")")
    print("OS version:   " .. (e.os_version or "?"))
    print("Dependencies: " .. (#e.dependencies > 0 and table.concat(e.dependencies, ", ") or "(none)"))
    print("Files:        " .. #e.files)
    local binNames = {}
    for cmd in pairs(e.bin or {}) do table.insert(binNames, cmd) end
    print("Commands:     " .. (#binNames > 0 and table.concat(binNames, ", ") or "(none)"))

else
    printUsage()
end
