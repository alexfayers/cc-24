package.path = package.path .. ";/usr/lib/?.lua"

require("lib-crafter.server.CraftServer")

CraftServer():listen()
