-- lib/theme.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- Central color palette for the AetherOS desktop environment.
-- The accent color is user configurable via the Settings app.

local config = dofile("/lib/config.lua")

local theme = {}

local accentNames = { "lightBlue", "cyan", "lime", "magenta", "orange", "pink", "purple", "red", "yellow", "green" }
theme.accentChoices = accentNames

local function accentColor()
    local name = config.get("accent") or "lightBlue"
    return colors[name] or colors.lightBlue
end

function theme.refresh()
    theme.accent = accentColor()
    theme.accentName = config.get("accent") or "lightBlue"
    theme.bg = colors.black
    theme.desktopBg = colors.gray
    theme.panelBg = colors.black
    theme.panelBg2 = colors.gray
    theme.text = colors.white
    theme.textDim = colors.lightGray
    theme.titlebarActive = theme.accent
    theme.titlebarInactive = colors.gray
    theme.titlebarText = colors.black
    theme.titlebarTextInactive = colors.lightGray
    theme.windowBg = colors.black
    theme.taskbarBg = colors.gray
    theme.error = colors.red
    theme.ok = colors.lime
    theme.warn = colors.yellow
    theme.buttonBg = colors.lightGray
    theme.buttonText = colors.black
end

theme.refresh()

return theme
