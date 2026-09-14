-- LarpCoins (Config.Drip): earned in larp-offs (MatchService pays through LarpOff) and spent on
-- drip (DripService). The balance lives in the profile (`coins`) and on the player as the
-- LarpCoins attribute, which the HUD and the Drip shop show.
local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Drip = require(Larp.Config.Drip)
local Net = require(Larp.Shared.Net)

local CoinService = {}
CoinService.ATTRIBUTE = "LarpCoins"

function CoinService:Init(services)
	self.Data = services.DataService
end

local function show(player: Player, data)
	player:SetAttribute(CoinService.ATTRIBUTE, data.coins or 0)
end

function CoinService:Get(player: Player): number
	local data = self.Data:Get(player)
	return if data then data.coins or 0 else 0
end

-- Adds `amount` (whole, above 0) coins; returns the new balance, or nil without a profile.
function CoinService:Add(player: Player, amount: number): number?
	local data = self.Data:Get(player)
	amount = math.floor(tonumber(amount) or 0)
	if not data or amount <= 0 then
		return nil
	end
	data.coins = (data.coins or 0) + amount
	show(player, data)
	return data.coins
end

-- Takes `amount` coins if the player has them; returns whether it did.
function CoinService:Spend(player: Player, amount: number): boolean
	local data = self.Data:Get(player)
	amount = math.floor(tonumber(amount) or 0)
	if not data or amount < 0 or (data.coins or 0) < amount then
		return false
	end
	data.coins = (data.coins or 0) - amount
	show(player, data)
	return true
end

-- What a larp-off pays (Config.Drip.earn): the winner's and the loser's coins. `winner` is
-- "A", "B" or "Draw" (a draw pays both the loser's share); against the Practice Larper
-- (`practice`) both are scaled by practiceShare.
function CoinService.payout(winner: string, upset: boolean, practice: boolean): (number, number)
	local E = Drip.earn
	local scale = if practice then E.practiceShare else 1
	local function round(x: number): number
		return math.floor(x * scale + 0.5)
	end
	if winner == "Draw" then
		return round(E.loss), round(E.loss)
	end
	return round(E.win + (if upset then E.upset else 0)), round(E.loss)
end

-- Pays both sides of a finished larp-off (A and B are MatchService combatants). Nothing when
-- the same pair has been paid too often lately (`allowed` false).
function CoinService:LarpOff(A, B, winner: string, upset: boolean, allowed: boolean)
	if not allowed then
		return
	end
	local practice = A.kind == "Npc" or B.kind == "Npc"
	local won, lost = CoinService.payout(winner, upset == true, practice)
	local W, L = A, B
	if winner == "B" then
		W, L = B, A
	end
	for _, pay in { { W, won }, { L, lost } } do
		local c, amount = pay[1], pay[2]
		if c.kind == "Player" and c.player.Parent and self:Add(c.player, amount) then
			Net.get("Notice"):FireClient(c.player, Drip.words.earned:format(amount), "success")
		end
	end
end

function CoinService:Start()
	self.Data.ProfileLoaded:Connect(function(player, data)
		show(player, data)
	end)
end

return CoinService
