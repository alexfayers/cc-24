---Host a remote control server for storage2
---Available via the `storage2-server` package
package.path = package.path .. ";/usr/lib/?.lua"

require("lib-storage2.remote.StorageServer")

StorageServer():listen()
