-- Client-side look of pickups: spin and bob, rarity glow, a light beam over legendaries,
-- floating "+15 Bag" text and a sparkle burst when you collect one. Purely visual; the
-- server owns spawning and collection.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Catalog = require(Larp.Shared.Catalog)
local Net = require(Larp.Shared.Net)
local SoundKit = require(script.Parent.SoundKit)

local TAG = "LarpPickup"
local PickupFx = {}

local active: { [Model]: { base: CFrame, phase: number } } = {}

local function decorate(model: Model)
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not root then
		return
	end
	local rarity = Catalog.rarities[model:GetAttribute("Rarity") or "Common"] or Catalog.rarities.Common
	local rarityName = model:GetAttribute("Rarity")
	if rarityName ~= "Common" then
		local glow = Instance.new("PointLight")
		glow.Color = rarity.color
		glow.Range = if rarityName == "Legendary" then 16 else 9
		glow.Brightness = if rarityName == "Legendary" then 3 else 1.5
		glow.Parent = root
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(rarity.color)
		sparkle.Size = NumberSequence.new(0.35, 0)
		sparkle.Lifetime = NumberRange.new(0.6, 1)
		sparkle.Rate = if rarityName == "Legendary" then 14 else 5
		sparkle.Speed = NumberRange.new(1, 2)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.LightEmission = 1
		sparkle.Parent = root
	end
	if rarityName == "Legendary" then
		local beam = Instance.new("Part")
		beam.Name = "LegendaryBeam"
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.Material = Enum.Material.Neon
		beam.Color = rarity.color
		beam.Transparency = 0.55
		beam.Shape = Enum.PartType.Cylinder
		beam.Size = Vector3.new(60, 1.2, 1.2)
		beam.CFrame = CFrame.new(model:GetPivot().Position + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.rad(90))
		beam.Parent = model
	end
	active[model] = { base = model:GetPivot(), phase = math.random() * math.pi * 2 }
end

local function floatText(position: Vector3, text: string, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 60)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(20, 20, 24)
	stroke.Parent = label
	label.Parent = gui

	local burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Color = ColorSequence.new(color)
	burst.Size = NumberSequence.new(0.6, 0)
	burst.Lifetime = NumberRange.new(0.4, 0.7)
	burst.Speed = NumberRange.new(6, 10)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.LightEmission = 1
	burst.Rate = 0
	burst.Parent = anchor
	burst:Emit(22)

	TweenService:Create(anchor, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(position + Vector3.new(0, 4, 0)) }):Play()
	TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.5), { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.5), { Transparency = 1 }):Play()
	Debris:AddItem(anchor, 1.2)
end

function PickupFx.start(ui)
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model)
		if model:IsA("Model") then
			decorate(model)
		end
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model)
		active[model] = nil
	end)
	for _, model in CollectionService:GetTagged(TAG) do
		if model:IsA("Model") then
			decorate(model)
		end
	end

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for model, info in active do
			if model.Parent then
				local y = math.sin(t * 2 + info.phase) * 0.35
				model:PivotTo(info.base * CFrame.new(0, y, 0) * CFrame.Angles(0, t * 1.4 + info.phase, 0))
			else
				active[model] = nil
			end
		end
	end)

	Net.get("PickupCollected").OnClientEvent:Connect(function(itemId, points, statId, rarityName, position)
		local stat = Catalog.statsById[statId]
		local rarity = Catalog.rarities[rarityName]
		if not stat or typeof(position) ~= "Vector3" or type(points) ~= "number" then
			return
		end
		floatText(position, ("+%d %s"):format(points, stat.displayName), if rarity then rarity.color else stat.color)
		local big = rarityName == "Epic" or rarityName == "Legendary"
		SoundKit.play(if big then "PickupRare" else "Pickup", { volume = if rarityName == "Legendary" then 0.7 else 0.4 })
	end)

	Net.get("LegendarySpawned").OnClientEvent:Connect(function(itemId)
		local item = Catalog.itemsById[itemId]
		local stat = item and Catalog.statsById[item.stat]
		if item then
			ui:Notify(("A %s just dropped in the %s!"):format(item.name, stat and stat.zoneName or "map"), "info")
			SoundKit.play("Ping", { volume = 0.5 })
		end
	end)
end

return PickupFx
