---Mail program for cc:t. Uses lib-mail.
package.path = package.path .. ";/usr/lib/?.lua"
local completion = require("cc.completion")
local strings = require("cc.strings")

local MailClient = require("lib-mail.client.MailClient")

local client = MailClient()


settings.define("mail.address-book", {
    description = "Known valid mail addresses",
    type = "table",
    default = {},
})


---Generate autocompletes for unread mails
---@return string[]
local function getUnreadAutocomplete()
    local unread_messages = client:getInboxUnreadCount()

    if unread_messages == 0 then
        return {}
    end

    local completions = {}

    for i = 1, unread_messages do
        table.insert(completions, "u." .. i)
    end

    return completions
end


---Generate autocompletes for read mails
---@return string[]
local function getReadAutocomplete()
    local read_messages = client:getInboxReadCount()

    if read_messages == 0 then
        return {}
    end

    local completions = {}

    for i = 1, read_messages do
        table.insert(completions, "r." .. i)
    end

    return completions
end


---Generate autocompletes for both read and unread mails
---@return string[]
local function getAllAutocomplete()
    local unread_completes = getUnreadAutocomplete()
    local read_completes = getReadAutocomplete()

    local choices = {}

    for _, v in ipairs(unread_completes) do
        table.insert(choices, v)
    end

    for _, v in ipairs(read_completes) do
        table.insert(choices, v)
    end

    return choices
end


---Get the list of known mail addresses
---@return string[]
local function getAddressBook()
    return settings.get("mail.address-book") or {"recipient"}
end


---Argument completion for the script
---@param _ any
---@param index number The index of the argument
---@param argument string The current arguments
---@param previous table
---@return table? _ A table of possible completions
local function complete(_, index, argument, previous)
    if index == 1 then
        return completion.choice(argument, {"read", "send", "reply", "delete"}, true)
    elseif index == 2 then

        if previous[2] == "read" then
            return completion.choice(argument, getAllAutocomplete(), false)
        elseif previous[2] == "send" then
            return completion.choice(argument, getAddressBook(), true)
        elseif previous[2] == "reply" then
            return completion.choice(argument, getAllAutocomplete(), false)
        elseif previous[2] == "delete" then
            return completion.choice(argument, getReadAutocomplete(), false)
        end
    elseif index == 3 then
        if previous[2] == "send" then
            return completion.choice(argument, {"subject"}, true)
        elseif previous[2] == "reply" then
            return completion.choice(argument, {"message"}, false)
        end
    elseif index == 4 then
        if previous[2] == "send" then
            return completion.choice(argument, {"message"}, false)
        end
    end

    return {}
end

shell.setCompletionFunction(shell.getRunningProgram(), complete)


---Print all the given mail messages
---@param messages MailMessage[]
local function printMessages(messages)
    for i, message in ipairs(messages) do
        print(i .. ". " .. message.subject .. " (" .. message.from .. ")")
    end
end

local defaultTermBG = term.getBackgroundColor()
local termWidth, termHeight = term.getSize()


local function cleanup()
    term.clear()
    term.setCursorPos(1, 1)
end


local function writeHeader(header)
    local prevX, prevY = term.getCursorPos()
    term.setCursorPos(1, 1)

    term.setBackgroundColor(colors.blue)
    term.clearLine()
    term.write(strings.ensure_width(header, termWidth))
    term.setBackgroundColor(defaultTermBG)

    term.setCursorPos(prevX, prevY)
end


local function writeFooter(footer)
    local prevX, prevY = term.getCursorPos()
    term.setCursorPos(1, termHeight)

    term.setBackgroundColor(colors.lightBlue)
    term.clearLine()
    term.write(strings.ensure_width(footer, termWidth))
    term.setBackgroundColor(defaultTermBG)

    term.setCursorPos(prevX, prevY)
end


