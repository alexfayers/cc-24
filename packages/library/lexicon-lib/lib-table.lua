---Helper functions for working with tables.


---Sort a table by key, in place (or by a custom order function)
---From https://stackoverflow.com/questions/15706270/sort-a-table-in-lua
---@param t table The table to sort
---@param order? function The order function to use
---@return function
local function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end


---Filter a table using a function
---@generic T: table
---@param tbl T The table to filter
---@param filter function The function to use to filter the table (takes an item and returns a boolean)
---@return T
local function filterTable(tbl, filter)
    local filtered = {}
    for _, item in ipairs(tbl) do
        if filter(item) then
            table.insert(filtered, item)
        end
    end
    return filtered
end


---Check if a table is empty
---@param table table
---@return boolean
local function tableIsEmpty(table)
    local next = next
    return next(table) == nil
end


---Save a table to a file as json
---@param path string The path to save the file to
---@param data table The data to save
---@return boolean, string? success Whether the save was successful, and an error message if it failed
local function saveTable(path, data)
    local file = fs.open(path, "w")
    if not file then
        return false, "Failed to open file for writing"
    end
    file.write(textutils.serialiseJSON(data))
    file.close()

    return true
end


---Load a table from a file
---@param path string The path to load the file from
---@return table|nil, string? t The loaded table, or an error message if it failed
local function loadTable(path)
    if not fs.exists(path) then
        return nil, "File does not exist"
    end

    local file = fs.open(path, "r")

    if not file then
        return nil, "Failed to open file for reading"
    end

    local data = file.readAll()
    file.close()

    if not data then
        return nil, "Failed to read file or the file was empty"
    end

    local jsonData = textutils.unserialiseJSON(data)

    if not jsonData then
        return nil, "Failed to parse json data from file"
    end

    return jsonData
end


---Ensure that a table has unique keys (mainly to prevent serialisation issues)
---@generic T: table
---@param t T The table to ensure unique keys for
---@return T
local function ensureUniqueKeys(t)
    local uniqueTags = {}
    for tag, value in pairs(t) do
        uniqueTags[tag] = value
    end
    return uniqueTags
end


return {
    spairs = spairs,
    filterTable = filterTable,
    tableIsEmpty = tableIsEmpty,
    saveTable = saveTable,
    loadTable = loadTable,
    ensureUniqueKeys = ensureUniqueKeys,
}