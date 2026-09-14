-- Accounts that own passes without buying them (server-only, like Codes): the game's owner
-- and anyone else the owner adds. On every join MonetizationService grants these, saves them
-- in the profile (`granted`) and makes the account a supporter. The place's creator always
-- gets LARP to Reality too.
--   [userId] = { pass keys (Config.Store) }
return {
	[2065214055] = { "Reality" }, -- the owner (owner request 2026-09-14: always able to test Reality)
}
