
ITEM.name = "HEV Suit"
ITEM.description = "The embleamtic gordon freeman suit"
ITEM.category = "Entity"
ITEM.model = "models/items/hevsuit.mdl"
ITEM.width = 1
ITEM.height = 1

ITEM.entityclass = "item_suit"
ITEM.deployable = true
--[[
function ITEM:Save(entity)
    return {
        health = entity:Health()
    }
end

function ITEM:Load(entity, data)
    if (not istable(data)) then return end

    if (data.health) then
        entity:SetHealth(data.health)
    end
end
]]