-- WIP

term.clear()
term.setCursorPos(1,1)

local BASE = "https://raw.githubusercontent.com/ItzPancakse/AetherOS/main/"
local files = {}

local function progress(ratio)
    ratio = math.max(0, math.min(1, ratio))
    local w, h = term.getSize()
    local x, y = term.getCursorPos()
    local barWidth = math.min(50, math.max(10, w - 30))
    local filled = math.floor(ratio * barWidth + 0.5)
    term.setCursorPos(1, y)
    term.write(string.rep(" ", w))
    term.setCursorPos(1, y)
    term.write("Progress: [" .. string.rep("=", filled) .. string.rep(" ", barWidth - filled) .. "] " .. math.floor(ratio * 100) .. "%")
    if ratio >= 1 then print("") end
end

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
