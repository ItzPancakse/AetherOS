local filesystem = {}

function filesystem.exists(path)
    return fs.exists(path)
end

function filesystem.isDir(path)
    return fs.isDir(path)
end

function filesystem.list(path)
    return fs.list(path)
end

function filesystem.makeDir(path)
    if not fs.exists(path) then
        fs.makeDir(path)
    end
end

function filesystem.delete(path)
    if fs.exists(path) then
        fs.delete(path)
    end
end

function filesystem.read(path)
    if not fs.exists(path) then
        return nil
    end

    local file = fs.open(path, "r")
    local text = file.readAll()
    file.close()

    return text
end

function filesystem.write(path, text)
    local file = fs.open(path, "w")
    file.write(text)
    file.close()
end

return filesystem