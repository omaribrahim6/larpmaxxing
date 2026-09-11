-- Plays larp-offs from the server's packets (see MatchService for the shapes).
-- Participants get the full cinematic: camera, screen stamps (Codex UI), flashes.
--
-- Config.Tuning.SceneMode picks how a round is shown:
--   "Cctv"    Security-cam footage on a split monitor (LarpClient.Cctv): each larper walks
--             a street on their own feed, clocks a ride and takes a selfie with it; the
--             winner's selfie becomes a post. The larpers watch the monitor full-screen
--             and everyone else on the stage's BigScreen. StreetRound plays the round
--             with the scene's "<id>Street" module. Intro and verdict are live on stage,
--             and the players on stage strike the same poses as their copies.
--   "Screen"  Each round plays in its own 3D set (Larp.Assets.Sets, placed far from the
--             map) with local copies of both avatars. Participants watch the set
--             full-screen; everyone else near the stage watches it on the stage's
--             BigScreen (a ViewportFrame). The intro and the verdict happen live on the
--             real stage, and the players on stage strike the same poses as their copies.
--   "Stage"   The original mode: props appear on the stage itself.
local Players = game:GetService("Players")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Catalog = require(Larp.Shared.Catalog)
local ClimbPlan = require(Larp.Shared.ClimbPlan)
local Text = require(Larp.Config.Text)
local Tuning = require(Larp.Config.Tuning)
local Net = require(Larp.Shared.Net)

local Kit = require(script.Parent.SceneKit)
local Poses = require(script.Parent.Poses)
local Crowd = require(script.Parent.Crowd)
local Cctv = require(script.Parent.Cctv)
local StreetRound = require(script.Parent.StreetRound)
local ChallengePrompts = require(script.Parent.ChallengePrompts)

local SceneDirector = {}

local SCREEN_MODE = Tuning.SceneMode == "Screen"
local CCTV_MODE = Tuning.SceneMode == "Cctv"
local SET_POSITION = Tuning.Screen and Tuning.Screen.setOrigin or Vector3.new(0, 0, 3000)

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

-- CCTV mode's module for a scene (Scenes.<id>Street), or nil.
local function streetScene(id: string?)
	return if id then scene(id .. "Street") else nil
end

-- The set model a scene plays in (Config.Scenes.<id>.setModel), or nil.
local function setNameFor(sceneId: string?): string?
	local config = sceneId and Larp.Config.Scenes:FindFirstChild(sceneId)
	return config and require(config).setModel
end

local function localFolder(name: string): Folder
	local folder = workspace:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = workspace
	end
	return folder
end

local function headPos(side, extra: number?)
	return side.mark.Position + Vector3.new(0, extra or 7.5, 0)
end

-- Height of a character's pivot above the ground it stands on (matches MatchService).
local function standHeight(model: Model): number
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return 3
	end
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		return humanoid.HipHeight + root.Size.Y / 2
	end
	return 2 + root.Size.Y / 2
end

-- A local, inert copy of a character for the scene set: no scripts, sounds, prompts or
-- nameplate, root anchored on `mark`.
local function avatarCopy(model: Model?, mark: CFrame, parent: Instance): Model?
	if not model or not model.Parent then
		return nil
	end
	local archivable = model.Archivable
	model.Archivable = true
	local ok, copy = pcall(model.Clone, model)
	model.Archivable = archivable
	if not ok or not copy then
		return nil
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("BillboardGui") or d:IsA("ProximityPrompt") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		pcall(function()
			humanoid.EvaluateStateMachine = false
		end)
	end
	local root = copy:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = true
	end
	copy.Name = "Avatar"
	copy:PivotTo(mark * CFrame.new(0, standHeight(copy), 0))
	copy.Parent = parent
	return copy
end

