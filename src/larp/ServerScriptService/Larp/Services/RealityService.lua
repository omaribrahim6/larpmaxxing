-- LARP to Reality's activities (Config.Reality; LarpBuild.Reality builds the world and
-- AreaService runs its doors): the valets' cars (CarService), the SK8 & MATCHA skate kit, the
-- Fashion Week runway, the 500 lb bench and the Prize Hall ceremony. The server does what
-- everyone sees (fits, poses, board texts, where players stand) and checks every step; the
-- player's client (LarpClient.Reality) runs the camera, the fit picker and the bench's
-- pushes, and sends each step back over RealityAction. The runway, bench and prize take one
-- player at a time. Anyone who leaves the world goes back to normal (and their car is towed).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Reality = require(Larp.Config.Reality)
local Net = require(Larp.Shared.Net)
local Lib = script.Parent.Parent.Lib
local Fits = require(Lib.Fits)
local Stance = require(Lib.Stance)

local RealityService = {}

local words = Reality.words
local UP = Vector3.yAxis
local state: { [Player]: any } = {}
local busy: { [string]: Player? } = {} -- "Runway" / "Bench" / "Prize" -> who's on it
local fitsById = {}
for _, fit in Reality.fits do
	fitsById[fit.id] = fit
end

function RealityService:Init(services)
	self.Cars = services.CarService
end

local function stateOf(player: Player)
	local s = state[player]
	if not s then
		s = { reps = 0, lastRep = 0, lastAction = 0 }
		state[player] = s
	end
	return s
end

local function notice(player: Player, text: string, kind: string?)
	Net.get("Notice"):FireClient(player, text, kind or "warning")
end

local function event(player: Player, kind: string, data: any?)
	Net.get("RealityEvent"):FireClient(player, kind, data)
end

-- A moment everyone nearby sees: the crowd in `venue` reacts (LarpClient.Reality).
local function moment(kind: string, venue: string, player: Player?)
	Net.get("RealityEvent"):FireAllClients("moment", { kind = kind, venue = venue, userId = player and player.UserId })
end

local function characterOf(player: Player): (Model?, BasePart?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and root and humanoid and humanoid.Health > 0) then
		return nil, nil
	end
	return character, root
end

