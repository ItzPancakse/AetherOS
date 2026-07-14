-- kernel/kernel.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- A small cooperative multitasking kernel for AetherOS.
-- Every running program (services, the desktop session, terminal windows,
-- GUI apps) is represented as a Lua coroutine wrapped in a "process".
-- "system" processes are resumed automatically on every event pulled from
-- the OS event queue (like background services). "window" processes are
-- owned and dispatched manually by the window manager, but are still
-- tracked here so tools like `ps`, `kill` and the Task Manager app can see
-- and manage the whole system.

local Kernel = {}
Kernel.__index = Kernel

function Kernel.new()
    local self = setmetatable({}, Kernel)
    self.processes = {}
    self.nextPid = 1
    self.running = true
    self.bootTime = os.clock()
    return self
end

-- kind: "system" (auto-dispatched every event) or "window" (manual dispatch)
function Kernel:spawn(name, fn, kind)
    local pid = self.nextPid
    self.nextPid = self.nextPid + 1
    local proc = {
        pid = pid,
        name = name,
        kind = kind or "system",
        co = coroutine.create(fn),
        status = "running",
        filter = nil,
        startedAt = os.clock(),
    }
    table.insert(self.processes, proc)
    return pid, proc
end

function Kernel:getProcess(pid)
    for _, p in ipairs(self.processes) do
        if p.pid == pid then return p end
    end
    return nil
end

function Kernel:kill(pid)
    local p = self:getProcess(pid)
    if not p then return false end
    p.status = "dead"
    return true
end

function Kernel:list()
    local out = {}
    for _, p in ipairs(self.processes) do
        table.insert(out, {
            pid = p.pid,
            name = p.name,
            kind = p.kind,
            status = p.status,
            uptime = os.clock() - p.startedAt,
        })
    end
    return out
end

-- Resumes a single process with an event (table, e.g. {"char","a"}).
-- Honors the filter the coroutine last yielded (mirrors os.pullEvent).
function Kernel:resume(proc, event)
    if not proc or proc.status ~= "running" then return end
    if coroutine.status(proc.co) ~= "suspended" then
        -- Already running (e.g. this IS the coroutine currently dispatching,
        -- as happens when kernel:run() is nested) or already dead - skip it
        -- rather than corrupting its state.
        return
    end
    if event ~= nil and proc.filter ~= nil
        and event[1] ~= proc.filter and event[1] ~= "terminate" then
        return
    end

    local args = event or {}
    local ok, result = coroutine.resume(proc.co, table.unpack(args))

    if coroutine.status(proc.co) == "dead" then
        proc.status = "dead"
        if not ok then
            proc.error = result
        end
    else
        proc.filter = result
    end
end

function Kernel:cleanup()
    local alive = {}
    for _, p in ipairs(self.processes) do
        if p.status ~= "dead" then
            table.insert(alive, p)
        end
    end
    self.processes = alive
end

-- Main loop. `onEvent(event)` is called after system processes are
-- dispatched for every event (used by the window manager / shell to
-- handle its own input). Returning false from onEvent stops the kernel.
function Kernel:run(onEvent)
    while self.running do
        local event = { os.pullEventRaw() }

        for _, proc in ipairs(self.processes) do
            if proc.kind == "system" and proc.status == "running" then
                self:resume(proc, event)
            end
        end

        if onEvent then
            local cont = onEvent(event)
            if cont == false then
                self.running = false
            end
        end

        self:cleanup()
    end
end

function Kernel:stop()
    self.running = false
end

return Kernel
