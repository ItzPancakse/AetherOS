-- kill.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- terminate a task with pid

local args = { ... }
if not (aether and aether.kernel) then
    print("kill: kernel not running")
    return
end

local pid = tonumber(args[1])
if not pid then
    print("usage: kill <pid>")
    return
end

if aether.wm then
    local win = aether.wm.findByPid(pid)
    if win then
        aether.wm.closeWindow(win.id)
        print("Closed window " .. win.title .. " (pid " .. pid .. ")")
        return
    end
end

if aether.kernel:kill(pid) then
    print("Killed process " .. pid)
else
    print("kill: no such process: " .. pid)
end
