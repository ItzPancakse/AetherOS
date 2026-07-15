-- lib/htmlrender.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- Renders the (simple) HTML produced by lib/markdown.lua directly
-- onto the current terminal, with basic colors standing in for
-- formatting a text terminal can't actually do (bold, headings, etc).
-- Not a general HTML renderer - just enough for markdown output.

local render = {}

local ENTITIES = {
    ["&amp;"] = "&", ["&lt;"] = "<", ["&gt;"] = ">",
    ["&quot;"] = "\"", ["&#39;"] = "'",
}

local function decodeEntities(text)
    for entity, char in pairs(ENTITIES) do
        text = text:gsub(entity, char)
    end
    text = text:gsub("&#(%d+);", function(n) return string.char(tonumber(n) % 256) end)
    text = text:gsub("&#x(%x+);", function(n) return string.char(tonumber(n, 16) % 256) end)
    return text
end

-- Renders markdown-generated HTML to the current term. Returns nothing;
-- writes directly, respecting the current cursor position.
function render.html(html, opts)
    opts = opts or {}
    local headingColor = opts.headingColor or colors.lightBlue
    local textColor = opts.textColor or colors.white
    local emColor = opts.emColor or colors.lime
    local strongColor = opts.strongColor or colors.yellow
    local codeColor = opts.codeColor or colors.lightGray
    local linkColor = opts.linkColor or colors.cyan
    local quoteColor = opts.quoteColor or colors.lightGray

    term.setTextColor(textColor)

    local listStack = {} -- stack of {type="ul"|"ol", index=n}
    local linkHref = nil
    local inPre = false

    local pos = 1
    local len = #html

    local function newlineIfNeeded()
        local x = select(1, term.getCursorPos())
        if x ~= 1 then print("") end
    end

    while pos <= len do
        local tagStart, tagEnd, closing, tagName, attrs = html:find("<(/?)([%a][%w]*)([^>]*)>", pos)
        local textChunk
        if tagStart then
            textChunk = html:sub(pos, tagStart - 1)
        else
            textChunk = html:sub(pos)
        end

        if #textChunk > 0 then
            local clean = decodeEntities(textChunk)
            if not inPre then
                clean = clean:gsub("%s+", " ")
            end
            if clean ~= "" and clean ~= " " then
                term.write(clean)
            elseif clean == " " and not inPre then
                term.write(" ")
            end
        end

        if not tagStart then break end

        tagName = tagName:lower()
        local isClose = (closing == "/")

        if tagName:match("^h[1-6]$") then
            if isClose then
                term.setTextColor(textColor)
                print("")
                print("")
            else
                newlineIfNeeded()
                term.setTextColor(headingColor)
                local level = tonumber(tagName:sub(2))
                term.write(string.rep("#", level) .. " ")
            end
        elseif tagName == "p" then
            if isClose and #listStack == 0 then
                print("")
                print("")
            end
        elseif tagName == "strong" or tagName == "b" then
            term.setTextColor(isClose and textColor or strongColor)
        elseif tagName == "em" or tagName == "i" then
            term.setTextColor(isClose and textColor or emColor)
        elseif tagName == "code" then
            term.setTextColor(isClose and textColor or codeColor)
        elseif tagName == "pre" then
            inPre = not isClose
            if not isClose then newlineIfNeeded() end
        elseif tagName == "a" then
            if isClose then
                if linkHref then
                    term.setTextColor(linkColor)
                    term.write(" (" .. linkHref .. ")")
                end
                term.setTextColor(textColor)
                linkHref = nil
            else
                linkHref = attrs:match('href="([^"]*)"')
                term.setTextColor(linkColor)
            end
        elseif tagName == "img" then
            local alt = attrs:match('alt="([^"]*)"') or ""
            local src = attrs:match('src="([^"]*)"') or ""
            term.setTextColor(linkColor)
            term.write("[image: " .. alt .. " (" .. src .. ")]")
            term.setTextColor(textColor)
        elseif tagName == "ul" or tagName == "ol" then
            if isClose then
                table.remove(listStack)
                if #listStack == 0 then print("") end
            else
                newlineIfNeeded()
                table.insert(listStack, { kind = tagName, index = 0 })
            end
        elseif tagName == "li" then
            if not isClose then
                newlineIfNeeded()
                local top = listStack[#listStack]
                local depth = #listStack
                term.setTextColor(textColor)
                term.write(string.rep("  ", math.max(0, depth - 1)))
                if top and top.kind == "ol" then
                    top.index = top.index + 1
                    term.write(top.index .. ". ")
                else
                    term.write("- ")
                end
            else
                print("")
            end
        elseif tagName == "blockquote" then
            term.setTextColor(isClose and textColor or quoteColor)
            if not isClose then
                newlineIfNeeded()
                term.write("| ")
            else
                print("")
            end
        elseif tagName == "hr" then
            newlineIfNeeded()
            local w = term.getSize()
            term.setTextColor(colors.gray)
            print(string.rep("-", w))
            term.setTextColor(textColor)
        elseif tagName == "br" then
            print("")
        end

        pos = tagEnd + 1
    end

    term.setTextColor(textColor)
end

return render
