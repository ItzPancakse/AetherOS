-- safeshell.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- A tiny, fully self-contained shell for recovery use. Deliberately does
-- NOT run anything from /bin or /lib (those might be broken) - every
-- command below is implemented inline using only native fs/term APIs.

term.setTextColor(colors.white)
print("AetherOS safe shell. Type 'help' for commands, 'exit' to leave.")

local function resolve(p)
    if not p or p == "" then return shell.dir() == "" and "/" or "/" .. shell.dir() end
    return shell.resolve(p)
end

local function cmd_help()
    local rows = {
        { "ls [path]", "list a directory" },
        { "cd <path>", "change directory" },
        { "pwd", "print working directory" },
        { "cat <file>", "print a file's contents" },
        { "write <file>", "write a file: type lines, then a single '.' to finish" },
        { "mkdir <dir>", "create a directory" },
        { "rm <path>", "delete a file or directory" },
        { "cp <src> <dst>", "copy a file or directory" },
        { "mv <src> <dst>", "move/rename a file or directory" },
        { "touch <file>", "create an empty file" },
        { "clear", "clear the screen" },
        { "reboot / shutdown", "power controls" },
        { "exit", "leave the safe shell" },
    }
    for _, r in ipairs(rows) do
        term.setTextColor(colors.yellow)
        term.write(("%-16s"):format(r[1]))
        term.setTextColor(colors.lightGray)
        print(r[2])
    end
    term.setTextColor(colors.white)
end

local function cmd_ls(args)
    local path = resolve(args[1])
    if not fs.exists(path) then print("ls: no such path: " .. path) return end
    if not fs.isDir(path) then print(fs.getName(path)) return end
    local items = fs.list(path)
    table.sort(items, function(a, b) return a:lower() < b:lower() end)
    for _, name in ipairs(items) do
        local full = fs.combine(path, name)
        if fs.isDir(full) then
            term.setTextColor(colors.lightBlue)
            print(name .. "/")
        else
            term.setTextColor(colors.white)
            print(name)
        end
    end
    term.setTextColor(colors.white)
end

local function cmd_cd(args)
    local path = resolve(args[1] or "/")
    if not fs.exists(path) or not fs.isDir(path) then
        print("cd: no such directory: " .. path)
        return
    end
    shell.setDir(path)
end

local function cmd_cat(args)
    if not args[1] then print("usage: cat <file>") return end
    local path = resolve(args[1])
    if not fs.exists(path) or fs.isDir(path) then
        print("cat: no such file: " .. path)
        return
    end
    local file = fs.open(path, "r")
    print(file.readAll())
    file.close()
end

local function cmd_write(args)
    if not args[1] then print("usage: write <file>") return end
    local path = resolve(args[1])
    print("Type file contents. Finish with a single '.' on its own line.")
    local lines = {}
    while true do
        local line = read()
        if line == "." then break end
        table.insert(lines, line)
    end
    local file = fs.open(path, "w")
    if not file then print("write: could not open " .. path) return end
    for _, l in ipairs(lines) do file.writeLine(l) end
    file.close()
    print("Wrote " .. #lines .. " line(s) to " .. path)
end

local function cmd_mkdir(args)
    if not args[1] then print("usage: mkdir <dir>") return end
    fs.makeDir(resolve(args[1]))
end

local function cmd_rm(args)
    if not args[1] then print("usage: rm <path>") return end
    local path = resolve(args[1])
    if not fs.exists(path) then print("rm: no such path: " .. path) return end
    if fs.isReadOnly(path) then print("rm: read-only: " .. path) return end
    fs.delete(path)
end

local function cmd_cp(args)
    if not args[1] or not args[2] then print("usage: cp <src> <dst>") return end
    local ok, err = pcall(fs.copy, resolve(args[1]), resolve(args[2]))
    if not ok then print("cp: " .. tostring(err)) end
end

local function cmd_mv(args)
    if not args[1] or not args[2] then print("usage: mv <src> <dst>") return end
    local ok, err = pcall(fs.move, resolve(args[1]), resolve(args[2]))
    if not ok then print("mv: " .. tostring(err)) end
end

local function cmd_touch(args)
    if not args[1] then print("usage: touch <file>") return end
    local path = resolve(args[1])
    if not fs.exists(path) then
        local file = fs.open(path, "w")
        if file then file.close() end
    end
end

local function cmd_reboot(args)
    if args[1] == "recovery" then
        if not fs.exists("/etc") then fs.makeDir("/etc") end
        local f = fs.open("/etc/bootmode", "w")
        if f then f.write("recovery") f.close() end
        print("Rebooting into recovery mode...")
    elseif fs.exists("/etc/bootmode") then
        fs.delete("/etc/bootmode")
    end
    sleep(0.5)
    os.reboot()
end

local commands = {
    help = cmd_help, ls = cmd_ls, cd = cmd_cd, pwd = function() print(resolve()) end,
    cat = cmd_cat, write = cmd_write, mkdir = cmd_mkdir, rm = cmd_rm,
    cp = cmd_cp, mv = cmd_mv, touch = cmd_touch,
    clear = function() term.clear() term.setCursorPos(1, 1) end,
    reboot = cmd_reboot,
    shutdown = function() os.shutdown() end,
    sudo = function(args)
        -- no real privilege model down here - just drop the leading
        -- 'sudo' and run the rest of the command line as-is.
        if not args[1] then print("usage: sudo <command> [args...]") return end
        local cmdName = table.remove(args, 1)
        if commands[cmdName] then
            commands[cmdName](args)
        else
            print(cmdName .. ": command not found (type 'help')")
        end
    end,
}

while true do
    term.setTextColor(colors.lime)
    term.write("safe")
    term.setTextColor(colors.white)
    term.write(":")
    term.setTextColor(colors.lightBlue)
    term.write(resolve())
    term.setTextColor(colors.white)
    term.write("$ ")

    local ok, line = pcall(read)
    if not ok or not line then print("") break end
    line = line:gsub("^%s+", ""):gsub("%s+$", "")
    if #line > 0 then
        local args = {}
        for w in line:gmatch("%S+") do table.insert(args, w) end
        local cmdName = table.remove(args, 1)

        if cmdName == "exit" then
            break
        elseif commands[cmdName] then
            local ok2, err = pcall(commands[cmdName], args)
            if not ok2 then
                term.setTextColor(colors.red)
                print("Error: " .. tostring(err))
                term.setTextColor(colors.white)
            end
        else
            term.setTextColor(colors.red)
            print(cmdName .. ": command not found (type 'help')")
            term.setTextColor(colors.white)
        end
    end
end