-- This client's live feed on the stage's big screen, or nil if the stage has none.
-- The feed is a SurfaceGui in PlayerGui adorned to the screen part (a ViewportFrame in
-- the part's own SurfaceGui doesn't render); it draws over the part's idle card and
-- copies its Viewport/Overlay templates.
local function bigScreen(stage: Instance)
	local model = stage:FindFirstChild("BigScreen")
	local part = model and model:FindFirstChild("Screen")
	local template = part and part:FindFirstChild("Surface")
	local viewportTemplate = template and template:FindFirstChild("Viewport")
	if not viewportTemplate then
		return nil
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local name = "LarpBigScreen_" .. stage.Name
	local gui = playerGui:FindFirstChild(name)
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name = name
		gui.ResetOnSpawn = false
		gui.Enabled = false
		gui.Adornee = part
		gui.Face = template.Face
		gui.SizingMode = template.SizingMode
		gui.PixelsPerStud = template.PixelsPerStud
		gui.LightInfluence = template.LightInfluence
		gui.Brightness = template.Brightness
		gui.ClipsDescendants = true
		gui.ZOffset = 1
		local viewport = viewportTemplate:Clone()
		viewport.Visible = true
		for _, child in viewport:GetChildren() do
			if not child:IsA("WorldModel") then
				child:Destroy()
			end
		end
		viewport.Parent = gui
		local overlay = template:FindFirstChild("Overlay")
		if overlay then
			overlay:Clone().Parent = gui
		end
		gui.Parent = playerGui
	end
	return { gui = gui, viewport = gui:FindFirstChild("Viewport"), overlay = gui:FindFirstChild("Overlay") }
end

local function showScreen(screen, live: boolean)
	if not screen then
		return
	end
	screen.gui.Enabled = live
	if not live then
		local world = screen.viewport:FindFirstChildOfClass("WorldModel")
		if world then
			world:ClearAllChildren()
		end
	end
end

-- A SurfaceGui in PlayerGui drawn on the stage's big screen, for the CCTV monitor.
local function stageSurface(stage: Instance): SurfaceGui?
	local model = stage:FindFirstChild("BigScreen")
	local part = model and model:FindFirstChild("Screen")
	local template = part and part:FindFirstChild("Surface")
	if not template then
		return nil
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local name = "LarpCctvScreen_" .. stage.Name
	local gui = playerGui:FindFirstChild(name)
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name = name
		gui.ResetOnSpawn = false
		gui.Adornee = part
		gui.Face = template.Face
		gui.SizingMode = template.SizingMode
		gui.PixelsPerStud = template.PixelsPerStud
		gui.LightInfluence = 0
		gui.Brightness = template.Brightness
		gui.ClipsDescendants = true
		gui.ZOffset = 1
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = playerGui
	end
	gui:ClearAllChildren()
	gui.Enabled = false
	return gui
end

