-- shell.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- AetherOS's interactive command line, styled after a Linux shell prompt.
-- Supports command history, `cmd arg1 arg2`, and resolves commands from
-- /bin much like $PATH does on Linux.

local config = (aether and aether.config) or dofile("/lib/config.lua")

_G.aether = _G.aether or {}
aether.shellHistory = aether.shellHistory or {}
local history = aether.shellHistory

local function shortDir()
    local dir = shell.dir()
    if dir == "" then return "/" end
    return "/" .. dir
end

local function prompt()
    local user = (aether and aether.sessionUser) or config.get("username") or "user"
    local host = config.get("hostname") or "aether"
    term.setTextColor(user == "root" and colors.red or colors.lime)
    term.write(user .. "@" .. host)
    term.setTextColor(colors.white)
    term.write(":")
    term.setTextColor(colors.lightBlue)
    term.write(shortDir())
    term.setTextColor(colors.white)
    term.write(user == "root" and "# " or "$ ")
end

local function resolveCommand(cmd)
    local candidates = {
        cmd,
        "/" .. cmd .. ".lua",
        "/s" .. cmd .. ".lua",
        "/bin/" .. cmd .. ".lua",
        "/sbin/" .. cmd .. ".lua",
        "/apps/" .. cmd .. ".lua",
        "/rom/programs/" .. cmd .. ".lua",
    }
    for _, path in ipairs(candidates) do
        if fs.exists(path) and not fs.isDir(path) then
            return path
        end
    end
    return nil
end

local function completeLine(text)
    if shell and shell.complete then
        return shell.complete(text)
    end
    return nil
end

print("AetherOS shell. Type 'help' for a list of commands.")

while true do
    prompt()

    local ok, line = pcall(read, nil, history, completeLine)
    if not ok or line == nil then
        print("")
        break
    end

    line = line:gsub("^%s+", ""):gsub("%s+$", "")
    if #line > 0 then
        table.insert(history, line)

        local args = {}
        for word in line:gmatch("%S+") do
            table.insert(args, word)
        end
        local cmd = table.remove(args, 1)

        if cmd == "exit" then
            break
        elseif cmd == nil then
            -- empty command, ignore
        else
            local path = resolveCommand(cmd)
            if path then
                local ok2, err = pcall(shell.run, path, table.unpack(args))
                if not ok2 then
                    term.setTextColor(colors.red)
                    print("Error: " .. tostring(err))
                    term.setTextColor(colors.white)
                end
            else
                term.setTextColor(colors.red)
                print(cmd .. ": command not found. Type 'help' for a list of commands.")
                term.setTextColor(colors.white)
            end
        end
    end
end
