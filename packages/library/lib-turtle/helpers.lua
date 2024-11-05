---Helper functions for the turtle library

---Check if a block is replaceable after inspecting it (e.g. if a turtle can go into it)
---@param inspectData ccTweaked.turtle.inspectInfo The data from inspecting the block
---@return boolean
local function isBlockReplaceable(inspectData)
    for tag in pairs(inspectData.tags) do
        if tag == "minecraft:replaceable" then
            return true
        end
    end

    return false
end


return {
    isBlockReplaceable = isBlockReplaceable,
}