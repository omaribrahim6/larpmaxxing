-- The lounge quiz on the client (Config.Quiz, QuizService):
--   * the big screen on each lounge's back wall, which everyone in the room reads — the
--     question, the four answer tiles, the countdown and the final scoreboard;
--   * your own answer pad, four big buttons that only appear while you're in a round, so you
--     pick from your screen the way you would in Kahoot (1-4 on a keyboard, tap on a phone);
--   * the START A QUIZ button, bound only while you're sitting in a lounge.
--
-- Everything here is drawn locally: the server sends one small packet per phase change and the
-- clock runs off `endsAt`, so nothing is replicated per frame and no GUI lives in the place.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Config = require(Larp.Config.Chatrooms)
local Quiz = require(Larp.Config.Quiz)
local Net = require(Larp.Shared.Net)

local QuizClient = {}

local SCREEN_TAG = "LarpQuizScreen"
local ACTION = "LarpQuizStart"
local INK = Color3.fromRGB(246, 244, 255)
local DIM = Color3.fromRGB(150, 146, 170)
local BACK = Color3.fromRGB(14, 13, 20)

local player = Players.LocalPlayer
-- a phone has no E to press, so the idle card names the touch button instead
local TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local rooms = {}
for _, room in Config.rooms do
	rooms[room.id] = room
end

local states: { [string]: any } = {} -- room id -> the last packet for that room
local screens: { [Instance]: any } = {} -- screen part -> its drawn bits
local hud = nil

