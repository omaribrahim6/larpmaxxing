-- Invite a friend (Roblox's friend referrals): anyone who joins from a player's invite gets a
-- 2x boost, and so does the player who invited them, once per friend, however they were
-- invited (the HUD's Invite button, a shared clip's link, Roblox's own invite).
-- Services.ReferralService pays it; the HUD's Invite button opens Roblox's invite prompt.
return {
	reward = { boostMinutes = 15 }, -- each side's reward (MonetizationService:Grant)
	maxWaiting = 4, -- rewards an inviter can have waiting for their next visit
	storeName = "LarpReferrals_v1", -- inviter id -> rewards waiting (friends who came while they were away)
	words = {
		joined = "🎁 You came from %s's invite: 2x points for 15 minutes!",
		friendJoined = "🎁 %s joined from your invite: 2x points for 15 minutes!",
		waiting = "🎁 %d friend(s) joined from your invites while you were away: 2x points for %d minutes!",
	},
}
