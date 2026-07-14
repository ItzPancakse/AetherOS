-- shell.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- Compatibility wrapper: keep older /shell.lua launchers working.

local args = {...}
return shell.run("/bin/shell.lua", table.unpack(args))