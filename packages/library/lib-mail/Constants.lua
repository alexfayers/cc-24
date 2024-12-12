settings.define("mail.folder", {
    description = "The folder to store mail in",
    type = "string",
    default = "/mail",
})
---@type string
local MAIL_FOLDER = settings.get("mail.folder") or error("mail.folder setting must be set", 0)

settings.define("mail.notifySound", {
    description = "The sound to play when a new mail is received",
    type = "string",
    default = "block.note_block.bit",
})
---@type string
local NOTIFY_SOUND = settings.get("mail.notifySound")


settings.define("mail.username", {
    description = "The hostname of the local mail server",
    type = "string",
    default = nil,
})
---@type string
local LOCAL_SERVER_HOSTNAME = settings.get("mail.username") or error("mail.username setting must be set", 0)

settings.define("mail.client.notify-poll-interval", {
    description = "The interval to poll for new mail",
    type = "number",
    default = 60,
})
---@type number
local NOTIFY_POLL_INTERVAL = settings.get("mail.client.notify-poll-interval")


local INBOX_FOLDER_NAME = "inbox"
local OUTBOX_FOLDER_NAME = "outbox"


local INBOX_FOLDER = fs.combine(MAIL_FOLDER, INBOX_FOLDER_NAME)
local OUTBOX_FOLDER = fs.combine(MAIL_FOLDER, OUTBOX_FOLDER_NAME)


local Constants = {
    INBOX_FOLDER_NAME = INBOX_FOLDER_NAME,
    OUTBOX_FOLDER_NAME = OUTBOX_FOLDER_NAME,

    UNREAD_FOLDER_NAME = "unread",
    READ_FOLDER_NAME = "read",

    MAIL_FOLDER = MAIL_FOLDER,
    NOTIFY_SOUND = NOTIFY_SOUND,
    LOCAL_SERVER_HOSTNAME = LOCAL_SERVER_HOSTNAME,

    MAIL_COMMAND = "MAIL",
    HOSTNAME_REQUEST_COMMAND = "HOST",

    PROTOCOL_NAME = "mail",

    INBOX_FOLDER = INBOX_FOLDER,
    OUTBOX_FOLDER = OUTBOX_FOLDER,

    NOTIFY_POLL_INTERVAL = NOTIFY_POLL_INTERVAL,
}

return Constants