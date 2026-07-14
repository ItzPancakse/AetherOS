-- df.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- prints disk usage information

local util = dofile("/lib/util.lua")

local roots = { "/" }
local drives = fs.list("/")
for _, name in ipairs(drives) do
    if fs.isDir("/" .. name) and fs.isDriveRoot("/" .. name) then
        table.insert(roots, "/" .. name)
    end
end

term.setTextColor(colors.lightBlue)
print(("%-16s %10s %10s"):format("MOUNT", "FREE", "CAPACITY"))
term.setTextColor(colors.white)

for _, root in ipairs(roots) do
    local ok1, free = pcall(fs.getFreeSpace, root)
    local ok2, cap = pcall(fs.getCapacity, root)
    print(("%-16s %10s %10s"):format(
        root,
        util.formatBytes(ok1 and free or nil),
        util.formatBytes(ok2 and cap or nil)
    ))
end
