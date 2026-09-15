-- Builds the streets of the city from LarpBuild.Layout: roads, sidewalks, lane markings,
-- crosswalks, buildings (LarpBuild.Buildings) on every frontage, street furniture, a hazy
-- skyline and one pickup zone per street (Map.Streets.<name>: ZoneBounds + SpawnPoints;
-- PickupService spawns every stat there). Edit-time only:
--   require(game.ServerStorage.LarpBuild.City).build()
-- rebuilds Workspace.Larp.City and Map.Streets from scratch. It also moves the Car Lot onto
-- its plot (once) and removes the old plaza-to-lot Road stub. Locations are built
-- separately (LarpBuild.Locations).
local Kit = require(script.Parent.Kit)
local Layout = require(script.Parent.Layout)
local Buildings = require(script.Parent.Buildings)
local Lounges = require(game:GetService("ReplicatedStorage"):WaitForChild("Larp"):WaitForChild("Config"):WaitForChild("Chatrooms"))
local P = Kit.Palette

local City = {}

local CELL = 4 -- raster resolution; every street coordinate is a multiple of it
local HALF, WALK = Layout.road.half, Layout.road.walk
local ROAD_TOP, WALK_TOP = Layout.road.roadTop, Layout.road.walkTop
local EXTENT = 640 -- the raster covers -EXTENT..EXTENT on X and Z (out past the outer ring)

local EMPTY, ROAD, SIDEWALK, RESERVED, BUILT = 0, 1, 2, 3, 4

local N = EXTENT * 2 // CELL
local grid: { number } = {}

local function idx(i: number, j: number): number
	return i * N + j + 1
end

local function cellOf(v: number): number
	return math.floor((v + EXTENT) / CELL)
end

local function get(x: number, z: number): number
	local i, j = cellOf(x), cellOf(z)
	if i < 0 or j < 0 or i >= N or j >= N then
		return RESERVED
	end
	return grid[idx(i, j)]
end

-- Sets every cell inside `rect` (minX, minZ, maxX, maxZ) to `value`.
local function fill(rect, value: number)
	for i = math.max(0, cellOf(rect[1])), math.min(N - 1, cellOf(rect[3] - 0.001)) do
		for j = math.max(0, cellOf(rect[2])), math.min(N - 1, cellOf(rect[4] - 0.001)) do
			grid[idx(i, j)] = value
		end
	end
end

local function allEmpty(rect): boolean
	local i0, i1 = cellOf(rect[1]), cellOf(rect[3] - 0.001)
	local j0, j1 = cellOf(rect[2]), cellOf(rect[4] - 0.001)
	if i0 < 0 or j0 < 0 or i1 >= N or j1 >= N then
		return false
	end
	for i = i0, i1 do
		for j = j0, j1 do
			if grid[idx(i, j)] ~= EMPTY then
				return false
			end
		end
	end
	return true
end

-- Merges the cells of one type into as few rectangles as possible.
local function mesh(value: number)
	local seen = {}
	local rects = {}
	for j = 0, N - 1 do
		for i = 0, N - 1 do
			local k = idx(i, j)
			if grid[k] == value and not seen[k] then
				local i1 = i
				while i1 + 1 < N and grid[idx(i1 + 1, j)] == value and not seen[idx(i1 + 1, j)] do
					i1 += 1
				end
				local j1 = j
				while j1 + 1 < N do
					local ok = true
					for a = i, i1 do
						local kk = idx(a, j1 + 1)
						if grid[kk] ~= value or seen[kk] then
							ok = false
							break
						end
					end
					if not ok then
						break
					end
					j1 += 1
				end
				for a = i, i1 do
					for b = j, j1 do
						seen[idx(a, b)] = true
					end
				end
				table.insert(rects, { -EXTENT + i * CELL, -EXTENT + j * CELL, -EXTENT + (i1 + 1) * CELL, -EXTENT + (j1 + 1) * CELL })
			end
		end
	end
	return rects
end

local function streetRect(s)
	if s.axis == "X" then
		return { s.from, s.at - HALF, s.to, s.at + HALF }
	end
	return { s.at - HALF, s.from, s.at + HALF, s.to }
end

-- A world point on street `s`: `u` along its axis, `lateral` across it.
local function point(s, u: number, lateral: number, y: number?): Vector3
	if s.axis == "X" then
		return Vector3.new(u, y or WALK_TOP, lateral)
	end
	return Vector3.new(lateral, y or WALK_TOP, u)
end

local function across(s, side: number): Vector3
	return if s.axis == "X" then Vector3.new(0, 0, side) else Vector3.new(side, 0, 0)
end