local function corner(instance: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = instance
	return c
end

local function text(parent: Instance, size: UDim2, pos: UDim2, str: string, px: number, font: Enum.Font, color: Color3?)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = pos
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextSize = px
	label.TextColor3 = color or INK
	label.Text = str
	label.TextWrapped = true
	label.Parent = parent
	return label
end

-- The four answer shapes, drawn from frames so they render the same everywhere.
local function shape(parent: Instance, kind: string, color: Color3, px: number)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromOffset(px, px)
	holder.BackgroundTransparency = 1
	holder.Parent = parent
	local body = Instance.new("Frame")
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	body.BackgroundColor3 = color
	body.BorderSizePixel = 0
	body.Parent = holder
	if kind == "Circle" then
		body.Size = UDim2.fromOffset(px, px)
		corner(body, px)
	elseif kind == "Square" then
		body.Size = UDim2.fromOffset(px * 0.88, px * 0.88)
		corner(body, 4)
	elseif kind == "Diamond" then
		body.Size = UDim2.fromOffset(px * 0.72, px * 0.72)
		body.Rotation = 45
		corner(body, 4)
	else -- Ring
		body.Size = UDim2.fromOffset(px, px)
		corner(body, px)
		local hole = Instance.new("Frame")
		hole.AnchorPoint = Vector2.new(0.5, 0.5)
		hole.Position = UDim2.fromScale(0.5, 0.5)
		hole.Size = UDim2.fromOffset(px * 0.46, px * 0.46)
		hole.BackgroundColor3 = BACK
		hole.BorderSizePixel = 0
		hole.Parent = body
		corner(hole, px)
	end
	return holder
end

-- A flag, drawn from frames. Equal `bands` down ("v") or across ("h"), a `disc` on a field,
-- or an offset Nordic `cross` -- enough shapes for the flags worth asking about, and none of
-- it can land as a blank box the way a flag emoji does on half the devices out there.
local function drawFlag(parent: Instance, spec, size: UDim2, pos: UDim2)
	local holder = Instance.new("Frame")
	holder.Name = "Flag"
	holder.Size = size
	holder.Position = pos
	holder.BackgroundColor3 = spec.field or Color3.fromRGB(245, 245, 245)
	holder.BorderSizePixel = 0
	holder.ClipsDescendants = true
	holder.Parent = parent
	Instance.new("UIStroke", holder).Color = Color3.fromRGB(16, 15, 22)
	if spec.bands then
		for i, color in spec.colors do
			local band = Instance.new("Frame")
			band.BackgroundColor3 = color
			band.BorderSizePixel = 0
			if spec.bands == "v" then
				band.Size = UDim2.fromScale(1 / #spec.colors, 1)
				band.Position = UDim2.fromScale((i - 1) / #spec.colors, 0)
			else
				band.Size = UDim2.fromScale(1, 1 / #spec.colors)
				band.Position = UDim2.fromScale(0, (i - 1) / #spec.colors)
			end
			band.Parent = holder
		end
	elseif spec.disc then
		local disc = Instance.new("Frame")
		disc.AnchorPoint = Vector2.new(0.5, 0.5)
		disc.Position = UDim2.fromScale(0.5, 0.5)
		disc.Size = UDim2.fromScale(0.42, 0.62)
		disc.BackgroundColor3 = spec.disc
		disc.BorderSizePixel = 0
		disc.Parent = holder
		Instance.new("UICorner", disc).CornerRadius = UDim.new(1, 0)
	elseif spec.cross then
		local arm = Instance.new("Frame")
		arm.Size = UDim2.fromScale(1, 0.2)
		arm.Position = UDim2.fromScale(0, 0.4)
		arm.BackgroundColor3 = spec.cross
		arm.BorderSizePixel = 0
		arm.Parent = holder
		local up = Instance.new("Frame")
		up.Size = UDim2.fromScale(0.13, 1)
		up.Position = UDim2.fromScale(0.28, 0) -- offset toward the hoist, as a Nordic cross is
		up.BackgroundColor3 = spec.cross
		up.BorderSizePixel = 0
		up.Parent = holder
	end
	return holder
end

--------------------------------------------------------------------------------------------
-- the wall screen
--------------------------------------------------------------------------------------------

local function buildScreen(part: BasePart)
	local room = rooms[part:GetAttribute("Room") or ""]
	if not room then
		return nil
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LarpQuizSurface"
	gui.Face = Enum.NormalId.Front
	-- The panel is about three times as wide as it is tall, so everything below is laid out
	-- for that shape — the four answers run in one row across the bottom, not a 2x2 block that
	-- squashes them (owner 2026-09-14: "the screens in the lounges are kinda stretched").
	gui.PixelsPerStud = 32
	gui.LightInfluence = 0
	gui.Adornee = part
	gui.Parent = part

	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = BACK
	root.BorderSizePixel = 0
	root.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 26), UDim.new(0, 26)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 20), UDim.new(0, 20)
	pad.Parent = root

	local head = text(root, UDim2.new(1, -240, 0, 40), UDim2.fromOffset(0, 0), room.name, 36, Enum.Font.LuckiestGuy, room.color)
	head.TextXAlignment = Enum.TextXAlignment.Left
	local clock = text(root, UDim2.new(0, 230, 0, 40), UDim2.new(1, -230, 0, 0), "", 36, Enum.Font.GothamBold, INK)
	clock.TextXAlignment = Enum.TextXAlignment.Right

	local body = text(root, UDim2.new(1, 0, 0, 280), UDim2.fromOffset(0, 68), "", 44, Enum.Font.GothamBold, INK)
	body.TextYAlignment = Enum.TextYAlignment.Top

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 8)
	bar.Position = UDim2.new(0, 0, 0, 50)
	bar.BackgroundColor3 = room.color
	bar.BorderSizePixel = 0
	bar.Parent = root
	corner(bar, 4)

	-- the scoreboard, shown instead of the grid
	local board = Instance.new("Frame")
	board.Size = UDim2.new(1, 0, 1, -182)
	board.Position = UDim2.fromOffset(0, 182)
	board.BackgroundTransparency = 1
	board.Visible = false
	board.Parent = root
	local rows = Instance.new("UIListLayout")
	rows.Padding = UDim.new(0, 8)
	rows.Parent = board

	return { part = part, room = room, gui = gui, root = root, head = head, clock = clock, body = body, bar = bar, board = board, flag = nil }
end

local function boardRow(parent: Instance, place: number, name: string, score: number, color: Color3)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 44)
	row.BackgroundColor3 = if place == 1 then color else Color3.fromRGB(34, 32, 46)
	row.BorderSizePixel = 0
	row.LayoutOrder = place
	row.Parent = parent
	corner(row, 8)
	local ink = if place == 1 then Color3.fromRGB(20, 18, 28) else INK
	local who = text(row, UDim2.new(1, -140, 1, 0), UDim2.fromOffset(16, 0), ("%d.  %s"):format(place, name), 26, Enum.Font.GothamBold, ink)
	who.TextXAlignment = Enum.TextXAlignment.Left
	local pts = text(row, UDim2.new(0, 120, 1, 0), UDim2.new(1, -136, 0, 0), tostring(score), 26, Enum.Font.GothamBold, ink)
	pts.TextXAlignment = Enum.TextXAlignment.Right
	return row
end

local function paintScreen(s, state)
	local phase = state and state.phase or "idle"
	s.board.Visible = phase == "results" or phase == "lobby"
	s.bar.Visible = phase == "question"

	if phase == "idle" then
		if s.flag then
			s.flag:Destroy()
			s.flag = nil
		end
		s.body.Text = if TOUCH then Quiz.words.idleTouch else Quiz.words.idle
		s.clock.Text = ""
		s.board:ClearAllChildren()
		local rows = Instance.new("UIListLayout")
		rows.Padding = UDim.new(0, 8)
		rows.Parent = s.board
		return
	end

	if phase == "lobby" then
		if s.flag then
			s.flag:Destroy()
			s.flag = nil
		end
		local ready = state.board and #state.board or 0
		s.body.Text = ("%s  —  %d/%d %s"):format(Quiz.words.waiting, ready, Quiz.minPlayers, Quiz.words.ready)
		s.board:ClearAllChildren()
		local rows = Instance.new("UIListLayout")
		rows.Padding = UDim.new(0, 8)
		rows.Parent = s.board
		for place, row in state.board or {} do
			boardRow(s.board, place, row.name, row.score, s.room.color)
		end
		return
	end

	if phase == "question" or phase == "reveal" then
		-- The answers are on your own pad, so the wall spends all of its room on the question
		-- and, when there is one, a big flag (owner 2026-09-15). At the reveal the question
		-- line becomes the answer, in the room's colour, so nothing has to move.
		if s.flag then
			s.flag:Destroy()
			s.flag = nil
		end
		if state.flag then
			s.flag = drawFlag(s.root, state.flag, UDim2.fromOffset(460, 230), UDim2.new(0.5, -230, 0, 132))
		end
		local revealing = phase == "reveal" and state.correct ~= nil
		if revealing then
			s.body.Text = string.upper(state.answers and state.answers[state.correct] or "")
			s.body.TextColor3 = s.room.color
			s.body.TextSize = if state.flag then 46 else 62
		else
			s.body.Text = ("Q%d/%d   %s"):format(state.index or 1, state.count or Quiz.questions, state.question or "")
			s.body.TextColor3 = INK
			s.body.TextSize = if state.flag then 32 else 44
		end
		s.body.Size = if state.flag then UDim2.new(1, 0, 0, 54) else UDim2.new(1, 0, 0, 280)
		return
	end

	-- results
	s.body.Text = Quiz.words.results
	s.clock.Text = ""
	s.board:ClearAllChildren()
	local rows = Instance.new("UIListLayout")
	rows.Padding = UDim.new(0, 8)
	rows.Parent = s.board
	for place, row in state.board or {} do
		if place <= 5 then
			boardRow(s.board, place, row.name, row.score, s.room.color)
		end
	end
end

--------------------------------------------------------------------------------------------
-- your own answer pad
--------------------------------------------------------------------------------------------

local function buildHud()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LarpQuiz"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- Global lets children escape a clip
	gui.DisplayOrder = 8
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -14)
	panel.Size = UDim2.fromOffset(560, 280)
	panel.BackgroundColor3 = Color3.fromRGB(20, 19, 28)
	panel.BackgroundTransparency = 0.12
	panel.Parent = gui
	corner(panel, 16)
	-- The pad is drawn at 560 wide whatever the screen, which swamped a phone and ran under the
	-- HUD at the bottom of it (owner 2026-09-15: "too big on mobile and goes below other UI
	-- items, simply make it smaller"). One UIScale shrinks the whole thing -- it is anchored at
	-- its bottom middle, so it keeps sitting there -- to about half size on a phone, a little
	-- under full size on a tablet, and never wider than the screen it is on.
	local fit = Instance.new("UIScale")
	fit.Parent = panel
	local function refit()
		local camera = workspace.CurrentCamera
		local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local short = math.min(size.X, size.Y)
		local s = math.min(1, (size.X - 24) / 560)
		if TOUCH or short < 540 then
			s = math.min(s, math.clamp(short / 900, 0.5, 0.8))
		end
		fit.Scale = s
	end
	local watching = nil
	local function watch()
		if watching then
			watching:Disconnect()
			watching = nil
		end
		local camera = workspace.CurrentCamera
		if camera then
			watching = camera:GetPropertyChangedSignal("ViewportSize"):Connect(refit)
		end
		refit()
	end
	watch()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watch)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(80, 76, 104)
	stroke.Thickness = 2
	stroke.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 12), UDim.new(0, 12)
	pad.Parent = panel

	local title = text(panel, UDim2.new(1, -110, 0, 26), UDim2.fromOffset(0, 0), "", 20, Enum.Font.GothamBold, INK)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local clock = text(panel, UDim2.new(0, 104, 0, 26), UDim2.new(1, -104, 0, 0), "", 20, Enum.Font.GothamBold, INK)
	clock.TextXAlignment = Enum.TextXAlignment.Right
	local note = text(panel, UDim2.new(1, 0, 0, 40), UDim2.fromOffset(0, 28), "", 18, Enum.Font.GothamMedium, DIM)
	note.TextYAlignment = Enum.TextYAlignment.Top

	local grid = Instance.new("Frame")
	grid.Size = UDim2.new(1, 0, 1, -76)
	grid.Position = UDim2.fromOffset(0, 76)
	grid.BackgroundTransparency = 1
	grid.Parent = panel
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.5, -6, 0.5, -6)
	layout.CellPadding = UDim2.fromOffset(12, 12)
	layout.Parent = grid

	local buttons = {}
	for i, choice in Quiz.choices do
		local button = Instance.new("TextButton")
		button.BackgroundColor3 = choice.color
		button.BorderSizePixel = 0
		button.Text = ""
		button.AutoButtonColor = true
		button.LayoutOrder = i
		button.Parent = grid
		corner(button, 12)
		local mark = shape(button, choice.shape, Color3.fromRGB(255, 255, 255), 26)
		mark.Position = UDim2.fromOffset(10, 10)
		local answer = text(button, UDim2.new(1, -50, 1, -12), UDim2.fromOffset(44, 6), "", 17, Enum.Font.GothamBold, Color3.fromRGB(255, 255, 255))
		answer.TextXAlignment = Enum.TextXAlignment.Left
		button.Activated:Connect(function()
			Net.get("QuizAnswer"):FireServer(i)
		end)
		buttons[i] = { button = button, answer = answer, color = choice.color }
	end

	return { gui = gui, panel = panel, title = title, clock = clock, note = note, grid = grid, buttons = buttons }
