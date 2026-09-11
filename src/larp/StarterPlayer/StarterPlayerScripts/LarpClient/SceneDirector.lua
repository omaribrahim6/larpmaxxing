-- Plays larp-offs from the server's packets (see MatchService for the shapes).
-- Participants get the full cinematic: camera, screen stamps (Codex UI), flashes.
-- Spectators near the stage see the same props, captions and world stamps.
local Players = game:GetService("Players")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Catalog = require(Larp.Shared.Catalog)
local ClimbPlan = require(Larp.Shared.ClimbPlan)
local Text = require(Larp.Config.Text)
local Net = require(Larp.Shared.Net)

local Kit = require(script.Parent.SceneKit)
local Poses = require(script.Parent.Poses)
local Crowd = require(script.Parent.Crowd)
local ChallengePrompts = require(script.Parent.ChallengePrompts)

local SceneDirector = {}

local player = Players.LocalPlayer
local scenes = {}
local current = nil -- active match context

local COLORS = {
	Ate = Color3.fromRGB(122, 214, 112),
	Fumbled = Color3.fromRGB(176, 180, 172),
	Exposed = Color3.fromRGB(255, 94, 82),
	Certified = Color3.fromRGB(149, 198, 114),
	Upset = Color3.fromRGB(255, 198, 64),
	Viral = Color3.fromRGB(176, 132, 255),
}

local function scene(id: string)
	if scenes[id] == nil then
		local module = script.Parent.Scenes:FindFirstChild(id)
		scenes[id] = if module then require(module) else false
	end
	return scenes[id] or nil
end

local function localFolder(): Folder
	local folder = workspace:FindFirstChild("LarpSceneLocal")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "LarpSceneLocal"
		folder.Parent = workspace
	end
	return folder
end

local function headPos(side, extra: number?)
	return side.mark.Position + Vector3.new(0, extra or 7.5, 0)
end

local function buildContext(header, ui)
	local stage = header.stage
	local markers = stage and stage:FindFirstChild("Markers")
	if not markers then
		return nil
	end
	local isA = header.a.userId == player.UserId
	local isB = header.b.userId == player.UserId
	local participant = isA or isB
	local folder = localFolder()
	folder:ClearAllChildren()
	local kit = Kit.new({ participant = participant, reduceEffects = ui:GetSetting("reduceEffects"), folder = folder })
	local function side(info, suffix: string, outward: number)
		return {
			character = info.model,
			name = info.name,
			userId = info.userId,
			kind = info.kind,
			rankIndex = info.rankIndex,
			mark = markers:FindFirstChild("Mark" .. suffix).CFrame,
			vehicleCF = markers:FindFirstChild("Vehicle" .. suffix).CFrame,
			jetCF = markers:FindFirstChild("Jet" .. suffix).CFrame,
			billboard = stage:FindFirstChild("Billboard" .. suffix),
			spotlight = stage:FindFirstChild("Spotlight" .. suffix),
			outward = outward,
			tier = 0,
		}
	end
	local ctx = {
		id = header.matchId,
		header = header,
		ui = ui,
		kit = kit,
		participant = participant,
		mySide = if isA then "A" elseif isB then "B" else nil,
		markers = markers,
		focus = markers.CameraFocus.Position,
		sides = { A = side(header.a, "L", -1), B = side(header.b, "R", 1) },
	}
	ctx.crowd = Crowd.new(kit, stage:FindFirstChild("Crowd"))
	return ctx
end

------------------------------------------------------------------ shots

local function bothShot(ctx, duration: number?)
	local f = ctx.focus
	-- Tight enough that both players fill the frame, wide enough for both vehicles.
	ctx.kit:lookShot(f + Vector3.new(0, 3.2, 19), f + Vector3.new(0, 0.6, -7), 56, duration or 0.4)
end

local function closeShot(ctx, key: string, duration: number?)
	local s = ctx.sides[key]
	local p = s.mark.Position
	ctx.kit:lookShot(p + Vector3.new(-s.outward * 1.5, 4.2, 10), p + Vector3.new(0, 3.6, 0), 48, duration or 0)
