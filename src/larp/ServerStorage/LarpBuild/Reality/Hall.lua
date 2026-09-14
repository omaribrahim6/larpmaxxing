-- The Prize Hall (LarpBuild.Reality): a grand cream hall north of the plaza, its entrance
-- facing south between marble columns. Inside, a red aisle between rows of seats (a seated
-- audience in some) up to a stage with a podium, red drapes, gold medals on the wall and the
-- banner board over it all, under chandeliers. The gold pedestal in front of the stage has
-- the Accept your prize prompt. Markers for RealityService: PrizeMark (where the laureate
-- stands, facing the audience), PrizeCam (the view from the seats), and the Board.
local Kit = require(script.Parent.Parent.Kit)
local Plot = require(script.Parent.Parent.Locations.Plot)
local Venue = require(script.Parent.Venue)
local Reality = require(game:GetService("ReplicatedStorage"):WaitForChild("Larp").Config.Reality)
local P = Kit.Palette

local Hall = {}

local CREAM = Color3.fromRGB(236, 228, 210)
local WOOD = Color3.fromRGB(70, 46, 34)
local RED = Color3.fromRGB(150, 20, 34)
local NAVY = Color3.fromRGB(20, 28, 56)
local F = Venue.FLOOR

function Hall.build(ctx)
	local m = Kit.folder(ctx.model, "Hall", "Model")
	local at, frame = Venue.frame(ctx, 0, -150, Vector3.zAxis)
	local W, D, H = 120, 100, 36
	Venue.hall(m, at, {
		w = W, d = D, h = H, door = 26,
		floor = WOOD, floorMaterial = Enum.Material.WoodPlanks,
		wall = CREAM, trim = P.gold,
		sign = "THE PRIZE HALL", signColor = P.gold, light = Color3.fromRGB(255, 232, 196),
	})
	local stageTop = F + 4

	-- the stage at the back, its steps at the side, drapes and the banner board
	Kit.block(m, "Stage", at(0, F + 2, 38), Vector3.new(64, 4, 22), WOOD, Enum.Material.WoodPlanks)
	Kit.detail(m, "StageEdge", at(0, stageTop - 0.2, 27), Vector3.new(64, 0.3, 0.3), P.gold, Enum.Material.Neon)
	for k = 1, 5 do
		Kit.block(m, "Step", at(32 + (5 - k) * 2 + 1, F + k * 0.4, 34), Vector3.new(2, k * 0.8, 8), WOOD, Enum.Material.WoodPlanks)
	end
	for _, s in { -1, 1 } do
		Kit.block(m, "Drape", at(s * 34, stageTop + 10, 44), Vector3.new(4, 20, 10), RED, Enum.Material.Fabric)
		local medal = Kit.block(m, "WallMedal", at(s * 22, stageTop + 9, D / 2 - 0.4) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.5, 12, 12), P.gold, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
		medal.Reflectance = 0.2
	end
	local board = Kit.block(m, "Board", at(0, stageTop + 20, D / 2 - 0.6), Vector3.new(60, 12, 0.6), NAVY)
	Kit.label(board, Enum.NormalId.Front, ("THE NOBEL PRIZE IN %s"):format(Reality.prize.field:upper()), { font = Enum.Font.Garamond, color = P.gold, pad = 0.18 })
	Kit.block(m, "Podium", at(-8, stageTop + 1.8, 31), Vector3.new(4, 3.6, 2.4), WOOD, Enum.Material.Wood)
	Kit.detail(m, "PodiumCrest", at(-8, stageTop + 2.4, 29.75), Vector3.new(1.6, 1.6, 0.1), P.gold, Enum.Material.Metal)

	-- where the laureate stands (facing the seats), and the view from the seats
	Venue.marker(m, "PrizeMark", at(0, stageTop, 30))
	local cam = at(6, F + 9, -8).Position
	Venue.marker(m, "PrizeCam", CFrame.lookAt(cam, at(0, stageTop + 3, 30).Position))

	-- the gold pedestal in front of the stage (the prompt)
	local pedestal = Kit.block(m, "Pedestal", at(0, F + 1.5, 22), Vector3.new(2, 3, 2), P.gold, Enum.Material.Metal)
	Kit.detail(m, "Trophy", at(0, F + 4, 22), Vector3.new(1.2, 2, 1.2), P.gold, Enum.Material.Neon, { Shape = Enum.PartType.Ball })
	Venue.prompt(pedestal, "Prize", Reality.words.prize, "The Prize Hall")

	-- the aisle and the seats, some of them taken
	Kit.block(m, "Aisle", at(0, F + 0.05, -12), Vector3.new(8, 0.1, 76), RED, Enum.Material.Fabric)
	local head = -frame.LookVector -- toward the stage
	local seats = {}
	for row = 0, 7 do
		local z = -36 + row * 7
		for _, s in { -1, 1 } do
			for k = 0, 7 do
				local x = s * (7 + k * 4.4)
				Kit.block(m, "Seat", at(x, F + 1.02, z), Vector3.new(2.6, 2.05, 2.4), RED, Enum.Material.Fabric)
				Kit.block(m, "SeatBack", at(x, F + 3.2, z - 1.35), Vector3.new(2.6, 2.6, 0.3), RED, Enum.Material.Fabric)
				if row >= 1 and row <= 6 and ctx.rng:NextNumber() < 0.3 then
					local p = at(x, F + 2.05, z + 0.2).Position
					table.insert(seats, CFrame.lookAt(p, p + head))
				end
			end
		end
	end
	local kinds = { { "BigBrain", "Reader" }, { "Aesthetic", "Friend" }, { "Aesthetic", "Crew" }, { "Drip", "Shopper" }, { "Gains", "Spotter" } }
	Venue.audience(m, "Hall", seats, kinds, ctx.rng, true)

	-- chandeliers
	for _, z in { -30, -5, 20 } do
		Kit.detail(m, "Chain", at(0, H - 3, z), Vector3.new(0.2, 6, 0.2), P.gold, Enum.Material.Metal)
		local bulb = Kit.detail(m, "Chandelier", at(0, H - 7, z), Vector3.new(4, 4, 4), Color3.fromRGB(255, 236, 190), Enum.Material.Neon, { Shape = Enum.PartType.Ball })
		local light = Instance.new("PointLight")
		light.Range = 45
		light.Brightness = 1.6
		light.Color = Color3.fromRGB(255, 226, 180)
		light.Parent = bulb
	end

	-- marble columns at the entrance
	for _, s in { -1, 1 } do
		for _, x in { 17, 26 } do
			Plot.column(m, "Column", at(s * x, 12, -D / 2 - 4).Position, 24, 3, Color3.fromRGB(246, 244, 238), Enum.Material.Marble)
		end
	end
end

return Hall
