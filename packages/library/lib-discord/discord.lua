--- Api for sending notifications to a discord channel

settings.define("discord.webhook", {
    description = "The webhook URL to send notifications to",
    type = "string",
    default = "",
})


local discord_webhook = settings.get("discord.webhook")

---Send a notification to a discord channel
---@param username string The username to send the notification as
---@param content string The content of the notification
---@return boolean Whether the notification was sent successfully
local function send(username, content)
    if discord_webhook == "" then
        return false
    end

    if os.getComputerLabel() then
        username = username .. " (" .. os.getComputerLabel() .. ")"
    end

    local res = http.post(discord_webhook, textutils.serializeJSON({
        username = username,
        content = content,
    }), {
        ["Content-Type"] = "application/json",
    })

    if not res then
        return false
    end

    return true
end


return {
    send = send,
}