-- createctl.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- A graphical front-end for controlling Create mod machinery (train
-- stations, RedRouters, kinetic networks, and anything else exposed
-- through the CC:C Bridge mod) from inside AetherOS.

local ui = dofile("/lib/ui.lua")
local theme = dofile("/lib/theme.lua")
local create = dofile("/lib/create.lua")

theme.refresh()

local peripherals = {}
local selected = 1
local message = "Scanning peripherals..."
local actionButtons = {}
local listButtons = {}

local function rescan()
    peripherals = create.scan()
    if selected > #peripherals then selected = #peripherals end
    if selected < 1 and #peripherals > 0 then selected = 1 end
    message = #peripherals .. " peripheral(s) found."
end
rescan()

local function selectedEntry()
    return peripherals[selected]
end

-- Prompts the user on the bottom status line for a line of text.
local function prompt(label)
    local w, h = term.getSize()
    ui.fillRect(1, h, w, 1, colors.gray)
    ui.text(1, h, label, colors.white, colors.gray)
    term.setCursorPos(#label + 1, h)
    term.setTextColor(colors.white)
    term.setCursorBlink(true)
    local ok, text = pcall(read)
    term.setCursorBlink(false)
    if not ok then return nil end
    return text
end

local function drawList(x, y, w, h)
    ui.panel(x, y, w, h, "Peripherals", { bg = theme.panelBg, fg = colors.white })
    listButtons = {}
    for i, entry in ipairs(peripherals) do
        local row = y + i
        if row >= y + h - 1 then break end
        local isSel = (i == selected)
        local bg = isSel and theme.accent or theme.panelBg
        local fg = isSel and colors.black or colors.white
        local cat = create.classify(entry)
        ui.fillRect(x + 1, row, w - 2, 1, bg)
        ui.text(x + 1, row, (entry.name):sub(1, w - 2), fg, bg)
        table.insert(listButtons, { x1 = x + 1, y1 = row, x2 = x + w - 2, y2 = row, id = i })
    end
end

local function drawTrainStation(entry, x, y, w, h)
    local name = entry.name
    local okS, station = create.call(name, "getStationName")
    local okP, present = create.call(name, "isTrainPresent")
    local okT, trainName = create.call(name, "getTrainName")

    ui.text(x, y, "Station: " .. (okS and tostring(station) or "?"), colors.white)
    ui.text(x, y + 1, "Train present: " .. (okP and tostring(present) or "?"), colors.white)
    if okP and present then
        ui.text(x, y + 2, "Train name: " .. (okT and tostring(trainName) or "?"), colors.white)
    end

    actionButtons = {}
    local by = y + 4
    local defs = {
        { "Refresh", colors.lightBlue },
        { "Assemble", colors.lime },
        { "Disassemble", colors.orange },
        { "Set Loop Schedule", colors.purple },
        { "Clear Schedule", colors.red },
    }
    for _, d in ipairs(defs) do
        table.insert(actionButtons, ui.button(x, by, w - 2, d[1], { bg = d[2], fg = colors.black, id = d[1] }))
        by = by + 2
    end
end

local function drawRedRouter(entry, x, y, w, h)
    actionButtons = {}
    local row = y
    for _, side in ipairs(create.REDROUTER_SIDES) do
        local ok, out = create.call(entry.name, "getOutput", side)
        local ok2, inp = create.call(entry.name, "getInput", side)
        local label = ("%-7s out:%-3s in:%-3s"):format(side, ok and tostring(out) or "?", ok2 and tostring(inp) or "?")
        table.insert(actionButtons, ui.button(x, row, w - 2, label, { bg = colors.gray, fg = colors.white, id = "toggle:" .. side }))
        row = row + 2
    end
end

local function drawKinetic(entry, x, y, w, h)
    local labels = { "getSpeed", "getStressCapacity", "getStressUnits", "getKineticSpeed" }
    local row = y
    for _, method in ipairs(labels) do
        local ok, val = create.call(entry.name, method)
        if ok then
            ui.text(x, row, method .. ": " .. tostring(val), colors.white)
            row = row + 1
        end
    end
    actionButtons = { ui.button(x, row + 1, w - 2, "Refresh", { bg = colors.lightBlue, fg = colors.black, id = "Refresh" }) }
end

local function drawGeneric(entry, x, y, w, h)
    ui.text(x, y, "Type: " .. table.concat(entry.types, ", "), colors.lightGray)
    ui.text(x, y + 1, "Methods (click to call):", colors.white)
    actionButtons = {}
    local row = y + 2
    for _, m in ipairs(entry.methods) do
        if row >= y + h - 2 then break end
        table.insert(actionButtons, ui.button(x, row, w - 2, m, { bg = colors.gray, fg = colors.white, id = "call:" .. m }))
        row = row + 1
    end
end

local function draw()
    local w, h = term.getSize()
    ui.clear(theme.windowBg)

    local listW = math.floor(w * 0.35)
    drawList(1, 1, listW, h - 1)

    local dx, dy, dw = listW + 2, 2, w - listW - 2
    actionButtons = {}

    local entry = selectedEntry()
    if entry then
        local cat = create.classify(entry)
        ui.text(dx, 1, entry.name .. "  [" .. create.friendlyCategory(cat) .. "]", colors.lightBlue)
        if cat == "train_station" then
            drawTrainStation(entry, dx, dy, dw, h)
        elseif cat == "redrouter" then
            drawRedRouter(entry, dx, dy, dw, h)
        elseif cat == "kinetic" then
            drawKinetic(entry, dx, dy, dw, h)
        else
            drawGeneric(entry, dx, dy, dw, h)
        end
    else
        ui.text(dx, 1, "No peripherals attached.", colors.lightGray)
    end

    ui.fillRect(1, h, w, 1, colors.gray)
    ui.text(1, h, message:sub(1, w), colors.yellow, colors.gray)
end

draw()

while true do
    local event, a, b, c = os.pullEvent()

    if event == "mouse_click" then
        local mx, my = b, c
        message = ""

        local listHit = ui.hitAny(listButtons, mx, my)
        if listHit then
            selected = listHit.id
        else
            local hit = ui.hitAny(actionButtons, mx, my)
            local entry = selectedEntry()
            if hit and entry then
                local cat = create.classify(entry)
                if hit.id == "Refresh" then
                    rescan()
                elseif hit.id == "Assemble" then
                    local ok, err = create.call(entry.name, "assemble")
                    message = ok and "Assembled." or ("Failed: " .. tostring(err))
                elseif hit.id == "Disassemble" then
                    local ok, err = create.call(entry.name, "disassemble")
                    message = ok and "Disassembled." or ("Failed: " .. tostring(err))
                elseif hit.id == "Clear Schedule" then
                    local ok, err = create.call(entry.name, "clearSchedule")
                    message = ok and "Schedule cleared." or ("Failed: " .. tostring(err))
                elseif hit.id == "Set Loop Schedule" then
                    local stops = prompt("Stations (comma separated): ")
                    if stops and #stops > 0 then
                        local names = {}
                        for s in stops:gmatch("[^,]+") do
                            table.insert(names, (s:gsub("^%s+", ""):gsub("%s+$", "")))
                        end
                        local delayStr = prompt("Delay seconds at each stop (default 5): ")
                        local delay = tonumber(delayStr) or 5
                        local schedule = create.buildLoopSchedule(names, delay)
                        local ok, err = create.call(entry.name, "setSchedule", schedule)
                        message = ok and ("Loop schedule set: " .. table.concat(names, " -> ")) or ("Failed: " .. tostring(err))
                    end
                elseif hit.id:match("^toggle:") then
                    local side = hit.id:sub(8)
                    local ok, current = create.call(entry.name, "getOutput", side)
                    local ok2, err = create.call(entry.name, "setOutput", side, not (ok and current))
                    message = ok2 and ("Toggled " .. side) or ("Failed: " .. tostring(err))
                elseif hit.id:match("^call:") then
                    local method = hit.id:sub(6)
                    local argStr = prompt("Args for " .. method .. " (comma separated, blank for none): ")
                    local parsed = {}
                    if argStr and #argStr > 0 then
                        for token in argStr:gmatch("[^,]+") do
                            token = token:gsub("^%s+", ""):gsub("%s+$", "")
                            if token == "true" then table.insert(parsed, true)
                            elseif token == "false" then table.insert(parsed, false)
                            elseif tonumber(token) then table.insert(parsed, tonumber(token))
                            else table.insert(parsed, token) end
                        end
                    end
                    local ok, result = create.call(entry.name, method, table.unpack(parsed))
                    if ok then
                        local resOk, resStr = pcall(textutils.serialize, result)
                        message = "OK: " .. (resOk and resStr or tostring(result))
                    else
                        message = "Error: " .. tostring(result)
                    end
                end
            end
        end
        draw()
    elseif event == "key" then
        if a == keys.up then
            selected = math.max(1, selected - 1)
        elseif a == keys.down then
            selected = math.min(#peripherals, selected + 1)
        elseif a == keys.r then
            rescan()
        elseif a == keys.q then
            break
        end
        draw()
    end
end
