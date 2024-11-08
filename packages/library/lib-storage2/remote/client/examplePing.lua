---Example ping program
package.path = package.path .. ";/usr/lib/?.lua"
require("lib-storage2.remote.client.Client")
local client = Client()
client:callCommand(client.ping)
