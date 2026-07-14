-- lib/crypto.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- Encrypts passwords before they're written to /etc/aether.cfg.

local KEY_PATH = "/etc/aether.key"

math.randomseed(os.epoch("utc"))

local aesModule = nil

-- Loads the vendored AES library in its own sandboxed environment. The
-- library declares most of its helpers as plain globals (SubTable,
-- XorBlock, KeyExpansion, etc) - loading it this way keeps those out of
-- AetherOS's shared global namespace instead of polluting it.
local function loadAES()
    if aesModule then return aesModule end

    local path = "/lib/aes.lua"
    if not fs.exists(path) then
        error("crypto: " .. path .. " is missing")
    end

    local file = fs.open(path, "r")
    local source = file.readAll()
    file.close()

    local env = setmetatable({}, { __index = _G })
    local chunk, err = load(source, "@" .. path, "t", env)
    if not chunk then
        error("crypto: failed to load AES library: " .. tostring(err))
    end

    aesModule = chunk()
    return aesModule
end

local function bytesToHex(bytes)
    local out = {}
    for i, b in ipairs(bytes) do
        out[i] = ("%02x"):format(b)
    end
    return table.concat(out)
end

local function hexToBytes(hex)
    local out = {}
    for i = 1, #hex, 2 do
        table.insert(out, tonumber(hex:sub(i, i + 1), 16))
    end
    return out
end

local function randomIV()
    local AES = loadAES()
    local key = AES.GenerateRandomKey() -- 32 random bytes, plenty to slice 16 from
    local iv = {}
    for i = 1, 16 do iv[i] = key[i] end
    return iv
end

-- Returns this computer's local AES key, generating and persisting one
-- (once) the first time it's needed.
local function getDeviceKey()
    if fs.exists(KEY_PATH) then
        local file = fs.open(KEY_PATH, "r")
        local hex = (file.readAll() or ""):gsub("%s+", "")
        file.close()
        if #hex == 64 then
            return hexToBytes(hex)
        end
    end

    local AES = loadAES()
    local key = AES.GenerateRandomKey()

    if not fs.exists("/etc") then fs.makeDir("/etc") end
    local file = fs.open(KEY_PATH, "w")
    file.write(bytesToHex(key))
    file.close()

    return key
end

local crypto = {}

-- Encrypts a plaintext password into one storable string,
-- "<iv hex>:<ciphertext hex>". Blank input stays blank (= no password).
function crypto.encryptPassword(plaintext)
    if not plaintext or plaintext == "" then return "" end

    local AES = loadAES()
    local key = getDeviceKey()
    local iv = randomIV()

    local ciphertext = AES.EncryptCBC(AES.StringToTable(plaintext), key, iv)
    return bytesToHex(iv) .. ":" .. bytesToHex(ciphertext)
end

-- Decrypts a value produced by encryptPassword. Returns "" for blank
-- input. If `stored` isn't in the expected iv:ciphertext hex format (or
-- fails to decrypt), it's returned unchanged - this lets a plaintext
-- password saved before encryption-at-rest was added keep working until
-- it's next changed with 'passwd'.
function crypto.decryptPassword(stored)
    if not stored or stored == "" then return "" end

    local ivHex, cipherHex = stored:match("^(%x+):(%x+)$")
    if not ivHex then
        return stored
    end

    local ok, result = pcall(function()
        local AES = loadAES()
        local key = getDeviceKey()
        local iv = hexToBytes(ivHex)
        local ciphertext = hexToBytes(cipherHex)
        local plaintext = AES.TableToString(AES.DecryptCBC(ciphertext, key, iv))
        return (plaintext:gsub("\0+$", ""))
    end)

    if ok then return result end
    return stored
end

-- Checks a freshly typed password against a stored value (encrypted or
-- legacy plaintext). An empty stored value always means "no password".
function crypto.checkPassword(entered, stored)
    if stored == nil or stored == "" then
        return true
    end
    return crypto.decryptPassword(stored) == (entered or "")
end

return crypto
