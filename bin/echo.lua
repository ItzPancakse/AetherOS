-- echo.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- prints the given arguments to the terminal
local args = { ... }
print(table.concat(args, " "))
