---Mail program for cc:t. Uses lib-mail.
package.path = package.path .. ";/usr/lib/?.lua"
local completion = require("cc.completion")

local MailClient = require("lib-mail.client.MailClient")

local client = MailClient()


---Argument completion for the script
---@param _ any
---@param index number The index of the argument
---@param argument string The current arguments
---@param previous table
---@return table? _ A table of possible completions
local function complete(_, index, argument, previous)
    if index == 1 then
        return completion.choice(argument, {"read", "send", "delete"}, true)
    elseif index == 2 then
        if previous[2] == "read" then
            return completion.choice(argument, {"u.1"}, false)
        elseif previous[2] == "send" then
            return completion.choice(argument, {"recipient"}, true)
        elseif previous[2] == "delete" then
            return completion.choice(argument, {"1"}, false)
        end
    elseif index == 3 then
        if previous[2] == "send" then
            return completion.choice(argument, {"subject"}, false)
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

            if #unread_messages > 0 then
                print("Unread messages:")
                printMessages(unread_messages)
            end

            if #read_messages > 0 then
                print("Read messages:")
                printMessages(read_messages)
            end

            return
        end

        local group, id_string = raw_id:match("^(%a)%.(%d+)$")

        if not group or not id_string then
            printError("Invalid message ID")
            return
        end

        local id = tonumber(id_string)

        if group == "u" then
            if id < 1 or id > #unread_messages then
                printError("Invalid message ID (1-" .. #unread_messages .. ")")
                return
            end

            local message = unread_messages[id]

            print("From: " .. message.from)
            print("Subject: " .. message.subject)
            print()
            print(message.body)

            if not client:markInboxRead(message) then
                printError("Failed to mark message as read")
            end

            return
        elseif group == "r" then
            if id < 1 or id > #read_messages then
                printError("Invalid message ID (1-" .. #read_messages .. ")")
                return
            end

            local message = read_messages[id]

            print("From: " .. message.from)
            print("Subject: " .. message.subject)
            print()
            print(message.body)

            return
        end

        printError("Invalid group (u, r)")

        return
    elseif command == "send" then
        local recipients_raw = args[2]
        local subject = args[3]
        local message = args[4]

        if not recipients_raw or not subject or not message then
            printError("Usage: mail send <recipients> <subject> <message>")
            return
        end

        local recipients = {}

        for recipient in recipients_raw:gmatch("[^,]+") do
            table.insert(recipients, recipient)
        end

        local success = client:sendMail(recipients, subject, message)

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

            if #unread_messages > 0 then
                print("Unread messages:")
                printMessages(unread_messages)
            end

            if #read_messages > 0 then
                print("Read messages:")
                printMessages(read_messages)
            end

            return
        end

        local group, id_string = raw_id:match("^(%a)%.(%d+)$")

        if not group or not id_string then
            printError("Invalid message ID")
            return
        end

        local id = tonumber(id_string)

        if group == "u" then
            if id < 1 or id > #unread_messages then
                printError("Invalid message ID (1-" .. #unread_messages .. ")")
                return
            end

            local message = unread_messages[id]

            client:deleteInboxMessage(message)

            return
        elseif group == "r" then
            if id < 1 or id > #read_messages then
                printError("Invalid message ID (1-" .. #read_messages .. ")")
                return
            end

            local message = read_messages[id]

            client:deleteInboxMessage(message)

            return
        end

        printError("Invalid group (u, r)")

        return
    end

    printError("Invalid command (read, send, delete)")
end


main()

