-- /recovery.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- laucnher recovery shell

if fs.exists("/recovery.lua") then
    shell.run("/recovery.lua")
else
    print("recovery: /recovery.lua is missing.")
end
