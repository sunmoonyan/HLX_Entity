
local function removeOwnedEntities(characterID, onlyProps)
    local removed = 0

    for _, v in ipairs(ents.GetAll()) do
        if (IsValid(v) and ix.entityplacing.GetOwnerID(v) == characterID) then
            if (not onlyProps or v:GetClass() == "prop_physics") then
                v:Remove()
                removed = removed + 1
            end
        end
    end

    return removed
end

ix.command.Add("CharRemoveProps", {
    description = "@entRemovePropsDesc",
    adminOnly = true,
    arguments = ix.type.character,
    OnRun = function(self, client, target)
        local removed = removeOwnedEntities(target:GetID(), true)

        client:NotifyLocalized("entRemovedProps", removed, target:GetName())
    end
})

ix.command.Add("CharRemoveEntities", {
    description = "@entRemoveEntitiesDesc",
    adminOnly = true,
    arguments = ix.type.character,
    OnRun = function(self, client, target)
        local removed = removeOwnedEntities(target:GetID(), false)

        if (removed == 1) then
            client:NotifyLocalized("entRemovedEntitySingular", target:GetName())
        else
            client:NotifyLocalized("entRemovedEntitiesPlural", removed, target:GetName())
        end
    end
})
