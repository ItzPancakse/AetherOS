-- createctl.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- A command-line utility for controlling Create mod machinery

local create = dofile("/lib/create.lua")
local args = { ... }
local sub = args[1]

local function printList()
    local scan = create.scan()
    if #scan == 0 then
        print("No peripherals attached.")
        return
    end
    term.setTextColor(colors.lightBlue)
    print(("%-16s %-16s %s"):format("NAME", "CATEGORY", "TYPE"))
    term.setTextColor(colors.white)
    for _, entry in ipairs(scan) do
        local cat = create.classify(entry)
        print(("%-16s %-16s %s"):format(entry.name, create.friendlyCategory(cat), table.concat(entry.types, ",")))
    end
end

local function printInfo(name)
    if not name then print("usage: createctl info <name>") return end
    local ok, methods = pcall(peripheral.getMethods, name)
    if not ok or not peripheral.isPresent(name) then
        print("createctl: no such peripheral: " .. tostring(name))
        return
    end
    term.setTextColor(colors.lightBlue)
    print(name .. " (" .. table.concat({ peripheral.getType(name) }, ",") .. ")")
    term.setTextColor(colors.white)
    print("Methods:")
    for _, m in ipairs(methods) do
        print("  " .. m)
    end
end

local function callMethod(name, method, methodArgs)
    if not name or not method then
        print("usage: createctl call <name> <method> [args...]")
        return
    end
    local parsed = {}
    for _, a in ipairs(methodArgs) do
        if a == "true" then
            table.insert(parsed, true)
        elseif a == "false" then
            table.insert(parsed, false)
        elseif tonumber(a) then
            table.insert(parsed, tonumber(a))
        else
            table.insert(parsed, a)
        end
    end
    local ok, result = create.call(name, method, table.unpack(parsed))
    if ok then
        print("OK: " .. textutils.serialize(result))
    else
        term.setTextColor(colors.red)
        print("Error: " .. tostring(result))
        term.setTextColor(colors.white)
    end
end

local function trainStatus(name)
    if not name then print("usage: createctl train <name> [assemble|disassemble|clear]") return end
    local ok1, present = create.call(name, "isTrainPresent")
    local ok2, trainName = create.call(name, "getTrainName")
    local ok3, stationName = create.call(name, "getStationName")
    print("Station: " .. (ok3 and tostring(stationName) or "?"))
    print("Train present: " .. (ok1 and tostring(present) or "?"))
    if ok1 and present then
        print("Train name: " .. (ok2 and tostring(trainName) or "?"))
    end

    local action = args[3]
    if action == "assemble" then
        local ok, err = create.call(name, "assemble")
        print(ok and "Assembled." or ("Failed: " .. tostring(err)))
    elseif action == "disassemble" then
        local ok, err = create.call(name, "disassemble")
        print(ok and "Disassembled." or ("Failed: " .. tostring(err)))
    elseif action == "clear" then
        local ok, err = create.call(name, "clearSchedule")
        print(ok and "Schedule cleared." or ("Failed: " .. tostring(err)))
    end
end

if sub == "list" or sub == nil then
    printList()
elseif sub == "info" then
    printInfo(args[2])
elseif sub == "call" then
    local rest = {}
    for i = 4, #args do table.insert(rest, args[i]) end
    callMethod(args[2], args[3], rest)
elseif sub == "train" then
    trainStatus(args[2])
else
    print("usage: createctl [list|info <name>|call <name> <method> [args...]|train <name> [assemble|disassemble|clear]]")
end
