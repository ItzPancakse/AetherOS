-- uname.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- prints the OS name and version, and the hostname
local config = (aether and aether.config) or dofile("/lib/config.lua")
print("AetherOS " .. (aether and aether.version or "1.0") .. " (" .. (config.get("hostname") or "aether") .. ") " .. _HOST)
