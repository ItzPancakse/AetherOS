term.clear()
term.setCursorPos(1,1)

print("[ OK ] Initializing Filesystem")
sleep(0.2)

print("[ OK ] Loading Libraries")
os.loadAPI("/lib/filesystem.lua")
os.loadAPI("/lib/process.lua")
os.loadAPI("/lib/util.lua")

print("[ OK ] Starting services")

if fs.exists("/boot/services.lua") then
    shell.run("/boot/services.lua")
else
    term.setTextColor(colors.red)
    print("ERROR: System could not boot: Services script missing at /boot/services.lua", 0)
end

print("[ OK ] Starting shell")
shell.run("/bin/shell.lua")
