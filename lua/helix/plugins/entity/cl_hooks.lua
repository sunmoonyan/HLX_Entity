
local PLUGIN = PLUGIN

function PLUGIN:HUDPaint()
	local client = LocalPlayer()
	local character = client:GetCharacter()

	if IsValid(client) and character and client:Alive() then
		if IsValid(client:GetActiveWeapon()) and (client:GetActiveWeapon():GetClass() == "ix_building") then

			ix.util.DrawText(L("entRotateHint"), ScrW() / 2, ScrH() - 116, ColorAlpha(color_white, 150), 1, 4, "ixSmallFont")
			ix.util.DrawText(L("entPlaceHint"), ScrW() / 2, ScrH() - 96, ColorAlpha(color_white, 150), 1, 4, "ixSmallFont")
		end
	end
end