end

------------------------------------------------------------------ phases

local function intro(ctx)
	local kit, header = ctx.kit, ctx.header
	local f = ctx.focus
	kit:lookShot(f + Vector3.new(0, 16, 52), f + Vector3.new(0, 2, -12), 70, 0)
	kit:lookShot(f + Vector3.new(0, 5, 32), f + Vector3.new(0, 0, -4), 60, header.introSeconds * 0.8)
	kit:title(Text.LarpOff, Color3.fromRGB(255, 214, 90), f + Vector3.new(0, 12, 0))
	kit:after(0.9, function()
		kit:title(("%s  VS  %s"):format(header.a.name, header.b.name), Color3.new(1, 1, 1))
	end)
	kit:sound("CrowdCheer", { volume = 0.45 })
	ctx.crowd:react("cheer", 1.2)
	for _, key in { "A", "B" } do
		Poses.apply(kit, ctx.sides[key].character, "Proud", 0.3)
	end
	if ctx.participant then
		ctx.ui:SetMatchActive(true)
		ChallengePrompts.setEnabled(false)
	end
end

local function playRound(ctx, pkg)
	local kit = ctx.kit
	local stat = Catalog.statsById[pkg.statId]
	local sc = scene(pkg.scene)
	if not sc then
		warn("[LarpScene] No client scene module for " .. tostring(pkg.scene))
		return
	end
	for _, key in { "A", "B" } do
		if sc.resetSide then
			sc.resetSide(ctx, key)
		end
	end
	ctx.folderClearedFor = pkg.index
	kit.folder:ClearAllChildren()
	for _, key in { "A", "B" } do
		ctx.sides[key].phone = nil
	end
	ctx.crowd:look(nil)
	ctx.crowd:setPhones(false)
	if ctx.participant then
		ctx.ui:SetRound(pkg.statId, pkg.index, pkg.count)
	end

	local timing = ctx.header.timing
	local beats = ClimbPlan.build(pkg, timing)
	local roll = { A = pkg.a, B = pkg.b }
	local winner = pkg.winner
	local loser = if winner == "A" then "B" elseif winner == "B" then "A" else nil

	local handlers = {}
	function handlers.title()
		kit:title(sc.title or stat.displayName:upper(), stat.color, ctx.focus + Vector3.new(0, 11, 0))
		kit:sound("Slam", { volume = 0.55 })
		kit:shake(0.25, 0.2)
		bothShot(ctx, 0.35)
	end
	function handlers.tier(b)
		sc.showTier(ctx, b.side, b.tier, false)
		if b.tier >= 4 then
			kit:punch(3, 0.25)
		end
	end
	function handlers.viral(b)
		local s = ctx.sides[b.side]
		kit:freeze(0.3)
		kit:flash(0.35, 0.3)
		kit:worldStamp(headPos(s, 9), Text.Stamps.Viral, COLORS.Viral, 1.3, 6)
		-- a burst of notification pings building to a whoosh
		for i = 0, 2 do
			kit:after(i * 0.07, function()
				kit:sound("Ping", { volume = 0.45 + i * 0.1, speed = 1 + i * 0.12 })
			end)
		end
		kit:after(0.22, function()
			kit:sound("Whoosh", { volume = 0.8, speed = 1.3 })
		end)
		ctx.crowd:setPhones(true)
		ctx.crowd:react("erupt", 1)
		if ctx.participant then
			ctx.ui:ShowStamp("Viral", 0.9)
			closeShot(ctx, b.side, 0.15)
			kit:after(0.45, function()
				bothShot(ctx, 0.3)
			end)
		end
		if b.to ~= b.from then
			sc.showTier(ctx, b.side, b.to, true)
		end
	end
	function handlers.settle(b)
		sc.signature(ctx, b.side, b.tier)
	end
	function handlers.faceoff()
		if not ctx.participant then
			return
		end
		closeShot(ctx, "A", 0)
		kit:after(0.18, function()
			closeShot(ctx, "B", 0)
		end)
		kit:after(0.36, function()
			bothShot(ctx, 0)
		end)
	end
	function handlers.takeover(b)
		sc.takeover(ctx, b.side, loser)
		if roll[b.side].tier >= 4 then
			kit:shake(0.6, 0.4)
		end
	end
	function handlers.fumble(b)
		sc.fumble(ctx, b.side, b.variant)
		kit:worldStamp(headPos(ctx.sides[b.side], 5.5), Text.Stamps.Fumbled, COLORS.Fumbled, 1.2, 5)
		-- a record scratch or the fail sting; derived from the match so every viewer hears the same one
		kit:sound(if (ctx.id + pkg.index) % 2 == 0 then "RecordScratch" else "FailSting", { volume = 0.55, duration = 1.4 })
		if ctx.participant then
			ctx.ui:ShowStamp("Fumbled", 0.7)
		end
	end
	function handlers.draw()
		kit:worldStamp(ctx.focus + Vector3.new(0, 8, 0), Text.Stamps.Draw, COLORS.Fumbled, 1.4, 0)
		kit:sound("Cartoon", { volume = 0.45, duration = 1.5 })
		if ctx.participant then
			ctx.ui:ShowStamp("Draw", 0.9)
		end
	end
	function handlers.numbers()
		for _, key in { "A", "B" } do
			local s = ctx.sides[key]
			kit:bigNumber(headPos(s, 4.6), roll[key].rolled, if key == winner then COLORS.Ate else COLORS.Fumbled, 1.1)
		end
		if winner and winner ~= "Draw" then
			local w = ctx.sides[winner]
			kit:worldStamp(headPos(w, 7.5), Text.Stamps.Ate, COLORS.Ate, 1.0, -8)
			kit:sound("Slam", { volume = 0.6 })
			kit:sound("CrowdCheer", { volume = 0.5 })
			ctx.crowd:react("cheer", 1)
			kit:punch(6, 0.3)
			if ctx.participant then
				ctx.ui:ShowStamp("Ate", 0.8)
			end
		end
	end

	for _, b in beats do
		local handler = handlers[b.kind]
		if handler then
			kit:after(b.t, function()
				if current == ctx then
					handler(b)
				end
			end)
		end
	end
