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
    default = "ui.toast.in",
})
---@type string
local NOTIFY_SOUND = settings.get("mail.notifySound")


settings.define("mail.client.local-server-hostname", {
    description = "The hostname of the local mail server",
    type = "string",
    default = nil,
})
---@type string
local LOCAL_SERVER_HOSTNAME = settings.get("mail.client.local-server-hostname") or error("mail.client.local-server-hostname setting must be set", 0)


local INBOX_FOLDER = fs.combine(Constants.MAIL_FOLDER, Constants.INBOX_FOLDER_NAME)
local OUTBOX_FOLDER = fs.combine(Constants.MAIL_FOLDER, Constants.OUTBOX_FOLDER_NAME)


local Constants = {
    INBOX_FOLDER_NAME = "inbox",
    OUTBOX_FOLDER_NAME = "outbox",

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
}

return Constants