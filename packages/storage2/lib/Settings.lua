-- Setting config

settings.define("storage2.inputChest", {
    description = "The name of the chest that items are pulled from into the system",
    default = "left",
    type = "string",
})

settings.define("storage2.outputChest", {
    description = "The name of the chest that items are pushed to out of the system",
    default = "right",
    type = "string",
})

settings.define("storage2.storageFile", {
    description = "The path to the file that the storage map is saved to",
    default = "/.storage2/map.json",
    type = "string",
})

settings.define("storage2.itemDetailCacheFile", {
    description = "The path to the file that the storage map is saved to",
    default = "/.storage2/itemDetailCache.json",
    type = "string",
})

settings.define("storage2.filterDirectory", {
    description = "The directory to load filter files from",
    default = "/.storage2/filters",
    type = "string",
})
