-- A larp-off participant: a player or an NPC (the practice NPC now, the Ultimate
-- LARPer later). Match code only ever talks to this shape.
local Combatant = {}

-- stats/rankIndex are a snapshot; MatchService refreshes player snapshots at match start.
function Combatant.fromPlayer(player: Player, statService)
	return {
		kind = "Player",
		key = "u" .. player.UserId,
		player = player,
		userId = player.UserId,
		name = player.DisplayName,
		model = player.Character,
		stats = statService:GetStats(player),
		rankIndex = statService:GetRankIndex(player),
	}
end

function Combatant.fromNpc(model: Model, key: string, name: string, stats: { [string]: number }, rankIndex: number)
	return {
		kind = "Npc",
		key = key,
		userId = 0,
		name = name,
		model = model,
		stats = stats,
		rankIndex = rankIndex,
	}
end

-- Refreshes a player's snapshot (NPC snapshots are fixed when they are created).
function Combatant.refresh(c, statService)
	if c.kind == "Player" then
		c.model = c.player.Character
		c.stats = statService:GetStats(c.player)
		c.rankIndex = statService:GetRankIndex(c.player)
	end
end

-- True while the combatant can still take part (in game, with a live character).
function Combatant.isValid(c): boolean
	local model = if c.kind == "Player" then c.player.Character else c.model
	if c.kind == "Player" and c.player.Parent == nil then
		return false
	end
	if not model or not model.Parent then
		return false
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and model:FindFirstChild("HumanoidRootPart") ~= nil
end

-- What clients are told about a combatant.
function Combatant.header(c)
	return {
		kind = c.kind,
		userId = c.userId,
		name = c.name,
		rankIndex = c.rankIndex,
		model = c.model,
		total = nil,
	}
end

return Combatant
