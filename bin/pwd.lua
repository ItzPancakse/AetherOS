-- pwd.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- prints working directory

local dir = shell.dir()
if dir == "" then dir = "/" else dir = "/" .. dir end
print(dir)
