-- Shared pieces for LARP to Reality's venues (Runway, Gym, Hall): a venue's frame, a hall
-- with a wide entrance, an audience of the scenes' NPC rigs (tagged RealityAudience, so
-- LarpClient.Reality can make them cheer), activity prompts and hidden markers.
local CollectionService = game:GetService("CollectionService")
local Kit = require(script.Parent.Parent.Kit)
local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local P = Kit.Palette

local Venue = {}

local HIDDEN = { Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false }
Venue.FLOOR = 0.3 -- a venue floor's top

-- A frame at local (x, z) whose -Z faces `face` (the entrance side). Returns at(x, y, z).
function Venue.frame(ctx, x: number, z: number, face: Vector3)
	local origin = ctx.center + Vector3.new(x, 0, z)
	local frame = CFrame.lookAt(origin, origin + face)
	return function(lx: number, ly: number, lz: number): CFrame
		return frame * CFrame.new(lx, ly, lz)
	end, frame
end

-- A hall w wide, d deep and h tall around the frame's origin, its entrance (`door` wide,
-- 16 tall) in the front wall (-Z) under a sign. spec: w, d, h, door, floor, floorMaterial,
-- wall, trim, sign, signColor, light (ceiling light colour).
function Venue.hall(m: Instance, at, spec)
	local w, d, h = spec.w, spec.d, spec.h
	local F = Venue.FLOOR
	Kit.block(m, "Floor", at(0, F - 0.5, 0), Vector3.new(w, 1, d), spec.floor, spec.floorMaterial or Enum.Material.SmoothPlastic)
	Kit.block(m, "Roof", at(0, h + 0.5, 0), Vector3.new(w + 2, 1, d + 2), spec.wall)
	for _, s in { -1, 1 } do
		Kit.block(m, "Wall", at(s * (w / 2 + 0.5), h / 2, 0), Vector3.new(1, h, d + 2), spec.wall)
		Kit.detail(m, "Trim", at(s * (w / 2 - 0.05), h - 1, 0), Vector3.new(0.1, 0.4, d), spec.trim, Enum.Material.Neon)
	end
	Kit.block(m, "Wall", at(0, h / 2, d / 2 + 0.5), Vector3.new(w, h, 1), spec.wall)
	local side = (w - spec.door) / 2
	for _, s in { -1, 1 } do
		Kit.block(m, "Wall", at(s * (spec.door / 2 + side / 2), h / 2, -d / 2 - 0.5), Vector3.new(side, h, 1), spec.wall)
	end
	Kit.block(m, "Lintel", at(0, 16 + (h - 16) / 2, -d / 2 - 0.5), Vector3.new(spec.door, h - 16, 1), spec.wall)
	Kit.detail(m, "DoorGlow", at(0, 16.2, -d / 2 - 1.05), Vector3.new(spec.door, 0.4, 0.1), spec.trim, Enum.Material.Neon)
	-- its name over the entrance, outside
	local sign = Kit.block(m, "Sign", at(0, 16 + math.min(6, (h - 16) / 2), -d / 2 - 1.2), Vector3.new(math.min(spec.door + 16, w - 4), 6, 0.6), P.dark)
	Kit.label(sign, Enum.NormalId.Front, spec.sign, { font = Enum.Font.LuckiestGuy, color = spec.signColor, stroke = 2 })
	-- light bars across the ceiling
	for z = -d / 2 + 10, d / 2 - 10, 20 do
		local bar = Kit.detail(m, "Light", at(0, h - 0.2, z), Vector3.new(w - 8, 0.3, 1.2), spec.light or Color3.fromRGB(255, 244, 226), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Range = 40
		light.Brightness = 1.2
		light.Color = spec.light or Color3.fromRGB(255, 236, 210)
		light.Parent = bar
	end
end

-- An NPC rig from the larp-off scenes' assets (`kind` = { scene, rig }), made into scenery.
local function rig(kind): Model?
	local scenes = Larp.Assets.Scenes
	local template = scenes:FindFirstChild(kind[1]) and scenes[kind[1]]:FindFirstChild(kind[2])
	if not template then
		return nil
	end
	local copy = template:Clone()
	for _, d in copy:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	return copy
end

-- Bends a rig's hips and knees 90 degrees: sitting.
local function sit(model: Model)
	for joint, angle in { RightHip = 90, LeftHip = 90, RightKnee = -90, LeftKnee = -90 } do
		for _, d in model:GetDescendants() do
			if d.Name == joint and d:IsA("Motor6D") then
				d.C0 = d.C0 * CFrame.Angles(math.rad(angle), 0, 0)
			end
		end
	end
end

-- An audience: a rig of a random `kinds` entry at each spot (a CFrame on the floor facing
-- the way the rig should), standing or sitting (spots are then seat tops). Tagged for the
-- client with the venue's name.
function Venue.audience(parent: Instance, venue: string, spots: { CFrame }, kinds, rng: Random, seated: boolean?)
	local folder = Kit.folder(parent, "Audience", "Model")
	for _, spot in spots do
		local model = rig(kinds[rng:NextInteger(1, #kinds)])
		local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if model and root and humanoid then
			local offset = root.CFrame:ToObjectSpace(model:GetPivot())
			local lift = humanoid.HipHeight + root.Size.Y / 2
			if seated then
				local lower = model:FindFirstChild("LowerTorso") :: BasePart?
				lift = if lower then root.Position.Y - (lower.Position.Y - lower.Size.Y / 2) else 1
				sit(model)
			end
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = d == root
					d.CanCollide = false
					d.CanTouch = false
				end
			end
			-- they only stand (or sit) and cheer (LarpClient.Reality moves their joints): no
			-- Humanoid state machine running for every audience rig on the server
			humanoid.EvaluateStateMachine = false
			model:PivotTo(spot * CFrame.new(0, lift, 0) * offset)
			model:SetAttribute("Venue", venue)
			CollectionService:AddTag(model, "RealityAudience")
			model.Parent = folder
		end
	end
	return folder
end

-- A hidden part marking a spot RealityService uses.
function Venue.marker(parent: Instance, name: string, cf: CFrame): Part
	return Kit.block(parent, name, cf, Vector3.new(2, 1, 2), P.white, nil, HIDDEN)
end

-- An activity prompt (RealityService reads RealityAction and the other attributes).
function Venue.prompt(part: BasePart, action: string, actionText: string, objectText: string, attributes: { [string]: any }?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RealityPrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("RealityAction", action)
	for key, value in attributes or {} do
		prompt:SetAttribute(key, value)
	end
	prompt.Parent = part
	return prompt
end

return Venue
