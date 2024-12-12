---Simple mail server
---Works by listening for mail messages, and when it receives one the it will
---write the mail to a json file in the configured mail folder
---The file name is a hash of the mail.
---The mail contains the sender, recipients, and body.
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

require("lib-remote.Server")
local MailMessage = require("lib-mail.MailMessage")
local Constants = require("lib-mail.Constants")
local lib = require("lib-mail.lib")

local logger = require("lexicon-lib.lib-logging").getLogger("MailServer")


---@class MailServer: Server
---@overload fun(): MailServer
local MailServer = Server:extend()

MailServer.protocol = Constants.PROTOCOL_NAME


---Initialise a new mail server
function MailServer:init()
    Server.init(self, Constants.LOCAL_SERVER_HOSTNAME)

    self.speaker = self:wrapSpeaker()

    self.commandHandlers = {
        [Constants.MAIL_COMMAND] = self.handleMail,
        [Constants.HOSTNAME_REQUEST_COMMAND] = self.handleHostnameRequest,
    }

    self.backgroundTasks = {
        function () self:checkNotify() end,
    }
end


---Wrap a speaker peripheral if available
---@return ccTweaked.peripherals.Speaker?
function MailServer:wrapSpeaker()
    local wrapped = peripheral.find("speaker")
    ---@cast wrapped ccTweaked.peripherals.Speaker?

    return wrapped
end


---Notify the user that they have mail
---@param unreadCount number
function MailServer:notify(unreadCount)
    if self.speaker then
        for _ = 1, unreadCount do
            while not self.speaker.playSound(Constants.NOTIFY_SOUND) do
                -- wait for the speaker to be ready again
                os.sleep(0.5)
            end
        end
    else
        logger:info("You have %d unread mails!", unreadCount)
    end
end


---Handle mail notifications
---@return boolean
function MailServer:checkNotify()
    while true do
        local unreadCount = lib.getUnreadCount(Constants.INBOX_FOLDER)
        if unreadCount > 0 then
            self:notify(unreadCount)
        end

        os.sleep(Constants.NOTIFY_POLL_INTERVAL)
    end
end


---Handle a message command
---@param clientId number
---@param data table
---@return boolean, table?
function MailServer:handleMail(clientId, data)
    local message = MailMessage.deserialise(data.message)
    if not message then
        return false, { error = "Invalid message" }
    end

    local path = fs.combine(Constants.INBOX_FOLDER, Constants.UNREAD_FOLDER_NAME, message.filename)

    if fs.exists(path) then
        return false, { error = "Mail already exists" }
    end

    local file = fs.open(path, "w")

    if not file then
        return false, { error = "Failed to open file for writing" }
    end

    file.write(message:serialise())
    file.close()

    logger:info("New message from %s!", message.from)

    self:notify(1)

    return true
end


---Handle a hostname request command from a local client
---@param clientId number
---@param data table
---@return boolean, table?
function MailServer:handleHostnameRequest(clientId, data)
    if clientId ~= os.getComputerID() then
        return false, { error = "Invalid client" }
    end

    return true, { hostname = self.hostname }
end


return MailServer
