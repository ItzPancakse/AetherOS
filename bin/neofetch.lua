-- neofetch.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- its neofetch

local version = require("version")

local config = (aether and aether.config) or dofile("/lib/config.lua")
local util = dofile("/lib/util.lua")

local uptimeSeconds = (aether and aether.kernel) and (os.clock() - aether.kernel.bootTime) or os.clock()

local lines = {
    { "OS", "AetherOS " .. (version) },
    { "Host", config.get("hostname") or "aether" },
    { "Runtime", _HOST or "CC:Tweaked" },
    { "Uptime", util.formatUptime(uptimeSeconds) },
    { "Shell", "/shell.lua" },
    { "Terminal", term.isColor() and "Advanced (color)" or "Standard" },
    { "Resolution", select(1, term.getSize()) .. "x" .. select(2, term.getSize()) },
    { "Free space", util.formatBytes(fs.getFreeSpace("/")) },
}

local art = {
    "      .--.      ",
    "   .-(    ).    ",
    "  (___.__)__)   ",
    "                ",
}

term.setTextColor(colors.lightBlue)
for _, row in ipairs(art) do
    print(row)
end
term.setTextColor(colors.white)

print("")
for _, entry in ipairs(lines) do
    term.setTextColor(colors.lightBlue)
    term.write(("%-12s"):format(entry[1]))
    term.setTextColor(colors.white)
    print(entry[2])
end
