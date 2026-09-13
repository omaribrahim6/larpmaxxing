-- Builds the VIP++ Arena (Config.Areas tier "Arena"): a huge open-air arena past the skyline
-- to the north, open to anyone who's bought anything in the Shop, with the richest props in
-- the game. Its door is a pink portal on the Plaza's west side. Into
-- Workspace.Larp.Map.Premium.Plaza: Entrance (the door and an Arrival) and Arena (the floor,
-- stands, lights, sign, EXIT door, Arrival, Volume, ZoneBounds and SpawnPoints).
--   require(game.ServerStorage.LarpBuild.Arena).build()
local Kit = require(script.Parent.Kit)
local Plot = require(script.Parent.Locations.Plot)
local Premium = require(script.Parent.Premium)
local Areas = require(game:GetService("ReplicatedStorage"):WaitForChild("Larp").Config.Areas)
local P = Kit.Palette

local Arena = {}

Arena.config = {
	center = Vector3.new(0, 60, -1400), -- the floor's top, far north past the skyline
	size = 260, -- the floor's width and depth inside the walls
	spawns = 140, -- spawn points (each holds Tuning.Pickup.slotsPerSpawnPoint props)
	door = Vector3.new(-46, 0.2, 8), -- the Plaza door, on the Plaza floor's west side
	doorFacing = Vector3.xAxis, -- it faces the spawn
}

local HIDDEN = { Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false }
local SOLID_HIDDEN = { Transparency = 1, CanTouch = false, CanQuery = false } -- keeps players in
local FLAT = { CanCollide = false, CanQuery = false }
local PINK = Areas.tiers.Arena.color
local FLOOR = Color3.fromRGB(38, 28, 56)
local STAND = Color3.fromRGB(58, 44, 84)

