-- settings.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- AetherOS Settings app

local ui = dofile("/lib/ui.lua")
local theme = dofile("/lib/theme.lua")
local config = dofile("/lib/config.lua")
local util = dofile("/lib/util.lua")

theme.refresh()
config.load()

local tabs = { "Appearance", "About", "System" }
local activeTab = 1
local message = ""

local tabButtons, accentButtons, actionButtons = {}, {}, {}

local function draw()
    local w, h = term.getSize()
    ui.clear(theme.windowBg)

    ui.fillRect(1, 1, w, 1, theme.panelBg2)
    tabButtons = {}
    local x = 1
    for i, t in ipairs(tabs) do
        local active = (i == activeTab)
        local box = ui.button(x, 1, #t + 2, t, {
            bg = active and theme.accent or theme.panelBg2,
            fg = active and colors.black or colors.white,
            id = i,
        })
        table.insert(tabButtons, box)
        x = x + #t + 2
    end

    if activeTab == 1 then
        ui.text(2, 3, "Accent color:", colors.white)
        accentButtons = {}
        local ax, ay = 2, 4
        for _, name in ipairs(theme.accentChoices) do
            local box = ui.button(ax, ay, 12, name, { bg = colors[name], fg = colors.black, id = name })
            table.insert(accentButtons, box)
            ay = ay + 1
        end
        ui.text(2, ay + 1, "Current: " .. theme.accentName, colors.lightGray)
    elseif activeTab == 2 then
        ui.text(2, 3, "AetherOS " .. (aether and aether.version or "1.0"), colors.lightBlue)
        ui.text(2, 4, "A linux-like desktop for CC:Tweaked.", colors.white)
        ui.text(2, 5, "Runtime: " .. (_HOST or "CC:Tweaked"), colors.lightGray)
        ui.text(2, 6, "Screen: " .. w .. "x" .. h, colors.lightGray)
        ui.text(2, 7, "Free space: " .. util.formatBytes(fs.getFreeSpace("/")), colors.lightGray)
    elseif activeTab == 3 then
        ui.text(2, 3, "Username: " .. ((aether and aether.sessionUser) or config.get("username") or "user"), colors.white)
        ui.text(2, 4, "Hostname: " .. (config.get("hostname") or "aether"), colors.white)
        ui.text(2, 5, "Installed version: " .. (config.get("version") or "1.0.0"), colors.lightGray)
        actionButtons = {}
        local by = 7
        table.insert(actionButtons, ui.button(2, by, 12, "Reboot", { bg = colors.orange, fg = colors.black, id = "reboot" }))
        table.insert(actionButtons, ui.button(15, by, 12, "Shutdown", { bg = colors.red, fg = colors.white, id = "shutdown" }))
        by = by + 2
        table.insert(actionButtons, ui.button(2, by, 25, "Check for Updates", { bg = colors.lightBlue, fg = colors.black, id = "checkupdate" }))
        by = by + 2
        local checkOnBoot = config.get("updateCheckOnBoot")
        table.insert(actionButtons, ui.toggle(2, by, checkOnBoot, "Check for updates on boot", { id = "toggleupdate" }))
    end

    ui.fillRect(1, h, w, 1, theme.panelBg2)
    ui.text(1, h, message:sub(1, w), colors.yellow, theme.panelBg2)
end

draw()

while true do
    local event, a, b, c = os.pullEvent()

    if event == "mouse_click" then
        local mx, my = b, c
        message = ""
        local tabHit = ui.hitAny(tabButtons, mx, my)
        if tabHit then
            activeTab = tabHit.id
        elseif activeTab == 1 then
            local hit = ui.hitAny(accentButtons, mx, my)
            if hit then
                config.set("accent", hit.id)
                theme.refresh()
                message = "Accent set to " .. hit.id
            end
        elseif activeTab == 3 then
            local hit = ui.hitAny(actionButtons, mx, my)
            if hit then
                if hit.id == "reboot" then
                    os.reboot()
                elseif hit.id == "shutdown" then
                    os.shutdown()
                elseif hit.id == "checkupdate" then
                    local updateLib = dofile("/lib/update.lua")
                    message = "Checking for updates..."
                    draw()
                    local ok, info = updateLib.check()
                    if not ok then
                        message = "Update check failed: " .. tostring(info)
                    elseif info.available then
                        message = "Update available: " .. info.localVersion .. " -> " .. info.remoteVersion .. " (use 'update install')"
                    else
                        message = "Up to date (" .. info.localVersion .. ")."
                    end
                elseif hit.id == "toggleupdate" then
                    config.set("updateCheckOnBoot", not config.get("updateCheckOnBoot"))
                end
            end
        end
        draw()
    elseif event == "key" and a == keys.q then
        break
    end
end
