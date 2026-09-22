local PLUGIN = PLUGIN

PLUGIN.name = "Entity"
PLUGIN.author = "Sunshi & Pedro.Santos53"
PLUGIN.description = "Item base to spawn entities or place them with a builder."

ix.entityplacing = ix.entityplacing or {}
ix.entityplacing.itemsByClass = ix.entityplacing.itemsByClass or {}
ix.entityplacing.ignore = ix.entityplacing.ignore or {}
ix.entityplacing.ignore["ix_bed"] = true 

local OWNER_KEY = "ixEntOwner"

function ix.entityplacing.SetOwner(entity, owner)
    if (not IsValid(entity)) then return end

    if (isentity(owner) and owner:IsPlayer()) then
        owner = owner:GetCharacter()
    end

    local id = 0

    if (isnumber(owner)) then
        id = owner
    elseif (istable(owner) and owner.GetID) then
        id = owner:GetID()
    end

    entity.ixEntOwnerID = id
    entity:SetNWInt(OWNER_KEY, id)
end

function ix.entityplacing.GetOwnerID(entity)
    if (not IsValid(entity)) then return 0 end
    return entity.ixEntOwnerID or entity:GetNWInt(OWNER_KEY, 0)
end

function ix.entityplacing.IsOwner(entity, client)
    if (not IsValid(client)) then return false end

    local character = client:GetCharacter()
    if (not character) then return false end

    local ownerID = ix.entityplacing.GetOwnerID(entity)
    return ownerID ~= 0 and ownerID == character:GetID()
end

function ix.entityplacing.CanPoliceSeize(entity, client)
    if (not IsValid(entity) or not IsValid(client)) then return false end
    if (not HelixPoliceConfig or not FACTION_POLICE) then return false end

    local character = client:GetCharacter()
    if (not character or character:GetFaction() ~= FACTION_POLICE) then return false end

    return HelixPoliceConfig.IllegalItems[entity:GetClass()] ~= nil
end

ix.config.Add("maxCharacterEntities", 30, "Maximum number of entities (constructed furniture, buildplan props, item-ent placements) a single character can have placed in the world at once.", nil, {
    min = 1,
    max = 500,
    decimals = 0,
    category = "Item Ent"
})

if (SERVER) then

    function ix.entityplacing.CountOwned(characterID)
        local count = 0

        for _, v in ipairs(ents.GetAll()) do
            if (IsValid(v) and ix.entityplacing.GetOwnerID(v) == characterID) then
                count = count + 1
            end
        end

        return count
    end

    function ix.entityplacing.CanPlaceEntity(client, character)
        local max = ix.config.Get("maxCharacterEntities", 30)
        local count = ix.entityplacing.CountOwned(character:GetID())

        if (count >= max) then
            client:NotifyLocalized("entMaxReached", count, max)

            return false
        end

        local newCount = count + 1

        if ((max - newCount) < 5) then
            client:NotifyLocalized("entNearLimit", newCount, max)
        end

        return true
    end

    -- Sound played whenever an entity item finishes being placed (instant
    -- Place or SWEP Deploy). item.deploySound overrides the sound per item.
    function ix.entityplacing.PlayDeployEffects(entity, item)
        if (not IsValid(entity)) then return end

        local deploySound = item and item.deploySound

        if (deploySound) then
            entity:EmitSound(deploySound)
        end
    end
end

ix.util.Include("sv_hooks.lua")
ix.util.Include("cl_hooks.lua")
ix.util.Include("sh_commands.lua")

