-- lib/filesystem.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- Thin convenience wrapper around the native `fs` API used by AetherOS
-- apps and commands. Kept small on purpose: the native fs API already
-- does the heavy lifting, this just adds a few safe helpers.

local filesystem = {}

function filesystem.exists(path)
    return fs.exists(path)
end

function filesystem.isDir(path)
    return fs.isDir(path)
end

function filesystem.list(path)
    if not fs.exists(path) or not fs.isDir(path) then return {} end
    local items = fs.list(path)
    table.sort(items, function(a, b) return a:lower() < b:lower() end)
    return items
end

function filesystem.makeDir(path)
    if not fs.exists(path) then
        fs.makeDir(path)
    end
end

function filesystem.delete(path)
    if fs.exists(path) then
        fs.delete(path)
    end
end

function filesystem.read(path)
    if not fs.exists(path) then
        return nil
    end
    local file = fs.open(path, "r")
    if not file then return nil end
    local text = file.readAll()
    file.close()
    return text
end

function filesystem.write(path, text)
    local file = fs.open(path, "w")
    if not file then return false end
    file.write(text)
    file.close()
    return true
end

function filesystem.append(path, text)
    local file = fs.open(path, "a")
    if not file then return false end
    file.write(text)
    file.close()
    return true
end

function filesystem.copy(from, to)
    if not fs.exists(from) then return false, "no such file" end
    local ok, err = pcall(fs.copy, from, to)
    return ok, err
end

function filesystem.move(from, to)
    if not fs.exists(from) then return false, "no such file" end
    local ok, err = pcall(fs.move, from, to)
    return ok, err
end

function filesystem.size(path)
    if not fs.exists(path) then return 0 end
    local ok, result = pcall(fs.getSize, path)
    if ok then return result end
    return 0
end

-- Returns a sorted list of {name=, isDir=, size=} entries for a directory.
function filesystem.entries(path)
    local names = filesystem.list(path)
    local out = {}
    for _, name in ipairs(names) do
        local full = fs.combine(path, name)
        table.insert(out, {
            name = name,
            isDir = fs.isDir(full),
            size = filesystem.size(full),
        })
    end
    table.sort(out, function(a, b)
        if a.isDir ~= b.isDir then return a.isDir end
        return a.name:lower() < b.name:lower()
    end)
    return out
end

function filesystem.extension(name)
    local ext = name:match("%.([^%.]+)$")
    return ext
end

return filesystem
