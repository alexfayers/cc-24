-- Custom terminal stuff for lexicon

local TERM_WIDTH, TERM_HEIGHT = term.getSize()

---Write a newline to the terminal
---@return nil
local function newline()
    local x, y = term.getCursorPos()

    if y >= TERM_HEIGHT then
        term.scroll(1)
        term.setCursorPos(1, TERM_HEIGHT)
    else
        term.setCursorPos(1, y + 1)
    end
end

---Write text to the terminal, wrapping it if it exceeds the terminal width
---@param text string The text to write
---@return nil
local function writeWrap(text)
    local x, y = term.getCursorPos()

    if x + string.len(text) > TERM_WIDTH then
        term.write(text:sub(1, TERM_WIDTH - x))
        newline()
        writeWrap(text:sub(TERM_WIDTH - x + 1))
    else
        term.write(text)
    end
end

---Write text to the terminal, wrapping it if it exceeds the terminal width and setting the text color
---@param text string The text to write
---@param color integer The color to set the text to
---@return nil
local function writeWrapColor(text, color)
    term.setTextColor(color)
    writeWrap(text)
    term.setTextColor(colors.white)
end

return {
    newline = newline,
    writeWrap = writeWrap,
    writeWrapColor = writeWrapColor
}
