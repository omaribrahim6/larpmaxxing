-- The lounge quiz (QuizService runs it, LarpClient.Quiz draws it): a Kahoot-style round on the
-- lounge's subject, played on the big screen everyone in the room can see while each player
-- answers on their own screen. It's there to sort the larpers from the rest, so the questions
-- are the basics and the jargon — the things someone pretending to be into it would fumble.
--
-- A bank is a list of { q, a = { four answers }, correct = index }. The first answer is the
-- right one here; QuizService shuffles the four before it sends them, so the order a player
-- sees is never the order written down.
local rgb = Color3.fromRGB

local Quiz = {}

Quiz.minPlayers = 2 -- two people have to be in the lounge and ready
Quiz.questions = 6 -- questions in a round
Quiz.lobbySeconds = 30 -- how long a lobby waits for company
Quiz.readySeconds = 8 -- once enough are ready, the countdown drops to this
Quiz.answerSeconds = 14
Quiz.revealSeconds = 4
Quiz.resultsSeconds = 12
Quiz.base = 100 -- points for a right answer
Quiz.speedBonus = 100 -- on top, scaled by how much time was left
Quiz.coins = { win = 25, second = 12, played = 4 }
Quiz.points = { win = 400, played = 120 } -- the lounge subject's stat

-- The four answer tiles, in order: shape and colour are the same on the wall and in your hand,
-- so you can answer by shape without reading (Kahoot's whole trick). All four shapes are drawn
-- from plain frames (LarpClient.Quiz), never glyphs, so none of them can land as a blank box.
Quiz.choices = {
	{ shape = "Circle", color = rgb(226, 46, 62), key = Enum.KeyCode.One },
	{ shape = "Diamond", color = rgb(30, 110, 210), key = Enum.KeyCode.Two },
	{ shape = "Square", color = rgb(226, 160, 20), key = Enum.KeyCode.Three },
	{ shape = "Ring", color = rgb(42, 154, 62), key = Enum.KeyCode.Four },
}

Quiz.words = {
	play = "START A QUIZ",
	idle = "PRESS E TO START A QUIZ",
	needPlayers = "Two people have to be sitting in here to start a quiz.",
	waiting = "WAITING FOR LARPERS",
	ready = "READY",
	starting = "STARTING",
	correct = "CORRECT",
	wrong = "NOT A LARPER",
	answered = "LOCKED IN",
	tooLate = "TOO SLOW",
	results = "WHO WAS ACTUALLY LARPING",
	winner = "CERTIFIED",
	abandoned = "Everyone left. Quiz cancelled.",
	noQuiz = "There's no quiz running in here.",
	sitFirst = "Sit down in the lounge first.",
}

Quiz.banks = {
	Geography = {
		{ q = "Which country's flag is a plain red circle on white?", a = { "Japan", "South Korea", "Bangladesh", "Laos" } },
		{ q = "What is the capital of Australia?", a = { "Canberra", "Sydney", "Melbourne", "Perth" } },
		{ q = "What is the capital of Canada?", a = { "Ottawa", "Toronto", "Vancouver", "Montreal" } },
		{ q = "Which country has the most time zones?", a = { "France", "Russia", "the USA", "China" } },
		{ q = "Which country completely surrounds Lesotho?", a = { "South Africa", "Namibia", "Botswana", "Zimbabwe" } },
		{ q = "A country with no coastline is called what?", a = { "Landlocked", "Enclosed", "Inland", "Sealed" } },
		{ q = "Which flag is a white cross on a red square?", a = { "Switzerland", "Denmark", "Norway", "Georgia" } },
		{ q = "Which is the largest country by area?", a = { "Russia", "Canada", "China", "the USA" } },
		{ q = "Which continent has no permanent residents?", a = { "Antarctica", "Oceania", "Greenland", "Siberia" } },
		{ q = "Mount Everest sits on the border of Nepal and which country?", a = { "China", "India", "Bhutan", "Pakistan" } },
		{ q = "Which river runs through Cairo?", a = { "the Nile", "the Congo", "the Niger", "the Tigris" } },
		{ q = "What does a cartographer make?", a = { "Maps", "Globes", "Compasses", "Atlas covers" } },
	},
	Anime = {
		{ q = "What does a seiyuu do?", a = { "Voice acting", "Storyboards", "Animation", "Music" } },
		{ q = "Shonen is aimed at which audience?", a = { "Teenage boys", "Adult men", "Teenage girls", "Young children" } },
		{ q = "What does OVA stand for?", a = { "Original Video Animation", "Open Visual Arc", "Overseas Anime", "Official Vocal Album" } },
		{ q = "A mangaka is a what?", a = { "Manga artist", "Voice actor", "Studio owner", "Translator" } },
		{ q = "Roughly how many episodes is one cour?", a = { "About 12", "About 4", "About 26", "About 50" } },
		{ q = "Isekai stories are about what?", a = { "Being taken to another world", "High school clubs", "Giant robots", "Cooking duels" } },
		{ q = "What does an anime's OP mean?", a = { "The opening theme", "The original plot", "The other protagonist", "The opening pose" } },
		{ q = "Seinen is aimed at which audience?", a = { "Adult men", "Teenage boys", "Young children", "Adult women" } },
		{ q = "What is a filler episode?", a = { "One not in the source manga", "A recap episode", "The last episode", "A bonus short" } },
		{ q = "What does sakuga describe?", a = { "A burst of high-end animation", "A slow episode", "An art book", "A fan edit" } },
		{ q = "What does tsundere describe?", a = { "Cold outside, warm underneath", "Always cheerful", "Silent and deadly", "Clumsy and shy" } },
		{ q = "What does SoL stand for?", a = { "Slice of Life", "Speed of Light", "Sound of Laughter", "Season of Love" } },
	},
	Philosophy = {
		{ q = "Who said \"I think, therefore I am\"?", a = { "Descartes", "Plato", "Kant", "Hume" } },
		{ q = "Epistemology is the study of what?", a = { "Knowledge", "Being", "Beauty", "Right and wrong" } },
		{ q = "Who wrote The Republic?", a = { "Plato", "Aristotle", "Socrates", "Cicero" } },
		{ q = "Utilitarianism judges an act by what?", a = { "Its consequences", "Its intention", "Its tradition", "Its beauty" } },
		{ q = "Who taught Plato?", a = { "Socrates", "Aristotle", "Pythagoras", "Zeno" } },
		{ q = "Nihilism is the belief that what?", a = { "Nothing has built-in meaning", "Everything is fated", "Only reason matters", "Pleasure is the good" } },
		{ q = "Ontology is the study of what?", a = { "Being and existence", "Language", "Numbers", "History" } },
		{ q = "Stoicism says to focus on what?", a = { "What you can control", "What you can own", "What you can prove", "What you can feel" } },
		{ q = "Who wrote Thus Spoke Zarathustra?", a = { "Nietzsche", "Kierkegaard", "Hegel", "Schopenhauer" } },
		{ q = "An a priori claim is known how?", a = { "Before experience", "Only by experiment", "By majority vote", "By revelation" } },
		{ q = "What is a syllogism?", a = { "An argument from two premises", "A trick question", "A famous quote", "A logical error" } },
		{ q = "Ethics is the study of what?", a = { "Right and wrong", "Knowledge", "Reality", "Art" } },
	},
	Film = {
		{ q = "What does a director of photography control?", a = { "Camera and lighting", "The script", "The edit", "The music" } },
		{ q = "What is a MacGuffin?", a = { "An object that drives the plot", "A camera move", "A lighting rig", "A stunt double" } },
		{ q = "Diegetic sound is what?", a = { "Sound the characters can hear", "Sound added later", "The score", "A sound effect" } },
		{ q = "What does the 180-degree rule keep consistent?", a = { "Screen direction", "Lighting colour", "Shot length", "Frame rate" } },
		{ q = "Who is the gaffer on a set?", a = { "The chief lighting technician", "The camera operator", "The script supervisor", "The stunt coordinator" } },
		{ q = "What does mise-en-scène mean?", a = { "Everything arranged in the frame", "The final cut", "The opening shot", "The sound mix" } },
		{ q = "What is a rough cut?", a = { "The first assembled edit", "A deleted scene", "An unlit take", "A test screening" } },
		{ q = "Films are usually shot at how many frames a second?", a = { "24", "30", "12", "60" } },
		{ q = "What is colour grading?", a = { "Adjusting colour after the shoot", "Picking the set paint", "Lighting the actors", "Choosing costumes" } },
		{ q = "A dolly zoom changes what while the camera moves?", a = { "The focal length", "The aperture", "The frame rate", "The shutter angle" } },
		{ q = "What does cutting on action mean?", a = { "Cutting mid-movement", "Cutting on a line", "Cutting to black", "Cutting the last frame" } },
		{ q = "The third act of a story is the what?", a = { "Resolution", "Setup", "Confrontation", "Prologue" } },
	},
	Music = {
		{ q = "What does BPM stand for?", a = { "Beats per minute", "Bars per measure", "Bass pitch mode", "Beat pattern mix" } },
		{ q = "How many strings does a standard bass guitar have?", a = { "Four", "Six", "Five", "Three" } },
		{ q = "A cappella means what?", a = { "Voices with no instruments", "Very quiet", "Sung in a chapel", "Sung in unison" } },
		{ q = "How many notes are in an octave, black keys included?", a = { "Twelve", "Eight", "Seven", "Ten" } },
		{ q = "What does reverb add to a sound?", a = { "A sense of space", "Distortion", "Speed", "Pitch" } },
		{ q = "What is a bridge in a song?", a = { "A contrasting section", "The first chorus", "The intro", "The fade-out" } },
		{ q = "How many beats are in a bar of 4/4?", a = { "Four", "Three", "Eight", "Two" } },
		{ q = "What does sampling mean?", a = { "Reusing part of a recording", "Recording live", "Writing a hook", "Tuning a track" } },
		{ q = "What is falsetto?", a = { "Singing above your normal range", "Singing very quietly", "Singing off key", "Singing in harmony" } },
		{ q = "What does DAW stand for?", a = { "Digital Audio Workstation", "Direct Amp Wiring", "Dynamic Audio Wave", "Drum And Wind" } },
		{ q = "A minor key usually sounds how?", a = { "Sad", "Bright", "Loud", "Fast" } },
		{ q = "What does a producer mainly do?", a = { "Shapes and oversees the recording", "Writes the lyrics", "Designs the cover", "Books the venue" } },
	},
	Cars = {
		{ q = "What spins a turbocharger?", a = { "Exhaust gases", "The battery", "A belt", "The gearbox" } },
		{ q = "What does RWD mean?", a = { "Rear-wheel drive", "Rapid wheel damping", "Rear wing down", "Road width dynamic" } },
		{ q = "Torque is a measure of what?", a = { "Turning force", "Top speed", "Fuel use", "Weight" } },
		{ q = "What does a differential let the wheels do?", a = { "Turn at different speeds", "Steer themselves", "Brake separately", "Change camber" } },
		{ q = "Understeer is when the car does what?", a = { "Pushes wide at the front", "Slides at the back", "Lifts a wheel", "Stalls in a corner" } },
		{ q = "What does a rear spoiler add?", a = { "Downforce", "Horsepower", "Fuel economy", "Ground clearance" } },
		{ q = "What does DOHC stand for?", a = { "Double overhead camshaft", "Direct output heat control", "Dual oil handling circuit", "Down-force optimised hood cowl" } },
		{ q = "What is the redline?", a = { "The engine's top safe rpm", "The speed limit", "The brake wear mark", "The tyre temperature" } },
		{ q = "What does the clutch do?", a = { "Disconnects engine from gearbox", "Slows the wheels", "Feeds fuel", "Cools the engine" } },
		{ q = "Camber is the wheel's what?", a = { "Tilt from vertical", "Width", "Pressure", "Offset" } },
		{ q = "What does a 0-60 time measure?", a = { "Acceleration", "Braking", "Cornering", "Top speed" } },
		{ q = "Heel-and-toe means doing what at once?", a = { "Braking and blipping the throttle", "Steering and braking", "Clutching and handbraking", "Shifting and indicating" } },
	},
	History = {
		{ q = "The Roman Republic became an empire under whom?", a = { "Augustus", "Julius Caesar", "Nero", "Hadrian" } },
		{ q = "The Magna Carta was sealed in which century?", a = { "The 13th", "The 11th", "The 15th", "The 17th" } },
		{ q = "What was the Silk Road?", a = { "A trade route network", "A Roman highway", "A royal title", "A peace treaty" } },
		{ q = "Which empire built Machu Picchu?", a = { "The Inca", "The Aztec", "The Maya", "The Olmec" } },
		{ q = "The printing press in Europe is credited to whom?", a = { "Gutenberg", "Da Vinci", "Galileo", "Luther" } },
		{ q = "What does BCE stand for?", a = { "Before Common Era", "Before Christian Empire", "Basic Calendar Epoch", "Before Colonial Era" } },
		{ q = "The Berlin Wall came down in which decade?", a = { "The 1980s", "The 1960s", "The 1970s", "The 1990s" } },
		{ q = "Hieroglyphs were deciphered using which stone?", a = { "The Rosetta Stone", "The Stone of Scone", "The Blarney Stone", "The Philosopher's Stone" } },
		{ q = "A primary source is what?", a = { "A first-hand record", "A textbook", "A modern summary", "A museum label" } },
		{ q = "The Industrial Revolution began in which country?", a = { "Britain", "Germany", "France", "the USA" } },
		{ q = "What was feudalism built on?", a = { "Land held in return for service", "Elected councils", "Paid armies", "Free trade" } },
		{ q = "Which ancient city was buried by Vesuvius?", a = { "Pompeii", "Carthage", "Troy", "Athens" } },
	},
	Literature = {
		{ q = "What is a protagonist?", a = { "The main character", "The villain", "The narrator", "The author" } },
		{ q = "An unreliable narrator is one who what?", a = { "Can't be trusted to tell it straight", "Speaks in the third person", "Dies at the end", "Never appears" } },
		{ q = "What is a metaphor?", a = { "Saying one thing is another", "A direct comparison using 'like'", "An exaggeration", "A sound word" } },
		{ q = "Iambic pentameter has how many beats a line?", a = { "Ten", "Eight", "Twelve", "Six" } },
		{ q = "Who wrote Pride and Prejudice?", a = { "Jane Austen", "Emily Bronte", "Mary Shelley", "George Eliot" } },
		{ q = "What is a sonnet's usual length?", a = { "14 lines", "8 lines", "20 lines", "12 lines" } },
		{ q = "What does 'in medias res' mean?", a = { "Starting mid-story", "Ending abruptly", "A story within a story", "Told backwards" } },
		{ q = "What is foreshadowing?", a = { "Hinting at what's to come", "Repeating a line", "A flashback", "A moral lesson" } },
		{ q = "Who wrote Nineteen Eighty-Four?", a = { "George Orwell", "Aldous Huxley", "Ray Bradbury", "H.G. Wells" } },
		{ q = "What is alliteration?", a = { "Repeating the opening sound", "Rhyming line ends", "A false rhyme", "A rhythm break" } },
		{ q = "A bildungsroman follows what?", a = { "A character growing up", "A crime being solved", "A war", "A journey home" } },
		{ q = "What is the denouement?", a = { "The tying up after the climax", "The opening scene", "The turning point", "The subplot" } },
	},
	Art = {
		{ q = "Who painted the ceiling of the Sistine Chapel?", a = { "Michelangelo", "Raphael", "Da Vinci", "Botticelli" } },
		{ q = "Impressionism is known for what?", a = { "Loose brushwork and light", "Sharp realism", "Flat blocks of colour", "Religious scenes only" } },
		{ q = "What is chiaroscuro?", a = { "Strong light and shadow", "Layered glaze", "A drawing grid", "A frame style" } },
		{ q = "What medium is fresco painted on?", a = { "Wet plaster", "Stretched canvas", "Wood panel", "Paper" } },
		{ q = "Cubism is most associated with whom?", a = { "Picasso", "Monet", "Rembrandt", "Turner" } },
		{ q = "What are the primary colours in paint?", a = { "Red, yellow, blue", "Red, green, blue", "Cyan, magenta, yellow", "Black, white, grey" } },
		{ q = "What is a still life?", a = { "A painting of objects", "A portrait", "A landscape", "A sketch study" } },
		{ q = "Surrealism draws on what?", a = { "Dreams and the unconscious", "Machines", "Geometry", "Classical myth" } },
		{ q = "What does 'en plein air' mean?", a = { "Painted outdoors", "Painted from memory", "Painted in one sitting", "Painted on glass" } },
		{ q = "What is the vanishing point?", a = { "Where perspective lines meet", "The darkest area", "The frame's centre", "The signature corner" } },
		{ q = "What is a triptych?", a = { "A work in three panels", "A three-colour print", "A trio of artists", "A third study" } },
		{ q = "Which is a printmaking technique?", a = { "Etching", "Glazing", "Modelling", "Gilding" } },
	},
	Football = {
		{ q = "How many players per side are on the pitch?", a = { "Eleven", "Ten", "Twelve", "Nine" } },
		{ q = "How often is the men's World Cup held?", a = { "Every four years", "Every two years", "Every year", "Every five years" } },
		{ q = "What is offside judged against?", a = { "The second-last defender", "The halfway line", "The goalkeeper", "The penalty box" } },
		{ q = "How long is a standard match, not counting stoppages?", a = { "90 minutes", "80 minutes", "100 minutes", "60 minutes" } },
		{ q = "What is a hat-trick?", a = { "Three goals by one player", "Three assists", "Three clean sheets", "Three saves" } },
		{ q = "A penalty is taken from how far out?", a = { "Twelve yards", "Eighteen yards", "Six yards", "Ten yards" } },
		{ q = "What does a clean sheet mean?", a = { "Conceding no goals", "Winning away", "No bookings", "A shutout win by three" } },
		{ q = "What shape is a false nine's role?", a = { "A striker dropping deep", "A wide defender", "A holding midfielder", "A second keeper" } },
		{ q = "Two yellow cards in a match mean what?", a = { "A sending off", "A penalty", "A warning", "A substitution" } },
		{ q = "What is a nutmeg?", a = { "Putting the ball through someone's legs", "A backheel goal", "A diving header", "A long throw" } },
		{ q = "How many substitutes are usually allowed in a league match?", a = { "Five", "Three", "Seven", "Unlimited" } },
		{ q = "What does VAR stand for?", a = { "Video Assistant Referee", "Verified Attack Review", "Variable Added Round", "Visual Appeal Rule" } },
	},
	Space = {
		{ q = "Which planet is closest to the Sun?", a = { "Mercury", "Venus", "Mars", "Earth" } },
		{ q = "What is a light year a measure of?", a = { "Distance", "Time", "Brightness", "Speed" } },
		{ q = "What holds a planet in orbit?", a = { "Gravity", "Magnetism", "Solar wind", "Air pressure" } },
		{ q = "Which planet has the Great Red Spot?", a = { "Jupiter", "Saturn", "Mars", "Neptune" } },
		{ q = "What is a nebula?", a = { "A cloud of gas and dust", "A dead star", "A small moon", "A comet's tail" } },
		{ q = "The Sun is what kind of object?", a = { "A star", "A planet", "A nebula", "A black hole" } },
		{ q = "What is the event horizon?", a = { "A black hole's point of no return", "The edge of the solar system", "A star's surface", "The end of an orbit" } },
		{ q = "Which galaxy are we in?", a = { "The Milky Way", "Andromeda", "Triangulum", "Sombrero" } },
		{ q = "What causes a solar eclipse?", a = { "The Moon passing in front of the Sun", "Earth's shadow on the Moon", "A sunspot", "A planet transit" } },
		{ q = "What is a light-minute roughly the distance of?", a = { "The Sun to Earth in eight of them", "One orbit of Mars", "The Moon's diameter", "A galaxy's width" } },
		{ q = "What is redshift a sign of?", a = { "Something moving away", "Something heating up", "Something exploding", "Something rotating" } },
		{ q = "What is a supernova?", a = { "An exploding star", "A new planet", "A double star", "A comet strike" } },
	},
	Coffee = {
		{ q = "An espresso shot is roughly how much liquid?", a = { "About 30ml", "About 100ml", "About 5ml", "About 250ml" } },
		{ q = "What is crema?", a = { "The foam on an espresso", "Steamed milk", "A milk alternative", "A roast level" } },
		{ q = "The two main coffee species are Arabica and what?", a = { "Robusta", "Liberica", "Excelsa", "Typica" } },
		{ q = "A flat white differs from a latte how?", a = { "Less milk, finer foam", "More syrup", "No espresso", "Served cold" } },
		{ q = "What does a burr grinder do better than a blade?", a = { "Grinds evenly", "Grinds faster", "Grinds quieter", "Grinds hotter" } },
		{ q = "What is a pour-over?", a = { "Hand-brewed through a filter", "Espresso with hot water", "Cold steeped overnight", "Boiled in a pot" } },
		{ q = "Coffee 'cherries' are what?", a = { "The fruit the beans grow in", "A flavour note", "A roast stage", "A cup size" } },
		{ q = "A darker roast generally has what?", a = { "Less acidity", "More caffeine by weight", "More fruit notes", "A lighter body" } },
		{ q = "What is cold brew?", a = { "Steeped in cold water for hours", "Espresso over ice", "Chilled filter coffee", "Iced with milk" } },
		{ q = "What does a barista's tamper do?", a = { "Compresses the grounds", "Heats the water", "Froths the milk", "Measures the dose" } },
		{ q = "Under-extracted coffee tastes how?", a = { "Sour and thin", "Bitter and harsh", "Sweet and heavy", "Salty" } },
		{ q = "What is a macchiato?", a = { "Espresso marked with a little milk", "Half coffee, half milk", "Coffee with cream on top", "A double espresso" } },
	},
	Tech = {
		{ q = "What does CPU stand for?", a = { "Central Processing Unit", "Core Power Unit", "Central Program Utility", "Computed Process Update" } },
		{ q = "What is RAM used for?", a = { "Short-term working memory", "Permanent storage", "Cooling", "Networking" } },
		{ q = "What does an IP address identify?", a = { "A device on a network", "A website's owner", "A file type", "A password" } },
		{ q = "What is open source software?", a = { "Its code is public to read and change", "It is always free of charge", "It has no licence", "It runs in a browser" } },
		{ q = "What does a compiler do?", a = { "Turns source code into machine code", "Finds bugs", "Runs tests", "Formats code" } },
		{ q = "What is the cloud, really?", a = { "Someone else's servers", "A satellite network", "Local storage", "A type of cable" } },
		{ q = "What does HTTPS add over HTTP?", a = { "Encryption", "Speed", "Compression", "Caching" } },
		{ q = "What is a binary digit called?", a = { "A bit", "A byte", "A node", "A pixel" } },
		{ q = "How many bits are in a byte?", a = { "Eight", "Four", "Sixteen", "Ten" } },
		{ q = "What does an API let programs do?", a = { "Talk to each other", "Run faster", "Store files", "Render graphics" } },
		{ q = "What is latency?", a = { "The delay before a response", "The amount of data", "The download speed", "The error rate" } },
		{ q = "What does version control track?", a = { "Changes to code over time", "Server uptime", "User logins", "Disk space" } },
	},
	Fashion = {
		{ q = "What does a garment's silhouette mean?", a = { "Its overall shape", "Its colour", "Its fabric", "Its price" } },
		{ q = "Haute couture means what?", a = { "Made to measure by hand", "Made in bulk", "Sold second hand", "Designed by a computer" } },
		{ q = "What makes selvedge denim different?", a = { "It has a finished edge", "It is stretchy", "It is dyed twice", "It is waterproof" } },
		{ q = "What is a capsule wardrobe?", a = { "A few pieces that all match", "A season's whole collection", "A locked display case", "A rented outfit" } },
		{ q = "What does drape describe?", a = { "How fabric hangs", "How bright a colour is", "How tight a fit is", "How rare a piece is" } },
		{ q = "Dressing monochrome means what?", a = { "One colour throughout", "Black and white only", "No patterns", "All denim" } },
		{ q = "What is a raw hem?", a = { "An unfinished edge", "A double stitch", "A folded cuff", "A taped seam" } },
		{ q = "What does OOTD stand for?", a = { "Outfit of the day", "One of the drip", "Out of the drawer", "Off overnight to donate" } },
		{ q = "A pea coat is what kind of garment?", a = { "A short wool coat", "A long raincoat", "A knitted vest", "A padded gilet" } },
		{ q = "What is gorpcore?", a = { "Outdoor gear worn as fashion", "Suits worn loose", "All-black tailoring", "Vintage sportswear" } },
		{ q = "Tailoring refers to what?", a = { "Structured, fitted clothing", "Printed graphics", "Loose knitwear", "Distressed denim" } },
		{ q = "What is a colourway?", a = { "A colour version of a design", "A runway order", "A dye technique", "A shop display" } },
	},
}

return Quiz