local function insideOther(s, x: number, z: number, margin: number): boolean
	for _, other in Layout.streets do
		if other ~= s then
			local r = streetRect(other)
			if x > r[1] - margin and x < r[3] + margin and z > r[2] - margin and z < r[4] + margin then
				return true
			end
		end
	end
	return false
end

local function stepped(range, rng: Random): number
	return range[1] + 4 * rng:NextInteger(0, (range[2] - range[1]) // 4)
end

local function hidden(): { [string]: any }
	return { Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false }
end

-- Moves the hand-built Car Lot so its west edge sits on its plot (a no-op once it has),
-- and tops its SpawnPoints up to Layout.carLotSpawns (they're population slots; the
-- pickup positions are scattered inside ZoneBounds).
local function placeCarLot(map: Instance)
	local lot = map:FindFirstChild("CarLot")
	local bounds = lot and lot:FindFirstChild("ZoneBounds")
	if bounds then
		local shift = Layout.plots.CarLot[1] - (bounds.Position.X - bounds.Size.X / 2)
		if math.abs(shift) > 1 then
			lot:PivotTo(lot:GetPivot() + Vector3.new(shift, 0, 0))
		end
	end
	local points = lot and lot:FindFirstChild("SpawnPoints")
	local sample = points and points:FindFirstChildWhichIsA("BasePart")
	if sample then
		for _ = #points:GetChildren() + 1, Layout.carLotSpawns do
			sample:Clone().Parent = points
		end
	end
end

local function rasterize()
	grid = table.create(N * N, EMPTY)
	for _, rect in Layout.plots do
		fill(rect, RESERVED)
	end
	-- The LARP lounges sit outside the ring, and `fill.reach` carries block filler up to 150
	-- studs from any street, which put whole shopfronts inside them. They are reserved the
	-- same way a location's plot is, with a margin so nothing crowds the doorway. Their
	-- footprint turns with `facing`: facing along Z means the width runs along X.
	local lounge = Lounges.size
	for _, room in Lounges.rooms do
		local alongX = math.abs(room.facing.Z) > 0.5
		local halfX = (if alongX then lounge.X else lounge.Z) / 2 + 12
		local halfZ = (if alongX then lounge.Z else lounge.X) / 2 + 12
		fill({ room.at.X - halfX, room.at.Z - halfZ, room.at.X + halfX, room.at.Z + halfZ }, RESERVED)
	end
	for _, s in Layout.streets do
		fill(streetRect(s), ROAD)
	end
	local reach = WALK // CELL
	for i = 0, N - 1 do
		for j = 0, N - 1 do
			if grid[idx(i, j)] == ROAD then
				for di = -reach, reach do
					for dj = -reach, reach do
						local a, b = i + di, j + dj
						if a >= 0 and b >= 0 and a < N and b < N and grid[idx(a, b)] == EMPTY then
							grid[idx(a, b)] = SIDEWALK
						end
					end
				end
			end
		end
	end
end

-- The grass under everything, tiled because a single part caps at 2048 studs. Anything a
-- player can reach has to sit on it, so it is sized from Layout.ground.reach rather than the
-- street raster.
local function groundPlates(folder: Instance)
	local g = Layout.ground
	local tiles = math.ceil(g.reach * 2 / g.tile)
	for i = 0, tiles - 1 do
		for j = 0, tiles - 1 do
			local x = -g.reach + g.tile * (i + 0.5)
			local z = -g.reach + g.tile * (j + 0.5)
			Kit.block(folder, "Grass", Vector3.new(x, g.top - 4, z), Vector3.new(g.tile, 8, g.tile), P.grass, Enum.Material.Grass, { CastShadow = false })
		end
	end
	return tiles * tiles
end

local function paveGround(ground: Instance)
	for _, r in mesh(ROAD) do
		Kit.block(ground, "Road", Vector3.new((r[1] + r[3]) / 2, ROAD_TOP - 0.2, (r[2] + r[4]) / 2), Vector3.new(r[3] - r[1], 0.4, r[4] - r[2]), P.asphalt, Enum.Material.Asphalt)
	end
	for _, r in mesh(SIDEWALK) do
		Kit.block(ground, "Sidewalk", Vector3.new((r[1] + r[3]) / 2, (WALK_TOP - 0.2) / 2, (r[2] + r[4]) / 2), Vector3.new(r[3] - r[1], WALK_TOP + 0.2, r[4] - r[2]), P.sidewalk, Enum.Material.Pavement)
	end
	-- fills the edges of the Plaza block, just under the Plaza floor
	local plaza = Layout.plots.Plaza
	Kit.block(ground, "PlazaApron", Vector3.new((plaza[1] + plaza[3]) / 2, -0.14, (plaza[2] + plaza[4]) / 2), Vector3.new(plaza[3] - plaza[1], 0.4, plaza[4] - plaza[2]), P.paving, Enum.Material.Concrete)
end

local function paint(marks: Instance)
	for _, s in Layout.streets do
		for u = s.from + 8, s.to - 8, 14 do
			local p = point(s, u, s.at, ROAD_TOP + 0.02)
			if not insideOther(s, p.X, p.Z, 4) then
				Kit.detail(marks, "Dash", p, if s.axis == "X" then Vector3.new(6, 0.05, 0.5) else Vector3.new(0.5, 0.05, 6), P.line)
			end
		end
		-- crosswalks across this street on each side of every junction it continues through
		local rs = streetRect(s)
		for _, t in Layout.streets do
			if t ~= s and t.axis ~= s.axis then
				local rt = streetRect(t)
				local x0, z0, x1, z1 = math.max(rs[1], rt[1]), math.max(rs[2], rt[2]), math.min(rs[3], rt[3]), math.min(rs[4], rt[4])
				if x0 < x1 and z0 < z1 then
					local lo = if s.axis == "X" then x0 else z0
					local hi = if s.axis == "X" then x1 else z1
					for _, u in { lo - 4, hi + 4 } do
						if u > s.from + 6 and u < s.to - 6 then
							for k = -3, 3 do
								Kit.detail(marks, "Crosswalk", point(s, u, s.at + k * 3.2, ROAD_TOP + 0.02), if s.axis == "X" then Vector3.new(5, 0.05, 1.6) else Vector3.new(1.6, 0.05, 5), P.white)
							end
						end
					end
				end
			end
		end
	end
end

local function lineStreets(folder: Instance, rng: Random): (number, number)
	local buildings, parks = 0, 0
	local lot = Buildings.lot
	for _, s in Layout.streets do
		for _, side in { -1, 1 } do
			-- a quiet street (the outer ring) is only built up on the city's side
			if s.quiet and side == (if s.at >= 0 then 1 else -1) then
				continue
			end
			local frontage = s.at + side * (HALF + WALK)
			local face = across(s, -side)
			local u = s.from - 40
			while u < s.to + 40 do
				local w, d = stepped(lot.widths, rng), stepped(lot.depths, rng)
				local a, b = frontage, frontage + side * d
				local rect = if s.axis == "X" then { u, math.min(a, b), u + w, math.max(a, b) } else { math.min(a, b), u, math.max(a, b), u + w }
				if allEmpty(rect) then
					fill(rect, BUILT)
					local front = point(s, u + w / 2, frontage, 0)
					if w >= 28 and rng:NextNumber() < lot.parkChance then
						Buildings.park(folder, front, face, w, d, rng)
						parks += 1
					else
						Buildings.building(folder, front, face, w, d, rng)
						buildings += 1
					end
					u += w
				else
					u += CELL
				end
			end
		end
	end
	return buildings, parks
end

-- One pickup zone per street, holding that street's lamps, trees and benches (so pickups
-- never spawn inside them).
local function streetZones(folder: Instance, rng: Random)
	local f = Layout.furniture
	for _, s in Layout.streets do
		local zone = Instance.new("Model")
		zone.Name = s.name
		local rs = streetRect(s)
		local b = if s.axis == "X"
			then { rs[1], s.at - HALF - WALK, rs[3], s.at + HALF + WALK }
			else { s.at - HALF - WALK, rs[2], s.at + HALF + WALK, rs[4] }
		Kit.block(zone, "ZoneBounds", Vector3.new((b[1] + b[3]) / 2, 10, (b[2] + b[4]) / 2), Vector3.new(b[3] - b[1], 20, b[4] - b[2]), P.white, nil, hidden())
		local spawns = Kit.folder(zone, "SpawnPoints")
		for k = 1, s.spawns do
			local u = s.from + (s.to - s.from) * (k - 0.5) / s.spawns
			Kit.block(spawns, "SpawnPoint", point(s, u, s.at, ROAD_TOP), Vector3.one, P.white, nil, hidden())
		end
		for _, side in { -1, 1 } do
			local n = 0
			for u = s.from + f.step, s.to - f.step, f.step do
				local clear = true
				for _, du in { -8, 0, 8 } do
					local p = point(s, u + du, s.at + side * (HALF + 1.2))
					clear = clear and get(p.X, p.Z) == SIDEWALK
				end
				if clear then
					n += 1
					if n % 2 == 1 then
						Kit.lamp(zone, point(s, u, s.at + side * (HALF + 1.2)), across(s, -side))
					else
						Kit.tree(zone, point(s, u, s.at + side * (HALF + 3.2)), rng)
					end
					local inner = point(s, u + 9, s.at + side * (HALF + WALK - 1.8))
					if get(inner.X, inner.Z) == SIDEWALK then
						local roll = rng:NextNumber()
						if roll < f.benchChance then
							Kit.bench(zone, CFrame.lookAt(inner, inner + across(s, -side)))
						elseif roll < f.benchChance + f.binChance then
							Kit.bin(zone, inner)
						elseif roll < f.benchChance + f.binChance + f.hydrantChance then
							Kit.hydrant(zone, point(s, u + 9, s.at + side * (HALF + 1.4)))
						end
					end
				end
			end
		end
		zone.Parent = folder
	end
