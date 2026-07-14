--[[ 
lib/wm.lua
Copyright (c) 2026 Pancakse
SPDX-License-Identifier: BSD-3-Clause
The AetherOS window manager. Every window runs a normal CC:Tweaked
program (from /bin or /apps) in its own coroutine with `term`
redirected to that window's buffer. Mouse events are translated to
window-local coordinates before being forwarded, so programs never
need to know where they are on screen.
Compositing trick: each window is really TWO nested CC `window`
objects - an outer one the WM draws chrome (titlebar) onto directly,
and an inner "content" window (parented to the outer one) that the
hosted program treats as `term`. To restack overlapping windows we
simply redraw every window bottom-to-top; window.redraw() re-blits a
window's whole buffer onto its parent, which naturally paints over
whatever was beneath it.
]]--

local theme = dofile("/lib/theme.lua")

local wm = {}

wm.windows = {}     -- ordered bottom -> top
wm.nextId = 1
wm.screenW, wm.screenH = term.getSize()
wm.realTerm = term.current()
wm.focusedId = nil
wm.dragging = nil   -- { id, offsetX, offsetY }
wm.bottomMargin = 0 -- rows reserved at the bottom of the screen (taskbar)

local MIN_W, MIN_H = 20, 6

local function ensureVersionModule()
    package.preload["version"] = package.preload["version"] or function()
        if _G.aether and aether.version then
            return aether.version
        end
        return "unknown"
    end
end

local function usableH()
    return wm.screenH - wm.bottomMargin
end

local function findIndex(id)
    for i, win in ipairs(wm.windows) do
        if win.id == id then return i end
    end
    return nil
end

function wm.get(id)
    local i = findIndex(id)
    return i and wm.windows[i]
end

function wm.focused()
    if not wm.focusedId then return nil end
    return wm.get(wm.focusedId)
end

-- Raises a window to the top of the stack and marks it focused.
function wm.focus(id)
    local i = findIndex(id)
    if not i then return end
    local win = table.remove(wm.windows, i)
    table.insert(wm.windows, win)
    wm.focusedId = id
end

local function clampWindowPos(win)
    win.x = math.max(1, math.min(win.x, wm.screenW - 4))
    win.y = math.max(1, math.min(win.y, usableH() - win.h + 1))
    win.y = math.max(1, win.y)
end

local function repositionWindow(win)
    clampWindowPos(win)
    win.outer.reposition(win.x, win.y, win.w, win.h)
    win.content.reposition(1, 2, win.w, win.h - 1, win.outer)
end

local function drawChrome(win)
    local active = (win.id == wm.focusedId)
    local bg = active and theme.titlebarActive or theme.titlebarInactive
    local fg = active and theme.titlebarText or theme.titlebarTextInactive

    win.outer.setBackgroundColor(bg)
    win.outer.setTextColor(fg)
    win.outer.setCursorPos(1, 1)
    win.outer.clearLine()

    local title = win.title
    if #title > win.w - 4 then title = title:sub(1, win.w - 4) end
    win.outer.setCursorPos(2, 1)
    win.outer.write(title)

    win.outer.setCursorPos(win.w, 1)
    win.outer.setBackgroundColor(colors.red)
    win.outer.setTextColor(colors.white)
    win.outer.write("x")
end

-- Full redraw/composite pass: bottom to top, content then chrome.
function wm.compositeAll()
    for _, win in ipairs(wm.windows) do
        drawChrome(win)
        win.content.redraw()
        win.outer.redraw()
    end
end

