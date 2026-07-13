while true do
    term.write("user@aether:$")

    local line = read()

    local args = {}

    for word in line:gmatch("%S+") do
        table.insert(args, word)
    end

    local cmd = args[1]

    if cmd == nil then
        -- its a empty command
    elseif fs.exists("/bin/" .. cmd .. ".lua") then -- basically if the command exists it will run the name of the command
        shell.run("/bin/" .. cmd .. ".lua", table.unpack(args, 2))
    else
        print("Command not found type 'help' for a list of commands")
    end
end