-- True while `player` is on an activity here or skating (the HUD's Larp-off button waits).
function RealityService:IsBusy(player: Player): boolean
	local s = state[player]
	return s ~= nil and (s.activity ~= nil or s.pending ~= nil or s.skating == true)
end

function RealityService:_marker(venue: string, name: string): BasePart?
	local v = self.world:FindFirstChild(venue)
	return v and v:FindFirstChild(name, true) :: BasePart?
end

-- Writes `text` on a venue's board (nil puts its own words back).
function RealityService:_board(venue: string, text: string?)
	local board = self:_marker(venue, "Board")
	local gui = board and board:FindFirstChild("Label")
	local label = gui and gui:FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = text or self.boards[venue] or ""
	end
end

------------------------------------------------------------------ the car valets

function RealityService:_drive(player: Player, id: string)
	local character = characterOf(player)
	if not character then
		return
	end
	self:_skate(player, false)
	-- the valet's spot in the lane, or the next free one behind it
	local spot = nil
	for _, d in self.world:GetDescendants() do
		if d.Name == "CarSpot" and d:GetAttribute("Car") == id then
			spot = d
		end
	end
	if not spot then
		return
	end
	local cars = workspace.Larp:FindFirstChild("Cars")
	local cf = spot.CFrame
	for k = 0, 6 do
		local try = spot.CFrame * CFrame.new(0, 0, k * 16)
		local clear = true
		for _, car in if cars then cars:GetChildren() else {} do
			if car:IsA("Model") and (car:GetPivot().Position - try.Position).Magnitude < 12 then
				clear = false
			end
		end
		if clear then
			cf = try
			break
		end
	end
	if self.Cars:Spawn(player, id, cf + UP * 0.4) then
		notice(player, words.carReady:format(require(Larp.Config.Cars).cars[id].name), "success")
	end
end

------------------------------------------------------------------ the skate kit

function RealityService:_skate(player: Player, on: boolean)
	local s = stateOf(player)
	local character = characterOf(player)
	if not character or s.skating == on then
		return
	end
	s.skating = on
	if on then
		Fits.dress(character, Reality.skateFit)
		s.fit = Reality.skateFit.id
		Fits.board(character, Reality.boardLift)
		Stance.set(character, "Skate")
		character:SetAttribute("Skating", true)
		notice(player, words.skateOn, "success")
	else
		Fits.unboard(character)
		if s.fit == Reality.skateFit.id then
			Fits.strip(character)
			s.fit = nil
		end
		Stance.clear(character)
		character:SetAttribute("Skating", nil)
	end
end

-- A push off the ground: the back leg kicks for a moment (the client adds the speed).
function RealityService:_push(player: Player)
	local s = stateOf(player)
	local character = characterOf(player)
	if not s.skating or not character or os.clock() - (s.lastPush or 0) < Reality.skate.cooldown * 0.8 then
		return
	end
	s.lastPush = os.clock()
	Stance.set(character, "SkatePush")
	task.delay(0.3, function()
		if s.skating and character.Parent then
			Stance.set(character, "Skate")
		end
	end)
end

------------------------------------------------------------------ the runway

function RealityService:_runway(player: Player, fitId: any)
	local s = stateOf(player)
	local fit = type(fitId) == "string" and fitsById[fitId]
	local character, root = characterOf(player)
	local start, stop, cam = self:_marker("Runway", "RunwayStart"), self:_marker("Runway", "RunwayEnd"), self:_marker("Runway", "RunwayCam")
	if not (fit and character and root and start and stop and cam) or s.pending ~= "Runway" or s.activity or busy.Runway then
		return
	end
	if (root.Position - start.Position).Magnitude > 60 then
		return
	end
	s.pending = nil
	self:_skate(player, false)
	busy.Runway = player
	s.activity, s.since, s.posed = "Runway", os.clock(), false
	Fits.dress(character, fit)
	s.fit = fit.id
	character:PivotTo(start.CFrame + UP * 3)
	self:_board("Runway", words.board.runway:format(player.DisplayName:upper(), fit.name:upper()))
	event(player, "runway", { start = start.CFrame, stop = stop.CFrame, cam = cam.CFrame, pose = Reality.runway.poseSeconds })
	moment("walk", "Runway", player)
end

function RealityService:_runwayPose(player: Player)
	local s = stateOf(player)
	local character = characterOf(player)
	if s.activity ~= "Runway" or s.posed or not character then
		return
	end
	s.posed = true
	Stance.set(character, "Serve")
	moment("cheer", "Runway", player)
	task.delay(Reality.runway.poseSeconds, function()
		if s.activity == "Runway" and character.Parent then
			Stance.clear(character)
		end
	end)
end

------------------------------------------------------------------ the bench

-- The root's frame lying face up on the bench, head toward the rack.
local function lying(spot: BasePart): CFrame
	local head = spot.CFrame.LookVector
	local at = spot.Position + UP * 0.9 - head * 0.4
	return CFrame.fromMatrix(at, head:Cross(-UP), head)
end

function RealityService:_barTo(name: string)
	local bar = self.world.Gym:FindFirstChild("Barbell", true)
	local mark = self:_marker("Gym", name)
	if bar and mark then
		bar:PivotTo(mark.CFrame)
	end
end

function RealityService:_bench(player: Player)
	local s = stateOf(player)
	local character, root = characterOf(player)
	local spot, cam = self:_marker("Gym", "BenchSpot"), self:_marker("Gym", "BenchCam")
	if not (character and root and spot and cam) then
		return
	end
	if busy.Bench then
		notice(player, words.taken)
		return
	end
	self:_skate(player, false)
	busy.Bench = player
	s.activity, s.since, s.reps, s.lastRep = "Bench", os.clock(), 0, 0
	character:PivotTo(lying(spot))
	root.Anchored = true
	Stance.set(character, "BenchLow")
	self:_barTo("BarLow")
	local b = Reality.bench
	self:_board("Gym", words.board.bench:format(player.DisplayName:upper(), b.weight, 0, b.reps))
	event(player, "bench", { reps = b.reps, pushes = b.pushes, cam = cam.CFrame })
	moment("watch", "Gym", player)
end

function RealityService:_rep(player: Player)
	local s = stateOf(player)
	local character = characterOf(player)
	local b = Reality.bench
	if s.activity ~= "Bench" or not character or os.clock() - s.lastRep < b.repSeconds or s.reps >= b.reps then
		return
	end
	s.lastRep = os.clock()
	s.reps += 1
	Stance.set(character, "BenchPress")
	self:_barTo("BarHigh")
	self:_board("Gym", words.board.bench:format(player.DisplayName:upper(), b.weight, s.reps, b.reps))
	moment("cheer", "Gym", player)
	local rep = s.reps
	task.delay(0.35, function()
		if s.activity == "Bench" and s.reps == rep and rep < b.reps and character.Parent then
			Stance.set(character, "BenchLow")
			self:_barTo("BarLow")
		end
	end)
	if s.reps >= b.reps then
		task.delay(0.6, function()
			if s.activity ~= "Bench" then
				return
			end
			self:_board("Gym", words.board.pr:format(player.DisplayName:upper(), b.weight))
			self:_barTo("BarRack")
			moment("erupt", "Gym", player)
			event(player, "benchDone")
			task.delay(2.4, function()
				if s.activity == "Bench" then
					self:_finish(player)
				end
			end)
		end)
	end
end

------------------------------------------------------------------ the prize

function RealityService:_prize(player: Player)
	local s = stateOf(player)
	local character = characterOf(player)
	local mark, cam = self:_marker("Hall", "PrizeMark"), self:_marker("Hall", "PrizeCam")
	if not (character and mark and cam) then
		return
	end
	if busy.Prize then
		notice(player, words.taken)
		return
	end
	self:_skate(player, false)
	busy.Prize = player
	s.activity, s.since = "Prize", os.clock()
	local p = Reality.prize
	local discovery = p.discoveries[math.random(1, #p.discoveries)]
	character:PivotTo(mark.CFrame + UP * 3)
	self:_board("Hall", words.board.prize:format(p.field:upper(), player.DisplayName:upper(), discovery))
	event(player, "prize", { field = p.field, discovery = discovery, cam = cam.CFrame, seconds = p.seconds })
	moment("watch", "Hall", player)
	-- the ceremony: a wave, the medal and a bow, both arms up, and done
	local steps = {
		{ 0.5, function() Stance.set(character, "Wave") end },
		{ 3.2, function()
			Fits.medal(character)
			Stance.set(character, "Bow")
			moment("erupt", "Hall", player)
		end },
		{ 5.6, function()
			Stance.set(character, "Victory")
			moment("cheer", "Hall", player)
		end },
		{ p.seconds, function() self:_finish(player) end },
	}
	for _, step in steps do
		task.delay(step[1], function()
			if s.activity == "Prize" and busy.Prize == player and character.Parent then
				step[2]()
			end
		end)
	end
end

------------------------------------------------------------------ steps, endings, leaving

-- Ends whatever `player` is doing (the runway, the bench or the prize), releasing the venue.
function RealityService:_finish(player: Player)
	local s = stateOf(player)
	local activity = s.activity
	s.activity, s.pending, s.posed = nil, nil, nil
	if not activity then
		return
	end
	if busy[activity] == player then
		busy[activity] = nil
	end
	local character, root = characterOf(player)
	if activity == "Bench" then
		self:_barTo("BarRack")
		local spot = self:_marker("Gym", "BenchSpot")
		if root then
			root.Anchored = false
		end
		if character and spot then
			local side = spot.Position + spot.CFrame.RightVector * 4 + UP * 3
			character:PivotTo(CFrame.lookAt(side, side - spot.CFrame.RightVector))
		end
		task.delay(6, function()
			if not busy.Bench then
				self:_board("Gym", nil)
			end
		end)
	elseif activity == "Runway" then
		self:_board("Runway", nil)
	elseif activity == "Prize" then
		task.delay(8, function()
			if not busy.Prize then
				self:_board("Hall", nil)
			end
		end)
	end
	if character then
		Stance.clear(character)
	end
	event(player, "done", { activity = activity })
end

-- Back to normal: out of the world, off the board, out of the fit, car towed.
function RealityService:_reset(player: Player)
	self:_finish(player)
	local s = stateOf(player)
	self:_skate(player, false)
	local character = player.Character
	if character then
		Fits.undress(character)
		Fits.unboard(character)
		Stance.clear(character)
		character:SetAttribute("Skating", nil)
	end
	s.fit, s.skating = nil, nil
	self.Cars:Despawn(player)
end

function RealityService:_prompt(player: Player, prompt: ProximityPrompt)
	if player:GetAttribute("Owns" .. Reality.pass) ~= true then
		return -- AreaService keeps everyone else out anyway
	end
	local action = prompt:GetAttribute("RealityAction")
	local s = stateOf(player)
	if action == "Drive" then
		if s.activity then
			notice(player, words.busy)
		else
			self:_drive(player, prompt:GetAttribute("Car"))
		end
	elseif action == "Skate" then
		if s.activity then
			notice(player, words.busy)
		else
			self:_skate(player, not s.skating)
		end
	elseif s.activity then
		notice(player, words.busy)
	elseif action == "Runway" then
		if busy.Runway then
			notice(player, words.taken)
		else
			s.pending = "Runway"
			s.since = os.clock()
			local list = {}
			for _, fit in Reality.fits do
				table.insert(list, { id = fit.id, name = fit.name, icon = fit.icon, top = fit.top, bottom = fit.bottom })
			end
			event(player, "fits", list)
		end
	elseif action == "Bench" then
		self:_bench(player)
	elseif action == "Prize" then
		self:_prize(player)
	end
end

function RealityService:_action(player: Player, action: any, arg: any)
	local s = stateOf(player)
	if os.clock() - s.lastAction < 0.08 then
		return
	end
	s.lastAction = os.clock()
	if action == "fit" then
		self:_runway(player, arg)
	elseif action == "runwayPose" then
		self:_runwayPose(player)
	elseif action == "runwayDone" and s.activity == "Runway" then
		self:_finish(player)
	elseif action == "rep" then
		self:_rep(player)
	elseif action == "cancel" then
		s.pending = nil
	elseif action == "stopSkate" then
		self:_skate(player, false)
	elseif action == "push" then
		self:_push(player)
	end
end

local function inside(part: BasePart, position: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

function RealityService:Start()
	local premium = workspace:WaitForChild("Larp"):WaitForChild("Map"):FindFirstChild("Premium")
	local plaza = premium and premium:FindFirstChild("Plaza")
	self.world = plaza and plaza:FindFirstChild("Reality")
	if not self.world then
		warn("[Larp] No LARP to Reality world (Map.Premium.Plaza.Reality); build it with LarpBuild.Reality")
		return
	end
	self.boards = {}
	for _, venue in { "Runway", "Gym", "Hall" } do
		local board = self:_marker(venue, "Board")
		local label = board and board:FindFirstChild("Label") and board.Label:FindFirstChildOfClass("TextLabel")
		self.boards[venue] = label and label.Text
	end
	local volume = self.world:FindFirstChild("Volume") :: BasePart
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name == "RealityPrompt" and prompt:IsDescendantOf(self.world) then
			self:_prompt(player, prompt)
		end
	end)
	Net.get("RealityAction").OnServerEvent:Connect(function(player, action, arg)
		self:_action(player, action, arg)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_finish(player)
		state[player] = nil
	end)
	-- leaving the world (the EXIT door, a reset) puts everything back; stuck steps time out
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local s = stateOf(player)
				local _, root = characterOf(player)
				local isIn = root ~= nil and volume ~= nil and inside(volume, root.Position)
				if s.inside and not isIn then
					self:_reset(player)
				end
				s.inside = isIn
				local limit = if s.activity == "Bench" then Reality.bench.timeout elseif s.activity == "Runway" then Reality.runway.timeout else Reality.prize.seconds + 6
				if s.activity and os.clock() - (s.since or 0) > limit then
					self:_finish(player)
				end
			end
		end
	end)
end

return RealityService
