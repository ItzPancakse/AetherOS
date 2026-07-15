-- lib/csv.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- Minimal CSV reader/writer (RFC 4180-ish: double-quote quoting, "" for
-- an embedded quote). Used as the native file format for the Sheets app
-- since it's the most portable, human-readable spreadsheet format -
-- easy to read on any other computer, and trivial to move to a floppy.

local csv = {}

function csv.parseLine(line)
    local fields = {}
    local i = 1
    local n = #line

    while i <= n do
        if line:sub(i, i) == '"' then
            local field = {}
            i = i + 1
            while i <= n do
                local c = line:sub(i, i)
                if c == '"' then
                    if line:sub(i + 1, i + 1) == '"' then
                        table.insert(field, '"')
                        i = i + 2
                    else
                        i = i + 1
                        break
                    end
                else
                    table.insert(field, c)
                    i = i + 1
                end
            end
            table.insert(fields, table.concat(field))
            if line:sub(i, i) == "," then i = i + 1 end
        else
            local commaPos = line:find(",", i, true)
            if commaPos then
                table.insert(fields, line:sub(i, commaPos - 1))
                i = commaPos + 1
            else
                table.insert(fields, line:sub(i))
                i = n + 1
            end
        end
    end

    if n > 0 and line:sub(n, n) == "," then
        table.insert(fields, "")
    end
    if n == 0 then
        return {}
    end

    return fields
end

function csv.encodeField(value)
    local s = tostring(value or "")
    if s:find('[,"\n]') then
        return '"' .. s:gsub('"', '""') .. '"'
    end
    return s
end

function csv.encodeLine(fields)
    local out = {}
    for i, f in ipairs(fields) do out[i] = csv.encodeField(f) end
    return table.concat(out, ",")
end

-- Returns an array of rows, each row an array of string fields.
function csv.read(path)
    if not fs.exists(path) then return {} end
    local file = fs.open(path, "r")
    if not file then return {} end
    local rows = {}
    local line = file.readLine()
    while line do
        table.insert(rows, csv.parseLine(line))
        line = file.readLine()
    end
    file.close()
    return rows
end

function csv.write(path, rows)
    local file = fs.open(path, "w")
    if not file then return false end
    for _, row in ipairs(rows) do
        file.writeLine(csv.encodeLine(row))
    end
    file.close()
    return true
end

return csv
