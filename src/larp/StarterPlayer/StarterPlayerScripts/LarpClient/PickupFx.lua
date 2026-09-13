-- Client-side look of pickups: spin and bob, rarity glow, a light beam over legendaries,
-- floating "+15 Money" text and a sparkle burst when you collect one. Purely visual; the
-- server owns spawning and collection.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Catalog = require(Larp.Shared.Catalog)
local Net = require(Larp.Shared.Net)
local Text = require(Larp.Config.Text)
local SoundKit = require(script.Parent.SoundKit)
local Announcer = require(script.Parent.Announcer)

local TAG = "LarpPickup"
local ANIMATE_RANGE = 100 -- studs from the camera within which pickups spin and bob (pickups got 3x denser)
local PickupFx = {}

local active: { [Model]: { base: CFrame, phase: number } } = {}

-- A collected pickup (the server set CollectedBy) flies into the player who took it: it
-- arcs toward their torso, following them, spinning up and shrinking, then hides until
-- the server removes it.
local function fly(model: Model)
	active[model] = nil
	local player = game:GetService("Players"):GetPlayerByUserId(model:GetAttribute("CollectedBy") or 0)
	local character = player and player.Character
	local body = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart"))
	if not body then
		return
	end
	local start = model:GetPivot()
	local seconds = require(Larp.Config.Tuning).Pickup.flySeconds
	local began = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local a = math.min(1, (os.clock() - began) / seconds)
		if not model.Parent or not body.Parent or a >= 1 then
			connection:Disconnect()
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = 1
				elseif d:IsA("ParticleEmitter") or d:IsA("PointLight") then
					d.Enabled = false
				end
			end
			return
		end
		local eased = a * a -- speeds up into the player, like a magnet
		local position = start.Position:Lerp(body.Position, eased) + Vector3.new(0, math.sin(a * math.pi) * 1.2, 0)
		model:PivotTo(CFrame.new(position) * start.Rotation * CFrame.Angles(0, a * 8, 0))
		model:ScaleTo(math.max(0.1, 1 - eased * 0.8))
	end)
end

local function decorate(model: Model)
	model:GetAttributeChangedSignal("CollectedBy"):Connect(function()
		fly(model)
	end)
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not root then
		return
	end
	local rarity = Catalog.rarities[model:GetAttribute("Rarity") or "Common"] or Catalog.rarities.Common
	local rarityName = model:GetAttribute("Rarity")
	if rarityName ~= "Common" then
		-- a glow only on Epic and Legendary: with pickups 3x denser, a light on every Uncommon
		-- and Rare would be hundreds of lights for a phone to draw
		if rarityName == "Epic" or rarityName == "Legendary" then
			local glow = Instance.new("PointLight")
			glow.Color = rarity.color
			glow.Range = if rarityName == "Legendary" then 16 else 9
			glow.Brightness = if rarityName == "Legendary" then 3 else 1.5
			glow.Parent = root
		end
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

	-- only pickups near the camera spin and bob; with hundreds on the map, far ones hold still
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local eye = workspace.CurrentCamera.CFrame.Position
		for model, info in active do
			if model.Parent then
				if (info.base.Position - eye).Magnitude < ANIMATE_RANGE then
					local y = math.sin(t * 2 + info.phase) * 0.35
					model:PivotTo(info.base * CFrame.new(0, y, 0) * CFrame.Angles(0, t * 1.4 + info.phase, 0))
				end
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
		-- the item flies into you first (see fly), then its points pop off your body
		task.delay(require(Larp.Config.Tuning).Pickup.flySeconds, function()
			local character = game:GetService("Players").LocalPlayer.Character
			local body = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart"))
			local at = if body then body.Position + Vector3.new(0, 2, 0) else position
			floatText(at, ("+%d %s"):format(points, stat.displayName), if rarity then rarity.color else stat.color)
			-- the points fly on into the stat's HUD bar; chained pickups count a combo, and
			-- each pickup in a chain rings a little higher
			local combo = ui:Collected(statId, points, rarityName, at) or 1
			local big = rarityName == "Epic" or rarityName == "Legendary"
			SoundKit.play(if big then "PickupRare" else "Pickup", {
				volume = if rarityName == "Legendary" then 0.7 else 0.4,
				speed = 1 + math.min(combo - 1, 16) * 0.03,
			})
		end)
	end)

	-- a legendary drop gets the big banner (Announcer), not a notification card
	Net.get("LegendarySpawned").OnClientEvent:Connect(function(itemId, _position, place)
		local item = Catalog.itemsById[itemId]
		local stat = item and Catalog.statsById[item.stat]
		if item then
			local where = if type(place) == "string" then place else "in the " .. (stat and stat.zoneName or "map")
			local rarity = Catalog.rarities[item.rarity]
			Announcer.push({
				title = Text.Legendary.title,
				text = item.name,
				sub = Text.Legendary.where:format(where),
				color = rarity and rarity.color,
			})
			SoundKit.play("Ping", { volume = 0.5 })
		end
	end)
end

return PickupFx
