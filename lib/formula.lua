-- lib/formula.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- Evaluates spreadsheet formulas ("=A1+B2*2", "=SUM(A1:A5)", ...) against
-- a sparse cell table keyed by reference strings like "A1". Formulas are
-- expanded into plain Lua expressions and run through a sandboxed load(),
-- so only arithmetic and a small set of aggregate functions are possible
-- - no filesystem/os access, same principle as lib/crypto.lua's AES sandbox.

local formula = {}

function formula.parseRef(ref)
    local col, row = ref:match("^(%a+)(%d+)$")
    if not col then return nil end
    return col:upper(), tonumber(row)
end

function formula.colToNum(col)
    local n = 0
    for i = 1, #col do
        n = n * 26 + (col:byte(i) - string.byte("A") + 1)
    end
    return n
end

function formula.numToCol(n)
    local s = ""
    while n > 0 do
        local rem = (n - 1) % 26
        s = string.char(65 + rem) .. s
        n = math.floor((n - 1) / 26)
    end
    return s
end

-- Expands "A1:B3" into an ordered list of individual cell refs covering
-- the rectangle between the two corners.
function formula.expandRange(startRef, endRef)
    local c1, r1 = formula.parseRef(startRef)
    local c2, r2 = formula.parseRef(endRef)
    if not c1 or not c2 then return {} end

    local n1, n2 = formula.colToNum(c1), formula.colToNum(c2)
    local colLo, colHi = math.min(n1, n2), math.max(n1, n2)
    local rowLo, rowHi = math.min(r1, r2), math.max(r1, r2)

    local refs = {}
    for row = rowLo, rowHi do
        for col = colLo, colHi do
            table.insert(refs, formula.numToCol(col) .. row)
        end
    end
    return refs
end

local ERROR_VALUE = "#ERROR!"
local CYCLE_VALUE = "#CYCLE!"

-- Returns the computed value of a cell (number or string), resolving
-- formulas recursively. `visiting` guards against circular references.
function formula.evaluate(cells, ref, visiting)
    visiting = visiting or {}
    local raw = cells[ref]
    if raw == nil or raw == "" then return "" end

    if raw:sub(1, 1) ~= "=" then
        local n = tonumber(raw)
        if n then return n end
        return raw
    end

    if visiting[ref] then return CYCLE_VALUE end
    visiting[ref] = true

    local ok, result = pcall(function()
        local expr = raw:sub(2):upper()

        -- Resolves a referenced cell to a number, immediately unwinding
        -- (via error()) if it turns out to be a cycle/error sentinel,
        -- instead of silently folding it into 0.
        local function resolveNumeric(cellRef)
            local v = formula.evaluate(cells, cellRef, visiting)
            if v == CYCLE_VALUE or v == ERROR_VALUE then
                error(v, 0)
            end
            return tonumber(v) or 0
        end

        -- Expand ranges (A1:B3) into comma-separated resolved values,
        -- only inside function calls' parentheses.
        expr = expr:gsub("(%u+%d+):(%u+%d+)", function(a, b)
            local refs = formula.expandRange(a, b)
            local values = {}
            for _, r in ipairs(refs) do
                table.insert(values, tostring(resolveNumeric(r)))
            end
            return table.concat(values, ",")
        end)

        -- Replace remaining bare cell references with their resolved values.
        expr = expr:gsub("(%u+)(%d+)", function(col, row)
            return tostring(resolveNumeric(col .. row))
        end)

        local function sum(...) local t=0 for _,v in ipairs({...}) do t=t+(tonumber(v) or 0) end return t end
        local function avg(...) local a={...} if #a==0 then return 0 end return sum(...)/#a end
        local function count(...) return select("#", ...) end
        local function minf(...) local a={...} local m=nil for _,v in ipairs(a) do v=tonumber(v) or 0 if not m or v<m then m=v end end return m or 0 end
        local function maxf(...) local a={...} local m=nil for _,v in ipairs(a) do v=tonumber(v) or 0 if not m or v>m then m=v end end return m or 0 end

        local env = {
            SUM = sum, AVERAGE = avg, AVG = avg, COUNT = count, MIN = minf, MAX = maxf,
            ROUND = function(n, d) d = d or 0 local m = 10^d return math.floor((n * m) + 0.5) / m end,
            ABS = math.abs, SQRT = math.sqrt, FLOOR = math.floor, CEIL = math.ceil,
            pi = math.pi,
        }

        local chunk = load("return " .. expr, "formula", "t", env)
        if not chunk then error(ERROR_VALUE, 0) end

        local ok2, res = pcall(chunk)
        if not ok2 then error(ERROR_VALUE, 0) end
        if type(res) ~= "number" and type(res) ~= "string" then error(ERROR_VALUE, 0) end
        return res
    end)

    visiting[ref] = nil

    if not ok then
        if result == CYCLE_VALUE or result == ERROR_VALUE then return result end
        return ERROR_VALUE
    end
    return result
end

return formula
