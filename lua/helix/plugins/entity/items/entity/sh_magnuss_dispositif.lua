
ITEM.name = "Magnusson Dispositif"
ITEM.description = "A weird ball"
ITEM.category = "Entity"
ITEM.model = "models/magnusson_device.mdl"
ITEM.width = 1
ITEM.height = 1

ITEM.entityclass = "weapon_striderbuster"
ITEM.deployable = false
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