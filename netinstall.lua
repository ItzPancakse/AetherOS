-- WIP

term.clear()
term.setCursorPos(1,1)

local BASE = "https://raw.githubusercontent.com/ItzPancakse/AetherOS/main/"
local files = {}

local response = http.get(BASE .. "manifest.txt")

if not response then
    print("Failed to fetch manifest file. Please check your internet connection.")
    return
end

local manifest = response.readAll()
response.close()

for file in manifest:gmatch("[^\r\n]+") do
    print("Download file: " .. file)

    local response = http.get(BASE .. file)

    if response then
        local data = response.readAll()
        response.close()

        local dir = fs.getDir(file)

        if dir ~= "" then
            fs.makeDir(dir)
        end
    
    local f = fs.open(file, "w")
    f.write(data)
    f.close()
    else
        print("Failed to download file: " .. file)
    end

end

for file in manifest:gmatch("[^\r\n]+") do
    table.insert(files, file)
end


for i, file in ipairs(files) do
    progress(i / #files)
end
