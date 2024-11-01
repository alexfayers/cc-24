-- Setup fake peripherals for testing using the periphemu api

if periphemu.create("left", "chest", true) then
    print("Created fake chest on left")
else
    print("Already created fake chest on left")
end

if periphemu.create("right", "chest") then
    print("Created fake chest on right")
else
    print("Already created fake chest on right")
end

if periphemu.create("bottom", "chest", true) then
    print("Created fake chest on bottom")
else
    print("Already created fake chest on bottom")
end

if periphemu.create("top", "chest", true) then
    print("Created fake chest on top")
else
    print("Already created fake chest on top")
end

local storageChest = peripheral.wrap("bottom")
print(storageChest.setItem(1, { name = "minecraft:stone", count = 64 }))

storageChest = peripheral.wrap("top")
print(storageChest.setItem(2, { name = "minecraft:dirt", count = 32 }))
print(storageChest.setItem(3, { name = "minecraft:stone", count = 32 }))
