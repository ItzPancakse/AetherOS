-- lib/ui.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- Minimal widget/drawing toolkit for AetherOS GUI apps.
-- Apps draw into whatever `term` is currently redirected to (their window)
-- and use local, window-relative coordinates.

local util = dofile("/lib/util.lua")

local ui = {}

function ui.clear(bg)
    term.setBackgroundColor(bg or colors.black)
    term.clear()
    term.setCursorPos(1, 1)
end

function ui.fillRect(x, y, w, h, bg)
    term.setBackgroundColor(bg)
    local line = string.rep(" ", w)
    for row = 0, h - 1 do
        term.setCursorPos(x, y + row)
        term.write(line)
    end
end

function ui.text(x, y, str, fg, bg)
    term.setCursorPos(x, y)
    if fg then term.setTextColor(fg) end
    if bg then term.setBackgroundColor(bg) end
    term.write(str)
end

function ui.hline(x, y, w, ch, fg, bg)
    ch = ch or "-"
    term.setCursorPos(x, y)
    if fg then term.setTextColor(fg) end
    if bg then term.setBackgroundColor(bg) end
    term.write(string.rep(ch, w))
end

-- A clickable button. Returns a hitbox table {x1,y1,x2,y2,id} to store
-- for later hit testing with ui.hit().
function ui.button(x, y, w, label, opts)
    opts = opts or {}
    local bg = opts.bg or colors.lightGray
    local fg = opts.fg or colors.black
    ui.fillRect(x, y, w, 1, bg)
    ui.text(x + math.max(0, math.floor((w - #label) / 2)), y, label, fg, bg)
    return { x1 = x, y1 = y, x2 = x + w - 1, y2 = y, id = opts.id or label }
end

-- Test whether (px,py) lands inside a hitbox produced by ui.button/panel.
function ui.hit(box, px, py)
    return px >= box.x1 and px <= box.x2 and py >= box.y1 and py <= box.y2
end

function ui.hitAny(boxes, px, py)
    for _, box in ipairs(boxes) do
        if ui.hit(box, px, py) then return box end
    end
    return nil
end

-- Draws a simple checkbox/toggle indicator.
function ui.toggle(x, y, on, label, opts)
    opts = opts or {}
    local mark = on and "[x]" or "[ ]"
    local fg = opts.fg or colors.white
    local bg = opts.bg or colors.black
    ui.text(x, y, mark .. " " .. label, fg, bg)
    return { x1 = x, y1 = y, x2 = x + 3 + #label, y2 = y, id = opts.id or label }
end

-- Renders a vertical list of selectable rows starting at (x,y), returns hitboxes.
function ui.list(x, y, w, items, selectedIndex, opts)
    opts = opts or {}
    local boxes = {}
    for i, item in ipairs(items) do
        local row = y + i - 1
        local isSel = (i == selectedIndex)
        local bg = isSel and (opts.selBg or colors.lightBlue) or (opts.bg or colors.black)
        local fg = isSel and (opts.selFg or colors.black) or (opts.fg or colors.white)
        ui.fillRect(x, row, w, 1, bg)
        ui.text(x, row, util.padRight(" " .. item, w), fg, bg)
        table.insert(boxes, { x1 = x, y1 = row, x2 = x + w - 1, y2 = row, id = i })
    end
    return boxes
end

-- Draws a titled panel border (single-line box drawing using ascii).
function ui.panel(x, y, w, h, title, opts)
    opts = opts or {}
    local bg = opts.bg or colors.black
    local fg = opts.fg or colors.white
    ui.fillRect(x, y, w, h, bg)
    term.setTextColor(fg)
    term.setBackgroundColor(bg)
    term.setCursorPos(x, y)
    term.write("+" .. string.rep("-", w - 2) .. "+")
    for row = 1, h - 2 do
        term.setCursorPos(x, y + row)
        term.write("|")
        term.setCursorPos(x + w - 1, y + row)
        term.write("|")
    end
    term.setCursorPos(x, y + h - 1)
    term.write("+" .. string.rep("-", w - 2) .. "+")
    if title then
        ui.text(x + 2, y, " " .. title .. " ", fg, bg)
    end
end

function ui.progressBar(x, y, w, ratio, opts)
    opts = opts or {}
    ratio = util.clamp(ratio, 0, 1)
    local filled = util.round(ratio * w)
    term.setCursorPos(x, y)
    term.setBackgroundColor(opts.fillColor or colors.lime)
    term.write(string.rep(" ", filled))
    term.setBackgroundColor(opts.bg or colors.gray)
    term.write(string.rep(" ", w - filled))
end

return ui
