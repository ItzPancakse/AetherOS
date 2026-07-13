local bootPath = "boot/init.lua"

if not fs.exists(bootPath) then
    term.setTextColor(colors.red)
    print("ERROR: System could not boot: Core OS boot script missing at " .. bootPath, 0)
    return
end

term.clear()
term.setCursorPos(1,1)
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)

local success, err = pcall(function()
    print("Welcome to AetherOS")
    sleep(1)
    shell.run(bootPath)
end)

if not success then
    term.setTextColor(colors.red)
    print("ERROR: System could not boot: " .. tostring(err), 0)
end