end

local function verdict(ctx, outcome)
	local kit = ctx.kit
	local winner = outcome.winner
	if winner ~= "A" and winner ~= "B" then
		kit:worldStamp(ctx.focus + Vector3.new(0, 8, 0), Text.Stamps.Draw, COLORS.Fumbled, 2, 0)
		return
	end
	local loser = if winner == "A" then "B" else "A"
	local w, l = ctx.sides[winner], ctx.sides[loser]
	local delay = 0
	if outcome.upset then
		delay = 0.7
		kit:slowmo(0.3, 0.45)
		-- record scratch, a beat of silence, then the crowd erupts
		kit:sound("RecordScratch", { volume = 0.7, duration = 0.9 })
		kit:sound("Slam", { volume = 0.9, speed = 0.8 })
		kit:shake(1.4, 0.5)
		kit:confetti(w.mark.Position + Vector3.new(0, 1, 0), 90)
		kit:worldStamp(ctx.focus + Vector3.new(0, 10, 0), Text.Stamps.Upset, COLORS.Upset, 1.6, -6)
		kit:after(0.5, function()
			kit:sound("CrowdErupt", { volume = 0.6 })
			ctx.crowd:react("erupt", 1.5)
		end)
		if ctx.participant then
			ctx.ui:ShowStamp("Upset", 0.7)
		end
	end
	kit:after(delay, function()
		Poses.apply(kit, w.character, "Victory", 0.2)
		kit:worldStamp(headPos(w, 8), Text.Stamps.Certified, COLORS.Certified, 1.6, -4)
		kit:sound("Fanfare", { volume = 0.5 })
		kit:confetti(w.mark.Position + Vector3.new(0, 1, 0), 50)
		ctx.crowd:react("cheer", 1.2)
		kit:orbit(w.mark.Position + Vector3.new(0, 2.5, 0), 12, 3.5, -35, 25, 1.6, 55)
		if ctx.participant then
			ctx.ui:ShowStamp("Certified", 1.1)
		end
	end)
	kit:after(delay + 1.5, function()
		Poses.apply(kit, l.character, "Slump", 0.2)
		local light = l.spotlight and l.spotlight:FindFirstChildOfClass("SpotLight")
		if light then
			light.Enabled = true
			ctx.spotOn = light
		end
		kit:worldStamp(headPos(l, 8), Text.Stamps.Exposed, COLORS.Exposed, 1.8, 6)
		kit:sound("Shutter", { volume = 0.8 })
		kit:sound("FailSting", { volume = 0.5 })
		kit:sound("CrowdMixed", { volume = 0.35 })
		kit:flash(0.4, 0.2)
		kit:after(0.2, function()
			kit:sound("Shutter", { volume = 0.6, speed = 1.15 })
			kit:flash(0.3, 0.2)
		end)
		ctx.crowd:react("wince", 1)
		ctx.crowd:look(l.mark.Position)
		local p = l.mark.Position
		kit:lookShot(p + Vector3.new(-l.outward * 1.2, 4.4, 7), p + Vector3.new(0, 4.2, 0), 42, 0.5)
		if ctx.participant then
			ctx.ui:ShowStamp("Exposed", 1.1)
		end
	end)
	if ctx.participant and ctx.mySide == winner and (outcome.bonus or 0) > 0 then
		kit:after(delay + 0.4, function()
			ctx.ui:Notify(("+%d bonus%s"):format(outcome.bonus, if outcome.upset then " (upset x2)" else ""), "success")
		end)
	end
