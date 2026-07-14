-- boot/services.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- Registers small background "system" processes with the kernel.
-- These run for the lifetime of the OS and are visible to `ps`/Task Manager.

local kernel = aether.kernel

-- clock: keeps a periodic timer alive so other parts of the system can
-- rely on regular wakeups even if nothing else is happening.
kernel:spawn("clockd", function()
    while true do
        os.startTimer(1)
        os.pullEvent("timer")
    end
end, "system")

-- logd: writes basic boot/crash info to /var/log/aether.log
kernel:spawn("logd", function()
    if not fs.exists("/var") then fs.makeDir("/var") end
    local file = fs.open("/var/log.txt", "a")
    if file then
        file.writeLine("[" .. textutils.formatTime(os.time(), true) .. "] AetherOS services started")
        file.close()
    end
    while true do
        coroutine.yield()
    end
end, "system")