-- Spawns a new window running `program` (a path) with `args`.
-- opts: title, x, y, w, h
function wm.spawnWindow(program, args, opts)
    opts = opts or {}
    local w = math.max(MIN_W, opts.w or 34)
    local h = math.max(MIN_H, math.min(opts.h or 14, usableH() - 1))
    local x = opts.x or math.max(2, math.floor((wm.screenW - w) / 2) + (#wm.windows % 4) * 2)
    local y = opts.y or math.max(2, math.floor((usableH() - h) / 2) + (#wm.windows % 4) * 1)

    local id = wm.nextId
    wm.nextId = wm.nextId + 1

    local outer = window.create(wm.realTerm, x, y, w, h, true)
    local content = window.create(outer, 1, 2, w, h - 1, true)

    local win = {
        id = id,
        title = opts.title or program,
        x = x, y = y, w = w, h = h,
        outer = outer,
        content = content,
        program = program,
        args = args or {},
    }

    win.co = coroutine.create(function()
        ensureVersionModule()
        local prev = term.redirect(win.content)
        pcall(shell.run, program, table.unpack(win.args))
        term.redirect(prev)
    end)
    win.status = "running"
    win.filter = nil

    table.insert(wm.windows, win)
    wm.focus(id)

    -- prime the coroutine so it renders its first frame
    wm.resumeWindow(win, nil)
    wm.compositeAll()

    if aether and aether.kernel then
        win.pid = aether.kernel:spawn("win:" .. win.title, function() end, "window")
    end

    return id
end

function wm.resumeWindow(win, event)
    if not win or win.status ~= "running" then return end
    if event ~= nil and win.filter ~= nil and event[1] ~= win.filter and event[1] ~= "terminate" then
        return
    end
    local prev = term.redirect(win.content)
    local args = event or {}
    local ok, result = coroutine.resume(win.co, table.unpack(args))
    term.redirect(prev)

    if coroutine.status(win.co) == "dead" then
        win.status = "dead"
    else
        win.filter = result
    end
end

function wm.findByPid(pid)
    for _, win in ipairs(wm.windows) do
        if win.pid == pid then return win end
    end
    return nil
end

function wm.closeWindow(id)
    local i = findIndex(id)
    if not i then return end
    local win = wm.windows[i]
    table.remove(wm.windows, i)
    if aether and aether.kernel and win.pid then
        aether.kernel:kill(win.pid)
    end
    if wm.focusedId == id then
        local top = wm.windows[#wm.windows]
        wm.focusedId = top and top.id or nil
    end
end

-- Removes dead windows (programs that exited on their own).
function wm.reapDead()
    local dead = {}
    for _, win in ipairs(wm.windows) do
        if win.status == "dead" then
            table.insert(dead, win.id)
        end
    end
    for _, id in ipairs(dead) do
        wm.closeWindow(id)
    end
    return #dead > 0
end

-- Handles a raw OS event, routing to chrome or the appropriate window.
-- Returns true if something changed and a recomposite is needed.
function wm.handleEvent(event)
    local kind = event[1]

    if kind == "mouse_click" then
        local button, mx, my = event[2], event[3], event[4]

        -- topmost window whose rect contains the click
        for i = #wm.windows, 1, -1 do
            local win = wm.windows[i]
            if mx >= win.x and mx <= win.x + win.w - 1 and my >= win.y and my <= win.y + win.h - 1 then
                wm.focus(win.id)

                if my == win.y then
                    -- titlebar
                    if mx == win.x + win.w - 1 then
                        wm.closeWindow(win.id)
                    else
                        wm.dragging = { id = win.id, offsetX = mx - win.x, offsetY = my - win.y }
                    end
                else
                    local localX = mx - win.x + 1
                    local localY = my - win.y
                    wm.resumeWindow(win, { "mouse_click", button, localX, localY })
                end
                return true
            end
        end
        return false

    elseif kind == "mouse_drag" then
        if wm.dragging then
            local mx, my = event[3], event[4]
            local win = wm.get(wm.dragging.id)
            if win then
                win.x = mx - wm.dragging.offsetX
                win.y = my - wm.dragging.offsetY
                repositionWindow(win)
                return true
            end
        else
            local win = wm.focused()
            if win then
                local mx, my = event[3], event[4]
                if my > win.y and mx >= win.x and mx <= win.x + win.w - 1 and my <= win.y + win.h - 1 then
                    local localX = mx - win.x + 1
                    local localY = my - win.y
                    wm.resumeWindow(win, { "mouse_drag", event[2], localX, localY })
                    return true
                end
            end
        end
        return false

    elseif kind == "mouse_up" then
        if wm.dragging then
            wm.dragging = nil
            return true
        end
        local win = wm.focused()
        if win then
            local mx, my = event[3], event[4]
            local localX = mx - win.x + 1
            local localY = my - win.y
            wm.resumeWindow(win, { "mouse_up", event[2], localX, localY })
        end
        return false

    elseif kind == "mouse_scroll" then
        local mx, my = event[3], event[4]
        for i = #wm.windows, 1, -1 do
            local win = wm.windows[i]
            if mx >= win.x and mx <= win.x + win.w - 1 and my >= win.y and my <= win.y + win.h - 1 then
                local localX = mx - win.x + 1
                local localY = my - win.y
                wm.resumeWindow(win, { "mouse_scroll", event[2], localX, localY })
                return true
            end
        end
        return false

    elseif kind == "char" or kind == "key" or kind == "key_up" or kind == "paste" then
        local win = wm.focused()
        if win then
            wm.resumeWindow(win, event)
            return true
        end
        return false

    elseif kind == "timer" or kind == "alarm" then
        -- Broadcast so any window waiting on its own timer wakes up.
        local changed = false
        for _, win in ipairs(wm.windows) do
            wm.resumeWindow(win, event)
            changed = true
        end
        return changed
    end

    return false
end

return wm