function Arena.build(): string
	local cfg = Arena.config
	local map = workspace:WaitForChild("Larp"):WaitForChild("Map")
	local root = Kit.folder(map, "Premium", "Folder")
	local zone = Kit.fresh(root, "Plaza", "Model")
	local name = Areas.zones.Plaza.Arena

	-- the Plaza door, and where players land when they leave the Arena
	local entrance = Instance.new("Model")
	entrance.Name = "Entrance"
	entrance.Parent = zone
	local base = CFrame.lookAt(cfg.door, cfg.door + cfg.doorFacing)
	Premium.door(entrance, base * CFrame.new(0, 5, 0), PINK, "VIP++ ARENA", Areas.words.enter,
		("💖 %s (anyone who's bought something)"):format(name), "Plaza", "Arena")
	Kit.detail(entrance, "Step", base * CFrame.new(0, 0.3, -1.6), Vector3.new(7, 0.2, 2), PINK, Enum.Material.Neon)
	Kit.block(entrance, "Arrival", base * CFrame.new(0, 0.5, -5), Vector3.new(4, 1, 4), P.white, nil, HIDDEN)

	local m = Instance.new("Model")
	m.Name = "Arena"
	m.Parent = zone
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(cfg.center + Vector3.new(x, y, z))
	end
	local S = cfg.size
	local half = S / 2

	-- the floor, a pink neon grid, and the VIP++ emblem in the middle
	Kit.block(m, "Floor", at(0, -1, 0), Vector3.new(S + 12, 2, S + 12), FLOOR, Enum.Material.Marble)
	for k = -half + 26, half - 26, 26 do
		Kit.detail(m, "Grid", at(k, 0.05, 0), Vector3.new(0.4, 0.1, S), PINK, Enum.Material.Neon)
		Kit.detail(m, "Grid", at(0, 0.05, k), Vector3.new(S, 0.1, 0.4), PINK, Enum.Material.Neon)
	end
	Plot.column(m, "Ring", at(0, 0.08, 0).Position, 0.1, 64, PINK, Enum.Material.Neon, FLAT)
	Plot.column(m, "RingInner", at(0, 0.1, 0).Position, 0.1, 60, FLOOR, Enum.Material.Marble, FLAT)
	local emblem = Kit.detail(m, "Emblem", at(0, 0.15, 0), Vector3.new(44, 0.1, 16), FLOOR, nil, { Transparency = 1 })
	Kit.label(emblem, Enum.NormalId.Top, "VIP++", { font = Enum.Font.LuckiestGuy, color = PINK, stroke = 3 })

	-- low walls with a pink glow, and invisible ones well above them
	for _, s in { -1, 1 } do
		Kit.block(m, "Wall", at(s * (half + 5), 2, 0), Vector3.new(2, 4, S + 12), STAND)
		Kit.block(m, "Wall", at(0, 2, s * (half + 5)), Vector3.new(S + 12, 4, 2), STAND)
		Kit.detail(m, "WallGlow", at(s * (half + 5), 4.15, 0), Vector3.new(2.2, 0.3, S + 12), PINK, Enum.Material.Neon)
		Kit.detail(m, "WallGlow", at(0, 4.15, s * (half + 5)), Vector3.new(S + 12, 0.3, 2.2), PINK, Enum.Material.Neon)
		Kit.block(m, "Barrier", at(s * (half + 6), 20, 0), Vector3.new(1, 40, S + 14), P.white, nil, SOLID_HIDDEN)
		Kit.block(m, "Barrier", at(0, 20, s * (half + 6)), Vector3.new(S + 14, 40, 1), P.white, nil, SOLID_HIDDEN)
	end

	-- stands down the east and west sides, rising toward the walls
	for _, s in { -1, 1 } do
		for tier = 0, 2 do
			local height = 6 - tier * 2
			Kit.block(m, "Stand", at(s * (half - 2 - tier * 4), height / 2, 0), Vector3.new(4, height, S - 40), STAND)
		end
	end

	-- a light tower in each corner
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local c = at(sx * (half - 4), 0, sz * (half - 4))
			Kit.block(m, "LightTower", c * CFrame.new(0, 15, 0), Vector3.new(2, 30, 2), P.dark, Enum.Material.Metal)
			local lamp = Kit.detail(m, "Lamp", c * CFrame.new(0, 30.5, 0), Vector3.new(6, 2, 6), Color3.fromRGB(255, 236, 246), Enum.Material.Neon)
			local light = Instance.new("PointLight")
			light.Range = 60
			light.Brightness = 2
			light.Color = Color3.fromRGB(255, 200, 230)
			light.Parent = lamp
		end
	end

	-- the big sign at the far (north) end, facing the arrivals
	for _, s in { -1, 1 } do
		Kit.block(m, "SignPost", at(s * 40, 13, -half - 2), Vector3.new(2, 26, 2), P.dark)
	end
	local sign = Kit.block(m, "Sign", at(0, 20, -half - 2) * CFrame.Angles(0, math.pi, 0), Vector3.new(90, 16, 1), P.dark)
	-- turned half round, so its Front faces south, toward the arrivals
	Kit.label(sign, Enum.NormalId.Front, name:upper(), { font = Enum.Font.LuckiestGuy, color = PINK, stroke = 3 })
	Kit.detail(m, "SignGlow", at(0, 11.7, -half - 1.4), Vector3.new(90, 0.4, 0.4), PINK, Enum.Material.Neon)

	-- the way out in the south wall, facing in; where players land; the whole area; the props
	Premium.door(m, at(0, 5, half + 3), PINK, "EXIT", Areas.words.leave, Areas.words.back:format("Plaza"), "Plaza", "Entrance")
	Kit.block(m, "Arrival", at(0, 0.5, half - 12), Vector3.new(4, 1, 4), P.white, nil, HIDDEN)
	Kit.block(m, "Volume", at(0, 20, 0), Vector3.new(S + 14, 44, S + 14), P.white, nil, HIDDEN)
	Premium.pickupZone(m, at, -half + 16, -half + 10, half - 16, half - 22, 0, cfg.spawns)
	return ("%d parts"):format(#zone:GetDescendants())
end

return Arena