end

-- Which room's round the local player is in, if any.
local function myState()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not seat then
		return nil, nil
	end
	local model = seat:FindFirstAncestorOfClass("Model")
	while model do
		if rooms[model.Name] and model.Parent and model.Parent.Name == "Chatrooms" then
			return states[model.Name], rooms[model.Name]
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil, nil
end

local function mine(state)
	for _, row in state and state.board or {} do
		if row.userId == player.UserId then
			return row
		end
	end
	return nil
end

-- Have we locked this question in? The packet carries who has, never what they picked.
local function answered(state): boolean
	for _, id in state and state.answered or {} do
		if id == player.UserId then
			return true
		end
	end
	return false
end

local function paintHud(state, room)
	local phase = state and state.phase or nil
	if not room or not phase or phase == "idle" then
		hud.gui.Enabled = false
		return
	end
	hud.gui.Enabled = true
	local row = mine(state)
	hud.title.Text = room.name
	hud.grid.Visible = phase == "question" or phase == "reveal"

	if phase == "lobby" then
		local ready = state.board and #state.board or 0
		hud.note.Text = ("%s — %d/%d ready"):format(Quiz.words.waiting, ready, Quiz.minPlayers)
		hud.panel.Size = UDim2.fromOffset(560, 104)
		return
	end
	if phase == "results" then
		local place = 0
		for i, r in state.board or {} do
			if r.userId == player.UserId then
				place = i
			end
		end
		-- coming first with nothing right isn't a win: the server pays it as a play, and the
		-- card has to say the same thing
		local score = row and row.score or 0
		if place == 1 and score > 0 then
			hud.note.Text = Quiz.words.winner .. (" — %d points. You actually larp."):format(score)
		elseif score > 0 then
			hud.note.Text = ("%d points — you came %d of %d."):format(score, place, #(state.board or {}))
		else
			hud.note.Text = Quiz.words.wrong .. " — you got nothing right all round."
		end
		hud.panel.Size = UDim2.fromOffset(560, 104)
		return
	end

	hud.panel.Size = UDim2.fromOffset(560, 280)
	local picked = nil
	if state.picks then
		picked = state.picks[tostring(player.UserId)]
		if picked == 0 then
			picked = nil
		end
	end
	for i, b in hud.buttons do
		local answer = state.answers and state.answers[i]
		b.button.Visible = answer ~= nil
		b.answer.Text = answer or ""
		local right = state.correct and i == state.correct
		b.button.BackgroundColor3 = b.color
		b.button.BackgroundTransparency = if state.correct and not right then 0.72 else 0
		b.button.Active = phase == "question" and not answered(state)
	end
	if phase == "reveal" then
		if picked and picked == state.correct then
			hud.note.Text = Quiz.words.correct .. ("  —  %d points"):format(row and row.score or 0)
			hud.note.TextColor3 = Color3.fromRGB(120, 230, 140)
		elseif picked then
			hud.note.Text = Quiz.words.wrong
			hud.note.TextColor3 = Color3.fromRGB(240, 120, 130)
		else
			hud.note.Text = Quiz.words.tooLate
			hud.note.TextColor3 = Color3.fromRGB(240, 190, 120)
		end
	else
		hud.note.TextColor3 = DIM
		hud.note.Text = if answered(state) then Quiz.words.answered else "Pick one. Faster is worth more."
	end
end

--------------------------------------------------------------------------------------------

function QuizClient.start()
	hud = buildHud()

	local function add(part: Instance)
		if screens[part] then
			return
		end
		local s = buildScreen(part)
		if s then
			screens[part] = s
			paintScreen(s, states[s.room.id])
		end
	end
	for _, part in CollectionService:GetTagged(SCREEN_TAG) do
		add(part)
	end
	CollectionService:GetInstanceAddedSignal(SCREEN_TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(SCREEN_TAG):Connect(function(part)
		screens[part] = nil
	end)

	Net.get("QuizState").OnClientEvent:Connect(function(state)
		if type(state) ~= "table" or not state.room then
			return
		end
		states[state.room] = if state.phase == "idle" then nil else state
		for _, s in screens do
			if s.room.id == state.room then
				paintScreen(s, states[state.room])
			end
		end
		local ours, room = myState()
		paintHud(ours, room)
	end)

	-- the start button, only while you're sitting in a lounge with no round running
	local bound = false
	task.spawn(function()
		while true do
			task.wait(0.25)
			local state, room = myState()
			local want = room ~= nil and (state == nil or state.phase == "lobby")
			if want ~= bound then
				bound = want
				if want then
					ContextActionService:BindAction(ACTION, function(_, input)
						if input == Enum.UserInputState.Begin then
							Net.get("QuizJoin"):FireServer()
						end
						return Enum.ContextActionResult.Sink
					end, true, Enum.KeyCode.E, Enum.KeyCode.ButtonY)
					ContextActionService:SetTitle(ACTION, Quiz.words.play)
				else
					ContextActionService:UnbindAction(ACTION)
				end
			end
			paintHud(state, room)
		end
	end)

	-- number keys answer, the way they do in the real thing
	for i, choice in Quiz.choices do
		ContextActionService:BindAction("LarpQuizKey" .. i, function(_, input)
			if input == Enum.UserInputState.Begin then
				Net.get("QuizAnswer"):FireServer(i)
			end
			return Enum.ContextActionResult.Pass
		end, false, choice.key)
	end

	-- the clocks: one loop, off the server time each packet carried
	RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		for _, s in screens do
			local state = states[s.room.id]
			if state and state.endsAt then
				local left = math.max(0, state.endsAt - now)
				s.clock.Text = if state.phase == "reveal" or state.phase == "results" then "" else ("%ds"):format(math.ceil(left))
				if state.phase == "question" then
					s.bar.Size = UDim2.new(math.clamp(left / Quiz.answerSeconds, 0, 1), 0, 0, 8)
				end
			else
				s.clock.Text = ""
			end
		end
		if hud.gui.Enabled then
			local state = myState()
			if state and state.endsAt then
				local left = math.max(0, state.endsAt - now)
				hud.clock.Text = if state.phase == "question" or state.phase == "lobby" then ("%ds"):format(math.ceil(left)) else ""
			end
		end
	end)
end

return QuizClient
