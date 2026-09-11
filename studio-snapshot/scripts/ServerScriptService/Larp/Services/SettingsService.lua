-- Validates and stores player settings sent from the client.
local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Net = require(Larp.Shared.Net)

local SettingsService = {}

-- key -> expected Luau type. Anything else is ignored.
local ALLOWED = {
	acceptLarpOffs = "boolean",
	clipMode = "boolean",
	reduceEffects = "boolean",
}

function SettingsService:Init(services)
	self.Data = services.DataService
end

function SettingsService:Start()
	Net.get("UpdateSetting").OnServerEvent:Connect(function(player, key, value)
		if type(key) ~= "string" or ALLOWED[key] == nil or type(value) ~= ALLOWED[key] then
			return
		end
		local data = self.Data:Get(player)
		if data then
			data.settings[key] = value
		end
	end)
end

function SettingsService:Get(player: Player, key: string)
	local data = self.Data:Get(player)
	return data and data.settings[key]
end

return SettingsService

