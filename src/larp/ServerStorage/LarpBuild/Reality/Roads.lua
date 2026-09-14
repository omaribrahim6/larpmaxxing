-- LARP to Reality's streets (LarpBuild.Reality): the ground, a loop of city streets round the
-- middle block (the Boulevard in front of the plaza, an Avenue down each side) and a six-lane
-- highway along the north, running out past the loop to a turnaround at each end. Lane
-- markings, sidewalks, jersey barriers, lamps, two overhead sign gantries, and a skyline of
-- buildings all round. Road tops are at y 0.2, sidewalks at 0.6.
local Kit = require(script.Parent.Parent.Kit)
local Buildings = require(script.Parent.Parent.Buildings)
local P = Kit.Palette

local Roads = {}

local ROAD_TOP, WALK_TOP = 0.2, 0.6
local GRASS = Color3.fromRGB(104, 150, 84)
local YELLOW = Color3.fromRGB(240, 196, 72)
local WHITE = Color3.fromRGB(236, 236, 230)
local CONCRETE = Color3.fromRGB(196, 196, 190)
local SIGN = Color3.fromRGB(10, 110, 62)

-- the street loop: the middle block is x -458..458, z -268..278 (inside the roads)
Roads.highway = { z = -300, width = 64, reach = 838, turnaround = 70, ends = 900 }
Roads.boulevard = { z = 300, width = 44, reach = 502 }
Roads.avenues = { x = 480, width = 44, from = -268, to = 278 }

