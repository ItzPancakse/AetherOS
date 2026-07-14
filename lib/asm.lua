-- lib/asm.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- Core logic for asm, the AetherOS package manager. Packages are plain
-- GitHub repos: `asm install someuser/somerepo` fetches manifest.json
-- from the repo root, then every file it lists, from
-- raw.githubusercontent.com. No central registry - the repo IS the
-- package.
-- Manifest format (manifest.json, JSON, at the repo root):
-- {
--   "name": "hello-world",
--   "version": "1.0.0",
--   "author": "someone",
--   "description": "optional, shown by 'asm info'",
--   "os_version": "1.0.0",
--   "dependencies": ["otheruser/otherrepo"],
--   "files": ["main.lua", "lib/helper.lua"],
--   "bin": { "hello": "main.lua" }
-- }
-- "files" are downloaded into /packages/<name>/<path>. "bin" entries
-- get a tiny stub created at /bin/<command>.lua that runs the named
-- file from the package folder, so it works as a normal shell command.
--
-- SAFETY NOTE: asm downloads and runs code from whatever GitHub repo
-- you point it at, with no review or sandboxing - exactly like apt,
-- pip, or npm. Only install packages you trust.

local json = dofile("/lib/dkjson.lua")

local asm = {}

local PACKAGES_DIR = "/packages"
local DB_DIR = "/etc/asm"
local DB_PATH = DB_DIR .. "/installed.json"
local CACHE_PATH = DB_DIR .. "/update-cache.json"

local function ensureDbDir()
    if not fs.exists(DB_DIR) then fs.makeDir(DB_DIR) end
end

local function readJson(path, default)
    if not fs.exists(path) then return default end
    local file = fs.open(path, "r")
    local text = file.readAll()
    file.close()
    local ok, data = pcall(json.decode, text)
    if ok and type(data) == "table" then return data end
    return default
end

local function writeJson(path, data)
    ensureDbDir()
    local file = fs.open(path, "w")
    if not file then return false end
    file.write(json.encode(data, { indent = true }))
    file.close()
    return true
end

function asm.loadDB()
    return readJson(DB_PATH, {})
end

function asm.saveDB(db)
    return writeJson(DB_PATH, db)
end

function asm.loadCache()
    return readJson(CACHE_PATH, {})
end

function asm.saveCache(cache)
    return writeJson(CACHE_PATH, cache)
end

-- Splits "user/repo", "user/repo@branch" into user, repo, branch (branch
-- may be nil, meaning "figure it out").
function asm.parsePackageArg(arg)
    local spec, branch = arg:match("^([^@]+)@(.+)$")
    spec = spec or arg
    local user, repo = spec:match("^([%w_%-%.]+)/([%w_%-%.]+)$")
    return user, repo, branch
end

local function rawUrl(user, repo, branch, path)
    return ("https://raw.githubusercontent.com/%s/%s/%s/%s"):format(user, repo, branch, path)
end

local function fetchRaw(user, repo, branch, path)
    if not http then return false, "HTTP API is disabled on this computer" end
    local response = http.get(rawUrl(user, repo, branch, path))
    if not response then return false, "couldn't fetch " .. path end
    local content = response.readAll()
    response.close()
    return true, content
end

-- Fetches manifest.json, trying 'main' then 'master' if no branch was
-- given explicitly. Returns ok, manifest, branch, err
function asm.fetchManifest(user, repo, branch)
    local branches = branch and { branch } or { "main", "master" }
    for _, b in ipairs(branches) do
        local ok, content = fetchRaw(user, repo, b, "manifest.json")
        if ok then
            local decOk, manifest = pcall(json.decode, content)
            if decOk and type(manifest) == "table" then
                return true, manifest, b
            else
                return false, nil, nil, "manifest.json is not valid JSON"
            end
        end
    end
    return false, nil, nil, "couldn't find manifest.json on " .. table.concat(branches, " or ")
end

local function versionParts(v)
    v = tostring(v or "0.0.0")
    local a, b, c = v:match("^(%d+)%.?(%d*)%.?(%d*)")
    return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
end

-- Returns compatible(bool), message(string or nil)
function asm.checkOSCompatibility(manifest)
    if not manifest.os_version then return true, nil end
    local myMajor = versionParts((aether and aether.version) or "1.0.0")
    local pkgMajor = versionParts(manifest.os_version)
    if myMajor ~= pkgMajor then
        return false, ("this package targets AetherOS %s; you're running %s"):format(
            manifest.os_version, (aether and aether.version) or "1.0.0")
    end
    return true, nil
end

local function installFiles(user, repo, branch, manifest, log)
    local dir = PACKAGES_DIR .. "/" .. manifest.name
    if not fs.exists(PACKAGES_DIR) then fs.makeDir(PACKAGES_DIR) end
    if not fs.exists(dir) then fs.makeDir(dir) end

    for _, relPath in ipairs(manifest.files or {}) do
        log("  fetching " .. relPath)
        local ok, content = fetchRaw(user, repo, branch, relPath)
        if not ok then
            return false, "failed to download " .. relPath .. ": " .. tostring(content)
        end
        local dest = dir .. "/" .. relPath
        local destDir = fs.getDir(dest)
        if destDir ~= "" and not fs.exists(destDir) then fs.makeDir(destDir) end
        local file = fs.open(dest, "w")
        if not file then return false, "couldn't write " .. dest end
        file.write(content)
        file.close()
    end
    return true
