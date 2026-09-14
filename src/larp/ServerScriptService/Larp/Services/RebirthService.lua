-- Touch Grass (spec "Touch Grass (rebirth)"): at the top rank a player can log off and touch
-- grass. Every stat goes back to 0 (so the rank back to the first), Wins and everything else
-- stay, and a farming bonus grows with each rebirth (Shared.RebirthMath, Tuning.TouchGrass;
-- PickupService applies it). The client asks with the TouchGrass remote; the server checks
-- the rank and that the player isn't in a larp-off.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Larp = ReplicatedStorage:WaitForChild("Larp")
local Catalog = require(Larp.Shared.Catalog)
local RebirthMath = require(Larp.Shared.RebirthMath)
local Tuning = require(Larp.Config.Tuning)
local Text = require(Larp.Config.Text)
local Net = require(Larp.Shared.Net)
local RateLimiter = require(ReplicatedStorage:WaitForChild("CodexShared"):WaitForChild("RateLimiter"))

local RebirthService = {}
local limiter = nil

function RebirthService:Init(services)
	self.Stats = services.StatService
	self.Matches = services.MatchService
	self.Cosmetics = services.CosmeticService
end

-- A player's farming bonus from their rebirths (1 before the first).
function RebirthService:Multiplier(player: Player): number
	return RebirthMath.multiplier(self.Stats:GetRebirths(player), Tuning.TouchGrass)
end

function RebirthService:_request(player: Player)
	if not limiter:Allow(player, 1) then
		return
	end
	if self.Stats:GetRankIndex(player) < #Catalog.ranks then
		Net.get("Notice"):FireClient(player, Text.TouchGrass.notYet:format(Catalog.ranks[#Catalog.ranks].name), "warning")
		return
	end
	if self.Matches:IsBusy("u" .. player.UserId) then
		Net.get("Notice"):FireClient(player, Text.TouchGrass.busy, "warning")
		return
	end
	local count = self.Stats:TouchGrass(player)
	if not count then
		return
	end
	self.Cosmetics:Refresh(player) -- a milestone's item goes on at once
	Net.get("TouchedGrass"):FireClient(player, count, RebirthMath.multiplier(count, Tuning.TouchGrass))
	-- everyone else gets a toast; the player has the full-screen moment
	local announce = Text.TouchGrass.announce:format(player.DisplayName, count)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Net.get("Announce"):FireClient(other, announce)
		end
	end
end

function RebirthService:Start()
	limiter = RateLimiter.new(1, 0.2, 200)
	Players.PlayerRemoving:Connect(function(player)
		limiter:Remove(player)
	end)
	Net.get("TouchGrass").OnServerEvent:Connect(function(player)
		self:_request(player)
	end)
end

return RebirthService
