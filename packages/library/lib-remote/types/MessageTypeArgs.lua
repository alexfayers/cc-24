---@class MessageDataArg
---@field name string
---@field type string|string[]

---@alias MessageDataArgs MessageDataArg[]


---@type table<MessageType, MessageDataArgs>
MessageTypeArgs = {
    [MessageType.ACK] = {
        {
            name = "chat_id",
            type = {"number", "nil"},
        },
    },
    [MessageType.END] = {
        {
            name = "chat_id",
            type = {"number", "nil"},
        },
        {
            name = "data",
            type = {"table", "nil"},
        },
    },
    [MessageType.ERR] = {
        {
            name = "chat_id",
            type = {"number", "nil"},
        },
        {
            name = "code",
            type = "string",
        },
        {
            name = "message",
            type = {"string", "nil"},
        }
    },
    [MessageType.CMD] = {
        {
            name = "chat_id",
            type = {"number", "nil"},
        },
        {
            name = "type",
            type = "string",
        },
        {
            name = "data",
            type = {"table", "nil"},
        },
    },
}
