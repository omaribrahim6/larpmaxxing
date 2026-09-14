-- Rank cosmetics (spec "Rank cosmetics", Config.Cosmetics): each rank-up adds an avatar item,
-- and a player wears every item up to the best rank they've reached, so Touch Grass keeps
-- them (StatService tracks bestRank). Touch Grass milestones (`grass` entries) add items by
-- rebirths instead. Settings > Show cosmetics takes a player's items off.
-- The items are built from parts (Lib.CosmeticModels) and welded on at each spawn.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Catalog = require(Larp.Shared.Catalog)
local Cosmetics = require(Larp.Config.Cosmetics)
local Models = require(script.Parent.Parent.Lib.CosmeticModels)

local CosmeticService = {}
local PREFIX = "LarpCosmetic_"
local UPRIGHT_TAG = "LarpUprightCosmetic" -- LarpClient.CosmeticFx keeps these standing

local rankIndex: { [string]: number } = {}
for i, rank in Catalog.ranks do
	rankIndex[rank.name] = i
end

-- The ids earned by a player whose best rank is `bestRank` and who has touched grass
-- `rebirths` times (the milestone items), in Config.Cosmetics order.
function CosmeticService.earned(bestRank: number, rebirths: number?): { string }
	local ids = {}
	for _, c in Cosmetics do
		local got = if c.grass then (rebirths or 0) >= c.grass else (rankIndex[c.rank] or math.huge) <= bestRank
		if got then
			table.insert(ids, c.id)
		end
	end
	return ids
end

function CosmeticService:Init(services)
	self.Data = services.DataService
	self.Stats = services.StatService
	self.Settings = services.SettingsService
end

-- A body part's attachment (not one inside an accessory the avatar already wears).
local function bodyAttachment(character: Model, name: string): Attachment?
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") then
			local att = part:FindFirstChild(name)
			if att and att:IsA("Attachment") then
				return att
			end
		end
	end
	return nil
end

function CosmeticService:_wear(character: Model, c)
	local att = bodyAttachment(character, c.attach)
	if not att then
		return
	end
	local part = att.Parent :: BasePart
	local item = Models.build(c.id, part.Size, att.Position)
	item.Name = PREFIX .. c.id
	if item:IsA("Model") and c.upright then
		-- not welded: every client stands it at the attachment each frame (LarpClient.CosmeticFx)
		local handle = item:FindFirstChild("Handle") :: BasePart
		handle.Anchored = true
		handle.CFrame = CFrame.new(att.WorldPosition)
		local anchor = Instance.new("ObjectValue")
		anchor.Name = "Anchor"
		anchor.Value = att
		anchor.Parent = item
		CollectionService:AddTag(item, UPRIGHT_TAG)
		item.Parent = character
	elseif item:IsA("Model") then
		-- welded in the body part's axes, at the attachment
		local handle = item:FindFirstChild("Handle") :: BasePart
		local weld = Instance.new("Weld")
		weld.Name = "CosmeticWeld"
		weld.Part0 = part
		weld.Part1 = handle
		weld.C0 = CFrame.new(att.Position)
		weld.Parent = handle
		item.Parent = character
	else
		(item :: Attachment).CFrame = att.CFrame
		item.Parent = part
	end
end

-- Puts on the items a player should wear and takes off the rest.
function CosmeticService:Refresh(player: Player)
	local character = player.Character
	if not character or not character.Parent or not self.Data:IsLoaded(player) then
		return
	end
	local want = {}
	if self.Settings:Get(player, "showCosmetics") ~= false then
		for _, id in CosmeticService.earned(self.Stats:GetBestRank(player), self.Stats:GetRebirths(player)) do
			want[id] = true
		end
	end
	for _, d in character:GetDescendants() do
		if d.Name:sub(1, #PREFIX) == PREFIX then
			local id = d.Name:sub(#PREFIX + 1)
			if want[id] then
				want[id] = nil -- already on
			else
				d:Destroy()
			end
		end
	end
	for _, c in Cosmetics do
		if want[c.id] then
			self:_wear(character, c)
		end
	end
end

function CosmeticService:Start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			-- wait for the avatar's own look, which can rebuild body parts
			if not player:HasAppearanceLoaded() then
				local loaded = false
				local connection = player.CharacterAppearanceLoaded:Connect(function()
					loaded = true
				end)
				local started = os.clock()
				while not loaded and character.Parent and os.clock() - started < 6 do
					task.wait(0.25)
				end
				connection:Disconnect()
			end
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
	self.Data.ProfileLoaded:Connect(function(player)
		self:Refresh(player)
	end)
	self.Stats.RankChanged:Connect(function(player)
		self:Refresh(player)
	end)
	self.Settings.Changed:Connect(function(player, key)
		if key == "showCosmetics" then
			self:Refresh(player)
		end
	end)
end

return CosmeticService
