-- Outfits and props for LARP to Reality (Config.Reality fits): box shells over the body in the
-- fit's colours, and props welded on: the Drip scene's blazer, chain, shades and jorts
-- (Larp.Assets.Scenes.Drip), clogs, the Normie earbuds and an iced matcha
-- (Lib.CosmeticModels; the matcha stays upright in the hand through LarpClient.CosmeticFx).
-- Everything is named RealityFit..., so undress() takes it all off. Also the skateboard
-- (under the feet; the humanoid stands taller by Config.Reality.boardLift) and the medal.
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local CosmeticModels = require(script.Parent.CosmeticModels)

local Fits = {}

local FIT = "RealityFit"
local BOARD = "RealityBoard"
local MEDAL = "RealityMedal"
local UPRIGHT_TAG = "LarpUprightCosmetic"

-- The Drip scene's props as it wears them (LarpClient.Scenes.DripStreet WORN): template, body
-- part, width as a share of the part's, and where on the part.
local WORN = {
	Jorts = {
		{ "JortsWaist", "LowerTorso", 1.06, function(s) return CFrame.new(0, -s.Y * 0.1, 0) end },
		{ "JortsLeg", "LeftUpperLeg", 1.08, function(s) return CFrame.new(0, s.Y * 0.12, 0) end },
		{ "JortsLeg", "RightUpperLeg", 1.08, function(s) return CFrame.new(0, s.Y * 0.12, 0) end },
	},
	Chain = { { "Chain", "UpperTorso", 0.5, function(s) return CFrame.new(0, s.Y * 0.1, -(s.Z / 2 + 0.16)) end } },
	Shades = { { "Shades", "Head", 0.95, function(s) return CFrame.new(0, s.Y * 0.1, -s.Z * 0.56) end } },
	Blazer = {
		{ "Blazer", "UpperTorso", 1.1, function() return CFrame.identity end },
		{ "BlazerSleeve", "LeftUpperArm", 1.12, function() return CFrame.identity end },
		{ "BlazerSleeve", "RightUpperArm", 1.12, function() return CFrame.identity end },
	},
}

