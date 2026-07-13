local function clock()
    while true do
        os.sleep(0.1)
    end
end

local function logger()
    while true do
        os.sleep(0.5)
    end
end

parallel.waitForAll(clock, logger)