end

local function installBinStubs(manifest)
    for command, relPath in pairs(manifest.bin or {}) do
        local stubPath = "/bin/" .. command .. ".lua"
        local targetPath = PACKAGES_DIR .. "/" .. manifest.name .. "/" .. relPath
        local file = fs.open(stubPath, "w")
        if file then
            file.write("-- auto-generated by asm for package '" .. manifest.name .. "'\n")
            file.write("shell.run(\"" .. targetPath .. "\", ...)\n")
            file.close()
        end
    end
end

local function removeBinStubs(binTable)
    for command in pairs(binTable or {}) do
        local stubPath = "/bin/" .. command .. ".lua"
        if fs.exists(stubPath) then fs.delete(stubPath) end
    end
end

-- Installs a package (and its dependencies first). `pkgArg` is a
-- "user/repo" or "user/repo@branch" string. `log(msg)` receives progress
-- lines. `seen` (internal) guards against dependency cycles.
-- Returns ok, nameOrError
function asm.installPackage(pkgArg, log, seen)
    log = log or function() end
    seen = seen or {}

    local user, repo, branch = asm.parsePackageArg(pkgArg)
    if not user or not repo then
        return false, "'" .. pkgArg .. "' doesn't look like user/repo"
    end

    local key = user .. "/" .. repo
    if seen[key] then
        log("  (skipping " .. key .. ", already being installed - circular dependency?)")
        return true, nil
    end
    seen[key] = true

    log("Fetching manifest for " .. key .. "...")
    local ok, manifest, resolvedBranch, err = asm.fetchManifest(user, repo, branch)
    if not ok then
        return false, "couldn't install " .. key .. ": " .. tostring(err)
    end
    if not manifest.name or not manifest.version then
        return false, key .. "'s manifest.json is missing 'name' or 'version'"
    end

    local compatible, warning = asm.checkOSCompatibility(manifest)
    if not compatible then
        log("  warning: " .. warning)
    end

    for _, dep in ipairs(manifest.dependencies or {}) do
        log("Resolving dependency " .. dep .. " (for " .. manifest.name .. ")...")
        local depOk, depErr = asm.installPackage(dep, log, seen)
        if not depOk then
            return false, "dependency " .. dep .. " failed: " .. tostring(depErr)
        end
    end

    log("Installing " .. manifest.name .. " " .. manifest.version .. "...")
    local filesOk, filesErr = installFiles(user, repo, resolvedBranch, manifest, log)
    if not filesOk then
        return false, filesErr
    end
    installBinStubs(manifest)

    local db = asm.loadDB()
    db[manifest.name] = {
        name = manifest.name,
        version = manifest.version,
        author = manifest.author,
        description = manifest.description,
        os_version = manifest.os_version,
        repo = key,
        branch = resolvedBranch,
        dependencies = manifest.dependencies or {},
        files = manifest.files or {},
        bin = manifest.bin or {},
    }
    asm.saveDB(db)

    log("Installed " .. manifest.name .. " " .. manifest.version .. ".")
    return true, manifest.name
end

-- Returns ok, message. Doesn't remove dependencies (in case something
-- else depends on them) - just warns if other installed packages list
-- this one as a dependency.
function asm.removePackage(name, log)
    log = log or function() end
    local db = asm.loadDB()
    local entry = db[name]
    if not entry then
        return false, "no such package: " .. name
    end

    local dependents = {}
    for otherName, otherEntry in pairs(db) do
        if otherName ~= name then
            for _, dep in ipairs(otherEntry.dependencies or {}) do
                if dep == entry.repo then table.insert(dependents, otherName) end
            end
        end
    end
    if #dependents > 0 then
        log("Warning: " .. table.concat(dependents, ", ") .. " depend(s) on " .. name .. ".")
    end

    local dir = PACKAGES_DIR .. "/" .. name
    if fs.exists(dir) then fs.delete(dir) end
    removeBinStubs(entry.bin)

    db[name] = nil
    asm.saveDB(db)

    return true, "Removed " .. name .. "."
end

-- Refreshes the update cache by checking every installed package's
-- manifest for a newer version. Returns ok, { name -> {installed=, latest=, available=} }
function asm.checkUpdates(log)
    log = log or function() end
    local db = asm.loadDB()
    local cache = {}

    for name, entry in pairs(db) do
        log("Checking " .. name .. "...")
        local user, repo = entry.repo:match("^([^/]+)/([^/]+)$")
        local ok, manifest = asm.fetchManifest(user, repo, entry.branch)
        if ok and manifest.version then
            cache[name] = {
                installed = entry.version,
                latest = manifest.version,
                available = (manifest.version ~= entry.version),
            }
        else
            cache[name] = { installed = entry.version, latest = entry.version, available = false, error = true }
        end
    end

    asm.saveCache(cache)
    return true, cache
end

-- Reinstalls a package at its latest version (also refreshes deps).
function asm.upgradePackage(name, log)
    log = log or function() end
    local db = asm.loadDB()
    local entry = db[name]
    if not entry then
        return false, "no such package: " .. name
    end
    return asm.installPackage(entry.repo .. "@" .. entry.branch, log)
end

function asm.upgradeAll(log)
    log = log or function() end
    local db = asm.loadDB()
    local results = {}
    for name in pairs(db) do
        local ok, err = asm.upgradePackage(name, log)
        table.insert(results, { name = name, ok = ok, err = err })
    end
    return results
end

return asm
