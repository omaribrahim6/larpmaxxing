-- Skateboarding anywhere (Config.Skate): a player hops on (the HUD's Skate button or B) and a
-- board styled by their drip (the Board slot, DripService) goes under their feet (Lib.Board).
-- The rider's client runs the speed, the pushes and the camera (LarpClient.Skate); every
-- client animates every rider from the Skating attribute and each push's SkatePush time
-- (LarpClient.SkateFx). Off the board in a car seat or a larp-off. LARP to Reality's skate
-- kit uses the same board (RealityService).
local Players = game:GetService("Players")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Skate = require(Larp.Config.Skate)
local Net = require(Larp.Shared.Net)
local Board = require(script.Parent.Parent.Lib.Board)

local SkateService = {}

local lastPush: { [Player]: number } = {}
local lastToggle: { [Player]: number } = {}
local told: { [Player]: boolean } = {} -- has had the how-to notice this visit

local function notice(player: Player, text: string, kind: string?)
	Net.get("Notice"):FireClient(player, text, kind or "info")
end

function SkateService:Init(services)
	self.Matches = services.MatchService
	self.Drip = services.DripService
	self.Reality = services.RealityService
end

function SkateService:IsSkating(player: Player): boolean
	local character = player.Character
	return character ~= nil and character:GetAttribute("Skating") == true
end

-- Puts `player` on their board (`on`) or takes them off; `force` skips the checks (LARP to
-- Reality's skate kit). Returns whether they're on it now.
function SkateService:Set(player: Player, on: boolean, force: boolean?): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return false
	end
	if not on then
		Board.remove(character)
		character:SetAttribute("Skating", nil)
		character:SetAttribute("SkatePush", nil)
		return false
	end
	if character:GetAttribute("Skating") == true then
		return true
	end
	if not force then
		if humanoid.Health <= 0 or character:GetAttribute("LarpStance") ~= nil then
			return false
		end
		if humanoid.SeatPart then
			notice(player, Skate.words.seated, "warning")
			return false
		end
		if self.Matches:IsBusy("u" .. player.UserId) or (self.Reality and self.Reality:IsBusy(player)) then
			notice(player, Skate.words.busy, "warning")
			return false
		end
	end
	Board.put(character, self.Drip and self.Drip:BoardStyle(player), Skate.lift)
	character:SetAttribute("Skating", true)
	if not told[player] then
		told[player] = true
		notice(player, Skate.words.on, "success")
	end
	return true
end

-- Rebuilds a rider's board: they picked another deck, or new clothes changed their height.
function SkateService:Restyle(player: Player)
	local character = player.Character
	if character and character:GetAttribute("Skating") == true then
		Board.put(character, self.Drip and self.Drip:BoardStyle(player), Skate.lift)
	end
end

-- A push: everyone's client animates it from the time (the rider's own already has).
function SkateService:_push(player: Player)
	local character = player.Character
	local now = os.clock()
	if not character or character:GetAttribute("Skating") ~= true or now - (lastPush[player] or -math.huge) < Skate.cooldown * 0.8 then
		return
	end
	lastPush[player] = now
	character:SetAttribute("SkatePush", workspace:GetServerTimeNow())
end

function SkateService:Start()
	Net.get("Skate").OnServerEvent:Connect(function(player, on)
		local now = os.clock()
		if type(on) ~= "boolean" or now - (lastToggle[player] or -math.huge) < 0.4 then
			return
		end
		lastToggle[player] = now
		self:Set(player, on)
	end)
	Net.get("SkatePush").OnServerEvent:Connect(function(player)
		self:_push(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastPush[player], lastToggle[player], told[player] = nil, nil, nil
	end)
	-- off the board in a car seat or a larp-off (the stage holds you still)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				if character and character:GetAttribute("Skating") == true then
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					if not humanoid or humanoid.Health <= 0 or humanoid.SeatPart or self.Matches:IsBusy("u" .. player.UserId) then
						self:Set(player, false)
					end
				end
			end
		end
	end)
end

return SkateService
