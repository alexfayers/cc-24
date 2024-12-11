package.path = package.path .. ";/usr/lib/?.lua"
local MailServer = require("lib-mail.server.MailServer")
MailServer():listen()