if (SERVER) then

    -- Force the ground-item prop to use ITEM.dropModel instead of the item's
    -- real ITEM.model. Only touches this one world entity's visual model -
    -- the item table (and therefore the spawn icon) is left untouched.
    function PLUGIN:OnItemSpawned(entity)
        if (not IsValid(entity)) then return end
        local item = entity.ixItemID and ix.item.instances[entity.ixItemID]

        if (istable(item) and item.base == "base_entity" and item.dropModel) then
            entity:SetModel(item.dropModel)

            -- The collision mesh was built from ITEM.model in ix_item:SetItem();
            -- rebuild it now that the model has changed, or the drop keeps the
            -- real item's hull under the cardboard box's visuals.
            entity:PhysicsInit(SOLID_VPHYSICS)
            entity:SetSolid(SOLID_VPHYSICS)

            local physObj = entity:GetPhysicsObject()

            if (IsValid(physObj)) then
                physObj:EnableMotion(true)
                physObj:Wake()
            end
        end
    end
end

function PLUGIN:PopulateEntityInfo(entity, tooltip)
    local isConstructed = entity:GetNWBool("constructed", false)

    if (not ix.entityplacing.itemsByClass[entity:GetClass()] and not isConstructed) then return end

    local client = LocalPlayer()

    if (isConstructed) then
        if (not ix.entityplacing.IsOwner(entity, client)) then return end

        local item = ix.item.Get(entity:GetNWString("item", ""))

        local title = tooltip:AddRow("entitem_printname")
        title:SetImportant()
        title:SetText(entity.PrintName or (item and item:GetName()) or L("entFurnitureFallback"))
        title:SizeToContents()

        local row = tooltip:AddRow("entitem_desc")
        row:SetText(L("entPickupHint"))
        row:SizeToContents()

        return
    end

    local item = ix.entityplacing.itemsByClass[entity:GetClass()]

    local title = tooltip:AddRow("entitem_printname")
    title:SetImportant()
    title:SetText(entity.PrintName or (item and item:GetName()) or entity:GetClass())
    title:SizeToContents()

    if (ix.entityplacing.IsOwner(entity, client)) then
        local row = tooltip:AddRow("entitem_desc")
        row:SetText(L("entPickupHint"))
        row:SizeToContents()
    elseif (ix.entityplacing.CanPoliceSeize(entity, client)) then
        local row = tooltip:AddRow("entitem_desc")
        row:SetText(L("entSeizeHint"))
        row:SizeToContents()
    end
end

function PLUGIN:CanPlayerHoldObject(client, entity)
    if (ix.entityplacing.itemsByClass[entity:GetClass()] and ix.entityplacing.IsOwner(entity, client)) then
        return true
    end
end

local BUSINESS_CATEGORIES = {
    ["Market"] = true,
    ["Salon"] = true,
    ["Bedroom"] = true,
    ["Bathroom"] = true,
    ["Kitchen"] = true,
    ["Other"] = true,
}

function PLUGIN:CanPlayerUseBusiness(client, uniqueID)
    local itemTable = ix.item.list[uniqueID]

    if (not itemTable or not BUSINESS_CATEGORIES[itemTable.category]) then
        return false
    end
end

function PLUGIN:PopulateItemTooltip(tooltip, item)
    if (not item.entityclass) then return end

    if (item.tooltip) then
        item.tooltip(item, tooltip)
        return
    end

    if (istable(item.data)) then
        for key, value in pairs(item.data) do
            local row = tooltip:AddRow("entitem_" .. string.lower(tostring(key)))
            row:SetText(key .. ": " .. tostring(value))
            row:SizeToContents()
        end
    end
end


local function RebuildItemsByClass()
    table.Empty(ix.entityplacing.itemsByClass)

    for uniqueID, itemTable in pairs(ix.item.list) do
        if (itemTable.base ~= "base_entity" or not itemTable.entityclass) then continue end

        -- Not validated against scripted_ents/weapons here: native engine
        -- classes (e.g. weapon_striderbuster) never show up in those
        -- registries even though they're spawnable. ents.Create() already
        -- fails safely (IsValid checks) if the class is genuinely wrong.
        ix.entityplacing.itemsByClass[itemTable.entityclass] = itemTable
    end
end

function PLUGIN:InitializedPlugins()
    RebuildItemsByClass()
end

