-- date.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- prints the current date and time
print(textutils.formatTime(os.time(), false) .. " (day " .. os.day() .. ")")
