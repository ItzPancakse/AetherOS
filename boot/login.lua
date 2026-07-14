-- boot/login.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- AetherOS login screen. Shows a tile for the main user and any other
-- non-root users, plus an "Other user" option for typing in any
-- username (including root, if a root password has been set). Works
-- with mouse (Advanced Computer/Monitor) and keyboard on any computer.
--
-- Note: if you ever get stuck here, pressing Ctrl+T (the CC:Tweaked
-- terminate key) interrupts login and lets the system continue booting
-- so you can fix things with 'passwd'. This isn't real security - just
-- enough friction to feel like a proper login.

local config = dofile("/lib/config.lua")
local ui = dofile("/lib/ui.lua")
local cryptoOk, crypto = pcall(dofile, "/lib/crypto.lua")
if not cryptoOk then crypto = nil end

_G.aether = _G.aether or {}

local users = config.get("users") or { "user" }
local passwords = config.get("userPasswords") or {}
local hostname = config.get("hostname") or "aether"
local rootPassword = config.get("sudoPassword") or ""

-- Zero-friction path: exactly one user, nobody has a password -> skip
-- the screen entirely and just boot in.
if #users == 1 and (passwords[users[1]] or "") == "" and rootPassword == "" then
    aether.sessionUser = users[1]
    return
end

local W, H = term.getSize()
local selected = 1 -- index into the tile list; last tile is "Other user"

local function tiles()
    local list = {}
    for _, name in ipairs(users) do
        table.insert(list, { label = name, kind = "user", name = name })
    end
    table.insert(list, { label = "Other user...", kind = "other" })
    return list
end

local tileList = tiles()

local function drawTiles()
    term.setBackgroundColor(colors.black)
    term.clear()

    term.setTextColor(colors.lightBlue)
    local title = "AetherOS - " .. hostname
    term.setCursorPos(math.max(1, math.floor((W - #title) / 2) + 1), 2)
    term.write(title)

    term.setTextColor(colors.lightGray)
    local sub = "Choose a user to log in"
    term.setCursorPos(math.max(1, math.floor((W - #sub) / 2) + 1), 3)
    term.write(sub)

    local boxW = math.min(28, W - 4)
    local startX = math.max(1, math.floor((W - boxW) / 2) + 1)
    local startY = 6
    local bottomReserved = 4 -- rows kept clear at the bottom for prompts/hint
    local available = H - bottomReserved - startY
    local spacing = (#tileList * 2 - 1 <= available) and 2 or 1

    local boxes = {}
    for i, t in ipairs(tileList) do
        local y = startY + (i - 1) * spacing
        local isSel = (i == selected)
        local bg = isSel and colors.lightBlue or colors.gray
        local fg = isSel and colors.black or colors.white
        local label = t.kind == "other" and ("+ " .. t.label) or t.label
        boxes[i] = ui.button(startX, y, boxW, label, { bg = bg, fg = fg, id = i })
    end

    term.setTextColor(colors.lightGray)
    local hint = "Arrows+Enter or click a user, number keys also work"
    term.setCursorPos(math.max(1, math.floor((W - #hint) / 2) + 1), H)
    term.write(hint)

    return boxes
end

-- Prompts (in the same screen, below the tiles) for a masked password
-- and returns what was typed, or nil if the prompt was skipped because
-- no password is required.
local function askPassword(label)
    local y = H - 2
    term.setCursorPos(1, y)
    term.clearLine()
    term.setTextColor(colors.white)
    term.write(label)
    local entered = read("*")
    return entered
end

local function flashError(msg)
    local y = H - 1
    term.setCursorPos(1, y)
    term.clearLine()
    term.setTextColor(colors.red)
    local x = math.max(1, math.floor((W - #msg) / 2) + 1)
    term.setCursorPos(x, y)
    term.write(msg)
    term.setTextColor(colors.white)
    sleep(1)
    term.setCursorPos(1, y)
    term.clearLine()
end

local function loginAsUser(name)
    local expected = passwords[name] or ""
    if expected == "" then
        aether.sessionUser = name
        return true
    end
    local entered = askPassword("Password for " .. name .. ": ")
    local matches = crypto and crypto.checkPassword(entered, expected) or (entered == expected)
    if matches then
        aether.sessionUser = name
        return true
    end
    flashError("Incorrect password.")
    return false
end

local function loginOther()
    local y = H - 3
    term.setCursorPos(1, y)
    term.clearLine()
    term.setTextColor(colors.white)
    term.write("Username: ")
    local name = read()

    if name == "root" then
        if rootPassword == "" then
            flashError("Root login is disabled (no root password set).")
            return false
        end
        local entered = askPassword("Password: ")
        local matches = crypto and crypto.checkPassword(entered, rootPassword) or (entered == rootPassword)
        if matches then
            aether.sessionUser = "root"
            aether.isRoot = true
            if not fs.exists("/root") then fs.makeDir("/root") end
            return true
        end
        flashError("Incorrect password.")
        return false
    end

    local known = false
    for _, u in ipairs(users) do
        if u == name then known = true break end
    end
    if not known then
        flashError("No such user '" .. tostring(name) .. "'.")
        return false
    end

    return loginAsUser(name)
end

while true do
    local boxes = drawTiles()

    local event = { os.pullEvent() }
    local kind = event[1]

    local function attemptLogin(index)
        local t = tileList[index]
        if not t then return false end
        selected = index
        if t.kind == "other" then
            return loginOther()
        end
        return loginAsUser(t.name)
    end

    if kind == "mouse_click" then
        local mx, my = event[3], event[4]
        local hit = ui.hitAny(boxes, mx, my)
        if hit and attemptLogin(hit.id) then break end

    elseif kind == "key" then
        local key = event[2]
        if key == keys.up then
            selected = math.max(1, selected - 1)
        elseif key == keys.down then
            selected = math.min(#tileList, selected + 1)
        elseif key == keys.enter then
            if attemptLogin(selected) then break end
        else
            local numberKeys = {
                [keys.one] = 1, [keys.two] = 2, [keys.three] = 3, [keys.four] = 4,
                [keys.five] = 5, [keys.six] = 6, [keys.seven] = 7, [keys.eight] = 8,
                [keys.nine] = 9,
            }
            local n = numberKeys[key]
            if n and attemptLogin(n) then break end
        end
    end
end

term.setBackgroundColor(colors.black)
term.setTextColor(colors.lime)
term.clear()
term.setCursorPos(1, 1)
print("Welcome, " .. aether.sessionUser .. "!")
sleep(0.4)