if (SERVER) then
    util.AddNetworkString("ix_InteractItemEnt")

    local PICKUP_TIME = 1
    local PICKUP_RANGE_SQR = 250 * 250

    local function PickupConstructedFurniture(client, entity)
        if (not ix.entityplacing.IsOwner(entity, client)) then return end

        local item = ix.item.Get(entity:GetNWString("item", ""))
        if (not item) then return end

        client:SetAction("@entPickingUpAction", PICKUP_TIME, function()
            if (not IsValid(client) or not IsValid(entity)) then return end
            if (not ix.entityplacing.IsOwner(entity, client)) then return end
            if (client:GetPos():DistToSqr(entity:GetPos()) > PICKUP_RANGE_SQR) then return end

            local character = client:GetCharacter()
            local inventory = character and character:GetInventory()

            if (not inventory) then return end

            if (inventory:FindEmptySlot(item.width, item.height)) then
                inventory:Add(item.uniqueID)
            else
                ix.item.Spawn(item.uniqueID, client:GetPos())
            end

            client:EmitSound("npc/zombie/foot_slide" .. math.random(1, 3) .. ".wav", 75, math.random(90, 120), 1)
            client:NotifyLocalized("entPickedUp", item:GetName())

            entity:Remove()
        end)
    end

    net.Receive("ix_InteractItemEnt", function(len, client)
        local entity = net.ReadEntity()

        if (not IsValid(client) or not IsValid(entity)) then return end
        if (client:GetPos():DistToSqr(entity:GetPos()) > PICKUP_RANGE_SQR) then return end

        local entData = ix.entityplacing.itemsByClass[entity:GetClass()]

        if (not entData) then
            if (entity:GetNWBool("constructed", false)) then
                PickupConstructedFurniture(client, entity)
            end

            return
        end

        local uniqueID = entData.uniqueID
        local character = client:GetCharacter()
        if (not character) then return end

        local isOwner = ix.entityplacing.IsOwner(entity, client)
        local isPoliceSeizure = not isOwner and ix.entityplacing.CanPoliceSeize(entity, client)

        if (not isOwner and not isPoliceSeizure) then
            client:NotifyLocalized("entNotOwner")
            return
        end

        local inventory = character:GetInventory()
        local w, h = entData.width or 1, entData.height or 1

        if (not inventory or not inventory:FindEmptySlot(w, h)) then
            client:NotifyLocalized("entNoSpace")
            return
        end

        client:SetAction(isPoliceSeizure and "@entSeizingAction" or "@entPickingUpAction", PICKUP_TIME, function()
            if (not IsValid(client) or not IsValid(entity)) then return end
            if (not ix.entityplacing.IsOwner(entity, client) and not ix.entityplacing.CanPoliceSeize(entity, client)) then return end
            if (client:GetPos():DistToSqr(entity:GetPos()) > PICKUP_RANGE_SQR) then return end

            local char = client:GetCharacter()
            local inv = char and char:GetInventory()

            if (not inv) then return end

            local savedData

            if (entData.Save) then
                local ok, result = pcall(entData.Save, entData, entity)
                savedData = ok and result or nil
            end

            local x = inv:Add(uniqueID, 1, savedData)

            if (not x) then
                client:NotifyLocalized("entNoSpace")
                return
            end

            client:EmitSound("npc/zombie/foot_slide" .. math.random(1, 3) .. ".wav", 75, math.random(90, 120), 1)
            entity:Remove()
        end)
    end)
else

    function PLUGIN:PlayerButtonDown(client, button)
        if (button == KEY_G and IsFirstTimePredicted()) then
            if (vgui.GetKeyboardFocus() or gui.IsGameUIVisible()) then return end

            local trace = client:GetEyeTrace()
            local entity = trace.Entity

            if (IsValid(entity) and trace.HitPos:DistToSqr(client:GetPos()) <= 40000) and
                (ix.entityplacing.itemsByClass[entity:GetClass()] or entity:GetNWBool("constructed", false)) then
                net.Start("ix_InteractItemEnt")
                    net.WriteEntity(entity)
                net.SendToServer()

            end
        end
    end

end
