---Message types

---@enum MessageType
MessageType = { ---@class _MessageType
    ACK = "ACK",
    END = "END",
    ERR = "ERR",
    CMD = "CMD",
}


---@enum MessageErrorCode
MessageErrorCode = {  ---@class _MessageErrorCode
    INVALID_DATA_TYPE = "INVALID_DATA_TYPE",
    UNKNOWN_COMMAND = "UNKNOWN_COMMAND",
    UNKNOWN = "UNKNOWN",
}


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

---@alias MessageEndData table?

---@class MessageErrorData
---@field code MessageErrorCode
---@field message? string

---@class MessageCommandData
---@field type string
---@field data? table

---@alias MessageData MessageErrorData|MessageCommandData|MessageEndData


---@alias CommandHandler fun(clientId: number, data?: table): boolean, table?
