-- lib/config.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- Loads/saves persisted AetherOS settings from /etc/aether.cfg

local CONFIG_PATH = "/etc/aether.cfg"

local defaults = {
    accent = "lightBlue",
    wallpaper = "dots",
    username = "user",
    hostname = "aether",
    firstBoot = true,
    users = { "user" },
    sudoPassword = "",
    userPasswords = {},
    updateCheckOnBoot = false,
    version = "1.0.0",
}

local config = {}
config.values = nil

local function loadFromDisk()
    if not fs.exists(CONFIG_PATH) then
        return nil
    end
    local file = fs.open(CONFIG_PATH, "r")
    if not file then return nil end
    local text = file.readAll()
    file.close()
    local ok, data = pcall(textutils.unserialize, text)
    if ok and type(data) == "table" then
        return data
    end
    return nil
end

function config.load()
    if config.values then return config.values end
    local loaded = loadFromDisk()
    local values = {}
    for k, v in pairs(defaults) do values[k] = v end
    if loaded then
        for k, v in pairs(loaded) do values[k] = v end
    end
    config.values = values
    return values
end

function config.save()
    if not config.values then return false end
    if not fs.exists("/etc") then
        fs.makeDir("/etc")
    end
    local file = fs.open(CONFIG_PATH, "w")
    if not file then return false end
    file.write(textutils.serialize(config.values))
    file.close()
    return true
end

function config.get(key)
    local values = config.load()
    return values[key]
end

function config.set(key, value)
    local values = config.load()
    values[key] = value
    return config.save()
end

return config