end

local function skyline(folder: Instance, rng: Random)
	local sky = Layout.skyline
	for k = 0, sky.count - 1 do
		local angle = k / sky.count * math.pi * 2 + rng:NextNumber(-0.02, 0.02)
		local radius = rng:NextNumber(sky.radius[1], sky.radius[2])
		local w, h = rng:NextNumber(40, 90), rng:NextNumber(sky.height[1], sky.height[2])
		local at = Vector3.new(math.cos(angle) * radius, h / 2, math.sin(angle) * radius)
		local shade = rng:NextNumber(0.55, 0.72)
		Kit.detail(folder, "Tower", CFrame.lookAt(at, Vector3.new(0, h / 2, 0)), Vector3.new(w, h, rng:NextNumber(40, 80)), Color3.new(shade * 0.92, shade * 0.96, shade * 1.05))
	end
end

-- Filler blocks on empty chunks near the streets, so the city reads as dense from above.
local function backBlocks(folder: Instance, rng: Random): number
	local cfg = Layout.fill
	local size = cfg.chunk // CELL
	local count = 0
	for i = 0, N - size, size do
		for j = 0, N - size, size do
			local rect = { -EXTENT + i * CELL, -EXTENT + j * CELL, -EXTENT + (i + size) * CELL, -EXTENT + (j + size) * CELL }
			local cx, cz = (rect[1] + rect[3]) / 2, (rect[2] + rect[4]) / 2
			local near = false
			for _, s in Layout.streets do
				if s.quiet then
					continue -- the ring keeps its open outside (the chatrooms sit there)
				end
				local r = streetRect(s)
				local dx = math.max(r[1] - cx, 0, cx - r[3])
				local dz = math.max(r[2] - cz, 0, cz - r[4])
				if dx * dx + dz * dz <= cfg.reach * cfg.reach then
					near = true
					break
				end
			end
			if near and allEmpty(rect) and rng:NextNumber() < cfg.chance then
				fill(rect, BUILT)
				local inset = rng:NextNumber(Buildings.back.inset[1], Buildings.back.inset[2])
				Buildings.filler(folder, { rect[1] + inset, rect[2] + inset, rect[3] - inset, rect[4] - inset }, rng)
				count += 1
			end
		end
	end
	return count
