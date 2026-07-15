-- lib/floppy.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- Helpers for working with CC:Tweaked disk drives ("drive" peripherals)
-- and the floppy disks in them. Once a disk is present, CC:Tweaked
-- already mounts its contents as a normal folder (e.g. "/disk/"), so
-- the Files app can browse it like anywhere else - these helpers exist
-- to make finding drives and copying files to/from them a one-click
-- action instead of manual navigation.

local floppy = {}

-- Returns a list of { name, present, mountPath, label } for every
-- attached disk drive (present = a floppy is actually in it).
function floppy.list()
    local drives = {}
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "drive" then
            local d = peripheral.wrap(name)
            local present = d.isDiskPresent and d.isDiskPresent() or false
            table.insert(drives, {
                name = name,
                present = present,
                mountPath = present and d.getMountPath and d.getMountPath() or nil,
                label = present and d.getDiskLabel and d.getDiskLabel() or nil,
            })
        end
    end
    return drives
end

-- Returns the first drive that currently has a floppy in it, or nil.
function floppy.firstPresent()
    for _, d in ipairs(floppy.list()) do
        if d.present and d.mountPath then return d end
    end
    return nil
end

-- Copies a local file/folder onto a floppy's root. Returns ok, destPathOrError.
function floppy.copyTo(mountPath, localPath, destName)
    destName = destName or fs.getName(localPath)
    local dest = "/" .. mountPath .. "/" .. destName
    if not fs.exists(localPath) then return false, "no such file: " .. localPath end
    local ok, err = pcall(fs.copy, localPath, dest)
    if not ok then return false, err end
    return true, dest
end

-- Copies a file/folder off a floppy into a local directory. Returns ok, destPathOrError.
function floppy.copyFrom(mountPath, diskItemName, destDir)
    local src = "/" .. mountPath .. "/" .. diskItemName
    if not fs.exists(src) then return false, "no such file on disk: " .. diskItemName end
    local dest = fs.combine(destDir, diskItemName)
    local ok, err = pcall(fs.copy, src, dest)
    if not ok then return false, err end
    return true, dest
end

return floppy
