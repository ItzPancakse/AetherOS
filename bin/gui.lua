-- gui.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- launcher for the AetherOS desktop environment
if aether and aether.wm then
    print("The desktop environment is already running.")
    return
end

if not term.isColor() then
    print("Warning: this terminal isn't an Advanced Computer/Monitor.")
    print("Mouse input (needed for windows) may not work.")
end

local ok, err = pcall(dofile, "/lib/desktop.lua")
aether.wm = nil
if not ok then
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.red)
    print("Desktop environment crashed: " .. tostring(err))
    term.setTextColor(colors.white)
end
