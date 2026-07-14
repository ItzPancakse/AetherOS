-- lib/util.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- General purpose helper functions shared across AetherOS.

local util = {}

function util.trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function util.split(s, sep)
    sep = sep or "%s"
    local parts = {}
    for part in string.gmatch(s, "([^" .. sep .. "]+)") do
        table.insert(parts, part)
    end
    return parts
end

function util.padRight(s, len, ch)
    ch = ch or " "
    s = tostring(s)
    if #s >= len then return s:sub(1, len) end
    return s .. string.rep(ch, len - #s)
end

function util.padLeft(s, len, ch)
    ch = ch or " "
    s = tostring(s)
    if #s >= len then return s:sub(1, len) end
    return string.rep(ch, len - #s) .. s
end

function util.center(s, width, ch)
    ch = ch or " "
    s = tostring(s)
    if #s >= width then return s:sub(1, width) end
    local total = width - #s
    local left = math.floor(total / 2)
    local right = total - left
    return string.rep(ch, left) .. s .. string.rep(ch, right)
end

function util.clamp(n, lo, hi)
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

function util.round(n)
    return math.floor(n + 0.5)
end

function util.deepcopy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do
        out[k] = util.deepcopy(v)
    end
    return out
end

function util.formatBytes(n)
    if n == nil then return "?" end
    if n < 0 then return "unlimited" end
    if n < 1024 then return n .. "B" end
    if n < 1024 * 1024 then return string.format("%.1fKB", n / 1024) end
    return string.format("%.1fMB", n / (1024 * 1024))
end

function util.formatUptime(seconds)
    seconds = math.floor(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end

-- Resolve a possibly relative path against the shell's current directory.
function util.resolve(path)
    if shell and shell.resolve then
        return shell.resolve(path)
    end
    return path
end

function util.contains(list, value)
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

return util
