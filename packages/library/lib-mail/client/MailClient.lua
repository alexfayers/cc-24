package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

require("lib-remote.Client")

local MailMessage = require("lib-mail.MailMessage")
local MailBase = require("lib-mail.MailBase")
local Constants = require("lib-mail.Constants")
local lib = require("lib-mail.lib")

local logger = require("lexicon-lib.lib-logging").getLogger("MailClient")


---@class MailClient: Client
---@overload fun(): MailClient
local MailClient = Client:extend()

MailClient.protocol = Constants.PROTOCOL_NAME


---Initialise a new mail client
function MailClient:init()
    MailBase.init(self)
    Client.init(self)
end


---Send a mail message
---@param recipients string[]
---@param subject string
---@param body string
---@return boolean, nil
function MailClient:sendMail(recipients, subject, body)
    local message = MailMessage(Constants.LOCAL_SERVER_HOSTNAME, recipients, subject, body)

    local successCount = 0
    local expectedSuccessCount = #message.to

    for _, to in ipairs(message.to) do
        logger:info("Sending mail to %s...", to)

        if not self:baseSendCommand(Constants.MAIL_COMMAND, {
            message = message:serialise(),
        }, to)
        then
            successCount = successCount + 1
            logger:error("Failed to send mail to '%s'", to)
        end
    end

    if successCount == expectedSuccessCount then
        return true
    end

    logger:warn("Failed to send mail to %d recipients", expectedSuccessCount - successCount)
    return false
end


---Fetch unread mail messages from a folder path
---@param folder string
---@return MailMessage[]?
function MailClient:fetchMail(folder)
    local messages = {}

    for _, file in ipairs(fs.list(folder)) do
        local path = fs.combine(folder, file)
        local data = fs.open(path, "r")

        if not data then
            logger:error("Failed to open file: %s", path)
            return
        end

        local serialised = data.readAll()

        if not serialised then
            logger:error("Failed to read file: %s", path)
            return
        end

        local message = MailMessage.deserialise(serialised)
        data.close()

        if message then
            table.insert(messages, message)
        end
    end

    return messages
end


---Fetch unread mail messages from a folder
---@param folder string
---@return MailMessage[]?
function MailClient:fetchUnreadMail(folder)
    return self:fetchMail(fs.combine(folder, Constants.UNREAD_FOLDER_NAME))
end


---Fetch read mail messages from a folder
---@param folder string
---@return MailMessage[]?
function MailClient:fetchReadMail(folder)
    return self:fetchMail(fs.combine(folder, Constants.READ_FOLDER_NAME))
end


---Get all mail folders
---@return string[]
function MailClient:getFolders()
    return fs.list(Constants.MAIL_FOLDER)
end


---Get the unread mails from the inbox
---@return MailMessage[]?
function MailClient:getInboxUnread()
    return self:fetchUnreadMail(Constants.INBOX_FOLDER)
end


---Get the read mails from the inbox
---@return MailMessage[]?
function MailClient:getInboxRead()
    return self:fetchReadMail(Constants.INBOX_FOLDER)
end


---Get the count of unread mail in the inbox
---@return number
function MailClient:getInboxUnreadCount()
    return lib.getUnreadCount(Constants.INBOX_FOLDER)
end


---Get the count of read mail in the inbox
---@return number
function MailClient:getInboxReadCount()
    return lib.getReadCount(Constants.INBOX_FOLDER)
end


---Mark an inbox message as read
---@param message MailMessage
---@return boolean
function MailClient:markInboxRead(message)
    return lib.markRead(Constants.INBOX_FOLDER, message)
end


---Mark an inbox message as unread
---@param message MailMessage
---@return boolean
function MailClient:markInboxUnread(message)
    return lib.markUnread(Constants.INBOX_FOLDER, message)
end


---Delete an inbox message
---@param message MailMessage
---@return boolean
function MailClient:deleteInboxMessage(message)
    local readPath = fs.combine(Constants.INBOX_FOLDER, Constants.READ_FOLDER_NAME, message.filename)
    local unreadPath = fs.combine(Constants.INBOX_FOLDER, Constants.UNREAD_FOLDER_NAME, message.filename)

    if fs.exists(readPath) then
        fs.delete(readPath)
    elseif fs.exists(unreadPath) then
        fs.delete(unreadPath)
    else
        logger:error("Mail message does not exist: %s", readPath)
        return false
    end

    return true
end



return MailClient