---Show a fancy paged print, like the "more" command in linux
---User can press the up and down arrow keys to scroll up and down
---@param text string The text to display
---@param header string The header to display at the top of the screen
local function functionPagedPrintFancy(text, header)
    local footer = "Hold Ctrl+T to exit | Scroll with up/down or mouse"

    local lines = strings.wrap(text, termWidth)

    if #lines < termHeight - 3 then
        footer = "Hold Ctrl+T to exit"
    end

    local currentTopLine = 1

    local function draw()
        term.clear()
        term.setCursorPos(1, 2)

        writeHeader(header)
        writeFooter(footer)

        for i = currentTopLine, math.min(#lines, currentTopLine + termHeight - 3) do
            print(lines[i])
        end
    end

    draw()

    while true do
        local event, keyOrDir = os.pullEvent()

        local scrollDir = 0

        if event == "key" then
            if keyOrDir == keys.up then
                scrollDir = -1
            elseif keyOrDir == keys.down then
                scrollDir = 1
            end
        elseif event == "mouse_scroll" then
            scrollDir = -keyOrDir
        end

        if scrollDir == 1 then
            currentTopLine = math.max(1, currentTopLine - 1)
            draw()
        elseif scrollDir == -1 then
            currentTopLine = math.min(#lines - termHeight + 1, currentTopLine + 1)
            currentTopLine = math.max(1, currentTopLine)
            draw()
        end
    end
end


---Get a user's multiline input
---@param header string The header to display at the top of the screen
---@param preamble string? Some string to display before the user's input
---@return string
local function getMultilineInput(header, preamble)
    ---Put the exit instructions at the bottom of the screen, with a grey background.
    ---Then take input from the user, making sure to scroll everything up if the user goes past the bottom of the screen.
    ---(but make sure to keep the exit instructions at the bottom of the screen)
    local function writeHeaderAndFooter()
        writeHeader(header)
        writeFooter("Hold Ctrl+T to exit | Put . by itself to send")
    end

    term.setCursorPos(1, 2)
    term.clear()

    for line in (preamble or ""):gmatch("([^\n]*)\n?") do
        print(line .. "\n")

        local prevX, prevY = term.getCursorPos()

        if prevY == termHeight then
            term.scroll(1)
            term.setCursorPos(prevX, prevY - 1)
            -- writeHeaderAndFooter()
        end
    end

    writeHeaderAndFooter()

    local lines = {}

    while true do
        term.clearLine()
        term.write("> ")

        local line = read()

        if line == "." then
            break
        end

        table.insert(lines, line)

        local _, currentY = term.getCursorPos()

        if currentY == termHeight then
            local prevX, prevY = term.getCursorPos()

            term.scroll(1)
            term.setCursorPos(prevX, prevY - 1)

            writeHeaderAndFooter()
        end
    end

    cleanup()

    return table.concat(lines, "\n")
end
    


local function main()
    local args = arg
    local command = args[1]

    if command == "read" then
        local raw_id = args[2]

        local unread_messages = client:getInboxUnread()

        if unread_messages == nil then
            printError("Failed to fetch unread mail")
            return
        end

        local read_messages = client:getInboxRead()

        if read_messages == nil then
            printError("Failed to fetch read mail")
            return
        end

        if not raw_id then
            if #unread_messages == 0 and #read_messages == 0 then
                print("No mail")
                return
            end

            if #read_messages > 0 then
                print("Read messages:")
                printMessages(read_messages)
            end

            if #unread_messages > 0 then
                print("Unread messages:")
                printMessages(unread_messages)
            end

            return
        end

        local group, id_string = raw_id:match("^(%a)%.(%d+)$")

        if not group or not id_string then
            printError("Invalid message ID")
            return
        end

        local id = tonumber(id_string)

        local range, message

        if group == "u" then
            if id < 1 or id > #unread_messages then
                range = #unread_messages > 0 and "1-" .. #unread_messages or "no unread messages"
                printError("Invalid message ID (" .. range .. ")")
                return
            end

            message = unread_messages[id]
        elseif group == "r" then
            if id < 1 or id > #read_messages then
                range = #read_messages > 0 and "1-" .. #read_messages or "no read messages"
                printError("Invalid message ID (" .. range .. ")")
                return
            end

            message = read_messages[id]
        else
            printError("Invalid group (u, r)")
            return
        end

        local statusString = "From: " .. message.from .. " | " .. message.subject

        local success, err = pcall(functionPagedPrintFancy, message.body, statusString)

        if not success then
            cleanup()
            if err ~= "Terminated" then
                printError(err)
                return
            end
        end

        if group == "u" and not client:markInboxRead(message) then
            printError("Failed to mark message as read")
        end

        return
    elseif command == "send" then
        local recipients_raw = args[2]
        local subject = args[3]

        if not recipients_raw or not subject then
            printError("Usage: mail send <recipients> <subject>")
            return
        end

        local recipients = {}

        for recipient in recipients_raw:gmatch("[^,]+") do
            table.insert(recipients, recipient)
        end

        local statusString = "To: " .. table.concat(recipients, ", ") .. " | " .. subject

        local message = getMultilineInput(statusString)

        local success = client:sendMail(recipients, subject, message)

        if success then
            print("Mail sent successfully")

            local address_book = settings.get("mail.address-book") or {}
            for _, recipient in ipairs(recipients) do
                local found_match = false

                for _, known_recipient in ipairs(address_book) do
                    if known_recipient == recipient then
                        found_match = true
                    end
                end

                if not found_match then
                    table.insert(address_book, recipient)
                end

                settings.set("mail.address-book", address_book)
                settings.save()
            end
        else
            printError("Failed to send mail")
        end

        return
    elseif command == "reply" then
        local raw_id = args[2]

        if not raw_id then
            printError("Usage: mail reply <message ID>")
            return
        end

        local unread_messages = client:getInboxUnread()

        if unread_messages == nil then
            printError("Failed to fetch unread mail")
            return
        end

        local read_messages = client:getInboxRead()

        if read_messages == nil then
            printError("Failed to fetch read mail")
            return
        end

        local group, id_string = raw_id:match("^(%a)%.(%d+)$")

        if not group or not id_string then
            printError("Invalid message ID")
            return
        end

        local id = tonumber(id_string)

        local range, replyToMessage

        if group == "u" then
            if id < 1 or id > #unread_messages then
                range = #unread_messages > 0 and "1-" .. #unread_messages or "no unread messages"
                printError("Invalid message ID (" .. range .. ")")
                return
            end

            replyToMessage = unread_messages[id]
        elseif group == "r" then
            if id < 1 or id > #read_messages then
                range = #read_messages > 0 and "1-" .. #read_messages or "no read messages"
                printError("Invalid message ID (" .. range .. ")")
                return
            end

            replyToMessage = read_messages[id]
        else
            printError("Invalid group (u, r)")

            return
        end

        local newSubject = replyToMessage.subject

        if not replyToMessage.subject:match("^Re: ") then
            newSubject = "Re: " .. replyToMessage.subject
        end

        local newMessage = ""

        ---Add "On <date>, <time>, <from> wrote:" to the end of the line with the last "---" line in the message
        local insertLine = 0

        local index = 0
        -- for each line including blank lines
        for line in replyToMessage.body:gmatch("([^\n]*)\n?") do
            index = index + 1

            if line:match("^%-%-%-") then
                insertLine = index
            end
        end

        index = 0
        for line in replyToMessage.body:gmatch("([^\n]*)\n?") do
            index = index + 1

            if index == insertLine or index == 1 and insertLine == 0 then
                local historyStub = "On " .. os.date("%Y-%m-%d %H:%M:%S", replyToMessage.timestamp) .. ", " .. replyToMessage.from .. " wrote:"

                if insertLine == 0 then
                    newMessage = newMessage .. "--- " .. historyStub .. "\n\n" .. line
                else
                    newMessage = newMessage .. line .. " " .. historyStub
                end
            else
                newMessage = newMessage .. line
            end

            newMessage = newMessage .. "\n"
        end

        local statusString = "To: " .. replyToMessage.from .. " | " .. newSubject

        local message = getMultilineInput(statusString, "\n\n" .. newMessage)

        newMessage = newMessage .. "\n---\n\n" .. message

        local success = client:sendMail({replyToMessage.from}, newSubject, newMessage)

        if success then
            print("Mail sent successfully")
        else
            printError("Failed to send mail")
        end

        return
    elseif command == "delete" then
        local raw_id = args[2]

        local unread_messages = client:getInboxUnread()

        if unread_messages == nil then
            printError("Failed to fetch unread mail")
            return
        end

        local read_messages = client:getInboxRead()

        if read_messages == nil then
            printError("Failed to fetch read mail")
            return
        end

        if not raw_id then
            if #unread_messages == 0 and #read_messages == 0 then
                print("No mail")
                return
            end

            if #read_messages > 0 then
                print("Read messages:")
                printMessages(read_messages)
            end

            if #unread_messages > 0 then
                print("Unread messages:")
                printMessages(unread_messages)
            end

            return
        end

        local group, id_string = raw_id:match("^(%a)%.(%d+)$")

        if not group or not id_string then
            printError("Invalid message ID")
            return
        end

        local id = tonumber(id_string)

        local range, message

        if group == "u" then
            if id < 1 or id > #unread_messages then
                range = #unread_messages > 0 and "1-" .. #unread_messages or "no unread messages"
                printError("Invalid message ID (" .. range .. ")")
                return
            end

            message = unread_messages[id]
        elseif group == "r" then
            if id < 1 or id > #read_messages then
                range = #read_messages > 0 and "1-" .. #read_messages or "no read messages"
                printError("Invalid message ID (" .. range .. ")")
                return
            end

            message = read_messages[id]
        else
            printError("Invalid group (u, r)")

            return
        end

        if client:deleteInboxMessage(message) then
            print("Message deleted")
        else
            printError("Failed to delete message")
        end

        return
    end

    printError("Invalid command (read, send, reply, delete)")
end


local success, err = pcall(main)

if not success then
    cleanup()
    if err ~= "Terminated" then
        printError(err)
    end
end
