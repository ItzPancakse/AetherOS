-- sbin/reboot.lua - restart the computer, optionally straight into recovery
-- usage: reboot [recovery|normal]
local args = { ... }
local target = args[1]

local function setBootMode(mode)
    if mode then
        local f = fs.open("/etc/bootmode", "w")
        if f then
            f.write(mode)
            f.close()
        end
    elseif fs.exists("/etc/bootmode") then
        fs.delete("/etc/bootmode")
    end
end

if not fs.exists("/etc") then fs.makeDir("/etc") end

if target == "recovery" then
    setBootMode("recovery")
    term.setTextColor(colors.yellow)
    print("Rebooting into recovery mode...")
    term.setTextColor(colors.white)
elseif target == "normal" or target == "default" then
    setBootMode(nil)
    print("Rebooting AetherOS...")
elseif target then
    print("reboot: unknown target '" .. target .. "' (expected 'recovery')")
    return
else
    print("Rebooting AetherOS...")
end

sleep(0.5)
os.reboot()
