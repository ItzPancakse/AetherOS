term.clear()
term.setCursorPos(1,1)
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)

print("Welcome to AetherOS")
sleep(1)

shell.run("boot/init")