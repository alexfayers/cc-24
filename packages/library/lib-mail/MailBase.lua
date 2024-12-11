---Base class for mail client and server
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

local MailMessage = require("lib-mail.MailMessage")
local Constants = require("lib-mail.Constants")

local logger = require("lexicon-lib.lib-logging").getLogger("MailBase")

---@class MailBase: Class
---@overload fun(): MailBase
local MailBase = class()


---Initialise a new mail base
function MailBase:init()
    self.inboxFolder = fs.combine(Constants.MAIL_FOLDER, Constants.INBOX_FOLDER_NAME)
    self.outboxFolder = fs.combine(Constants.MAIL_FOLDER, Constants.OUTBOX_FOLDER_NAME)

    self:ensureFolders()
end


---Ensure the mail folders exist
---@param folder string
function MailBase.ensureFolder(folder)
    if not fs.exists(folder) then
        fs.makeDir(folder)
    end
end


---Ensure the read and unread subfolder folders exist in a folder
---Will also create parent folder if it does not exist
---@param folder string
function MailBase.ensureReadUnreadFolders(folder)
    local unreadFolder = fs.combine(folder, Constants.UNREAD_FOLDER_NAME)
    MailBase.ensureFolder(unreadFolder)

    local readFolder = fs.combine(folder, Constants.READ_FOLDER_NAME)
    MailBase.ensureFolder(readFolder)
end


---Ensure the mail folders exist
function MailBase:ensureFolders()
    MailBase.ensureFolder(Constants.MAIL_FOLDER)

    MailBase.ensureReadUnreadFolders(self.inboxFolder)
    MailBase.ensureReadUnreadFolders(self.outboxFolder)
end


---Get the count of unread mail in a folder
---@param folder string
---@return number
function MailBase:getUnreadCount(folder)
    return #fs.list(fs.combine(folder, Constants.UNREAD_FOLDER_NAME))
end

---Get the count of read mail in a folder
---@param folder string
---@return number
function MailBase:getReadCount(folder)
    return #fs.list(fs.combine(folder, Constants.READ_FOLDER_NAME))
end


---Mark a mail message as read
---@param folder string
---@param message MailMessage
---@return boolean
function MailBase:markRead(folder, message)
    local unreadPath = fs.combine(folder, Constants.UNREAD_FOLDER_NAME, message.filename)
    local readPath = fs.combine(folder, Constants.READ_FOLDER_NAME, message.filename)

    if not fs.exists(unreadPath) then
        logger:error("Mail message does not exist: %s", unreadPath)
        return false
    end

    fs.move(unreadPath, readPath)

    return true
end


---Mark a mail message as unread
---@param folder string
---@param message MailMessage
---@return boolean
function MailBase:markUnread(folder, message)
    local readPath = fs.combine(folder, Constants.READ_FOLDER_NAME, message.filename)
    local unreadPath = fs.combine(folder, Constants.UNREAD_FOLDER_NAME, message.filename)

    if not fs.exists(readPath) then
        logger:error("Mail message does not exist: %s", readPath)
        return false
    end

    fs.move(readPath, unreadPath)

    return true
end


---Delete a mail message
---@param folder string
---@param message MailMessage
---@return boolean
function MailBase:deleteMessage(folder, message)
    local unreadPath = fs.combine(folder, Constants.UNREAD_FOLDER_NAME, message.filename)
    local readPath = fs.combine(folder, Constants.READ_FOLDER_NAME, message.filename)

    if fs.exists(unreadPath) then
        fs.delete(unreadPath)
    end

    if fs.exists(readPath) then
        fs.delete(readPath)
    end

    return true
end


return MailBase
