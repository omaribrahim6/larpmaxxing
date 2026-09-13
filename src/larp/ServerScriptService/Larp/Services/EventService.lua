-- Stat rushes (spec "Events", Config.Events): every few minutes one stat's rush runs for two
-- minutes, rotating through the stats. While one runs, PickupService asks for its points
-- and respawn multipliers. Every client hears EventChanged(id, endsAt, summonedBy) when a
-- rush starts and EventChanged() when it ends (LarpClient.EventFx shows it).
local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Config = require(Larp.Config.Events)
local Net = require(Larp.Shared.Net)

local EventService = {
	current = nil, -- { id, rush, endsAt, by } while a rush runs
}

function EventService:Init() end

-- How many times its points a pickup of `statId` is worth right now.
function EventService:PointsMultiplier(statId: string): number
	local c = self.current
	return if c and c.rush.stat == statId then c.rush.points or 1 else 1
end

-- How many times as fast the home zone of `statId` respawns its pickups right now.
function EventService:SpawnMultiplier(statId: string?): number
	local c = self.current
	return if c and statId and c.rush.stat == statId then c.rush.spawn or 1 else 1
end

local function tell(target: Player?, c)
	local remote = Net.get("EventChanged")
	if target and c then
		remote:FireClient(target, c.id, c.endsAt, c.by)
	elseif c then
		remote:FireAllClients(c.id, c.endsAt, c.by)
	else
		remote:FireAllClients()
	end
end

-- Starts rush `id` now: from the schedule, or a summon (`by` is the summoner's name). A
-- rush already running is replaced. Returns false for an unknown id.
function EventService:Begin(id: string, by: string?): boolean
	local rush = Config.rushes[id]
	if not rush then
		return false
	end
	local c = { id = id, rush = rush, endsAt = workspace:GetServerTimeNow() + Config.seconds, by = by }
	self.current = c
	tell(nil, c)
	task.delay(Config.seconds, function()
		if self.current == c then
			self.current = nil
			tell(nil, nil)
		end
	end)
	return true
end

function EventService:Start()
	-- a joining client asks once its listeners are connected
	Net.get("ClientReady").OnServerEvent:Connect(function(player)
		if self.current then
			tell(player, self.current)
		end
	end)
	task.spawn(function()
		local i = math.random(1, #Config.order)
		task.wait(Config.firstDelay)
		while true do
			self:Begin(Config.order[i])
			i = i % #Config.order + 1
			task.wait(Config.every)
		end
	end)
end

return EventService