end

function City.build(): string
	local rng = Random.new(Layout.seed)
	local larp = workspace:WaitForChild("Larp")
	local map = larp:WaitForChild("Map")

	placeCarLot(map)
	local stub = map:FindFirstChild("Road")
	if stub then
		stub:Destroy()
	end
	local base = workspace:FindFirstChild("Baseplate")
	if base then
		base.Material = Enum.Material.Grass
		base.Color = P.grass
		local texture = base:FindFirstChildOfClass("Texture")
		if texture then
			texture.Transparency = 1
		end
	end

	local city = Kit.fresh(larp, "City")
	rasterize()
	local groundFolder = Kit.folder(city, "Ground")
	groundPlates(groundFolder) -- first, so the streets and pavements lie on top of it
	paveGround(groundFolder)
	-- the default baseplate only reached 1024 and is what the grass tiles replace
	local plate = workspace:FindFirstChild("Baseplate")
	if plate then
		plate:Destroy()
	end
	paint(Kit.folder(city, "Markings"))
	local buildings, parks = lineStreets(Kit.folder(city, "Buildings"), rng)
	local blocks = backBlocks(Kit.folder(city, "Blocks"), rng)
	streetZones(Kit.fresh(map, "Streets"), rng)
	local furniture = Kit.folder(city, "Furniture")
	for _, sign in Layout.signs do
		Kit.signpost(furniture, sign[1], sign[2])
	end
	skyline(Kit.folder(city, "Skyline"), rng)

	return ("buildings %d, parks %d, blocks %d, city parts %d, street zones %d"):format(buildings, parks, blocks, #city:GetDescendants(), #map.Streets:GetChildren())
end

return City
