-- Overhead nameplates: rank title (coloured by rank), name + wins, and the EXPOSED tag.
-- Works for players and NPC models alike.
local Players = game:GetService("Players")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Catalog = require(Larp.Shared.Catalog)
local Text = require(Larp.Config.Text)

local NameplateService = {}

local plates: { [Model]: { gui: BillboardGui, rank: TextLabel, name: TextLabel, tag: TextLabel } } = {}
local exposedUntil: { [Player]: number } = {}

local function now()
	return workspace:GetServerTimeNow()
end

local function label(parent, name, font, y, height)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Size = UDim2.fromScale(1, height)
	l.Position = UDim2.fromScale(0, y)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(16, 20, 16)
	stroke.Parent = l
	l.Parent = parent
	return l
end

local function build(model: Model)
	local head = model:FindFirstChild("Head")
	if not head then
		return nil
	end
	local existing = plates[model]
	if existing and existing.gui.Parent then
		return existing
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "LarpNameplate"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(230, 84)
	gui.StudsOffset = Vector3.new(0, 2.8, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	local plate = {
		gui = gui,
		rank = label(gui, "Rank", Enum.Font.FredokaOne, 0, 0.42),
		name = label(gui, "Name", Enum.Font.GothamBold, 0.42, 0.24),
		tag = label(gui, "Tag", Enum.Font.LuckiestGuy, 0.68, 0.32),
	}
	plate.tag.TextColor3 = Color3.fromRGB(255, 94, 82)
	plate.tag.Text = Text.Stamps.Exposed
	plate.tag.Visible = false
	gui.Parent = head
	plates[model] = plate
	model.Destroying:Connect(function()
		plates[model] = nil
	end)
	return plate
end

-- Line 3 shows EXPOSED while it lasts, otherwise the Touch Grass count once there is one.
local function render(plate, rankIndex: number, name: string, wins: number?, exposed: boolean, rebirths: number?)
	local rank = Catalog.ranks[rankIndex] or Catalog.ranks[1]
	plate.rank.Text = rank.name
	plate.rank.TextColor3 = rank.color or Color3.new(1, 1, 1)
	plate.name.Text = if wins then ("%s   W %d"):format(name, wins) else name
	plate.tag.Visible = exposed or (rebirths or 0) > 0
	plate.tag.Text = if exposed then Text.Stamps.Exposed else Text.TouchGrass.plate:format(rebirths or 0)
	plate.tag.TextColor3 = if exposed then Color3.fromRGB(255, 94, 82) else Color3.fromRGB(122, 214, 112)
end

function NameplateService:Init(services)
	self.Data = services.DataService
	self.Stats = services.StatService
end

function NameplateService:Refresh(player: Player)
	local character = player.Character
	if not character or not self.Data:IsLoaded(player) then
		return
	end
	local plate = build(character)
	if plate then
		local exposed = (exposedUntil[player] or 0) > now()
		render(plate, self.Stats:GetRankIndex(player), player.DisplayName, self.Stats:GetWins(player), exposed, self.Stats:GetRebirths(player))
	end
end

function NameplateService:Start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			self:Refresh(player)
		end)
		if player.Character then
			task.spawn(self.Refresh, self, player)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		exposedUntil[player] = nil
	end)
	self.Data.ProfileLoaded:Connect(function(player)
		self:Refresh(player)
	end)
	self.Stats.Changed:Connect(function(player)
		self:Refresh(player)
	end)
end

-- Shows the EXPOSED tag on a player for `seconds`.
function NameplateService:SetExposed(player: Player, seconds: number)
	local untilTime = now() + seconds
	exposedUntil[player] = untilTime
	self:Refresh(player)
	task.delay(seconds + 0.1, function()
		if exposedUntil[player] == untilTime then
			exposedUntil[player] = nil
			self:Refresh(player)
		end
	end)
end

-- Nameplate for an NPC model. Returns a function to update it later.
function NameplateService:AttachNpc(model: Model, name: string, rankIndex: number)
	local plate = build(model)
	if plate then
		render(plate, rankIndex, name, nil, false)
	end
	return function(newRankIndex: number, exposed: boolean?)
		local current = build(model)
		if current then
			render(current, newRankIndex, name, nil, exposed == true)
		end
	end
end

return NameplateService
