-- sbin/mkuser.lua - create a new AetherOS user
local config = (aether and aether.config) or dofile("/lib/config.lua")
local args = { ... }

local name = args[1]
if not name or not name:match("^[%w_%-]+$") then
    print("usage: mkuser <name>")
    print("(letters, numbers, - and _ only)")
    return
end

local users = config.get("users") or {}
for _, u in ipairs(users) do
    if u == name then
        print("mkuser: user '" .. name .. "' already exists")
        return
    end
end

table.insert(users, name)
config.set("users", users)

if not fs.exists("/home") then fs.makeDir("/home") end
local homeDir = "/home/" .. name
if not fs.exists(homeDir) then fs.makeDir(homeDir) end

term.setTextColor(colors.lime)
print("Created user '" .. name .. "' (home: " .. homeDir .. ")")
term.setTextColor(colors.white)
print("Switch to it with: su " .. name)
