-- whoami.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- self explanatory

local config = (aether and aether.config) or dofile("/lib/config.lua")
print((aether and aether.sessionUser) or config.get("username") or "user")
