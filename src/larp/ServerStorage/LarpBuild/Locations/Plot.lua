-- Shared by the location builders. Plot.new(name, facing) replaces Workspace.Larp.Map.<name>
-- with an empty model on that location's Layout plot and returns plot space: -Z faces the
-- entrance (the location's street), X runs across, and the plot spans x in [-w/2, w/2] and
-- z in [-d/2, d/2]. plot.at(x, y, z) is a CFrame there, plot.pos a position, plot.dir a
-- flat direction.
local Kit = require(script.Parent.Parent.Kit)
local Layout = require(script.Parent.Parent.Layout)
local P = Kit.Palette

local Plot = {}

local FACING = { East = Vector3.xAxis, West = -Vector3.xAxis, North = -Vector3.zAxis, South = Vector3.zAxis }
local WATER = Color3.fromRGB(92, 172, 212)
local STONE = Color3.fromRGB(206, 200, 190)

local function hidden(): { [string]: any }
	return { Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false }
end

function Plot.new(name: string, facing: string)
	local rect = Layout.plots[name]
	local map = workspace:WaitForChild("Larp"):WaitForChild("Map")
	local model = Kit.fresh(map, name, "Model")
	local center = Vector3.new((rect[1] + rect[3]) / 2, 0, (rect[2] + rect[4]) / 2)
	local dir = FACING[facing]
	local cf = CFrame.lookAt(center, center + dir)
	local alongX = dir.X ~= 0
	local plot = {
		name = name,
		model = model,
		cf = cf,
		w = if alongX then rect[4] - rect[2] else rect[3] - rect[1],
		d = if alongX then rect[3] - rect[1] else rect[4] - rect[2],
	}
	function plot.at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	function plot.pos(x: number, y: number, z: number): Vector3
		return (cf * CFrame.new(x, y, z)).Position
	end
	function plot.dir(x: number, z: number): Vector3
		return cf:VectorToWorldSpace(Vector3.new(x, 0, z))
	end
	return plot
end

-- A flat surface over the plot-space rectangle, its top at height `top`.
function Plot.ground(plot, x0: number, z0: number, x1: number, z1: number, color: Color3, material: Enum.Material, top: number, name: string?)
	return Kit.block(plot.model, name or "Ground", plot.at((x0 + x1) / 2, (top - 0.2) / 2, (z0 + z1) / 2), Vector3.new(x1 - x0, top + 0.2, z1 - z0), color, material)
end

-- The pickup zone: an invisible ZoneBounds over the plot-space rectangle and `count` spawn
-- slots on a grid inside it at height `y` (PickupService scatters the real positions).
function Plot.zone(plot, x0: number, z0: number, x1: number, z1: number, count: number, y: number)
	Kit.block(plot.model, "ZoneBounds", plot.at((x0 + x1) / 2, 10, (z0 + z1) / 2), Vector3.new(x1 - x0, 20, z1 - z0), P.white, nil, hidden())
	local spawns = Kit.folder(plot.model, "SpawnPoints")
	local cols = math.max(1, math.round(math.sqrt(count * (x1 - x0) / (z1 - z0))))
	local rows = math.ceil(count / cols)
	local n = 0
	for r = 1, rows do
		for c = 1, cols do
			if n < count then
				n += 1
				Kit.block(spawns, "SpawnPoint", plot.at(x0 + (x1 - x0) * (c - 0.5) / cols, y, z0 + (z1 - z0) * (r - 0.5) / rows), Vector3.one, P.white, nil, hidden())
			end
		end
	end
end

-- An upright cylinder centered on `center`.
function Plot.column(parent: Instance, name: string, center: Vector3, height: number, diameter: number, color: Color3, material: Enum.Material?, opts: { [string]: any }?)
	local props = { Shape = Enum.PartType.Cylinder }
	for key, value in opts or {} do
		props[key] = value
	end
	return Kit.block(parent, name, CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(height, diameter, diameter), color, material, props)
end

-- A cylinder lying along plot X at plot (x, y, z).
function Plot.bar(plot, name: string, x: number, y: number, z: number, length: number, diameter: number, color: Color3, material: Enum.Material?, collide: boolean?)
	return Kit.block(plot.model, name, plot.at(x, y, z), Vector3.new(length, diameter, diameter), color, material, {
		Shape = Enum.PartType.Cylinder, CanCollide = collide == true, CastShadow = collide == true,
	})
end

-- The entrance arch: two pillars and a sign beam across plot-z `z`.
function Plot.arch(plot, z: number, width: number, text: string, opts: { [string]: any }?)
	opts = opts or {}
	local color = opts.color or P.dark
	for _, side in { -1, 1 } do
		Kit.block(plot.model, "ArchPillar", plot.at(side * (width / 2 + 1), 9, z), Vector3.new(2, 18, 2), color)
	end
	local beam = Kit.block(plot.model, "ArchSign", plot.at(0, 17, z), Vector3.new(width + 4, 4, 1.6), color)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		Kit.label(beam, face, text, { font = opts.font or Enum.Font.FredokaOne, color = opts.textColor or P.gold, pad = 0.16 })
	end
	Kit.detail(plot.model, "ArchTrim", plot.at(0, 14.8, z - 0.9), Vector3.new(width + 4, 0.3, 0.2), opts.trim or P.gold, Enum.Material.Neon)
end

-- A tiered fountain standing on height `top`.
function Plot.fountain(plot, x: number, z: number, diameter: number, top: number)
	local base = plot.pos(x, top, z)
	local m = plot.model
	local still = { Transparency = 0.25, CanCollide = false, CastShadow = false }
	Plot.column(m, "Basin", base + Vector3.new(0, 0.9, 0), 1.8, diameter, STONE, Enum.Material.Marble)
	Plot.column(m, "Water", base + Vector3.new(0, 1.85, 0), 0.15, diameter - 1.4, WATER, Enum.Material.Glass, still)
	Plot.column(m, "Pillar", base + Vector3.new(0, 3.5, 0), 5, math.max(1.2, diameter * 0.1), STONE, Enum.Material.Marble)
	Plot.column(m, "Bowl", base + Vector3.new(0, 6.2, 0), 0.7, diameter * 0.4, STONE, Enum.Material.Marble)
	Plot.column(m, "BowlWater", base + Vector3.new(0, 6.6, 0), 0.1, diameter * 0.36, WATER, Enum.Material.Glass, still)
	Plot.column(m, "Spout", base + Vector3.new(0, 7.8, 0), 2.4, 0.6, WATER, Enum.Material.Glass, still)
end

-- A lamp post with a glowing globe.
function Plot.globeLamp(parent: Instance, at: Vector3)
	Plot.column(parent, "LampPost", at + Vector3.new(0, 5, 0), 10, 0.5, P.dark, Enum.Material.Metal)
	Kit.detail(parent, "Globe", at + Vector3.new(0, 10.6, 0), Vector3.one * 1.8, Color3.fromRGB(255, 238, 200), Enum.Material.Neon, { Shape = Enum.PartType.Ball })
end

return Plot
