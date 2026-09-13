-- The Plaza's leaderboard wall: all-time top lists (OrderedDataStores) for total points,
-- wins and biggest upset, plus a live board of the players in this server. The boards are
-- the parts LarpBuild.LeaderboardWall builds (each part's Leaderboard attribute names its
-- entry in Config.Leaderboards); this service draws a SurfaceGui on each and keeps it
-- current. Without DataStore access (Studio) the all-time boards show this server instead.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Config = require(Larp.Config.Leaderboards)
local Tuning = require(Larp.Config.Tuning)
local Catalog = require(Larp.Shared.Catalog)
local Format = require(Larp.Shared.Format)

local LeaderboardService = {}

local T = Tuning.Leaderboard
local PPS = 40 -- SurfaceGui pixels per stud
local INK = Color3.fromRGB(14, 12, 20)
local MEDALS = { Color3.fromRGB(255, 198, 64), Color3.fromRGB(206, 214, 226), Color3.fromRGB(214, 142, 88) }

local stores: { [string]: OrderedDataStore } = {} -- board id -> its all-time store
local names: { [number]: string } = {} -- userId -> username
local written: { [Player]: { [string]: number } } = {} -- what we last stored for a player
local views = {} -- board id -> { sub = TextLabel, rows = { { face, name, value } } }
local offline = false -- the last all-time read failed (no DataStore access)

function LeaderboardService:Init(services)
	self.Stats = services.StatService
	self.Data = services.DataService
end

-- A profile's number on a board. Upsets are stored as whole tenths of a percent, because
-- OrderedDataStores only keep integers.
local function valueFrom(board, data): number
	if board.value == "wins" then
		return data.wins or 0
	elseif board.value == "upset" then
		return math.floor((data.biggestUpsetPct or 0) * T.upsetScale + 0.5)
	elseif board.value == "rebirths" then
		return data.rebirths or 0
	end
	return Catalog.total(data.stats)
end
LeaderboardService.valueFrom = valueFrom

local function show(board, value: number): string
	if board.value == "upset" then
		return ("%.1f%%"):format(value / T.upsetScale)
	end
	return Format.short(value)
end

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	local ok, name = true, player and player.Name
	if not name then
		ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	end
	names[userId] = if ok and type(name) == "string" then name else "Player " .. userId
	return names[userId]
end

local function make(class: string, parent: Instance, props: { [string]: any }): any
	local inst = Instance.new(class)
	for key, value in props do
		(inst :: any)[key] = value
	end
	inst.Parent = parent
	return inst
end

local function label(parent: Instance, props: { [string]: any }, stroke: number?): TextLabel
	props.BackgroundTransparency = 1
	props.TextScaled = true
	local l = make("TextLabel", parent, props)
	if stroke then
		make("UIStroke", l, { Color = INK, Thickness = stroke })
	end
	return l
end

-- Draws a board's SurfaceGui once: its title, a subtitle and a row per place.
local function build(part: BasePart, board)
	local old = part:FindFirstChild("Board")
	if old then
		old:Destroy()
	end
	local gui = make("SurfaceGui", part, {
		Name = "Board",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = PPS,
		LightInfluence = 0,
		MaxDistance = 300,
	})
	local height = part.Size.Y * PPS
	local bg = make("Frame", gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(56, 47, 82), BorderSizePixel = 0 })
	make("UIGradient", bg, { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(110, 110, 130)) })
	make("UIStroke", bg, { Color = board.color, Thickness = 10, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	label(bg, { Name = "Title", Text = board.title, Font = Enum.Font.LuckiestGuy, TextColor3 = board.color, Position = UDim2.fromOffset(24, 16), Size = UDim2.new(1, -48, 0, 62) }, 4)
	local sub = label(bg, { Name = "Sub", Text = "", Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(196, 188, 214), Position = UDim2.fromOffset(24, 82), Size = UDim2.new(1, -48, 0, 22) })
	local count = if board.store then T.top else T.serverTop
	local top, bottom = 116, height - 18
	local rowHeight = (bottom - top) / count
	local rows = {}
	for i = 1, count do
		local row = make("Frame", bg, {
			Position = UDim2.fromOffset(16, top + (i - 1) * rowHeight + 2),
			Size = UDim2.new(1, -32, 0, rowHeight - 4),
			BackgroundColor3 = if i % 2 == 0 then Color3.fromRGB(46, 40, 66) else Color3.fromRGB(36, 31, 54),
			BorderSizePixel = 0,
		})
		make("UICorner", row, { CornerRadius = UDim.new(0, 10) })
		local badge = rowHeight - 14
		local medal = make("Frame", row, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(badge, badge), BackgroundColor3 = MEDALS[i] or Color3.fromRGB(70, 62, 98), BorderSizePixel = 0 })
		make("UICorner", medal, { CornerRadius = UDim.new(1, 0) })
		label(medal, { Text = tostring(i), Font = Enum.Font.LuckiestGuy, TextColor3 = if MEDALS[i] then INK else Color3.new(1, 1, 1), Position = UDim2.fromScale(0.15, 0.15), Size = UDim2.fromScale(0.7, 0.7) })
		local face = make("ImageLabel", row, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, badge + 16, 0.5, 0), Size = UDim2.fromOffset(badge, badge), BackgroundColor3 = Color3.fromRGB(58, 52, 80), BorderSizePixel = 0, Image = "" })
		make("UICorner", face, { CornerRadius = UDim.new(1, 0) })
		local left = badge * 2 + 26
		local name = label(row, { Name = "Name", Text = "—", Font = Enum.Font.FredokaOne, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, left, 0, 6), Size = UDim2.new(0.64, -left, 1, -12) }, 2)
		local value = label(row, { Name = "Value", Text = "", Font = Enum.Font.LuckiestGuy, TextColor3 = board.color, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.64, 0, 0, 6), Size = UDim2.new(0.36, -14, 1, -12) }, 2)
		rows[i] = { face = face, name = name, value = value }
	end
	views[board.id] = { sub = sub, rows = rows }
