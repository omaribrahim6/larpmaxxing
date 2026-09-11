-- Server bootstrap: creates remotes, then Init()s every service (wiring only) and
-- Start()s them. DataService starts last so every ProfileLoaded listener is connected
-- before the first profile can load.
local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
require(Larp.Shared.Net).init()

local Services = script.Parent:WaitForChild("Services")
local ORDER = {
	"DataService",
	"SettingsService",
	"StatService",
	"NameplateService",
	"MatchService",
	"ChallengeService",
	"PickupService",
	"PracticeNpcService",
}

local services = {}
for _, name in ORDER do
	services[name] = require(Services:WaitForChild(name))
end
for _, name in ORDER do
	if services[name].Init then
		services[name]:Init(services)
	end
end
for _, name in ORDER do
	if name ~= "DataService" and services[name].Start then
		services[name]:Start()
	end
end
services.DataService:Start()

-- Studio-only test hook (never created on live servers): lets playtests drive the real
-- services, e.g. ServerStorage.LarpDebug:Invoke("addPoints", userId, "Bag", 5000).
if game:GetService("RunService"):IsStudio() then
	local hook = Instance.new("BindableFunction")
	hook.Name = "LarpDebug"
	hook.OnInvoke = function(command, userId, ...)
		local target = game:GetService("Players"):GetPlayerByUserId(userId)
		if not target then
			return "no player"
		end
		if command == "addPoints" then
			local statId, amount = ...
			return services.StatService:AddPoints(target, statId, amount, "debug")
		elseif command == "practice" then
			services.PracticeNpcService:_start(target, true, true)
			return "queued"
		elseif command == "stats" then
			return services.StatService:GetStats(target)
		end
		return "unknown command"
	end
	hook.Parent = game:GetService("ServerStorage")
end
