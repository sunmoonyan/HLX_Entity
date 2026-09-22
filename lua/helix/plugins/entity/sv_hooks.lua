local PLUGIN = PLUGIN

util.AddNetworkString("CreateFurniture")

local PLACE_RANGE = 300
local CONSTRUCTION_COOLDOWN = 2
local PICKUP_COOLDOWN = 1

net.Receive("CreateFurniture", function(len, client)
	local model = net.ReadString()
	local pos = net.ReadVector()
	local ang = net.ReadAngle()
	local bCantPlace = net.ReadBool()

	if (not IsValid(client)) then return end

	if ((client.ixNextConstruction or 0) > CurTime()) then
		client:NotifyLocalized("entWaitBeforePlacing")
		return
	end

	local furniture = client:GetLocalVar("furniture", false)

	if (not istable(furniture) or not furniture.model) then
		client:NotifyLocalized("entNoObjectEquipped")
		return
	end

	if (bCantPlace or pos:Distance(client:GetPos()) > PLACE_RANGE) then
		client:NotifyLocalized("entTooFar")
		return
	end

	if (model:lower() ~= furniture.model:lower()) then
		client:NotifyLocalized("entPlaceMismatch")
		return
	end

	local weapon = client:GetActiveWeapon()

	if (not IsValid(weapon) or weapon:GetClass() ~= "ix_building") then return end

	local character = client:GetCharacter()

	if (not character or not ix.entityplacing.CanPlaceEntity(client, character)) then return end

	local ent = ents.Create(furniture.class or "prop_physics")

	if (not IsValid(ent)) then return end

	if (not furniture.class) then
		ent:SetModel(model)
	end

	ent:SetPos(pos)
	ent:SetAngles(ang)
	ent:Spawn()

	ent:SetSolid(SOLID_VPHYSICS)
	ent:SetMoveType(MOVETYPE_VPHYSICS)
	ent:SetNotSolid(false)
	ent:SetNWBool("constructed", true)
	ent:SetNWString("item", furniture.item or "")
	ix.entityplacing.SetOwner(ent, client)

	local physObject = ent:GetPhysicsObject()

	if (IsValid(physObject)) then
		physObject:EnableMotion(false)
		physObject:Wake()
	end

	local itemName = "object"

	if (character) then
		local inventory = character:GetInventory()

		for _, v in pairs(inventory:GetItems()) do
			if ((furniture.item and furniture.item ~= "" and v.uniqueID == furniture.item) or
				(v.entityclass and furniture.class and v.entityclass:lower() == furniture.class:lower()) or
				(v.model and v.model:lower() == model:lower())) then
				itemName = v:GetName()

				if (v.Load) then
					v:Load(ent, v.data)
				end

				ix.entityplacing.PlayDeployEffects(ent, v)

				if (v.OnDeploy) then
					v:OnDeploy(client, ent)
				end

				v:Remove()
				break
			end
		end
	end

	local itemEntity = furniture.item_entity

	if (IsValid(itemEntity)) then
		local _item = itemEntity:GetItemTable()

		if (_item) then
			if (_item.Load) then
				_item:Load(ent, _item.data)
			end

			ix.entityplacing.PlayDeployEffects(ent, _item)

			if (_item.OnDeploy) then
				_item:OnDeploy(client, ent)
			end
		end

		itemEntity:Remove()
	end

	client:SetLocalVar("furniture")
	client:StripWeapon("ix_building")
	client:NotifyLocalized("entPlaced", itemName)

	client.ixNextConstruction = CurTime() + CONSTRUCTION_COOLDOWN
end)

function PLUGIN:PlayerUse(client, entity)
	-- Ctrl (IN_DUCK) + USE picks a constructed prop back up.
	if (not client:KeyDown(IN_DUCK)) then return end
	if (entity:GetClass() ~= "prop_physics") then return end
	if (client:GetLocalVar("furniture", nil)) then return end
	if ((client.ixNextPickup or 0) > CurTime()) then return end
	if (not entity:GetNWBool("constructed", false)) then return end
	if (not ix.entityplacing.IsOwner(entity, client)) then return end

	local character = client:GetCharacter()
	if (not character) then return end

	local item = ix.item.Get(entity:GetNWString("item", ""))
	if (not item) then return end

	local inventory = character:GetInventory()

	if (inventory:FindEmptySlot(item.width, item.height)) then
		inventory:Add(item.uniqueID)
	else
		ix.item.Spawn(item.uniqueID, client:GetPos())
	end

	client:SetLocalVar("furniture", {
		item = item.uniqueID,
		model = entity:GetModel():lower()
	})

	entity:Remove()
	client:Give("ix_building")
	client:SelectWeapon("ix_building")

	client:NotifyLocalized("entPickedUp", item:GetName())

	client.ixNextPickup = CurTime() + PICKUP_COOLDOWN
end

ix.entityplacing = ix.entityplacing or {}
ix.entityplacing.ignore = ix.entityplacing.ignore or {}
ix.entityplacing.ignore["ix_bed"] = true

function PLUGIN:PlayerDeath(client)
	client:SetLocalVar("furniture")
end

function PLUGIN:PlayerSwitchWeapon(client, oldweapon, newweapon)
	if (not IsValid(oldweapon) or oldweapon:GetClass() ~= "ix_building") then return end
	if (not client:GetCharacter()) then return end

	client:SetLocalVar("furniture")

	timer.Simple(0.01, function()
		if (IsValid(client) and IsValid(oldweapon)) then
			client:StripWeapon("ix_building")
		end
	end)
end
