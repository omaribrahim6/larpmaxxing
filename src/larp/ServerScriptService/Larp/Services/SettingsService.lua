-- Validates and stores player settings sent from the client.
local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Net = require(Larp.Shared.Net)
local Signal = require(Larp.Shared.Signal)

local SettingsService = {
	Changed = Signal.new(), -- (player, key, value) after a setting is stored
}

-- key -> expected Luau type. Anything else is ignored.
local ALLOWED = {
	acceptLarpOffs = "boolean",
	clipMode = "boolean",
	reduceEffects = "boolean",
	showCosmetics = "boolean",
	musicVolume = "number",
	sfxVolume = "number",
	tutorialSeen = "boolean", -- the first-run tour is over: finished or skipped (CodexUI.Onboarding)
	tourStep = "number", -- how many of the tour's steps are done, so a rejoin carries on from there
}

-- Cleans a value that passed the type check. Returns nil to reject it.
function SettingsService.sanitize(key: string, value: any): any
	if type(key) ~= "string" or ALLOWED[key] == nil or type(value) ~= ALLOWED[key] then
		return nil
	end
	if type(value) == "number" then
		if value ~= value or math.abs(value) == math.huge then
			return nil
		end
		if key == "tourStep" then
			return math.clamp(math.floor(value), 0, 100)
		end
		-- volumes: 0..1 in steps of 0.05
		return math.floor(math.clamp(value, 0, 1) * 20 + 0.5) / 20
	end
	return value
end

function SettingsService:Init(services)
	self.Data = services.DataService
end

function SettingsService:Start()
	-- The client says whether it is a phone or tablet with no keyboard, so server-sent hints
	-- ("Space pushes", "F hops off") can say "tap" instead. Only ever picks which line of
	-- text someone sees, so trusting the client costs nothing.
	Net.get("ClientReady").OnServerEvent:Connect(function(player, info)
		player:SetAttribute("Touch", if type(info) == "table" and info.touch == true then true else nil)
	end)
	Net.get("UpdateSetting").OnServerEvent:Connect(function(player, key, value)
		local clean = SettingsService.sanitize(key, value)
		if clean == nil then
			return
		end
		local data = self.Data:Get(player)
		if data then
			data.settings[key] = clean
			self.Changed:Fire(player, key, clean)
		end
	end)
end

function SettingsService:Get(player: Player, key: string)
	local data = self.Data:Get(player)
	return data and data.settings[key]
end

return SettingsService
