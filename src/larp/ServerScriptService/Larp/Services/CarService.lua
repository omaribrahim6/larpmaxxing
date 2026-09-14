-- Drivable cars (Config.Cars, built by Lib.CarRig): spawns a player's car, sits them in its
-- driver's seat and hands them its physics (LarpClient.Drive drives it), and tows it once
-- it's been empty for Config.Cars.leaveSeconds. One car each; only its owner can drive it
-- (a Drive prompt on the car lets them back in), and friends can hop in the passenger seat.
-- Cars and characters don't collide, so nobody gets run over, but cars hit each other.
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Cars = require(Larp.Config.Cars)
local Sounds = require(Larp.Config.Sounds)
local Net = require(Larp.Shared.Net)
local CarRig = require(script.Parent.Parent.Lib.CarRig)

local CarService = {}

local TAG = "LarpCar"
local CAR_GROUP = "LarpCar"
local CHARACTER_GROUP = "LarpCharacter"
local cars: { [Player]: Model } = {}

local function register(name: string)
	if not PhysicsService:IsCollisionGroupRegistered(name) then
		PhysicsService:RegisterCollisionGroup(name)
	end
end

local function group(model: Instance, name: string)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = name
		end
	end
end

function CarService:Init() end

function CarService:Get(player: Player): Model?
	return cars[player]
end

function CarService:Despawn(player: Player)
	local car = cars[player]
	cars[player] = nil
	if car then
		car:Destroy()
	end
end

-- The player's humanoid, if they're alive.
local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return if humanoid and humanoid.Health > 0 then humanoid else nil
end

-- Sits the owner in the driver's seat and gives them the car's physics.
function CarService:Enter(player: Player): boolean
	local car = cars[player]
	local seat = car and car:FindFirstChild("DriverSeat") :: VehicleSeat?
	local humanoid = humanoidOf(player)
	if not seat or not humanoid or seat.Occupant then
		return false
	end
	humanoid.Sit = false
	seat:Sit(humanoid)
	-- the car stays still until the driver is in and owns it (Drive's springs hold it up)
	CarRig.release(car)
	for _, d in car:GetDescendants() do
		if d:IsA("BasePart") and not d.Anchored and d:CanSetNetworkOwnership() then
			d:SetNetworkOwner(player)
		end
	end
	return true
end

-- A fresh car `id` at `cframe` for `player` (their old one is towed), with them at the wheel.
function CarService:Spawn(player: Player, id: string, cframe: CFrame): Model?
	if not Cars.cars[id] or not humanoidOf(player) then
		return nil
	end
	self:Despawn(player)
	local car = CarRig.build(id, cframe)
	car.Name = player.Name .. "_" .. id
	car:SetAttribute("OwnerId", player.UserId)
	group(car, CAR_GROUP)
	CollectionService:AddTag(car, TAG)
	local seat = car:FindFirstChild("DriverSeat") :: VehicleSeat
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DrivePrompt"
	prompt.ActionText = "Drive"
	prompt.ObjectText = Cars.cars[id].name
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = seat
	local horn = Instance.new("Sound")
	horn.Name = "Horn"
	horn.SoundId = "rbxassetid://" .. tostring(Sounds.CarHorn)
	horn.Volume = 0.9
	horn.RollOffMinDistance = 15
	horn.RollOffMaxDistance = 220
	horn.Parent = car.PrimaryPart
	car.Parent = self.folder
	cars[player] = car

	-- only the owner drives; an empty car waits a while, then it's towed
	local left = 0
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occupant = seat.Occupant
		local owner = humanoidOf(player)
		if occupant and occupant ~= owner then
			occupant.Sit = false
			local weld = seat:FindFirstChild("SeatWeld")
			if weld then
				weld:Destroy()
			end
			return
		end
		prompt.Enabled = occupant == nil
		left += 1
		local mine = left
		if occupant == nil then
			-- parked where they left it, once the driver's springs have let it settle
			task.delay(1.2, function()
				if left == mine and cars[player] == car and seat.Occupant == nil then
					for _, d in car:GetDescendants() do
						if d:IsA("BasePart") then
							d.Anchored = true
						end
					end
				end
			end)
			task.delay(Cars.leaveSeconds, function()
				if left == mine and cars[player] == car and seat.Occupant == nil then
					self:Despawn(player)
				end
			end)
		end
	end)
	self:Enter(player)
	return car
end

function CarService:Start()
	register(CAR_GROUP)
	register(CHARACTER_GROUP)
	PhysicsService:CollisionGroupSetCollidable(CAR_GROUP, CHARACTER_GROUP, false)
	local larp = workspace:WaitForChild("Larp")
	self.folder = larp:FindFirstChild("Cars") or Instance.new("Folder")
	self.folder.Name = "Cars"
	self.folder.Parent = larp

	-- characters go in their own group, so cars pass through people
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			group(character, CHARACTER_GROUP)
			character.DescendantAdded:Connect(function(d)
				if d:IsA("BasePart") then
					d.CollisionGroup = CHARACTER_GROUP
				end
			end)
		end)
		if player.Character then
			group(player.Character, CHARACTER_GROUP)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		self:Despawn(player)
	end)

	-- the horn: played from the driver's car on the server, so everyone nearby hears it
	local honked: { [Player]: number } = {}
	Net.get("CarHorn").OnServerEvent:Connect(function(player)
		local car = cars[player]
		local seat = car and car:FindFirstChild("DriverSeat") :: VehicleSeat?
		if not seat or seat.Occupant ~= humanoidOf(player) or os.clock() - (honked[player] or 0) < 0.6 then
			return
		end
		honked[player] = os.clock()
		local horn = car.PrimaryPart and car.PrimaryPart:FindFirstChild("Horn") :: Sound?
		if horn then
			horn:Play()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		honked[player] = nil
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name ~= "DrivePrompt" then
			return
		end
		local car = prompt:FindFirstAncestorWhichIsA("Model")
		while car and not CollectionService:HasTag(car, TAG) do
			car = car.Parent and car.Parent:FindFirstAncestorWhichIsA("Model")
		end
		if not car then
			return
		end
		if car:GetAttribute("OwnerId") == player.UserId then
			self:Enter(player)
		else
			local owner = Players:GetPlayerByUserId(car:GetAttribute("OwnerId") or 0)
			Net.get("Notice"):FireClient(player, ("That's %s's car. Hop in the passenger side!"):format(if owner then owner.DisplayName else "someone"), "warning")
		end
	end)
end

return CarService