end

local function render(board, entries, subtitle: string)
	local view = views[board.id]
	if not view then
		return
	end
	view.sub.Text = subtitle
	for i, row in view.rows do
		local e = entries[i]
		row.name.Text = if e then e.name else "—"
		row.value.Text = if e then show(board, e.value) else ""
		row.face.Image = if e and e.userId > 0 then ("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48"):format(e.userId) else ""
	end
end

-- The players in this server, best first, for a board.
function LeaderboardService:_serverEntries(board, count: number)
	local list = {}
	for _, player in Players:GetPlayers() do
		local data = self.Data:Get(player)
		if data then
			table.insert(list, { userId = player.UserId, name = player.Name, value = valueFrom(board, data) })
		end
	end
	table.sort(list, function(a, b)
		return a.value > b.value
	end)
	while #list > count do
		table.remove(list)
	end
	return list
end

-- Stores a profile's numbers on the all-time boards (only the ones that changed).
local function store(userId: number, data, cache: { [string]: number })
	for _, board in Config.boards do
		local ods = stores[board.id]
		local value = ods and valueFrom(board, data)
		if value and value > 0 and cache[board.id] ~= value then
			if pcall(ods.SetAsync, ods, "p_" .. userId, value) then
				cache[board.id] = value
			end
		end
	end
end

-- Rereads one all-time board; without DataStore access it shows this server instead.
function LeaderboardService:_refresh(board)
	local ods = stores[board.id]
	local ok, page = pcall(function()
		return ods:GetSortedAsync(false, T.top):GetCurrentPage()
	end)
	if not ok then
		offline = true
		render(board, self:_serverEntries(board, T.top), Config.offline)
		return
	end
	offline = false
	local entries = {}
	for _, e in page do
		local userId = tonumber(string.match(e.key, "(-?%d+)$"))
		if userId then
			table.insert(entries, { userId = userId, name = nameOf(userId), value = e.value })
		end
	end
	render(board, entries, Config.allTime)
end

function LeaderboardService:Start()
	local byId = {}
	for _, board in Config.boards do
		byId[board.id] = board
		if board.store then
			local ok, ods = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, board.store)
			if ok then
				stores[board.id] = ods
			end
		end
	end
	local found = 0
	for _, part in workspace.Larp:GetDescendants() do
		local board = part:IsA("BasePart") and byId[part:GetAttribute("Leaderboard") or ""]
		if board then
			build(part, board)
			found += 1
		end
	end
	if found == 0 then
		warn("[Larp] No leaderboard boards in Workspace.Larp (build them with LarpBuild.LeaderboardWall)")
		return
	end

	-- a leaving player's final numbers (the profile is already released: use its data)
	self.Data.ProfileReleasing:Connect(function(player, data)
		local cache = written[player]
		written[player] = nil
		if cache then
			task.spawn(store, player.UserId, data, cache)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		names[player.UserId] = player.Name
	end)

	-- this server's board (and the all-time boards while there's no DataStore) stay live
	task.spawn(function()
		while true do
			for _, board in Config.boards do
				if not board.store then
					render(board, self:_serverEntries(board, T.serverTop), Config.thisServer)
				elseif offline then
					render(board, self:_serverEntries(board, T.top), Config.offline)
				end
			end
			task.wait(T.serverSeconds)
		end
	end)
	-- every few minutes: store everyone's numbers, then reread the all-time lists
	task.spawn(function()
		task.wait(3)
		while true do
			for _, player in Players:GetPlayers() do
				local data = self.Data:Get(player)
				if data and self.Data:IsPersistent(player) then
					written[player] = written[player] or {}
					store(player.UserId, data, written[player])
				end
			end
			for _, board in Config.boards do
				if board.store then
					self:_refresh(board)
				end
			end
			task.wait(T.refreshSeconds)
		end
	end)
end

return LeaderboardService
