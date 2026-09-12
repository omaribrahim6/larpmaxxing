-- Helpers the larp-off prop builders share (LarpBuild.Scenes.*): props with an invisible
-- Root at the origin (front is -Z, like the items), Items models resized, and NPCs as real
-- R15 rigs so they walk and pose like the players' avatar copies. Edit-time only.
local Kit = require(script.Parent.Kit)
local Items = require(script.Parent.Items)

local SceneProps = {}

local M = Enum.Material
SceneProps.WHITE = Color3.fromRGB(246, 244, 238)
SceneProps.DARK = Color3.fromRGB(28, 28, 32)
SceneProps.SKIN = { Color3.fromRGB(234, 192, 160), Color3.fromRGB(198, 140, 100), Color3.fromRGB(140, 94, 64), Color3.fromRGB(250, 214, 184) }

function SceneProps.root(model: Model): Part
	local r = Kit.block(model, "Root", CFrame.identity, Vector3.one, SceneProps.WHITE, M.SmoothPlastic, { Transparency = 1, CanCollide = false })
	model.PrimaryPart = r
	return r
end

-- A cylinder whose axis is `cf`'s Y axis.
function SceneProps.cyl(m: Instance, name: string, cf: CFrame, h: number, d: number, color: Color3, material: Enum.Material?, opts: { [string]: any }?): Part
	local props = { Shape = Enum.PartType.Cylinder, CanCollide = false }
	for k, v in opts or {} do
		props[k] = v
	end
	return Kit.block(m, name, cf * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(h, d, d), color, material, props)
end

function SceneProps.part(m: Instance, name: string, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?, opts: { [string]: any }?): Part
	local props = { CanCollide = false }
	for k, v in opts or {} do
		props[k] = v
	end
	return Kit.block(m, name, cf, size, color, material, props)
end

function SceneProps.model(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	SceneProps.root(m)
	return m
end

-- An Items model resized for holding or wearing.
function SceneProps.item(id: string, name: string, scale: number): Model
	local m = Items.make(id)
	m.Name = name
	m:ScaleTo(scale)
	return m
end

-- A real R15 rig in these colours: { skin, shirt, pants, hair }, plus extras(rig, wear)
-- for worn parts; wear(on, name, offset, size, color, material?, shape?) welds a massless,
-- non-colliding part to `on`. The rig's root is anchored and its Animate script removed
-- (it would run inside a feed, which lives in PlayerGui).
function SceneProps.npc(name: string, colors, extras: ((Model, any) -> ())?): Model
	local d = Instance.new("HumanoidDescription")
	d.HeadColor, d.LeftArmColor, d.RightArmColor = colors.skin, colors.skin, colors.skin
	d.TorsoColor = colors.shirt
	d.LeftLegColor, d.RightLegColor = colors.pants, colors.pants
	local rig = game:GetService("Players"):CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	rig.Name = name
	-- sleeves: the upper arms wear the shirt colour
	for _, arm in { "LeftUpperArm", "RightUpperArm" } do
		local p = rig:FindFirstChild(arm)
		if p then
			p.Color = colors.shirt
		end
	end
	local head = rig:FindFirstChild("Head")
	if head then
		local face = Instance.new("Decal")
		face.Name = "face"
		face.Texture = "rbxasset://textures/face.png"
		face.Face = Enum.NormalId.Front
		face.Parent = head
	end
	local function wear(on: BasePart, partName: string, offset: CFrame, size: Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
		local p = Instance.new("Part")
		p.Name = partName
		p.Size = size
		p.Color = color
		p.Material = material or M.SmoothPlastic
		p.Shape = shape or Enum.PartType.Block
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
		p.CastShadow = false
		p.CFrame = on.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = on, p
		weld.Parent = p
		p.Parent = rig
		return p
	end
	if head and colors.hair then
		local s = head.Size
		wear(head, "Hair", CFrame.new(0, s.Y * 0.28, s.Z * 0.08), Vector3.new(s.X * 1.08, s.Y * 0.62, s.Z * 1.1), colors.hair, M.SmoothPlastic, Enum.PartType.Ball)
	end
	if extras then
		extras(rig, wear)
	end
	for _, p in rig:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		elseif p:IsA("BaseScript") then
			p:Destroy()
		end
	end
	local rootPart = rig:FindFirstChild("HumanoidRootPart")
	if rootPart then
		rootPart.Anchored = true
	end
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	return rig
end

-- Builds every builder into a fresh Larp.Assets.Scenes.<name> folder. Returns a summary.
function SceneProps.buildAll(name: string, builders: { [string]: () -> Instance }): string
	local scenes = game:GetService("ReplicatedStorage"):WaitForChild("Larp"):WaitForChild("Assets"):WaitForChild("Scenes")
	local folder = Kit.fresh(scenes, name)
	local names = {}
	for id, fn in builders do
		local m = fn()
		m.Name = id
		m.Parent = folder
		table.insert(names, id)
	end
	table.sort(names)
	return ("%d props: %s"):format(#names, table.concat(names, ", "))
end

return SceneProps
