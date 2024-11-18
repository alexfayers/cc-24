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


---Check if a table's keys contains a specific value
---@param t table The table to check
---@param value any The value to check for
---@return boolean
local function contains(t, value)
    return t[value] ~= nil
end


---Check if a table's values contain a specific value
---@param t table The table to check
---@param value any The value to check for
---@return boolean
local function valuesContain(t, value)
    for _, v in pairs(t) do
        if v == value then
            return true
        end
    end
    return false
end



---Group a list of tables by a function that returns a key
---@generic T: table
---@generic K: string
---@param list T[] The list of tables to group
---@param keyFunction fun(item: T): K The key to group by
---@return table<K, T>
local function groupBy(list, keyFunction)
    local grouped = {}
    for _, item in ipairs(list) do
        local key = keyFunction(item)
        if not grouped[key] then
            grouped[key] = {}
        end
        table.insert(grouped[key], item)
    end
    return grouped
end


---Batch a list of items into groups of a certain size, with the last group being the remainder
---@generic T: table
---@param list T The list of items to batch
---@param batchSize number The size of each batch
---@return T[]
local function batch(list, batchSize)
    local batches = {}
    local currentBatch = {}
    for i, item in ipairs(list) do
        table.insert(currentBatch, item)
        if i % batchSize == 0 then
            table.insert(batches, currentBatch)
            currentBatch = {}
        end
    end
    if #currentBatch > 0 then
        table.insert(batches, currentBatch)
    end
    return batches
end


---Copy a table
---@generic T: table
---@param t T The table to copy
---@return T
local function copy(t)
    local newTable = {}
    for k, v in pairs(t) do
        newTable[k] = v
    end
    return newTable
end


---Concatenate two lists
---@generic T: any[]
---@param list1 T The first list
---@param list2 T The second list
---@return T
local function concat(list1, list2)
    local newList = {}
    for _, item in ipairs(list1) do
        table.insert(newList, item)
    end
    for _, item in ipairs(list2) do
        table.insert(newList, item)
    end
    return newList
end


return {
    spairs = spairs,
    filterTable = filterTable,
    tableIsEmpty = tableIsEmpty,
    saveTable = saveTable,
    loadTable = loadTable,
    ensureUniqueKeys = ensureUniqueKeys,
    contains = contains,
    valuesContain = valuesContain,
    groupBy = groupBy,
    batch = batch,
    copy = copy,
    concat = concat,
}