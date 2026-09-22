ITEM.name = "bpEntityBaseName"
ITEM.description = "."
ITEM.category = "Entity"
ITEM.entityclass = nil

ITEM.model = "models/props_junk/cardboard_box001a.mdl"

ITEM.dropModel = "models/props_junk/cardboard_box001a.mdl"

ITEM.deployable = false

ITEM.deploySound = "npc/zombie/foot_slide1.wav"

local PLACE_RANGE = 300

function ITEM:Save(entity)
end


function ITEM:Load(entity, data)
end

ITEM.functions.Place = {
    name = "entPlaceFunctionName",
    icon = "icon16/box.png",
    OnCanRun = function(itemTable)
        return not itemTable.deployable
    end,
    OnRun = function(item)
        local client = item.player

        if (not IsValid(client)) then return false end

        local character = client:GetCharacter()

        if (not character) then return false end

        local trace = client:GetEyeTrace()

        if (not trace.Hit) then
            client:NotifyLocalized("entCantPlaceHere")
            return false
        end

        if (trace.HitPos:Distance(client:GetPos()) > PLACE_RANGE) then
            client:NotifyLocalized("entTooFar")
            return false
        end

        if (not ix.entityplacing.CanPlaceEntity(client, character)) then return false end

        local entity = ents.Create(item.entityclass)

        if (not IsValid(entity)) then return false end

        entity:SetPos(trace.HitPos)
        entity:SetAngles(Angle(0, client:EyeAngles().y, 0))
        entity:Spawn()
        entity:Activate()

        -- OBBMins is only valid once the model is loaded (after Spawn), so
        -- only now can we push the entity up by its own bottom offset - the
        -- same trick the SWEP's ghost preview uses - instead of an arbitrary
        -- fixed offset that can leave it floating or sunk into the floor.
        entity:SetPos(trace.HitPos - trace.HitNormal * entity:OBBMins().z)

        ix.entityplacing.SetOwner(entity, character)
        entity.ixItemEnt = true

        item:Load(entity, item.data)
        ix.entityplacing.PlayDeployEffects(entity, item)

        local physObj = entity:GetPhysicsObject()

        if (IsValid(physObj)) then
            physObj:Wake()
        end

        return true
    end
}


ITEM.functions.Deploy = {
    icon = "icon16/box.png",
    OnCanRun = function(itemTable)
        local client = itemTable.player
        return itemTable.deployable and (not client:GetLocalVar("furniture", false))
    end,
    OnRun = function(itemTable)
        local client = itemTable.player

        client:SetLocalVar("furniture", {
            item_entity = itemTable.entity or nil,
            item = itemTable.uniqueID,
            model = itemTable.model,
            class = itemTable.entityclass
        })

        client:Give("ix_building")
        client:SelectWeapon("ix_building")

        return false
    end
}

function ITEM:OnDeploy(client, entity)
end
