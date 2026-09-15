-- Player-facing words, kept together so a reskin can rewrite the voice.
return {
	Stamps = {
		Ate = "ATE",
		Fumbled = "FUMBLED",
		Certified = "CERTIFIED",
		Exposed = "EXPOSED",
		Upset = "UPSET!",
		Viral = "VIRAL MOMENT",
		Draw = "NOBODY ATE",
	},
	LarpOff = "LARP-OFF",
	-- the CCTV monitor and the winner's post (Scene mode "Cctv")
	Cctv = {
		rec = "● REC",
		subject = "SUBJECT: @%s",
		signalLost = "SIGNAL LOST",
		connecting = "CONNECTING…",
		enhance = "ENHANCE",
		likes = "%s likes",
		viral = "🔥 VIRAL",
		app = "flexr",
	},
	PromptAction = "Larp-off",
	Practice = {
		name = "Practice Larper",
		busy = "Every Practice Larper is mid larp-off. Try again in a few seconds.",
		seated = "Hop out first, then larp-off",
		activity = "Finish what you're doing first, then larp-off",
		noStats = "You've got nothing to larp with yet. Grab some Money in the Car Lot first.",
	},
	Challenge = {
		incoming = "%s wants to larp-off",
		sent = "Larp-off sent to %s",
		declined = "%s declined",
		expired = "%s didn't answer",
		notAccepting = "%s isn't taking larp-offs right now",
		cooldown = "Wait %d seconds before challenging %s again",
		busy = "%s is busy",
		queued = "You're #%d in line for the stage",
		youAreBusy = "Finish your current larp-off first",
	},
	UpsetBanner = "UPSET on %s!",
	-- the banner when a legendary item drops (LarpClient.Announcer)
	Legendary = {
		title = "✦ LEGENDARY DROP ✦",
		where = "just dropped %s",
	},
	RewardsLimited = "No bonus: you've already larped-off each other twice in 10 minutes",
	SavingDisabled = "Progress won't save this session",
	-- the shop and codes (MonetizationService)
	Store = {
		boost = "⚡ 2x pickups for %d minutes!",
		thanks = "Thanks! Your pass is active",
		badCode = "That code doesn't exist (or it expired)",
		usedCode = "You've already used that code",
		slow = "Slow down a little",
	},
	-- Touch Grass (RebirthService, and the nameplate's third line)
	TouchGrass = {
		notYet = "Touch Grass unlocks at %s",
		busy = "Finish your larp-off first",
		announce = "🌱 %s touched grass (x%d)!",
		plate = "🌱 Touched Grass x%d",
		titled = "🌱 %s x%d", -- a milestone's title (Config.Cosmetics `grass`)
	},
}
