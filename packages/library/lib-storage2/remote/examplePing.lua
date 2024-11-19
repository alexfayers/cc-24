---Example ping program
package.path = package.path .. ";/usr/lib/?.lua"

require("lib-storage2.remote.StorageClient")

local client = StorageClient()

client:callCommand(client.ping)
