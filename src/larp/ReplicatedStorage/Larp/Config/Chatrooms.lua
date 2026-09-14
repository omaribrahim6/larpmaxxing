-- The LARP chatrooms (LarpBuild.Chatrooms builds them; LarpClient.Chatrooms turns their
-- boards): lounges along the outer ring where players sit on the sofas and larp about the
-- topic on the board. Every board shows the same topic at the same time (it comes from the
-- server clock) and changes every `rotateSeconds`. Each room has its own pickup zone, so the
-- long skate out there pays.
--   at: the room's middle; facing: the way its open front looks (toward the street)
local rgb = Color3.fromRGB

return {
	seed = 31,
	rotateSeconds = 120,
	spawns = 10, -- pickups inside a room
	size = Vector3.new(46, 15, 38), -- width, height, depth; the front is open
	wall = rgb(64, 58, 78),
	floor = rgb(126, 92, 64),
	woodDark = rgb(74, 52, 38),
	words = { topic = "TOPIC" },

	rooms = {
		{
			id = "Matcha", name = "MATCHA LOUNGE", icon = "🍵",
			at = Vector3.new(-300, 0, 599), facing = Vector3.new(0, 0, -1),
			color = rgb(132, 196, 96), sofa = rgb(92, 122, 86),
			topics = { "Is matcha a personality?", "Oat milk or nothing", "The café you'd be seen dead in", "Latte art: skill or luck?" },
		},
		{
			id = "GroupChat", name = "THE GROUP CHAT", icon = "💬",
			at = Vector3.new(300, 0, 599), facing = Vector3.new(0, 0, -1),
			color = rgb(255, 120, 190), sofa = rgb(120, 70, 110),
			topics = { "Who's the biggest larper here?", "Best excuse you've ever used", "Rate the last fit you saw", "Say your most controversial take" },
		},
		{
			id = "GymTalk", name = "GYM TALK", icon = "💪",
			at = Vector3.new(300, 0, -599), facing = Vector3.new(0, 0, 1),
			color = rgb(255, 96, 80), sofa = rgb(110, 62, 56),
			topics = { "Natty or not?", "Cardio: necessary evil?", "Your worst gym excuse", "Does the mirror pump count?" },
		},
		{
			id = "ReadingRoom", name = "THE READING ROOM", icon = "🧠",
			at = Vector3.new(-300, 0, -599), facing = Vector3.new(0, 0, 1),
			color = rgb(176, 132, 255), sofa = rgb(86, 74, 120),
			topics = { "Books you've only pretended to read", "Is the audiobook cheating?", "Explain your podcast opinion", "Smartest thing you've said this week" },
		},
		{
			id = "FitCheck", name = "FIT CHECK CORNER", icon = "👟",
			at = Vector3.new(599, 0, -200), facing = Vector3.new(-1, 0, 0),
			color = rgb(255, 198, 64), sofa = rgb(120, 96, 48),
			topics = { "Best fit in the room", "Baggy or fitted?", "The piece you overpaid for", "Thrifted or brand new?" },
		},
		{
			id = "CarMeet", name = "CAR MEET CAFÉ", icon = "🏎️",
			at = Vector3.new(599, 0, 200), facing = Vector3.new(-1, 0, 0),
			color = rgb(80, 200, 255), sofa = rgb(56, 96, 120),
			topics = { "Rent or own?", "Loud exhaust: yes or no?", "The car you'd larp in", "Is the T4 underrated?" },
		},
		{
			id = "LateNight", name = "LATE NIGHT CHAT", icon = "🌙",
			at = Vector3.new(-599, 0, 0), facing = Vector3.new(1, 0, 0),
			color = rgb(120, 140, 255), sofa = rgb(62, 70, 120),
			topics = { "Best thing about 3am", "Your fake deep thought of the day", "Would you touch grass for a million?", "The last thing you lied about" },
		},
	},
}
