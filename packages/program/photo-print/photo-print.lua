---Program to print computercraft nfp images
package.path = package.path .. ";/usr/lib/?.lua"
require("lib-storage2.remote.StorageClient")


---TODO: make smarter
---@type string
local outputChestName = settings.get("storage2.outputChest")

local outputChest = peripheral.wrap(outputChestName) or error("Failed to wrap output chest", 0)
---@cast outputChest ccTweaked.peripherals.Inventory

local storageClient = StorageClient()

local DYE_COLOR_MAP = {
    ["0"] = "white",
    ["1"] = "orange",
    ["2"] = "magenta",
    ["3"] = "light_blue",
    ["4"] = "yellow",
    ["5"] = "lime",
    ["6"] = "pink",
    ["7"] = "gray",
    ["8"] = "light_gray",
    ["9"] = "cyan",
    ["a"] = "purple",
    ["b"] = "blue",
    ["c"] = "brown",
    ["d"] = "green",
    ["e"] = "red",
    ["f"] = "black",
}

local PAGE_WIDTH = 25
local PAGE_HEIGHT = 21

local _, termHeight = term.getSize()


---Check if there is enough ink to print the image
---@param image table The image to print
---@return boolean, string[]? # Whether there is enough ink, and the required inks if there's enough
local function calculateRequiredInk(image)
    local requiredInks = {}

    for y = 1, #image do
        for x = 1, #image[y] do
            local pixelColor = image[y][x]
            if pixelColor and pixelColor ~= 0 then
                local pixelPrintColor = colors.toBlit(pixelColor)
                requiredInks[pixelPrintColor] = true
            end
        end
    end

    for ink in pairs(requiredInks) do
        if not DYE_COLOR_MAP[ink] then
            error("Invalid ink color: " .. ink, 0)
        end

        local itemCountRes, itemCountData = storageClient:getItemCount(DYE_COLOR_MAP[ink] .. "_dye")
        if not itemCountRes or not itemCountData then
            error("Failed to get ink count", 0)
        end

        if itemCountData.count < 1 then
            printError("Not enough " .. DYE_COLOR_MAP[ink] .. " dye")
            return false, nil
        end
    end

    return true, requiredInks
end


---Print a photo
---@param imagePath string The path to the image
---@return boolean Whether the image was printed
local function printPhoto(imagePath)
    local printer = peripheral.find("printer")
    if not printer then
        error("No printer found", 0)
    end
    ---@cast printer ccTweaked.peripherals.Printer
    local printerName = peripheral.getName(printer)

    local imageRaw = fs.open(imagePath, "r")
    if not imageRaw then
        error("Failed to open image", 0)
    end

    local image = paintutils.loadImage(imagePath)
    if not image then
        error("Failed to load image", 0)
    end

    if #image[1] > PAGE_WIDTH or #image > PAGE_HEIGHT then
        error("Image is too large to print. Max size is " .. PAGE_WIDTH .. "x" .. PAGE_HEIGHT, 0)
    end

    local paperCount = printer.getPaperLevel()
    if paperCount < 1 then
        error("Out of paper", 0)
    end

    local haveRequiredInk, requiredInks = calculateRequiredInk(image)

    if not haveRequiredInk or not requiredInks then
        return false
    end

    term.setCursorPos(1, 1)
    term.clear()
    term.write("Printing...")

    -- go through each ink color, pull the ink into the printer, print the page
    -- then pull the page back into the input slot and repeat until all inks are used

    for inkColor in pairs(requiredInks) do
        local inkColorName = DYE_COLOR_MAP[inkColor]

        local pullRes, pullData = storageClient:pull(outputChestName, inkColorName .. "_dye", 1, 27, false)
        if not pullRes or not pullData then
            error("Failed to pull " .. inkColorName .. " dye", 0)
        end

        if not outputChest.pushItems(printerName, 27, 1) then
            error("Failed to push " .. inkColorName .. " dye into printer", 0)
        end

        printer.newPage()

        printer.setPageTitle(fs.getName(imagePath))

        for y = 1, #image do
            for x = 1, #image[y] do
                local pixelColor = image[y][x]

                if pixelColor and pixelColor ~= 0 and colors.toBlit(pixelColor) == inkColor then
                    term.setCursorPos(1,1)
                    term.clearLine()
                    term.write("Printing " .. inkColorName .. ": " .. x .. "," ..y)

                    if y + 1 <= termHeight then
                        local prevTextColor = term.getTextColor()
                        term.setCursorPos(x, y + 1)
                        term.setTextColor(pixelColor)
                        term.write("#")
                        term.setTextColor(prevTextColor)
                    end

                    printer.setCursorPos(x, y)
                    printer.write("#")
                end
            end
        end

        printer.endPage()

        if not outputChest.pullItems(printerName, 8, 1, 27) then
            error("Failed to pull page from printer", 0)
        end

        if not outputChest.pushItems(printerName, 27, 1, 2) then
            error("Failed to push page back into printer", 0)
        end
    end

    if not outputChest.pullItems(printerName, 2, 1) then
        error("Failed to pull final printed page from printer", 0)
    end

    term.setCursorPos(1, 1)
    term.clearLine()
    term.write("Print complete")
    term.setCursorPos(1, termHeight)

    return true
end


if #arg < 1 then
    printError("Usage: photo-print <image>")
    return
end

printPhoto(arg[1])
