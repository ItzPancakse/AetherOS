-- lib/create.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- Integration helpers for controlling Create mod machinery
local create = {}

local REDROUTER_SIDES = { "top", "bottom", "left", "right", "front", "back" }
create.REDROUTER_SIDES = REDROUTER_SIDES

-- Scan every attached peripheral and return a list of
-- { name, types = {...}, methods = {...} }
function create.scan()
    local out = {}
    for _, name in ipairs(peripheral.getNames()) do
        local ok, methods = pcall(peripheral.getMethods, name)
        local types = { peripheral.getType(name) }
        table.insert(out, {
            name = name,
            types = types,
            methods = ok and methods or {},
        })
    end
    return out
end

local function hasMethods(entry, ...)
    local set = {}
    for _, m in ipairs(entry.methods) do set[m] = true end
    for _, needed in ipairs({ ... }) do
        if not set[needed] then return false end
    end
    return true
end

-- Classifies a scanned peripheral entry into a category AetherOS knows
-- how to build a smart UI for. Falls back to "generic".
function create.classify(entry)
    if hasMethods(entry, "getSchedule", "setSchedule") then
        return "train_station"
    end
    if hasMethods(entry, "setOutput", "getAnalogInput", "getAnalogOutput") then
        return "redrouter"
    end
    if hasMethods(entry, "getSpeed", "getStressCapacity") or hasMethods(entry, "getStressUnits") then
        return "kinetic"
    end
    if hasMethods(entry, "getText", "setText") or hasMethods(entry, "setSignal") then
        return "display"
    end
    return "generic"
end

function create.friendlyCategory(cat)
    local names = {
        train_station = "Train Station",
        redrouter = "RedRouter",
        kinetic = "Kinetic/Stress",
        display = "Display/Source-Target",
        generic = "Peripheral",
    }
    return names[cat] or "Peripheral"
end

-- Safely calls a method on a peripheral by name, returns ok, result/err
function create.call(name, method, ...)
    local p = peripheral.wrap(name)
    if not p then return false, "peripheral not found" end
    if not p[method] then return false, "no such method: " .. tostring(method) end
    return pcall(p[method], ...)
end

-- Builds a simple cyclic Create train schedule that loops through a list
-- of station names, waiting `delay` seconds at each one.
function create.buildLoopSchedule(stationNames, delay)
    delay = delay or 5
    local entries = {}
    for _, station in ipairs(stationNames) do
        table.insert(entries, {
            instruction = {
                id = "create:destination",
                data = { text = station },
            },
            conditions = {
                {
                    { id = "create:delay", data = { value = delay, time_unit = 1 } },
                },
            },
        })
    end
    return { cyclic = true, entries = entries }
end

-- Reads back the human-friendly stop list from a schedule (best effort).
function create.describeSchedule(schedule)
    if type(schedule) ~= "table" or not schedule.entries then
        return {}
    end
    local out = {}
    for _, entry in ipairs(schedule.entries) do
        local instr = entry.instruction
        if instr and instr.data and instr.data.text then
            table.insert(out, instr.data.text)
        elseif instr and instr.id then
            table.insert(out, instr.id)
        end
    end
    return out
end

return create