function Roads.build(ctx)
	local m = Kit.folder(ctx.model, "Streets", "Model")
	local at = ctx.at
	local C = ctx.center
	local rng = ctx.rng
	local hw, bl, av = Roads.highway, Roads.boulevard, Roads.avenues

	Kit.block(m, "Ground", at(0, -2, 0), Vector3.new(1960, 4, 1040), GRASS, Enum.Material.Grass)

	local function road(name: string, cx: number, cz: number, sx: number, sz: number)
		Kit.block(m, name, at(cx, ROAD_TOP - 0.5, cz), Vector3.new(sx, 1, sz), P.asphalt, Enum.Material.Asphalt)
	end
	road("Highway", 0, hw.z, hw.reach * 2, hw.width)
	road("Boulevard", 0, bl.z, bl.reach * 2, bl.width)
	local avLength = av.to - av.from
	for _, s in { -1, 1 } do
		road("Avenue", s * av.x, (av.from + av.to) / 2, av.width, avLength)
		-- the highway's turnarounds: its ends meet each disc at the chord where they just touch
		Kit.block(m, "Turnaround", at(s * hw.ends, ROAD_TOP - 0.5, hw.z) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(1, hw.turnaround * 2, hw.turnaround * 2), P.asphalt, Enum.Material.Asphalt, { Shape = Enum.PartType.Cylinder })
	end

	-- markings: along x (u0..u1 at z) or along z (u0..u1 at x)
	local marks = Kit.folder(m, "Markings", "Model")
	local function lineX(x0, x1, z, color, width)
		Kit.detail(marks, "Line", at((x0 + x1) / 2, ROAD_TOP + 0.02, z), Vector3.new(x1 - x0, 0.04, width or 0.5), color)
	end
	local function lineZ(z0, z1, x, color, width)
		Kit.detail(marks, "Line", at(x, ROAD_TOP + 0.02, (z0 + z1) / 2), Vector3.new(width or 0.5, 0.04, z1 - z0), color)
	end
	local function dashesX(x0, x1, z)
		for u = x0, x1 - 12, 30 do
			lineX(u, u + 12, z, WHITE)
		end
	end
	local function dashesZ(z0, z1, x)
		for u = z0, z1 - 12, 30 do
			lineZ(u, u + 12, x, WHITE)
		end
	end
	for _, s in { -1, 1 } do
		lineX(-hw.reach, hw.reach, hw.z + s * 0.7, YELLOW)
		dashesX(-hw.reach, hw.reach, hw.z + s * 11)
		dashesX(-hw.reach, hw.reach, hw.z + s * 21)
		lineX(-hw.reach, hw.reach, hw.z + s * 30.5, WHITE)
		lineX(-bl.reach, bl.reach, bl.z + s * 0.7, YELLOW)
		dashesX(-bl.reach, bl.reach, bl.z + s * 11)
		for _, a in { -1, 1 } do
			lineZ(av.from, av.to, a * av.x + s * 0.7, YELLOW)
			dashesZ(av.from, av.to, a * av.x + s * 11)
		end
	end
	-- a zebra crossing from the plaza over the Boulevard
	for z = bl.z - bl.width / 2 + 2, bl.z + bl.width / 2 - 2, 3.4 do
		lineX(-7, 7, z, WHITE, 1.7)
	end

	-- sidewalks: a ring round the middle block (the skate loop), and the far sides' curbs
	local walks = Kit.folder(m, "Sidewalks", "Model")
	local function walk(cx, cz, sx, sz)
		Kit.block(walks, "Sidewalk", at(cx, WALK_TOP - 0.5, cz), Vector3.new(sx, 1, sz), P.sidewalk, Enum.Material.Concrete)
	end
	walk(0, 270, 916, 16)
	walk(0, -260, 916, 16)
	walk(-450, 5, 16, 514)
	walk(450, 5, 16, 514)
	walk(0, 330, 1004, 16)
	walk(-510, 27, 16, 590)
	walk(510, 27, 16, 590)

	-- jersey barriers along the highway (gaps where the avenues join it)
	local function barrier(x0, x1, z)
		Kit.block(m, "Barrier", at((x0 + x1) / 2, ROAD_TOP + 1.3, z), Vector3.new(x1 - x0, 2.6, 1.4), CONCRETE, Enum.Material.Concrete)
	end
	local north, south = hw.z - hw.width / 2 + 0.7, hw.z + hw.width / 2 - 0.7
	barrier(-hw.reach, hw.reach, north)
	barrier(-av.x + av.width / 2, av.x - av.width / 2, south)
	for _, s in { -1, 1 } do
		local near, far = av.x + av.width / 2, hw.reach
		barrier(if s > 0 then near else -far, if s > 0 then far else -near, south)
	end

	-- street lamps
	local lamps = Kit.folder(m, "Lamps", "Model")
	for x = -800, 800, 90 do
		Kit.lamp(lamps, C + Vector3.new(x, 0, north - 4), Vector3.zAxis)
	end
	for x = -470, 470, 70 do
		Kit.lamp(lamps, C + Vector3.new(x, WALK_TOP, 335), -Vector3.zAxis)
		Kit.lamp(lamps, C + Vector3.new(x, WALK_TOP, 265), Vector3.zAxis)
	end
	for z = -240, 260, 70 do
		for _, s in { -1, 1 } do
			Kit.lamp(lamps, C + Vector3.new(s * 514, WALK_TOP, z), Vector3.new(-s, 0, 0))
			Kit.lamp(lamps, C + Vector3.new(s * 446, WALK_TOP, z), Vector3.new(s, 0, 0))
		end
	end

	-- two sign gantries over the highway: a green sign over each direction's lanes
	for _, gx in { -360, 360 } do
		for _, z in { north - 2, south + 2 } do
			Kit.block(m, "GantryPost", at(gx, 12, z), Vector3.new(1.2, 24, 1.2), P.metal, Enum.Material.Metal)
		end
		Kit.block(m, "GantryBeam", at(gx, 23, hw.z), Vector3.new(1.6, 1.6, hw.width + 4), P.metal, Enum.Material.Metal)
		-- eastbound keeps right (the south lanes) and meets a sign facing west, and back
		for _, spec in {
			{ z = hw.z + 15, face = -1, text = "EXIT 1 ↘\nFASHION WEEK · IRON PARADISE · PRIZE HALL" },
			{ z = hw.z - 15, face = 1, text = "LARP CITY ←\nYOU'RE NOT LARPING ANYMORE" },
		} do
			local p = C + Vector3.new(gx, 19, spec.z)
			local board = Kit.block(m, "HighwaySign", CFrame.lookAt(p, p + Vector3.new(spec.face, 0, 0)), Vector3.new(26, 7, 0.4), SIGN)
			Kit.label(board, Enum.NormalId.Front, spec.text, { font = Enum.Font.GothamBold, pad = 0.1 })
		end
	end

	-- the skyline: shopfronts facing the Boulevard, towers past the highway, blocks down the sides
	local sky = Kit.folder(m, "Skyline", "Model")
	local x = -490
	while x < 480 do
		local w = 4 * rng:NextInteger(8, 11)
		Buildings.building(sky, C + Vector3.new(x + w / 2, 0, 340), -Vector3.zAxis, w, 36, rng, { floors = rng:NextInteger(3, 7) })
		x += w + 2
	end
	x = -760 -- clear of the turnarounds
	while x < 700 do
		local w = 4 * rng:NextInteger(10, 15)
		Buildings.building(sky, C + Vector3.new(x + w / 2, 0, north - 18), Vector3.zAxis, w, 44, rng, { floors = rng:NextInteger(5, 10) })
		Buildings.filler(sky, { C.X + x + 2, C.Z + north - 110, C.X + x + w - 2, C.Z + north - 66 }, rng)
		x += w + 4
	end
	for _, s in { -1, 1 } do
		local z = -250
		while z < 300 do
			local w = 4 * rng:NextInteger(9, 12)
			Buildings.building(sky, C + Vector3.new(s * 522, 0, z + w / 2), Vector3.new(-s, 0, 0), w, 40, rng, { floors = rng:NextInteger(4, 8) })
			z += w + 3
		end
	end
end

return Roads
