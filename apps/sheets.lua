-- apps/sheets.lua - AetherOS Sheets: a grid spreadsheet with formulas
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- ("=A1+B2", "=SUM(A1:A5)", ...). Files are stored as plain .csv, so
-- they're easy to move to a floppy disk or open on any other computer.

local csv = dofile("/lib/csv.lua")
local formula = dofile("/lib/formula.lua")

local args = { ... }
local path = args[1] and shell.resolve(args[1]) or nil

local cells = {}      -- ref ("A1") -> raw string content
local maxCol, maxRow = 8, 20 -- grows to fit loaded data, min visible grid

local function loadFile()
    if not path or not fs.exists(path) then return end
    local rows = csv.read(path)
    for r, row in ipairs(rows) do
        for c, value in ipairs(row) do
            if value ~= "" then
                local ref = formula.numToCol(c) .. r
                cells[ref] = value
                if c > maxCol then maxCol = c end
                if r > maxRow then maxRow = r end
            end
        end
    end
end
loadFile()

local dirty = false
local statusMsg = path and ("Editing " .. args[1]) or "New sheet (no path given - Ctrl+S to name it)"

local w, h = term.getSize()
local ROW_HEADER_TOP = 3
local GUTTER_W = 4
local COL_W = 9

local selCol, selRow = 1, 1
local scrollCol, scrollRow = 1, 1

local editing = false
local editBuffer = ""

local function ref(col, row) return formula.numToCol(col) .. row end

local function visibleCols()
    return math.max(1, math.floor((w - GUTTER_W) / COL_W))
end
local function visibleRows()
    return math.max(1, h - ROW_HEADER_TOP)
end

local function clampScroll()
    local vc, vr = visibleCols(), visibleRows()
    if selCol < scrollCol then scrollCol = selCol end
    if selCol > scrollCol + vc - 1 then scrollCol = selCol - vc + 1 end
    if selRow < scrollRow then scrollRow = selRow end
    if selRow > scrollRow + vr - 1 then scrollRow = selRow - vr + 1 end
    scrollCol = math.max(1, scrollCol)
    scrollRow = math.max(1, scrollRow)
end

local function displayValue(col, row)
    local r = ref(col, row)
    if not cells[r] then return "" end
    local v = formula.evaluate(cells, r)
    if type(v) == "number" then
        -- trim excessive decimals for display
        local s = tostring(v)
        if s:find("%.") then
            s = ("%.4f"):format(v):gsub("0+$", ""):gsub("%.$", "")
        end
        return s
    end
    return tostring(v)
end

local function drawTitle()
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.clearLine()
    local name = path or "[No Name]"
    term.write((" Sheets - " .. name .. (dirty and " *" or "")):sub(1, w))
    local hint = "^S save  ^Q quit "
    if #hint < w - 12 then
        term.setCursorPos(w - #hint + 1, 1)
        term.write(hint)
    end
    term.setBackgroundColor(colors.black)
end

local function drawFormulaBar()
    term.setCursorPos(1, 2)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.lightBlue)
    term.clearLine()
    local label = ref(selCol, selRow) .. ": "
    term.write(label)
    term.setTextColor(colors.white)
    if editing then
        term.write(editBuffer)
    else
        term.write(cells[ref(selCol, selRow)] or "")
    end
end

local function drawGrid()
    local vc, vr = visibleCols(), visibleRows()

    -- column header row
    term.setCursorPos(1, ROW_HEADER_TOP)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.clearLine()
    term.setCursorPos(1, ROW_HEADER_TOP)
    term.write(string.rep(" ", GUTTER_W))
    for i = 0, vc - 1 do
        local col = scrollCol + i
        local x = GUTTER_W + 1 + i * COL_W
        term.setCursorPos(x, ROW_HEADER_TOP)
        local label = formula.numToCol(col)
        if col == selCol then term.setBackgroundColor(colors.lightBlue) term.setTextColor(colors.black) end
        term.write((" " .. label):sub(1, COL_W - 1) .. " ")
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.white)
    end

    for rr = 0, vr - 1 do
        local row = scrollRow + rr
        local y = ROW_HEADER_TOP + 1 + rr
        term.setCursorPos(1, y)
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.white)
        term.write((tostring(row) .. string.rep(" ", GUTTER_W)):sub(1, GUTTER_W))

        for cc = 0, vc - 1 do
            local col = scrollCol + cc
            local x = GUTTER_W + 1 + cc * COL_W
            term.setCursorPos(x, y)
            local isSel = (col == selCol and row == selRow)
            local val = displayValue(col, row)
            local isError = val:sub(1, 1) == "#"
            local bg = isSel and colors.lightBlue or colors.black
            local fg = isSel and colors.black or (isError and colors.red or colors.white)
            term.setBackgroundColor(bg)
            term.setTextColor(fg)
            local text = val
            if #text > COL_W - 1 then text = text:sub(1, COL_W - 2) .. ">" end
            term.write((text .. string.rep(" ", COL_W)):sub(1, COL_W))
        end
    end

    term.setBackgroundColor(colors.black)
