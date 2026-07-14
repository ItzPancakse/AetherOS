-- lib/update.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- Checks the AetherOS source repo for a newer version and can pull down
-- the latest files. Shared by /update.lua and the optional boot-time
-- update check.

local BASE_URL = "https://raw.githubusercontent.com/ItzPancakse/AetherOS/main/"

local update = {}
update.BASE_URL = BASE_URL

local function readLocal(path)
    if not fs.exists(path) then return nil end
    local file = fs.open(path, "r")
    local text = file.readAll()
    file.close()
    return (text:gsub("%s+$", ""))
end

local version = require("version")

function update.localVersion()
    return readLocal(version) or "unknown"
end

-- Returns ok, remoteVersion (or ok=false, errorMessage)
function update.remoteVersion()
    if not http then
        return false, "HTTP API is disabled on this computer or server"
    end
    local response = http.get(BASE_URL .. version)
    if not response then
        return false, "couldn't reach " .. BASE_URL
    end
    local text = response.readAll()
    response.close()
    return true, (text:gsub("%s+$", ""))
end

-- Returns ok, info where info = { local=, remote=, available= } or ok=false, err
function update.check()
    local ok, remote = update.remoteVersion()
    if not ok then
        return false, remote
    end
    local localV = update.localVersion()
    return true, {
        localVersion = localV,
        remoteVersion = remote,
        available = (localV ~= remote),
    }
end

-- Downloads manifest.txt and every file it lists, overwriting local
-- copies. progressCb(i, total, filename, ok) is called after each file.
function update.install(progressCb)
    if not http then
        return false, "HTTP API is disabled on this computer"
    end

    local response = http.get(BASE_URL .. "manifest.txt")
    if not response then
        return false, "couldn't fetch manifest.txt"
    end
    local manifestText = response.readAll()
    response.close()

    local files = {}
    for line in manifestText:gmatch("[^\r\n]+") do
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        if #line > 0 then table.insert(files, line) end
    end
    table.insert(files, version) -- always update the version file

    local okCount, failed = 0, {}

    for i, file in ipairs(files) do
        local fileResponse = http.get(BASE_URL .. file)
        local fileOk = false
        if fileResponse then
            local data = fileResponse.readAll()
            fileResponse.close()

            local dir = fs.getDir(file)
            if dir ~= "" and not fs.exists(dir) then
                fs.makeDir(dir)
            end

            local f = fs.open(file, "w")
            if f then
                f.write(data)
                f.close()
                fileOk = true
                okCount = okCount + 1
            end
        end
        if not fileOk then table.insert(failed, file) end
        if progressCb then progressCb(i, #files, file, fileOk) end
    end

    return true, { installed = okCount, total = #files, failed = failed }
end

return update
