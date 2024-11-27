---Start the door server
package.path = package.path .. ";/usr/lib/?.lua"

require("lib-door.DoorServer")

DoorServer():listen()
