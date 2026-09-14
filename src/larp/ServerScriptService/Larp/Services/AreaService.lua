-- Rank-gated areas (spec "Map", Config.Areas): every home zone has a VIP room (from Poser)
-- and an Elite rooftop (from Aura Farmer), built by LarpBuild.Premium into Map.Premium.
-- Their doors are ProximityPrompts with attributes Home (the zone) and To ("VIP", "Elite"
-- or "Entrance"): the server checks the rank and moves the player to that area's Arrival.
-- Anyone inside an area their rank doesn't open (after Touch Grass, say) is sent back out.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Catalog = require(Larp.Shared.Catalog)
local Net = require(Larp.Shared.Net)
local Areas = require(Larp.Config.Areas)

local AreaService = { config = Areas }

local rankOf: { [string]: number } = {}
for i, rank in Catalog.ranks do
	rankOf[rank.name] = i
end

-- Whether a player at rank index `rank`, a `supporter` or not, owning the passes in `owns`
-- (key -> true), may be in `tier` (nil: an open area). The VIP++ Arena goes by supporter,
-- LARP to Reality by its own pass, the others by rank.
function AreaService.allowed(tier: string?, rank: number, supporter: boolean?, owns: { [string]: boolean }?): boolean
	local spec = tier and Areas.tiers[tier]
	if spec == nil then
		return true
	end
	if spec.pass then
		return owns ~= nil and owns[spec.pass] == true
	end
	if spec.supporter then
		return supporter == true
	end
	return rank >= (rankOf[spec.rank] or math.huge)
end

local function isSupporter(player: Player): boolean
	return player:GetAttribute("Supporter") == true
end

-- The passes a player owns, read from MonetizationService's Owns<key> attributes.
local function ownsOf(player: Player): { [string]: boolean }
	return setmetatable({}, {
		__index = function(_, key)
			return player:GetAttribute("Owns" .. tostring(key)) == true
		end,
	}) :: any
end

function AreaService:Init(services)
	self.Stats = services.StatService
	self.Matches = services.MatchService
end

local function arrival(area: Instance?): BasePart?
	local part = area and area:FindFirstChild("Arrival")
	return if part and part:IsA("BasePart") then part else nil
end

local function areaName(home: string, tier: string): string
	return Areas.zones[home] and Areas.zones[home][tier] or tier
end

-- Stands the player's character on `part`, facing the way it faces. The far areas stream in
-- around it first, so nobody lands before the floor has.
local function moveTo(player: Player, part: BasePart?)
	local character = player.Character
	if character and part then
		pcall(player.RequestStreamAroundAsync, player, part.Position, 4)
		if character.Parent then
			character:PivotTo(part.CFrame + Vector3.new(0, 3, 0))
		end
	end
end

local function inside(part: BasePart, position: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

function AreaService:_locked(player: Player, home: string, tier: string)
	local spec = Areas.tiers[tier]
	if spec.pass then
		-- the shop opens at the pass's tour
		Net.get("Notice"):FireClient(player, Areas.words.passOnly:format(areaName(home, tier)), "warning")
		Net.get("OpenShop"):FireClient(player, spec.pass)
	elseif spec.supporter then
		-- the shop opens, so the way in is right there
		Net.get("Notice"):FireClient(player, Areas.words.supporterOnly:format(areaName(home, tier)), "warning")
		Net.get("OpenShop"):FireClient(player)
	else
		Net.get("Notice"):FireClient(player, Areas.words.locked:format(areaName(home, tier), spec.rank), "warning")
	end
end

function AreaService:_use(player: Player, prompt: ProximityPrompt)
	local home, to = prompt:GetAttribute("Home"), prompt:GetAttribute("To")
	local zone = type(home) == "string" and self.root:FindFirstChild(home)
	if not zone or type(to) ~= "string" or self.Matches:IsBusy("u" .. player.UserId) then
		return
	end
	if Areas.tiers[to] then
		if not AreaService.allowed(to, self.Stats:GetRankIndex(player), isSupporter(player), ownsOf(player)) then
			self:_locked(player, home, to)
			return
		end
		moveTo(player, arrival(zone:FindFirstChild(to)))
		Net.get("Notice"):FireClient(player, Areas.words.welcome[to]:format(areaName(home, to)), "success")
	else
		moveTo(player, arrival(zone:FindFirstChild(to)))
	end
end

-- Sends anyone out of an area their rank doesn't open.
function AreaService:_sweep()
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local rank = self.Stats:GetRankIndex(player)
			for _, v in self.volumes do
				if not AreaService.allowed(v.tier, rank, isSupporter(player), ownsOf(player)) and inside(v.part, root.Position) then
					moveTo(player, arrival(v.zone:FindFirstChild("Entrance")))
					self:_locked(player, v.zone.Name, v.tier)
					break
				end
			end
		end
	end
end

function AreaService:Start()
	local map = workspace:WaitForChild("Larp"):WaitForChild("Map")
	self.root = map:FindFirstChild("Premium")
	self.volumes = {}
	if not self.root then
		warn("[Larp] No VIP/Elite areas (Map.Premium); build them with LarpBuild.Premium")
		return
	end
	for _, zone in self.root:GetChildren() do
		for tier in Areas.tiers do
			local area = zone:FindFirstChild(tier)
			local volume = area and area:FindFirstChild("Volume")
			if volume and volume:IsA("BasePart") then
				table.insert(self.volumes, { zone = zone, tier = tier, part = volume })
			end
		end
	end
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt:IsDescendantOf(self.root) then
			self:_use(player, prompt)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			self:_sweep()
		end
	end)
end

return AreaService