end

local function finish(ctx, aborted: boolean, reason: string?)
	if current ~= ctx then
		return
	end
	current = nil
	for _, key in { "A", "B" } do
		local sc = scene("Bag")
		if sc and sc.resetSide then
			sc.resetSide(ctx, key)
		end
	end
	if ctx.spotOn then
		ctx.spotOn.Enabled = false
	end
	ctx.crowd:reset()
	Poses.reset()
	ctx.kit:Destroy()
	if ctx.participant then
		ChallengePrompts.setEnabled(true)
		ctx.ui:SetMatchActive(false)
		if aborted then
			ctx.ui:Notify("Larp-off cancelled: " .. tostring(reason or "aborted"), "warning")
		else
			local other = if ctx.mySide == "A" then ctx.header.b else ctx.header.a
			local seconds = ctx.rematchSeconds or 60
			if other.kind == "Npc" then
				ctx.ui:ShowRematch("Npc", 0, seconds)
			else
				ctx.ui:ShowRematch("Player", other.userId, seconds)
			end
		end
	end
end

function SceneDirector.start(ui)
	local function begin(header)
		if current and current.id == header.matchId then
			return current
		end
		if current then
			finish(current, true, "replaced")
		end
		local ctx = buildContext(header, ui)
		current = ctx
		return ctx
	end

	Net.get("MatchBegin").OnClientEvent:Connect(function(header)
		local ctx = begin(header)
		if ctx then
			intro(ctx)
		end
	end)
	Net.get("MatchRound").OnClientEvent:Connect(function(pkg)
		-- late spectators build their context from the header carried in every round
		local ctx = if current and current.id == pkg.matchId then current else begin(pkg.header)
		if ctx then
			playRound(ctx, pkg)
		end
	end)
	Net.get("MatchVerdict").OnClientEvent:Connect(function(outcome)
		if current and current.id == outcome.matchId then
			current.rematchSeconds = outcome.rematchSeconds
			verdict(current, outcome)
		end
	end)
	Net.get("MatchEnd").OnClientEvent:Connect(function(matchId)
		if current and current.id == matchId then
			finish(current, false)
		end
	end)
	Net.get("MatchAborted").OnClientEvent:Connect(function(matchId, reason)
		if current and current.id == matchId then
			finish(current, true, reason)
		end
	end)
	player.CharacterAdded:Connect(function()
		if current and current.participant then
			finish(current, true, "respawned")
		end
	end)
end

return SceneDirector
