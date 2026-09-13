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
	"LeaderboardService",
	"EventService",
	"MonetizationService",
	"RebirthService",
	"CosmeticService",
	"AreaService",
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
-- services, e.g. ServerStorage.LarpDebug:Invoke("addPoints", userId, "Money", 5000).
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
		elseif command == "demo" then
			-- NPC vs NPC larp-off the target can watch as a spectator (stand near the stage)
			return services.PracticeNpcService:_demo(...)
		elseif command == "rush" then
			-- a stat rush now (a Config.Events id, e.g. "GoldenHour")
			return services.EventService:Begin(...)
		elseif command == "force" then
			-- the next larp-offs' stats, tiers, winner, fumble and timing (nil clears it);
			-- see MatchService.force
			services.MatchService.force = ...
			return "forced"
		end
		return "unknown command"
	end
	hook.Parent = game:GetService("ServerStorage")
end
