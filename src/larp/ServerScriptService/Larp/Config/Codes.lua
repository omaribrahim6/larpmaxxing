-- Codes players redeem in the shop (MonetizationService). Server-only, so nobody can read
-- them off the client. Keys are upper case with no spaces; players can type them any way.
-- Each code works once per player.
--   boostMinutes: a 2x pickup boost for that long (added onto one that's running)
--   pass:         a pass key from Config.Store, given for good (it lands in the profile's
--                 `granted`, so it comes back on every join) and makes them a supporter
--   expires:      optional os.time() after which the code stops working
return {
	LARPMAXXING = { boostMinutes = 15 }, -- the launch code
	REAL1TYAWA1TS = { pass = "Reality" }, -- owner 2026-09-15: hands over LARP to Reality
}
