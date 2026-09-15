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
	"MapService",
	"CarService",
	"RealityService",
	"ReferralService",
	"CoinService",
	"DripService",
	"SkateService",
	"QuizService",
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
		if command == "tests" then
			return require(game:GetService("ServerStorage").UnitTest.RunUnitTest)()
		end
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
		elseif command == "supporter" then
			-- the VIP++ Arena without buying anything (Studio only)
			return services.MonetizationService:MakeSupporter(target)
		elseif command == "reality" then
			-- LARP to Reality without buying it (Studio only; gone on rejoin)
			target:SetAttribute("OwnsReality", true)
			return services.MonetizationService:MakeSupporter(target)
		elseif command == "coins" then
			-- LarpCoins, to try the Drip shop (Studio only)
			return services.CoinService:Add(target, ...)
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

	-- Studio only: run the unit suite once a playtest starts and print the summary, so every
	-- playtest is a regression check and the result is readable straight from the output
	-- window. Live servers never get here.
	task.spawn(function()
		task.wait(5)
		local ok, result = pcall(require(game:GetService("ServerStorage").UnitTest.RunUnitTest))
		if ok and type(result) == "table" then
			print(("[Larp] unit tests: %d run, %d passed, %d failed"):format(result.run, result.passed, result.failed))
		else
			warn("[Larp] unit tests could not run: " .. tostring(result))
		end
	end)
end