end

local function draw()
    clampScroll()
    drawTitle()
    drawFormulaBar()
    drawGrid()
end

local function commitEdit()
    local r = ref(selCol, selRow)
    if editBuffer == "" then
        cells[r] = nil
    else
        cells[r] = editBuffer
    end
    if selCol > maxCol then maxCol = selCol end
    if selRow > maxRow then maxRow = selRow end
    dirty = true
    editing = false
    editBuffer = ""
end

local function save()
    if not path then
        term.setCursorPos(1, h)
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.white)
        term.clearLine()
        term.write("Save as (path): ")
        local newPath = read()
        term.setBackgroundColor(colors.black)
        if not newPath or newPath == "" then
            statusMsg = "Save cancelled."
            return
        end
        path = shell.resolve(newPath)
        if not path:match("%.csv$") then path = path .. ".csv" end
    end

    -- find real bounds (largest used col/row) so we don't write a huge
    -- mostly-empty file
    local usedCol, usedRow = 1, 1
    for r, _ in pairs(cells) do
        local c, row = formula.parseRef(r)
        if c then
            local n = formula.colToNum(c)
            if n > usedCol then usedCol = n end
            if row > usedRow then usedRow = row end
        end
    end

    local rows = {}
    for r = 1, usedRow do
        local rowData = {}
        for c = 1, usedCol do
            rowData[c] = cells[ref(c, r)] or ""
        end
        rows[r] = rowData
    end

    local ok = csv.write(path, rows)
    if ok then
        dirty = false
        statusMsg = "Saved " .. path
    else
        statusMsg = "Failed to save " .. path
    end
end

draw()

local ctrlDown = false

while true do
    local event, a, b, c = os.pullEvent()

    if event == "key" and (a == keys.leftCtrl or a == keys.rightCtrl) then
        ctrlDown = true
    elseif event == "key_up" and (a == keys.leftCtrl or a == keys.rightCtrl) then
        ctrlDown = false
    end

    if event == "key" and a == keys.s and ctrlDown then
        save()
    elseif event == "key" and a == keys.q and ctrlDown then
        if editing then editing = false editBuffer = "" else break end

    elseif editing then
        if event == "char" then
            editBuffer = editBuffer .. a
        elseif event == "key" then
            if a == keys.backspace then
                editBuffer = editBuffer:sub(1, -2)
            elseif a == keys.enter then
                commitEdit()
                selRow = math.min(maxRow + 1, selRow + 1)
            elseif a == keys.escape then
                editing = false
                editBuffer = ""
            end
        end

    else
        if event == "key" then
            if a == keys.up then
                selRow = math.max(1, selRow - 1)
            elseif a == keys.down then
                selRow = selRow + 1
            elseif a == keys.left then
                selCol = math.max(1, selCol - 1)
            elseif a == keys.right then
                selCol = selCol + 1
            elseif a == keys.tab then
                selCol = selCol + 1
            elseif a == keys.enter then
                editing = true
                editBuffer = cells[ref(selCol, selRow)] or ""
            elseif a == keys.delete or a == keys.backspace then
                cells[ref(selCol, selRow)] = nil
                dirty = true
            end
        elseif event == "char" then
            -- typing directly on a cell starts editing it, replacing its content
            editing = true
            editBuffer = a
        elseif event == "mouse_click" then
            local mx, my = b, c
            if my >= ROW_HEADER_TOP + 1 then
                local col = scrollCol + math.floor((mx - GUTTER_W - 1) / COL_W)
                local row = scrollRow + (my - ROW_HEADER_TOP - 1)
                if col >= 1 and row >= 1 then
                    selCol, selRow = col, row
                end
            end
        elseif event == "mouse_scroll" then
            scrollRow = math.max(1, scrollRow + a * 3)
        end
    end

    draw()
end

term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)
