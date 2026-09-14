-- The LARP lounges (LarpBuild.Chatrooms builds them; LarpClient.Quiz drives their screens):
-- rooms along the outer ring where people sit and talk. Each one is a subject you can actually
-- larp about — something with enough depth that claiming to be well versed in it is a real
-- claim — and each has a screen on the back wall running a quiz on that subject (Config.Quiz),
-- which is how the room finds out who's really into it and who's larping.
--
-- A lounge is a chill spot on purpose: no pickups spawn inside one, and nothing is dropped
-- there. The only thing to earn in here is the quiz.
--   at: the room's middle; facing: the way its open front looks (toward the street)
--   name: the subject, shown on the sign, the screen and the map — nothing else
--   subject: the key into Config.Quiz.banks; stat: what winning its quiz feeds
--
-- The 14 rooms sit just outside the outer ring (LarpBuild.Layout), four along each of the long
-- walls and three down each side. To add one, pick a free spot on a wall at least 60 studs
-- from its neighbours, give it a bank in Config.Quiz, and rebuild.
local rgb = Color3.fromRGB

return {
	seed = 31,
	size = Vector3.new(46, 15, 38), -- width, height, depth; the front is open
	wall = rgb(64, 58, 78),
	floor = rgb(126, 92, 64),
	woodDark = rgb(74, 52, 38),

	rooms = {
		-- the south wall, looking back at the city
		{
			id = "Geography", name = "GEOGRAPHY", icon = "🌍", subject = "Geography", stat = "BigBrain",
			at = Vector3.new(-450, 0, 599), facing = Vector3.new(0, 0, -1),
			color = rgb(96, 196, 140), sofa = rgb(78, 118, 96),
		},
		{
			id = "History", name = "HISTORY", icon = "📜", subject = "History", stat = "BigBrain",
			at = Vector3.new(-150, 0, 599), facing = Vector3.new(0, 0, -1),
			color = rgb(214, 176, 110), sofa = rgb(112, 94, 62),
		},
		{
			id = "Philosophy", name = "PHILOSOPHY", icon = "🧠", subject = "Philosophy", stat = "BigBrain",
			at = Vector3.new(150, 0, 599), facing = Vector3.new(0, 0, -1),
			color = rgb(176, 132, 255), sofa = rgb(86, 74, 120),
		},
		{
			id = "Literature", name = "LITERATURE", icon = "📚", subject = "Literature", stat = "BigBrain",
			at = Vector3.new(450, 0, 599), facing = Vector3.new(0, 0, -1),
			color = rgb(198, 128, 96), sofa = rgb(104, 70, 54),
		},
		-- the north wall
		{
			id = "Anime", name = "ANIME", icon = "🍥", subject = "Anime", stat = "BigBrain",
			at = Vector3.new(-450, 0, -599), facing = Vector3.new(0, 0, 1),
			color = rgb(255, 120, 190), sofa = rgb(120, 70, 110),
		},
		{
			id = "Film", name = "FILM", icon = "🎬", subject = "Film", stat = "Aesthetic",
			at = Vector3.new(-150, 0, -599), facing = Vector3.new(0, 0, 1),
			color = rgb(240, 214, 140), sofa = rgb(110, 96, 64),
		},
		{
			id = "Music", name = "MUSIC", icon = "🎧", subject = "Music", stat = "Aesthetic",
			at = Vector3.new(150, 0, -599), facing = Vector3.new(0, 0, 1),
			color = rgb(120, 140, 255), sofa = rgb(62, 70, 120),
		},
		{
			id = "Art", name = "ART", icon = "🎨", subject = "Art", stat = "Aesthetic",
			at = Vector3.new(450, 0, -599), facing = Vector3.new(0, 0, 1),
			color = rgb(244, 140, 190), sofa = rgb(120, 74, 98),
		},
		-- the east side
		{
			id = "Fashion", name = "FASHION", icon = "👟", subject = "Fashion", stat = "Drip",
			at = Vector3.new(599, 0, -300), facing = Vector3.new(-1, 0, 0),
			color = rgb(255, 198, 64), sofa = rgb(120, 96, 48),
		},
		{
			id = "Cars", name = "CARS", icon = "🏎️", subject = "Cars", stat = "Money",
			at = Vector3.new(599, 0, 0), facing = Vector3.new(-1, 0, 0),
			color = rgb(80, 200, 255), sofa = rgb(56, 96, 120),
		},
		{
			id = "Football", name = "FOOTBALL", icon = "⚽", subject = "Football", stat = "Gains",
			at = Vector3.new(599, 0, 300), facing = Vector3.new(-1, 0, 0),
			color = rgb(110, 214, 120), sofa = rgb(62, 110, 70),
		},
		-- the west side
		{
			id = "Space", name = "SPACE", icon = "🚀", subject = "Space", stat = "BigBrain",
			at = Vector3.new(-599, 0, -300), facing = Vector3.new(1, 0, 0),
			color = rgb(140, 160, 255), sofa = rgb(66, 76, 126),
		},
		{
			id = "Coffee", name = "COFFEE", icon = "☕", subject = "Coffee", stat = "Aesthetic",
			at = Vector3.new(-599, 0, 0), facing = Vector3.new(1, 0, 0),
			color = rgb(186, 134, 92), sofa = rgb(96, 70, 50),
		},
		{
			id = "Tech", name = "TECH", icon = "💻", subject = "Tech", stat = "BigBrain",
			at = Vector3.new(-599, 0, 300), facing = Vector3.new(1, 0, 0),
			color = rgb(96, 214, 230), sofa = rgb(56, 108, 118),
		},
	},
}