-- The idle card's hint line on a stage's big screen (shows "A VS B" during a match).
local function idleHint(stage: Instance): TextLabel?
	local model = stage:FindFirstChild("BigScreen")
	local idle = model and model:FindFirstChild("Idle", true)
	return idle and idle:FindFirstChild("Hint")
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

	local root = localFolder("LarpSceneLocal")
	root:ClearAllChildren()
	local stageFx = localFolder("LarpStageFx")
	stageFx:ClearAllChildren()

	local firstScene = Catalog.statsById[Catalog.statIds[1]].scene
	local cctv = CCTV_MODE and streetScene(firstScene) ~= nil
	local screenMode = SCREEN_MODE and setNameFor(firstScene) ~= nil
	local screen = if screenMode and not participant then bigScreen(stage) else nil
	local world: Instance = root
	local camera = nil
	if screen then
		-- spectators watch the round on the stage's big screen
		local worldModel = screen.viewport:FindFirstChildOfClass("WorldModel")
		if not worldModel then
			worldModel = Instance.new("WorldModel")
			worldModel.Parent = screen.viewport
		end
		worldModel:ClearAllChildren()
		camera = screen.viewport.CurrentCamera
		if not camera then
			camera = Instance.new("Camera")
			camera.Parent = screen.viewport
			screen.viewport.CurrentCamera = camera
		end
		world = worldModel
		showScreen(screen, true)
	end
	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = world
	local setFolder = Instance.new("Folder")
	setFolder.Name = "Set"
	setFolder.Parent = world

	local kit = Kit.new({
		participant = participant,
		reduceEffects = ui:GetSetting("reduceEffects"),
		folder = props,
		camera = camera,
		overlay = if screenMode then (if screen then screen.overlay else participant) else nil,
		stageFolder = stageFx,
		noParticles = camera ~= nil,
	})
	local function side(info, suffix: string, outward: number)
		local mark = markers:FindFirstChild("Mark" .. suffix).CFrame
		return {
			character = info.model, -- the set's avatar copy in Screen mode
			stageCharacter = info.model,
			name = info.name,
			userId = info.userId,
			kind = info.kind,
			rankIndex = info.rankIndex,
			mark = mark, -- the set's mark in Screen mode
			stageMark = mark,
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
		screenMode = screenMode,
		screen = screen,
		setFolder = setFolder,
		mySide = if isA then "A" elseif isB then "B" else nil,
		markers = markers,
		focus = markers.CameraFocus.Position, -- the set's focus in Screen mode
		stageFocus = markers.CameraFocus.Position,
		screenCenter = if stage:FindFirstChild("BigScreen") then stage.BigScreen:GetPivot().Position else nil,
		sides = { A = side(header.a, "L", -1), B = side(header.b, "R", 1) },
	}
	ctx.crowd = Crowd.new(kit, stage:FindFirstChild("Crowd"))
	ctx.stage = stage
	if cctv then
		-- the monitor: full-screen for the two larpers, on the big screen for the audience
		local config = require(Larp.Config.Scenes:FindFirstChild(firstScene))
		local cams = config.street and config.street.cams or {}
		local function camInfo(key: string, info)
			local cam = cams[key] or {}
			return { label = cam.label or ("CAM 0" .. (if key == "A" then "1" else "2")), place = cam.place or "", subject = info.name }
		end
		ctx.cctv = true
		ctx.avatarCopy = avatarCopy
		ctx.standHeight = standHeight
		ctx.monitor = Cctv.new(kit, { A = camInfo("A", header.a), B = camInfo("B", header.b) })
		if participant then
			local gui = Instance.new("ScreenGui")
			gui.Name = "LarpCctvFull"
			gui.IgnoreGuiInset = true
			gui.ResetOnSpawn = false
			gui.DisplayOrder = 4
			gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			gui.Enabled = false
			gui.Parent = player:WaitForChild("PlayerGui")
			ctx.fullGui = gui
			ctx.monitor:mount(gui)
		else
			ctx.surface = stageSurface(stage)
			ctx.monitor:mount(ctx.surface)
		end
	end
	local hint = idleHint(stage)
	if hint then
		ctx.hint, ctx.hintWas = hint, hint.Text
		hint.Text = ("%s  VS  %s"):format(header.a.name, header.b.name)
	end
	return ctx
end

