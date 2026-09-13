-- Swaps the Car Lot's plain parked cars for the Money scene's expensive ones (owner: larping
-- Money means going to the lot to take selfies with the cars): each spot gets a T5 supercar
-- or a T4 sports car in turn, on the same spot and heading, wheels on the ground. The cars
-- are clones of Larp.Assets.Scenes.Money models, anchored and named ShowCar, so this can be
-- run again (it swaps ShowCars too).
--   require(game.ServerStorage.LarpBuild.CarLotCars).build()
local Money = game:GetService("ReplicatedStorage"):WaitForChild("Larp").Assets.Scenes.Money

local CarLotCars = {}

CarLotCars.models = { "T5_Supercar", "T4_SportsCar" } -- taken in turn, spot by spot

-- what a car may rest on or over: the ground and its markings
local GROUND = { Asphalt = true, ParkingLine = true, ZoneBounds = true, SpawnPoint = true, Ground = true }

-- Whether anything but the ground is inside the car's box.
local function blocked(car: Model): boolean
	local box, size = car:GetBoundingBox()
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { car }
	for _, part in workspace:GetPartBoundsInBox(box * CFrame.new(0, 0.3, 0), size - Vector3.new(0.2, 0.6, 0.2), params) do
		if not GROUND[part.Name] then
			return true
		end
	end
	return false
end

function CarLotCars.build(): string
	local lot = workspace.Larp.Map.CarLot
	local middle = lot:GetBoundingBox().Position
	local spots = {}
	for _, c in lot:GetChildren() do
		if c:IsA("Model") and (c.Name == "ParkedCar" or c.Name == "ShowCar") then
			local cf, size = c:GetBoundingBox()
			table.insert(spots, { cf = cf, bottom = cf.Position.Y - size.Y / 2, old = c })
		end
	end
	-- a fixed order, so a rebuild puts the same car on the same spot
	table.sort(spots, function(a, b)
		local pa, pb = a.cf.Position, b.cf.Position
		return pa.X < pb.X or (pa.X == pb.X and pa.Z < pb.Z)
	end)
	local placed = 0
	for i, spot in spots do
		local template = Money:FindFirstChild(CarLotCars.models[(i - 1) % #CarLotCars.models + 1])
		if template then
			spot.old:Destroy()
			local car = template:Clone()
			car.Name = "ShowCar"
			car:SetAttribute("Model", template.Name)
			local box, size = car:GetBoundingBox()
			-- the new car's box centred on the old spot, same heading, standing on the ground
			local target = CFrame.new(spot.cf.Position.X, spot.bottom + size.Y / 2, spot.cf.Position.Z) * spot.cf.Rotation
			car:PivotTo(target * box:ToObjectSpace(car:GetPivot()))
			for _, d in car:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
				end
			end
			car.Parent = lot
			-- these cars are longer than the spots were made for: slide each along its length
			-- toward the lot's middle until it clears the fence and the lamps (half a stud at a
			-- time, 8 studs at most)
			local long = car:GetBoundingBox().ZVector * Vector3.new(1, 0, 1)
			local step = long.Unit * 0.5 * math.sign(long:Dot(middle - target.Position))
			for _ = 1, 16 do
				if not blocked(car) then
					break
				end
				car:PivotTo(car:GetPivot() + step)
			end
			placed += 1
		end
	end
	return ("%d show cars"):format(placed)
end

return CarLotCars
