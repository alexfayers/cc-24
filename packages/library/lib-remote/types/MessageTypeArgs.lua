---@class MessageDataArg
---@field name string
---@field type string|string[]

---@alias MessageDataArgs MessageDataArg[]


---@type table<MessageType, MessageDataArgs>
MessageTypeArgs = {
    [MessageType.END] = {
        {
            name = "data",
            type = {"table", "nil"},
        },
    },
    [MessageType.ERR] = {
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
            name = "type",
            type = "string",
        },
        {
            name = "data",
            type = {"table", "nil"},
        },
    },
}