-- Screen mode: puts the named set in place (if it isn't already) with fresh avatar
-- copies on its marks, and points the sides at the set's markers.
local function ensureSet(ctx, setName: string?)
	if not ctx.screenMode or not setName or ctx.setName == setName then
		return
	end
	local sets = Larp.Assets:FindFirstChild("Sets")
	local template = sets and sets:FindFirstChild(setName)
	if not template then
		warn("[LarpScene] Missing set " .. tostring(setName))
		return
	end
	ctx.setFolder:ClearAllChildren()
	local set = template:Clone()
	set:PivotTo(CFrame.new(SET_POSITION) * template:GetPivot().Rotation)
	set.Parent = ctx.setFolder
	ctx.setName = setName
	local m = set:FindFirstChild("Markers")
	ctx.focus = m.CameraFocus.Position
	for key, suffix in { A = "L", B = "R" } do
		local s = ctx.sides[key]
		s.mark = m:FindFirstChild("Mark" .. suffix).CFrame
		s.vehicleCF = m:FindFirstChild("Vehicle" .. suffix).CFrame
		s.jetCF = m:FindFirstChild("Jet" .. suffix).CFrame
		s.billboard = set:FindFirstChild("Billboard" .. suffix)
		s.avatarRest = nil
		s.character = avatarCopy(s.stageCharacter, s.mark, ctx.setFolder)
		if s.character then
			Poses.link(s.character, s.stageCharacter)
		end
	end
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
	if ctx.screenMode then
		local first = Catalog.statsById[Catalog.statIds[1]].scene
		ensureSet(ctx, setNameFor(first))
		-- the street starts empty: everyone arrives in their ride once the round starts
		local sc = scene(first)
		if sc and sc.resetSide then
			for _, key in { "A", "B" } do
				sc.resetSide(ctx, key)
			end
		end
	end
	if ctx.cctv then
		-- build both streets now so the first round starts without a hitch
		local sc = streetScene(Catalog.statsById[Catalog.statIds[1]].scene)
		for _, key in { "A", "B" } do
			if sc and sc.build then
				sc.build(ctx, key)
			end
		end
	end
	local f = ctx.focus
	if (ctx.screenMode or ctx.cctv) and ctx.participant then
		-- live on stage first, then the camera dives into the big screen
		local sf = ctx.stageFocus
		-- aim between the players and the screen so both are in frame
		local target = sf:Lerp(ctx.screenCenter or (sf + Vector3.new(0, 16, -26)), 0.55)
		kit:lookShot(sf + Vector3.new(0, 14, 50), sf + Vector3.new(0, 6, -10), 70, 0)
		kit:lookShot(sf + Vector3.new(0, 9, 20), target, 50, header.introSeconds * 0.8)
		kit:after(header.introSeconds - 0.25, function()
			kit:flash(0.7, 0.3)
			if ctx.cctv then
				-- into the screen: the monitor goes full-screen
				ctx.fullGui.Enabled = true
				ctx.monitor:connect(0.6)
			else
				bothShot(ctx, 0)
			end
		end)
	else
		kit:lookShot(f + Vector3.new(0, 16, 52), f + Vector3.new(0, 2, -12), 70, 0)
		kit:lookShot(f + Vector3.new(0, 5, 32), f + Vector3.new(0, 0, -4), 60, header.introSeconds * 0.8)
	end
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
	if ctx.cctv then
		local sc = streetScene(pkg.scene)
		if not sc then
			warn("[LarpScene] No CCTV scene module for " .. tostring(pkg.scene))
			return
		end
		if ctx.fullGui then
			ctx.fullGui.Enabled = true
		end
		if ctx.surface then
			ctx.surface.Enabled = true
		end
		StreetRound.play(ctx, pkg, sc, function()
			return current == ctx
		end)
		return
	end
	local stat = Catalog.statsById[pkg.statId]
	local sc = scene(pkg.scene)
	if not sc then
		warn("[LarpScene] No client scene module for " .. tostring(pkg.scene))
		return
	end
	ensureSet(ctx, setNameFor(pkg.scene))
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
		end
		if ctx.participant or ctx.screen then
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
		if not ctx.participant and not ctx.screen then
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
	-- Screen mode: the verdict lands on the players standing on the real stage. The
	-- participants' camera comes back to the stage; the big screen keeps showing the set.
	-- One stamp per result (CERTIFIED, EXPOSED, UPSET!), in the world, in the stamp font;
	-- the UI's full-screen stamp isn't used here so nothing shows twice.
	local live = ctx.screenMode or ctx.cctv
	local camOnStage = live and ctx.participant
	if ctx.cctv and ctx.participant then
		-- the monitor shrinks back into the big screen behind the players
		local surface = stageSurface(ctx.stage)
		if surface then
			surface.Enabled = true
			ctx.monitor:mount(surface)
			ctx.surface = surface
		end
		if ctx.fullGui then
			ctx.fullGui.Enabled = false
		end
	end
	local function stagePos(s, height: number)
		return s.stageMark.Position + Vector3.new(0, height, 0)
	end
	local function camPos(s): Vector3
		return if camOnStage then s.stageMark.Position else s.mark.Position
	end
	local function stamp(s, height: number, text: string, color: Color3, lifetime: number, rotation: number)
		if live then
			kit:stageStamp(stagePos(s, height), text, color, lifetime, rotation)
			if ctx.screen then
				kit:worldStamp(headPos(s, height), text, color, lifetime, rotation)
			end
		else
			kit:worldStamp(headPos(s, height), text, color, lifetime, rotation)
		end
	end
	local function confetti(s, count: number)
		if live then
			kit:stageConfetti(s.stageMark.Position + Vector3.new(0, 1, 0), count)
		else
			kit:confetti(s.mark.Position + Vector3.new(0, 1, 0), count)
		end
	end
	if camOnStage then
		local sf = ctx.stageFocus
		kit:flash(0.5, 0.25)
		kit:lookShot(sf + Vector3.new(0, 4, 22), sf + Vector3.new(0, 1.5, -6), 58, 0)
	end

	if winner ~= "A" and winner ~= "B" then
		local where = if live then ctx.stageFocus else ctx.focus
		if live then
			kit:stageStamp(where + Vector3.new(0, 8, 0), Text.Stamps.Draw, COLORS.Fumbled, 2, 0)
		end
		if not live or ctx.screen then
			kit:worldStamp(ctx.focus + Vector3.new(0, 8, 0), Text.Stamps.Draw, COLORS.Fumbled, 2, 0)
		end
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
		confetti(w, 90)
		local center = if live then ctx.stageFocus else ctx.focus
		if live then
			kit:stageStamp(center + Vector3.new(0, 10, 0), Text.Stamps.Upset, COLORS.Upset, 1.6, -6)
		end
		if not live or ctx.screen then
			kit:worldStamp(ctx.focus + Vector3.new(0, 10, 0), Text.Stamps.Upset, COLORS.Upset, 1.6, -6)
		end
		kit:after(0.5, function()
			kit:sound("CrowdErupt", { volume = 0.6 })
			ctx.crowd:react("erupt", 1.5)
		end)
	end
	kit:after(delay, function()
		Poses.apply(kit, w.character, "Victory", 0.2)
		stamp(w, 8, Text.Stamps.Certified, COLORS.Certified, 1.6, -4)
		kit:sound("Fanfare", { volume = 0.5 })
		confetti(w, 50)
		ctx.crowd:react("cheer", 1.2)
		kit:orbit(camPos(w) + Vector3.new(0, 2.5, 0), 12, 3.5, -35, 25, 1.6, 55)
	end)
	kit:after(delay + 1.5, function()
		Poses.apply(kit, l.character, "Slump", 0.2)
		local light = l.spotlight and l.spotlight:FindFirstChildOfClass("SpotLight")
		if light then
			light.Enabled = true
			ctx.spotOn = light
		end
		-- just above their head, so it stays in the close-up below
		stamp(l, 6.4, Text.Stamps.Exposed, COLORS.Exposed, 1.8, 6)
		kit:sound("Shutter", { volume = 0.8 })
		kit:sound("FailSting", { volume = 0.5 })
		kit:sound("CrowdMixed", { volume = 0.35 })
		kit:flash(0.4, 0.2)
		kit:after(0.2, function()
			kit:sound("Shutter", { volume = 0.6, speed = 1.15 })
			kit:flash(0.3, 0.2)
		end)
		ctx.crowd:react("wince", 1)
		ctx.crowd:look(l.stageMark.Position)
		local p = camPos(l)
		kit:lookShot(p + Vector3.new(-l.outward * 1.2, 5, 7.5), p + Vector3.new(0, 4.8, 0), 44, 0.5)
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
	if ctx.monitor then
		ctx.monitor:destroy()
	end
	if ctx.fullGui then
		ctx.fullGui:Destroy()
	end
	if ctx.surface then
		ctx.surface.Enabled = false
	end
	ctx.kit:Destroy()
	if ctx.setFolder and ctx.setFolder.Parent then
		ctx.setFolder:Destroy()
	end
	showScreen(ctx.screen, false)
	localFolder("LarpStageFx"):ClearAllChildren()
	if ctx.hint and ctx.hint.Parent then
		ctx.hint.Text = ctx.hintWas
	end
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