-- A part welded to body part `part` at `offset` (in the part's space).
local function piece(parent: Instance, part: BasePart, size: Vector3, color: Color3, material: Enum.Material, offset: CFrame, name: string, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = false
	p.CFrame = part.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = part
	weld.Part1 = p
	weld.C0 = offset
	weld.Parent = p
	p.Parent = parent
	return p
end

-- A slightly bigger box over body part `name`: clothing in `color`.
local function shell(folder: Instance, character: Model, name: string, color: Color3?, scale: number)
	local part = character:FindFirstChild(name)
	if color and part and part:IsA("BasePart") then
		piece(folder, part, part.Size * scale, color, Enum.Material.Fabric, CFrame.identity, "Shell")
	end
end

-- A Drip prop (template name) worn on body part `partName`, scaled to the part.
local function wear(folder: Instance, character: Model, template: string, partName: string, share: number, at)
	local part = character:FindFirstChild(partName)
	local source = Larp.Assets.Scenes.Drip:FindFirstChild(template)
	if not (part and part:IsA("BasePart") and source) then
		return
	end
	local model = source:Clone()
	local _, size = model:GetBoundingBox()
	if size.X > 0 then
		model:ScaleTo(model:GetScale() * part.Size.X * share / size.X)
	end
	local box = model:GetBoundingBox()
	model:PivotTo(part.CFrame * at(part.Size) * box:ToObjectSpace(model:GetPivot()))
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = part
			weld.Part1 = d
			weld.Parent = d
		end
	end
	model.Parent = folder
end

-- Clogs: a cork sole under each foot and two leather straps over it.
local function clogs(folder: Instance, character: Model)
	local cork, leather, buckle = Color3.fromRGB(201, 164, 112), Color3.fromRGB(96, 62, 36), Color3.fromRGB(214, 180, 90)
	for _, name in { "LeftFoot", "RightFoot" } do
		local foot = character:FindFirstChild(name)
		if foot and foot:IsA("BasePart") then
			local s = foot.Size
			piece(folder, foot, Vector3.new(s.X * 1.12, 0.16, s.Z * 1.15), cork, Enum.Material.Sand, CFrame.new(0, -s.Y / 2 - 0.04, 0), "Sole")
			for _, z in { -0.28, 0.06 } do
				piece(folder, foot, Vector3.new(s.X * 1.14, 0.13, 0.24), leather, Enum.Material.Leather, CFrame.new(0, s.Y / 2 - 0.02, z * s.Z), "Strap")
				piece(folder, foot, Vector3.new(0.06, 0.1, 0.1), buckle, Enum.Material.Metal, CFrame.new(s.X * 0.58, s.Y / 2 - 0.02, z * s.Z), "Buckle")
			end
		end
	end
end

-- The Normie earbuds (unless the rank cosmetic is already on).
local function earbuds(folder: Instance, character: Model)
	local head = character:FindFirstChild("Head")
	local att = head and head:FindFirstChild("FaceCenterAttachment")
	if not (head and att) or character:FindFirstChild("LarpCosmetic_Earbuds") then
		return
	end
	local item = CosmeticModels.build("Earbuds", head.Size, att.Position)
	local handle = item:FindFirstChild("Handle") :: BasePart
	local weld = Instance.new("Weld")
	weld.Part0 = head
	weld.Part1 = handle
	weld.C0 = CFrame.new(att.Position)
	weld.Parent = handle
	item.Parent = folder
end

-- An iced matcha upright in the right hand (unless the golden one is already there).
local function matcha(character: Model)
	local hand = character:FindFirstChild("RightHand")
	local att = hand and hand:FindFirstChild("RightGripAttachment")
	if not att or character:FindFirstChild("LarpCosmetic_GoldenMatcha") then
		return
	end
	local item = CosmeticModels.build("Matcha")
	item.Name = FIT .. "_Matcha"
	local handle = item:FindFirstChild("Handle") :: BasePart
	handle.Anchored = true
	handle.CFrame = CFrame.new(att.WorldPosition)
	local anchor = Instance.new("ObjectValue")
	anchor.Name = "Anchor"
	anchor.Value = att
	anchor.Parent = item
	CollectionService:AddTag(item, UPRIGHT_TAG)
	item.Parent = character -- CosmeticFx finds the root next to it
end

-- While a fit is on, it's the only outfit (owner 2026-09-14): the avatar's own clothes (shirt,
-- pants, t-shirt, layered clothing and shoes) and rank cosmetics wait in ServerStorage and go
-- back on when the fit comes off. Hair, hats and faces stay.
local CLOTHING = {
	[Enum.AccessoryType.Shirt] = true,
	[Enum.AccessoryType.TShirt] = true,
	[Enum.AccessoryType.Pants] = true,
	[Enum.AccessoryType.Jacket] = true,
	[Enum.AccessoryType.Sweater] = true,
	[Enum.AccessoryType.Shorts] = true,
	[Enum.AccessoryType.DressSkirt] = true,
	[Enum.AccessoryType.LeftShoe] = true,
	[Enum.AccessoryType.RightShoe] = true,
}
local stashes: { [Model]: { Instance } } = {}

local function wardrobe(): Folder
	local folder = ServerStorage:FindFirstChild("LarpWardrobe")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "LarpWardrobe"
		folder.Parent = ServerStorage
	end
	return folder :: Folder
end

local function stash(character: Model)
	if stashes[character] then
		return
	end
	local list = {}
	for _, child in character:GetChildren() do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic")
			or (child:IsA("Accessory") and CLOTHING[child.AccessoryType])
			or child.Name:sub(1, 13) == "LarpCosmetic_" then
			table.insert(list, child)
			child.Parent = wardrobe()
		end
	end
	stashes[character] = list
	-- a character that's gone (a respawn) takes its stash with it
	character.AncestryChanged:Connect(function(_, parent)
		if not parent and stashes[character] then
			for _, item in stashes[character] do
				item:Destroy()
			end
			stashes[character] = nil
		end
	end)
end

local function unstash(character: Model)
	local list = stashes[character]
	stashes[character] = nil
	for _, item in list or {} do
		item.Parent = character
	end
end

-- Takes off the current fit (the medal stays) and puts the avatar's own clothes back.
local function strip(character: Model)
	for _, child in character:GetChildren() do
		if child.Name == FIT or child.Name:sub(1, #FIT + 1) == FIT .. "_" then
			child:Destroy()
		end
	end
	unstash(character)
end

Fits.strip = strip

-- Takes off everything Reality put on: the fit and the medal (not the board: see unboard).
function Fits.undress(character: Model)
	strip(character)
	local medal = character:FindFirstChild(MEDAL)
	if medal then
		medal:Destroy()
	end
end

-- Puts on `fit` (Config.Reality fits / skateFit), replacing any other Reality fit.
function Fits.dress(character: Model, fit)
	strip(character)
	stash(character)
	local folder = Instance.new("Model")
	folder.Name = FIT
	shell(folder, character, "UpperTorso", fit.top, 1.07)
	shell(folder, character, "LowerTorso", fit.bottom, 1.07)
	for _, side in { "Left", "Right" } do
		if fit.sleeves then
			shell(folder, character, side .. "UpperArm", fit.top, 1.1)
			if fit.sleeves == "long" then
				shell(folder, character, side .. "LowerArm", fit.top, 1.1)
			end
		end
		if fit.legs then
			shell(folder, character, side .. "UpperLeg", fit.bottom, 1.08)
			if fit.legs == "long" then
				shell(folder, character, side .. "LowerLeg", fit.bottom, 1.08)
			end
		end
		shell(folder, character, side .. "Foot", fit.shoes, 1.12)
	end
	for _, prop in fit.props or {} do
		for _, w in WORN[prop] or {} do
			wear(folder, character, w[1], w[2], w[3], w[4])
		end
		if prop == "Clogs" then
			clogs(folder, character)
		elseif prop == "Earbuds" then
			earbuds(folder, character)
		elseif prop == "Matcha" then
			matcha(character)
		end
	end
	folder.Parent = character
end

-- The prize: a gold medal on a ribbon, on the chest.
function Fits.medal(character: Model)
	local torso = character:FindFirstChild("UpperTorso")
	if not (torso and torso:IsA("BasePart")) or character:FindFirstChild(MEDAL) then
		return
	end
	local model = Instance.new("Model")
	model.Name = MEDAL
	local s = torso.Size
	local front = -s.Z / 2 - 0.08
	piece(model, torso, Vector3.new(0.12, 0.7, 0.7), Color3.fromRGB(255, 200, 70), Enum.Material.Metal, CFrame.new(0, -s.Y * 0.12, front) * CFrame.Angles(0, math.rad(90), 0), "Disc", Enum.PartType.Cylinder)
	for _, side in { -1, 1 } do
		local a = Vector3.new(side * 0.1, -s.Y * 0.12 + 0.3, front)
		local b = Vector3.new(side * s.X * 0.28, s.Y / 2, front * 0.6)
		piece(model, torso, Vector3.new(0.18, 0.04, (b - a).Magnitude), Color3.fromRGB(40, 70, 160), Enum.Material.Fabric, CFrame.lookAt((a + b) / 2, b), "Ribbon")
	end
	model.Parent = character
end

-- A skateboard under the feet; the character stands `lift` studs taller on it.
function Fits.board(character: Model, lift: number)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or character:FindFirstChild(BOARD) then
		return
	end
	local hip = humanoid.HipHeight
	humanoid:SetAttribute("RealityHip", hip)
	humanoid.HipHeight = hip + lift
	local feet = -(hip + root.Size.Y / 2) -- the soles, relative to the root
	local floor = feet - lift
	local model = Instance.new("Model")
	model.Name = BOARD
	local wood, grip, metal, urethane = Color3.fromRGB(214, 170, 118), Color3.fromRGB(30, 30, 34), Color3.fromRGB(180, 184, 190), Color3.fromRGB(240, 236, 220)
	piece(model, root, Vector3.new(1.1, 0.14, 3.4), wood, Enum.Material.WoodPlanks, CFrame.new(0, feet - 0.09, 0), "Deck")
	piece(model, root, Vector3.new(1.06, 0.03, 3.3), grip, Enum.Material.Sand, CFrame.new(0, feet - 0.01, 0), "Grip")
	for _, z in { -1.15, 1.15 } do
		piece(model, root, Vector3.new(0.9, 0.12, 0.26), metal, Enum.Material.Metal, CFrame.new(0, floor + 0.34, z), "Truck")
		for _, x in { -0.46, 0.46 } do
			piece(model, root, Vector3.new(0.24, 0.44, 0.44), urethane, Enum.Material.SmoothPlastic, CFrame.new(x, floor + 0.22, z), "Wheel", Enum.PartType.Cylinder)
		end
	end
	model.Parent = character
end

function Fits.unboard(character: Model)
	local board = character:FindFirstChild(BOARD)
	if board then
		board:Destroy()
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hip = humanoid and humanoid:GetAttribute("RealityHip")
	if humanoid and type(hip) == "number" then
		humanoid.HipHeight = hip
		humanoid:SetAttribute("RealityHip", nil)
	end
end

return Fits
