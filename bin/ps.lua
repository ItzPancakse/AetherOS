-- ps.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- lists all running processes

if not (aether and aether.kernel) then
    print("ps: kernel not running")
    return
end

local procs = aether.kernel:list()

term.setTextColor(colors.lightBlue)
print(("%-5s %-12s %-8s %-8s %s"):format("PID", "NAME", "KIND", "STATUS", "UPTIME"))
term.setTextColor(colors.white)

for _, p in ipairs(procs) do
    print(("%-5d %-12s %-8s %-8s %ds"):format(p.pid, p.name, p.kind, p.status, math.floor(p.uptime)))
end
