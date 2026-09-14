-- The Practice Larper: a fictional NPC anyone can larp-off. Its stats are the
-- challenger's own, scaled by a random factor, so every fight is close enough for
-- upsets. Until the challenger's first Win it plays weaker (Tuning.Practice.rookie).
-- Also lets a single player test the whole larp-off loop.
-- Quiet servers (the owner's pick of the growth ideas, 2026-09-14): it's never "busy" (while
-- it's mid larp-off a stand-in Practice Larper takes the next challenger and leaves after),
-- and the HUD's Larp-off button asks for one from anywhere (RequestPractice { quick = true }):
-- the stage takes the player and MatchService puts them back where they were.
local Players = game:GetService("Players")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Tuning = require(Larp.Config.Tuning)
local Text = require(Larp.Config.Text)
local Catalog = require(Larp.Shared.Catalog)
local RankMath = require(Larp.Shared.RankMath)
local Net = require(Larp.Shared.Net)
local Combatant = require(script.Parent.Parent.Lib.Combatant)

local PracticeNpcService = {}
PracticeNpcService.KEY = "npc:practice"

local rng = Random.new()
local npc: Model? = nil
local home: CFrame = CFrame.new(-22, 0.2, -30)
local updatePlate = nil
local standIns = 0 -- stand-in Practice Larpers out now

local function notice(player: Player, text: string)
	Net.get("Notice"):FireClient(player, text, "info")
end

-- Stands an NPC on `spot`.
local function standAt(model: Model, spot: CFrame)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if root and humanoid then
		model:PivotTo(spot * CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
	end
end

local function spawnNpc()
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = Color3.fromRGB(163, 162, 165)
	description.TorsoColor = Color3.fromRGB(240, 124, 167)
	description.LeftArmColor = Color3.fromRGB(163, 162, 165)
	description.RightArmColor = Color3.fromRGB(163, 162, 165)
	description.LeftLegColor = Color3.fromRGB(52, 58, 70)
	description.RightLegColor = Color3.fromRGB(52, 58, 70)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[Larp] Could not create the Practice Larper: " .. tostring(model))
		return nil
	end
	model.Name = Text.Practice.name
	local root = model:WaitForChild("HumanoidRootPart")
	root.Anchored = true
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false

	standAt(model, home)
	model.Parent = workspace.Larp

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LarpOffPrompt"
	prompt.ActionText = Text.PromptAction
	prompt.ObjectText = Text.Practice.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Tuning.Challenge.range
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = root
	return model, prompt
end

-- The key a player's stand-in Practice Larper fights under.
local function standInKey(player: Player): string
	return PracticeNpcService.KEY .. ":" .. player.UserId
end

function PracticeNpcService:Init(services)
	self.Stats = services.StatService
	self.Data = services.DataService
	self.Matches = services.MatchService
	self.Nameplate = services.NameplateService
	self.Reality = services.RealityService
end

-- Stats for a practice fight against a player with `playerStats`. `rookie` picks the
-- weaker band (the player has no Wins yet).
function PracticeNpcService.statsFor(playerStats: { [string]: number }, random: Random, rookie: boolean?)
	local P = Tuning.Practice
	local band = if rookie then P.rookie else P
	local out = {}
	for _, id in Catalog.statIds do
		local own = math.max(0, playerStats[id] or 0)
		if own > 0 then
			out[id] = math.max(P.floor, math.floor(own * random:NextNumber(band.statMin, band.statMax) + 0.5))
		else
			out[id] = 0
		end
	end
	return out
end

-- A stand-in Practice Larper for `player` while the real one is mid larp-off: it waits beside
-- the real one until its larp-off and is gone after, however that ends. nil if there are
-- Tuning.Practice.maxStandIns out already.
function PracticeNpcService:_standIn(player: Player, stats, rankIndex: number)
	if standIns >= Tuning.Practice.maxStandIns then
		return nil
	end
	local model, prompt = spawnNpc()
	if not model then
		return nil
	end
	prompt:Destroy()
	standIns += 1
	standAt(model, home * CFrame.new(-4 * standIns, 0, 0))
	local plate = self.Nameplate:AttachNpc(model, Text.Practice.name, rankIndex)
	local key = standInKey(player)
	local opponent = Combatant.fromNpc(model, key, Text.Practice.name, stats, rankIndex)
	opponent.limitKey = PracticeNpcService.KEY -- same-pair reward limits count it as the real one
	local released = false
	opponent.release = function()
		if not released then
			released = true
			standIns -= 1
			model:Destroy()
		end
	end
	opponent.onExposed = function()
		plate(rankIndex, true)
	end
	opponent.onFinished = opponent.release
	-- MatchService drops a queued larp-off whose challenger left without calling back
	task.spawn(function()
		repeat
			task.wait(2)
		until released or not self.Matches:IsBusy(key)
		opponent.release()
	end)
	return opponent
end

-- `skipChecks` is only passed by the Studio debug hook in Main; `quick` is the HUD's
-- Larp-off button (no walking over, but not from a car or a LARP to Reality activity).
function PracticeNpcService:_start(player: Player, isRematch: boolean, skipChecks: boolean?, quick: boolean?)
	if not npc or not npc.Parent or not self.Data:IsLoaded(player) then
		return
	end
	local playerKey = "u" .. player.UserId
	if self.Matches:IsBusy(playerKey) then
		notice(player, Text.Challenge.youAreBusy)
		return
	end
	if skipChecks then
		-- debug hook: no distance or rematch-window checks
	elseif isRematch then
		local window = Tuning.Practice.rematchWindowSeconds
		if not (self.Matches:WereRecentOpponents(playerKey, PracticeNpcService.KEY, window) or self.Matches:WereRecentOpponents(playerKey, standInKey(player), window)) then
			return
		end
	elseif quick then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.SeatPart then
			notice(player, Text.Practice.seated)
			return
		end
		if self.Reality and self.Reality:IsBusy(player) then
			notice(player, Text.Practice.activity)
			return
		end
	else
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local npcRoot = npc:FindFirstChild("HumanoidRootPart")
		if not root or not npcRoot then
			return
		end
		if (root.Position - npcRoot.Position).Magnitude > Tuning.Challenge.range + Tuning.Challenge.rangeTolerance then
			return
		end
	end

	local challenger = Combatant.fromPlayer(player, self.Stats)
	if Catalog.total(challenger.stats) <= 0 then
		-- Nothing to compare: point them at the Car Lot instead of a guaranteed draw.
		notice(player, Text.Practice.noStats)
		return
	end
	local stats = PracticeNpcService.statsFor(challenger.stats, rng, self.Stats:GetWins(player) == 0)
	local rankIndex = RankMath.indexFor(Catalog.total(stats), Catalog.ranks)
	local opponent
	if self.Matches:IsBusy(PracticeNpcService.KEY) then
		opponent = self:_standIn(player, stats, rankIndex)
		if not opponent then
			notice(player, Text.Practice.busy)
			return
		end
	else
		opponent = Combatant.fromNpc(npc, PracticeNpcService.KEY, Text.Practice.name, stats, rankIndex)
		if updatePlate then
			updatePlate(rankIndex, false)
		end
		opponent.onExposed = function()
			if updatePlate then
				updatePlate(rankIndex, true)
			end
		end
		opponent.onFinished = function()
			if npc and npc.Parent then
				standAt(npc, home)
			end
			task.delay(6, function()
				if updatePlate then
					updatePlate(1, false)
				end
			end)
		end
	end
	if not self.Matches:Enqueue(challenger, opponent) and opponent.release then
		opponent.release()
	end
end

-- Studio-only (the LarpDebug hook's "demo" command): the Practice Larper vs a temporary
-- second NPC through the real match pipeline, so one tester can watch as a spectator.
function PracticeNpcService:_demo(bag: number?)
	if not npc or not npc.Parent or self.Matches:IsBusy(PracticeNpcService.KEY) then
		return "busy"
	end
	local rival, prompt = spawnNpc()
	if not rival then
		return "no rival"
	end
	prompt:Destroy()
	rival.Name = "Demo Larper"
	local function combatant(model, key, name)
		local stats = {}
		for _, id in Catalog.statIds do
			stats[id] = math.floor((bag or 20000) * rng:NextNumber(0.6, 1.4))
		end
		return Combatant.fromNpc(model, key, name, stats, RankMath.indexFor(Catalog.total(stats), Catalog.ranks))
	end
	local a = combatant(npc, PracticeNpcService.KEY, Text.Practice.name)
	local b = combatant(rival, "npc:demo", "Demo Larper")
	a.onFinished = function()
		standAt(npc, home)
	end
	b.onFinished = function()
		rival:Destroy()
	end
	local position = self.Matches:Enqueue(a, b)
	return if position then "demo queued" else "could not queue"
end

function PracticeNpcService:Start()
	local spot = workspace.Larp:FindFirstChild("Map") and workspace.Larp.Map:FindFirstChild("PracticeNpcSpot")
	if spot and spot:IsA("BasePart") then
		home = spot.CFrame
	end
	local prompt
	npc, prompt = spawnNpc()
	if not npc then
		return
	end
	updatePlate = self.Nameplate:AttachNpc(npc, Text.Practice.name, 1)
	prompt.Triggered:Connect(function(player)
		self:_start(player, false)
	end)
	local lastRequest: { [Player]: number } = {}
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
	Net.get("RequestPractice").OnServerEvent:Connect(function(player, options)
		local now = os.clock()
		if now - (lastRequest[player] or -math.huge) < Tuning.Challenge.requestCooldownSeconds then
			return
		end
		lastRequest[player] = now
		if type(options) ~= "table" then
			return
		end
		if options.rematch == true then
			self:_start(player, true)
		elseif options.quick == true then
			self:_start(player, false, false, true)
		end
	end)
end

return PracticeNpcService
