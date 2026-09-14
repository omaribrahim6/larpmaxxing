-- Iron Paradise (LarpBuild.Reality): a gym east of the plaza, its entrance facing west. In
-- the middle, a platform with the bench and a 500 lb barbell in its rack, gym bros standing
-- round it and a 500 LB CLUB board on the back wall; dumbbell racks and mirrors down the
-- sides. The bench has the Bench 500 lb prompt. Markers for RealityService: BenchSpot (the
-- pad's top, facing where the head goes), BarRack / BarLow / BarHigh (the bar's middle when
-- racked, at the chest and pressed up), BenchCam, and the Board.
local Kit = require(script.Parent.Parent.Kit)
local Venue = require(script.Parent.Venue)
local Reality = require(game:GetService("ReplicatedStorage"):WaitForChild("Larp").Config.Reality)
local P = Kit.Palette

local Gym = {}

local RED = Color3.fromRGB(230, 70, 60)
local IRON = Color3.fromRGB(40, 42, 46)
local STEEL = Color3.fromRGB(176, 180, 188)
local CYLINDER = { Shape = Enum.PartType.Cylinder }
local F = Venue.FLOOR

function Gym.build(ctx)
	local m = Kit.folder(ctx.model, "Gym", "Model")
	local at, frame = Venue.frame(ctx, 280, 60, -Vector3.xAxis)
	local W, D, H = 90, 110, 26
	Venue.hall(m, at, {
		w = W, d = D, h = H, door = 24,
		floor = Color3.fromRGB(40, 42, 48), floorMaterial = Enum.Material.Rubber,
		wall = Color3.fromRGB(56, 58, 66), trim = RED,
		sign = "IRON PARADISE", signColor = Color3.fromRGB(255, 96, 80),
	})

	-- the platform and the bench (the head end toward the back wall, +Z)
	local deck = F + 0.6
	Kit.block(m, "Platform", at(0, F + 0.3, 6), Vector3.new(22, 0.6, 22), Color3.fromRGB(150, 110, 70), Enum.Material.WoodPlanks)
	local padTop = deck + 1.9
	local pad = Kit.block(m, "BenchPad", at(0, deck + 1.6, 6), Vector3.new(2.2, 0.6, 6), Color3.fromRGB(26, 26, 30), Enum.Material.Leather)
	Kit.block(m, "BenchFrame", at(0, deck + 0.65, 6), Vector3.new(1.2, 1.3, 5), IRON, Enum.Material.Metal)
	for _, x in { -2.8, 2.8 } do
		Kit.block(m, "Upright", at(x, deck + 2.6, 8.8), Vector3.new(0.5, 5.2, 0.5), IRON, Enum.Material.Metal)
		Kit.block(m, "Hook", at(x, padTop + 3.2, 8.5), Vector3.new(0.5, 0.3, 0.8), STEEL, Enum.Material.Metal)
	end
	Venue.prompt(pad, "Bench", Reality.words.bench, "Iron Paradise")
	local head = -frame.LookVector -- local +Z, toward the back wall
	local spot = at(0, padTop, 5.4).Position
	Venue.marker(m, "BenchSpot", CFrame.lookAt(spot, spot + head))
	Venue.marker(m, "BarRack", at(0, padTop + 3.5, 8.4))
	Venue.marker(m, "BarLow", at(0, padTop + 1.7, 7.2))
	Venue.marker(m, "BarHigh", at(0, padTop + 3.3, 7.6))
	local cam = at(11, padTop + 6, -6).Position
	Venue.marker(m, "BenchCam", CFrame.lookAt(cam, at(0, padTop + 1.5, 6.5).Position))

	-- the barbell: a bar and five plates a side (500 lb), racked
	local bar = Instance.new("Model")
	bar.Name = "Barbell"
	bar.Parent = m
	local rack = at(0, padTop + 3.5, 8.4)
	local core = Kit.block(bar, "Bar", rack * CFrame.new(0, 0, 0), Vector3.new(9.4, 0.26, 0.26), STEEL, Enum.Material.Metal, { CanCollide = false })
	for _, s in { -1, 1 } do
		for k = 0, 4 do
			Kit.block(bar, "Plate", rack * CFrame.new(s * (2.9 + k * 0.48), 0, 0), Vector3.new(0.42, 3.4, 3.4), if k == 0 then RED else IRON, Enum.Material.Rubber, { Shape = Enum.PartType.Cylinder, CanCollide = false })
		end
		Kit.block(bar, "Collar", rack * CFrame.new(s * 5.3, 0, 0), Vector3.new(0.3, 0.7, 0.7), STEEL, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	end
	bar.PrimaryPart = core

	-- the 500 LB CLUB board on the back wall (RealityService writes the lifts on it)
	local board = Kit.block(m, "Board", at(0, 15, D / 2 - 0.3), Vector3.new(34, 7, 0.4), P.dark)
	Kit.label(board, Enum.NormalId.Front, "500 LB CLUB", { font = Enum.Font.LuckiestGuy, color = Color3.fromRGB(255, 96, 80), stroke = 2 })

	-- the crowd round the platform (open toward the entrance)
	local spots = {}
	for k = 0, 11 do
		local a = math.rad(35 + k * (290 / 11))
		local x, z = math.sin(a) * 15, 6 - math.cos(a) * 15
		local p = at(x, F, z).Position
		table.insert(spots, CFrame.lookAt(p, at(0, F, 6).Position))
	end
	Venue.audience(m, "Gym", spots, { { "Gains", "Bro" }, { "Gains", "Spotter" } }, ctx.rng)

	-- dumbbell racks and mirrors down both sides
	for _, s in { -1, 1 } do
		local x = s * (W / 2 - 3)
		Kit.block(m, "DumbbellRack", at(x, F + 1.4, 0), Vector3.new(2.4, 2.8, 30), IRON, Enum.Material.Metal)
		for k = 0, 12 do
			local size = 0.7 + (k % 4) * 0.12
			Kit.block(m, "Dumbbell", at(x, F + 3.1, -13 + k * 2.2), Vector3.new(1.6, size, size), if k % 3 == 0 then RED else STEEL, Enum.Material.Metal, CYLINDER)
		end
		Kit.block(m, "Mirror", at(s * (W / 2 - 0.3), 8, 0), Vector3.new(0.2, 10, 40), Color3.fromRGB(200, 220, 235), Enum.Material.Glass, { Reflectance = 0.5 })
		for _, z in { -34, 32 } do
			Kit.block(m, "SquatRack", at(s * 30, F + 4.5, z), Vector3.new(5, 9, 5), IRON, Enum.Material.Metal, { Transparency = 0.6 })
			Kit.block(m, "RackBar", at(s * 30, F + 6, z), Vector3.new(7, 0.25, 0.25), STEEL, Enum.Material.Metal)
		end
	end
end

return Gym
