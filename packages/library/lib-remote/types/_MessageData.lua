---@class MessageDataWithId
---@field chat_id? number

---@class MessageAckData : MessageDataWithId

---@class MessageEndData : MessageDataWithId

---@class MessageErrorData : MessageDataWithId
---@field code MessageErrorCode
---@field message? string

---@class MessageCommandData : MessageDataWithId
---@field type string
---@field data? table

---@alias MessageData MessageAckData|MessageErrorData|MessageCommandData|MessageEndData
