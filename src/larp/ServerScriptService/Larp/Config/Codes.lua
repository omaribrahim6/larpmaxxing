-- Codes players redeem in the shop (MonetizationService). Server-only, so nobody can read
-- them off the client. Keys are upper case with no spaces; players can type them any way.
-- Each code works once per player.
--   boostMinutes: a 2x pickup boost for that long (added onto one that's running)
--   expires:      optional os.time() after which the code stops working
return {
	LARPMAXXING = { boostMinutes = 15 }, -- the launch code
}
