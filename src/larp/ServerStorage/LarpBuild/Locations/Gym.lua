-- The Gym (Gains' home zone): the Iron Yard, an outdoor rubber-floored training yard with
-- squat racks, bench presses, dumbbell racks, a pull-up bar and tires, in front of GAINS
-- GYM with a giant dumbbell on its roof.
--   require(game.ServerStorage.LarpBuild.Locations.Gym).build()
local Kit = require(script.Parent.Parent.Kit)
local Plot = require(script.Parent.Plot)
local P = Kit.Palette

local Gym = {}

Gym.config = {
	seed = 41,
	facing = "West", -- the entrance faces Iron & Ink Street
	yard = 84, -- depth of the yard (the pickup zone) from the entrance
	spawns = 80,
	name = "GAINS GYM",
	floor = Color3.fromRGB(58, 60, 66),
	accent = Color3.fromRGB(214, 64, 52),
	iron = Color3.fromRGB(40, 42, 46),
	steel = Color3.fromRGB(170, 176, 184),
}

-- A barbell along plot X at (x, y, z), with plates on both ends.
local function barbell(plot, x: number, y: number, z: number, length: number, c)
	Plot.bar(plot, "Bar", x, y, z, length, 0.35, c.steel, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		Plot.bar(plot, "Plate", x + side * (length / 2 - 1), y, z, 0.7, 4, c.iron, Enum.Material.Rubber)
		Plot.bar(plot, "Plate", x + side * (length / 2 - 1.8), y, z, 0.6, 3.2, c.accent, Enum.Material.Rubber)
	end
end

local function squatRack(plot, x: number, z: number, c)
	local m = plot.model
	Kit.block(m, "RackBase", plot.at(x, 0.9, z), Vector3.new(8, 0.4, 5), c.iron, Enum.Material.Metal)
	for _, dx in { -3, 3 } do
		for _, dz in { -1.8, 1.8 } do
			Kit.block(m, "Upright", plot.at(x + dx, 5.4, z + dz), Vector3.new(0.6, 9, 0.6), c.iron, Enum.Material.Metal)
		end
		Kit.detail(m, "Crossbar", plot.at(x + dx, 9.7, z), Vector3.new(0.6, 0.6, 4.2), c.iron, Enum.Material.Metal)
	end
	barbell(plot, x, 6, z - 1.8, 10, c)
end

local function benchPress(plot, x: number, z: number, c)
	local m = plot.model
	Kit.block(m, "Bench", plot.at(x, 2.2, z + 1), Vector3.new(2.2, 0.8, 6), Color3.fromRGB(30, 30, 34), Enum.Material.Leather)
	Kit.detail(m, "BenchLeg", plot.at(x, 1.3, z + 1), Vector3.new(1.2, 1.2, 5), c.iron, Enum.Material.Metal)
	for _, dx in { -2.2, 2.2 } do
		Kit.block(m, "Upright", plot.at(x + dx, 3.2, z - 2.2), Vector3.new(0.5, 5, 0.5), c.iron, Enum.Material.Metal)
	end
	barbell(plot, x, 5.4, z - 2.2, 8, c)
end

local function dumbbellRack(plot, x: number, z: number, c)
	local m = plot.model
	Kit.block(m, "DumbbellRack", plot.at(x, 1.9, z), Vector3.new(14, 2.4, 2.4), c.iron, Enum.Material.Metal)
	for k = 0, 6 do
		local dx = -6 + k * 2
		Plot.bar(plot, "Dumbbell", x + dx, 3.6, z, 1.6, 0.9 + k * 0.08, if k % 2 == 0 then c.accent else c.steel, Enum.Material.Metal)
	end
end

local function pullUpBar(plot, x: number, z: number, c)
	for _, dx in { -5, 5 } do
		Kit.block(plot.model, "Post", plot.at(x + dx, 6.7, z), Vector3.new(0.8, 12, 0.8), c.iron, Enum.Material.Metal)
	end
	Plot.bar(plot, "PullBar", x, 12.4, z, 10.6, 0.4, c.steel, Enum.Material.Metal)
end

local function tire(plot, x: number, z: number, c)
	local at = plot.pos(x, 0.7, z)
	Plot.column(plot.model, "Tire", at + Vector3.new(0, 0.8, 0), 1.6, 7, Color3.fromRGB(28, 28, 30), Enum.Material.Rubber)
	Plot.column(plot.model, "TireHole", at + Vector3.new(0, 1.62, 0), 0.05, 3.6, Color3.fromRGB(14, 14, 16), Enum.Material.Rubber, { CanCollide = false })
end

function Gym.build(): string
	local c = Gym.config
	local plot = Plot.new("Gym", c.facing)
	local m = plot.model
	local hw, hd = plot.w / 2, plot.d / 2
	local yardEnd = -hd + c.yard

	-- the yard, fenced on three sides with a gate toward the street
	Plot.ground(plot, -hw, -hd, hw, yardEnd + 4, c.floor, Enum.Material.Rubber, 0.7)
	local fence = { Transparency = 0.45 }
	for _, side in { -1, 1 } do
		Kit.block(m, "Fence", plot.at(side * (hw - 0.5), 3.2, (-hd + yardEnd) / 2), Vector3.new(0.4, 5, c.yard), c.steel, Enum.Material.DiamondPlate, fence)
		Kit.block(m, "Fence", plot.at(side * (hw + 14) / 2, 3.2, -hd + 0.5), Vector3.new(hw - 14, 5, 0.4), c.steel, Enum.Material.DiamondPlate, fence)
	end
	Plot.arch(plot, -hd + 2, 24, "IRON YARD", { color = c.iron, textColor = P.white, trim = c.accent, font = Enum.Font.LuckiestGuy })

	for _, z in { -40, -20, 0 } do
		squatRack(plot, -42, z, c)
		benchPress(plot, 42, z, c)
	end
	dumbbellRack(plot, -24, yardEnd - 6, c)
	dumbbellRack(plot, 24, yardEnd - 6, c)
	pullUpBar(plot, 0, yardEnd - 6, c)
	tire(plot, -16, -hd + 14, c)
	tire(plot, 16, -hd + 14, c)

	-- the gym building
	local front = yardEnd + 4
	local depth = hd - front
	Kit.block(m, "GymBody", plot.at(0, 15, front + depth / 2), Vector3.new(plot.w, 30, depth), Color3.fromRGB(64, 66, 72), Enum.Material.Concrete)
	Kit.detail(m, "Windows", plot.at(0, 12, front - 0.2), Vector3.new(plot.w - 20, 12, 0.3), P.glass, Enum.Material.Glass, { Reflectance = 0.3 })
	Kit.detail(m, "Door", plot.at(0, 5.2, front - 0.4), Vector3.new(12, 9, 0.3), P.dark)
	Kit.detail(m, "Stripe", plot.at(0, 19.4, front - 0.3), Vector3.new(plot.w, 1.2, 0.5), c.accent)
	local sign = Kit.block(m, "GymSign", plot.at(0, 25, front - 0.6), Vector3.new(56, 7, 0.8), c.accent)
	Kit.label(sign, Enum.NormalId.Front, c.name, { font = Enum.Font.LuckiestGuy, color = P.white, stroke = 3, pad = 0.1 })
	-- the giant roof dumbbell
	local roofY, roofZ = 34, front + depth / 2
	Plot.bar(plot, "GiantBar", 0, roofY, roofZ, 34, 2, c.steel, Enum.Material.Metal, true)
	for _, side in { -1, 1 } do
		Plot.bar(plot, "GiantPlate", side * 12, roofY, roofZ, 2, 11, c.iron, Enum.Material.Metal, true)
		Plot.bar(plot, "GiantPlate", side * 14.4, roofY, roofZ, 2, 9, c.accent, Enum.Material.Metal, true)
	end
	for _, side in { -1, 1 } do
		Kit.detail(m, "Stand", plot.at(side * 6, 31.5, roofZ), Vector3.new(1.2, 3, 1.2), c.iron, Enum.Material.Metal)
	end

	Plot.zone(plot, -hw + 2, -hd + 4, hw - 2, yardEnd, c.spawns, 0.7)
	return ("%d parts"):format(#m:GetDescendants())
end

return Gym
