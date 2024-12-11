package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

local logger = require("lexicon-lib.lib-logging").getLogger("MailMessage")


---@class MailMessage: Class
---@overload fun(from: string, to: string[], subject: string, body: string, id: string?): MailMessage
local MailMessage = class()


---Initialise a new mail message
---@param from string
---@param to string[]
---@param subject string
---@param body string
---@param id string?
function MailMessage:init(from, to, subject, body, id)
    self.from = from
    self.to = to
    if #self.to == 0 then
        logger:warn("Message has no recipients, this is probably a mistake")
    end

    self.subject = subject
    self.body = body

    self.id = id or self:makeId()
    self.filename = self.id .. ".mail"
end


---Make a filename for the message
---@return string
function MailMessage:makeId()
    return self.subject:gsub("%s+", "_"):gsub("[^%w]", "") .. "-" .. os.epoch("utc") .. "-" .. math.random(1000, 9999)
end


---Serialise the mail message
---@return string
function MailMessage:serialise()
    return textutils.serialise({
        from = self.from,
        to = self.to,
        subject = self.subject,
        body = self.body,
        id = self.id,
    }, { compact = true })
end


---Deserialise a mail message
---@param data string
---@return MailMessage?
function MailMessage.deserialise(data)
    local message = textutils.unserialise(data)

    if not message then
        return
    end

    if not message.from then
        logger:error("Message is missing 'from' field")
        return
    end

    if not type(message.from) == "string" then
        logger:error("Message 'from' field must be a string")
        return
    end

    if not message.to then
        logger:error("Message is missing 'to' field")
        return
    end

    if not type(message.to) == "table" then
        logger:error("Message 'to' field must be a table")
        return
    end

    for _, to in ipairs(message.to) do
        if not type(to) == "string" then
            logger:error("Message 'to' field must be a table of strings")
            return
        end
    end

    if not message.subject then
        logger:error("Message is missing 'subject' field")
        return
    end

    if not type(message.subject) == "string" then
        logger:error("Message 'subject' field must be a string")
        return
    end

    if not message.body then
        logger:error("Message is missing 'body' field")
        return
    end

    if not type(message.body) == "string" then
        logger:error("Message 'body' field must be a string")
        return
    end

    if message.id and not type(message.id) == "string" then
        logger:error("Message 'id' field must be a string")
        return
    end

    return MailMessage(message.from, message.to, message.subject, message.body, message.id)
end


return MailMessage