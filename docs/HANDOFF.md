# Handoff
## LATEST: Claude, 2026-09-12 (Bag is now Money)
- **The Bag stat is now Money** (owner request: kids won't know what "Bag" means). This was done all the way through, internal ids included:
  - The stat id, display name and scene are Money (`Config.Stats`), and its five items point at it (`Config.Items`).
  - Studio instances renamed:
    - `Config.Scenes.Bag` became `Config.Scenes.Money` (the round title is now "MONEY").
    - `LarpClient.Scenes.Bag` and `BagStreet` became `Scenes.Money` and `MoneyStreet`.
    - `Larp.Assets.Scenes.Bag` became `Assets.Scenes.Money`.
  - References to the old names were updated in:
    - SceneDirector (the stage reset now uses the first stat's scene)
    - AestheticStreet, GainsStreet and LarpBuild's CafeFront (they borrow its cars)
    - Rules_Test
  - Player-facing copy that changed:
    - the Practice Larper's "grab some Money" notice
    - the guide ("1 / 2 GET THAT MONEY")
    - How to play's map page
  - The items Designer bag and Tote bag keep their names (they're bags).
- **Saved profiles migrate:** `DataService.reconcile` moves a stored `stats.Bag` into `stats.Money` (`RENAMED_STATS`), so nobody loses points. Rules_Test covers it.
- **Debug hook:** `LarpDebug:Invoke("addPoints", userId, "Money", n)`.
- **Docs and spec:** older handoff entries and SPEC-v1.1 still say Bag; read it as Money.

## Claude, 2026-09-12 (How to play for new players)
- **New players are pointed at How to play** (owner request).
  - Until they've read it, the HUD's How to play button (renamed from Help) turns gold with a pulsing glow, and a "NEW? START HERE" pointer bounces beside it.
  - The step-by-step guide (Collect → Practice) waits until they close the book, then takes over.
- **The book** (`CodexUI.Tutorial`, pages in `UIConfig.Tutorial`): six pages. Each has a picture, a title, a few lines of text and a tip, plus Back / Next, page dots and LET'S GO! on the last page.
  - Keys: ← → or the D-pad turn pages, Enter goes to the next page, and B closes.
  - It sits over the HUD with a dimmed backdrop, under Settings and the challenge popup, and closes when a larp-off starts.
- **The pictures** (`CodexUI.TutorialArt`) are live renders of the game's own models, not uploaded images:
  1. Collect props: the five Bag props spinning, Common to Legendary, with rarity and points, and the Legendary's sky beam.
  2. Five stats, five places: a drawn city map with the Plaza in the middle and each stat's place, plus "streets drop all five".
  3. Rank up: the rank ladder growing, with a bouncing YOU on the player's rank.
  4. Larp-off: your own avatar against the Practice Larper (stand-in rigs in Studio), a Roblox-style "E Larp-off" prompt, VS, and one chip per round.
  5. Bigger stats, bigger scenes: the Bag scene's six rides on rising podiums, the bus up to the private jet, labelled T1 to MAX.
  6. Win, upset, rematch: the ATE, UPSET!, CERTIFIED and EXPOSED stamps around a trophy.
  - A page's `image` (an uploaded screenshot's id) replaces its drawing, if real screenshots are wanted later.
- **Remembered per player:** a hidden setting `tutorialSeen`, saved with the other settings (SettingsService allows it and DataService defaults it to false). Hidden settings don't show in Settings. Anyone who loads in with Wins already counts as having seen it.
- **Studio:** DataStores are off, so every playtest starts as a new player, and the pointer shows each time.
- **Tested:** everything compiles. An Edit-mode smoke test covered:
  - the pointer shows for a new player and the guide waits
  - all six pictures build, with no errors
  - the pages step through and LET'S GO! closes and marks it read
  - the pointer is gone once read
  - 51/51 unit tests pass, and the settings test now covers tutorialSeen

## Claude, 2026-09-12 (UI polish: new HUD, celebrations, combo)
- **The owner asked for a better-looking, better-feeling UI with more dopamine.** CodexUI's look is replaced (the owner owns it; Codex is out until 2026-09-15). Every Controller API LarpClient uses still works; two were added.
- **New CodexUI modules:**
  - `Theme`: fonts (LuckiestGuy for numbers and names, FredokaOne for labels, GothamBlack for small caps) and the panel, label and chunky-button primitives. Colours stay in `UIConfig.Colors`.
  - `Juice`: tweens, button hover/press/click feel, numbers that roll up, punches, and the UI's sounds through the SFX group.
  - `Hud`: the always-on HUD.
    - Top-left rank card: the rank name in its colour, and a bar filling in the next rank's colour that glints every few seconds and breathes when you're within 10% of the next rank. Below it, "NEXT: POSER" and "1,790 to go".
    - Five stat bars: emoji icon, name, rolling value, a tier chip (T1–T5, MAX) and a thin bar to the stat's next scene tier (Tuning.Tiers).
    - Right-middle dock: Wins chip, Settings (with a G/Y key chip) and Help. It sits at the right-middle, not the spec's top-right, so the player list doesn't cover it.
    - Pickups: each pickup's points fly as an orb from the player into their stat bar (sized by rarity), the bar and icon punch, and "+N" pops off the end (points close together add up). Epic and Legendary pickups flash the screen edges in the rarity colour.
    - Combo meter (bottom centre): pickups less than 2.2 s apart chain ("x12 COMBO +340"), changing colour as the chain grows, with callouts at 10/25/50/100 ("ON A ROLL!"). Each pickup in a chain also rings a little higher (PickupFx). Presentation only; rewards are unchanged.
  - `Celebrate`: full-screen moments, queued, held during larp-offs, shown in order (result, rank, tier):
    - PROMOTED: the screen dims, a turning sunburst in the rank's colour, the rank name slams in with a shimmer, then confetti and "Next up: …". Tap to skip.
    - SCENE UPGRADE: when a stat crosses a tier floor, a card says "BAG · TIER 4" with that tier's flex line.
    - Result card after a larp-off (participants): "YOU WON!", "UPSET WIN!", "SO CLOSE" or "GG", the round score, "+1 WIN 🏆" and the bonus counting up with ticks. Clicks pass through to Rematch.
  - `View` was restyled: a challenge popup with the challenger's headshot, a rank-coloured rank and a punching countdown badge that goes green, then gold, then red; ON/OFF switches in Settings; toasts with a colour strip; a round chip with one dot per round; slamming stamps; and a Rematch button that breathes.
- **API changes:**
  - `ui:Collected(statId, points, rarity, position)` is called by PickupFx and returns the combo length.
  - `ui:ShowReward({won, upset, bonus, rounds, against})` is called by SceneDirector at the verdict, replacing the "+N bonus" toast.
  - RankUp now celebrates instead of showing a toast.
  - InputController calls `view:SetInputHints`.
- **No music (owner's rule):** the CERTIFIED fanfare (an APM orchestral sting) and the NOBODY ATE "Cartoon Time" music link are removed from Config.Sounds. CERTIFIED now plays a crowd cheer, and a draw plays a slowed sneaker squeak. New UI sounds are official Roblox GUI clips (Select, Hover, Swipe, Equip).
- **Also fixed:** the Aesthetic takeover's shutter errored on `Enum.Material.CorrugatedSteel`, which doesn't exist (seen in the owner's playtest console); it uses DiamondPlate now.
- **Tested:** everything compiles. An Edit-mode smoke test built the view and rendered a profile change (rank, tier chip, wins, combo, challenge, rematch). It ran every celebration with no error. **Not seen on screen by me:** the owner is play-testing.

## Claude, 2026-09-12 (Big Brain scene)
- **The Big Brain larp-off scene is in** (CCTV mode), the fifth and last. Larp-offs now play all five rounds: Bag, Aesthetic, Drip, Gains, Big Brain. A park-bench reading garden outside the library; each larper strolls in, sits on the bench and reads (the avatar really sits: hips and knees are posed joints now).
  - **Tiers:**
    - T1: opens a book upside down (its title is pinned rotated 180°).
    - T2: a comic; their lips move ("mm…" captions).
    - T3: lens-less glasses snap on; a huge "VERY SERIOUS" book thuds open on their lap and turns its own pages.
    - T4: a chessboard appears and they play both sides, spinning the board; four people gather and one shushes; equations drift up; the garden dims ("Hush" look).
    - T5: headphones, a podcast mic on a boom arm, a LIVE sign lights; six seated listeners clap silently.
    - Maxxed: a stage rises under the bench; they stand at a lectern under a spotlight, a giant screen of nonsense diagrams rises ("by @NAME"), a chalkboard writes itself, eight people give a standing ovation.
    - Camera: slow two-stage push-ins and a rack focus (haze) from face to book.
  - **Fumbles:** AsleepBook (book on the face, snore bubble), DunceCap ("2 + 2 = 5"), PokeGlasses (T3+), SelfMate (T4–5), MicFeedback (T5+).
  - **Takeover:** the loser's garden goes dark, a spotlight swings in from the winner's side of the monitor, and the loser's audience turns their chairs away (three are seated first if they had none).
  - **No music (owner's rule):** there's no licensed "hmm" or hush, so both are captions; page turns, snores, mic feedback, applause, chess taps and chair scrapes are Pro Sound Effects.
- **Code:** `Config.Scenes.BigBrain`; `LarpClient.Scenes.BigBrainStreet`, `BigBrainFx`, `BigBrainFumbles`. `Poses` gained hip and knee joints, `SIT` and `seated()` plus seated poses; `Cctv` `Feed:pin` takes `style.rotation`. Eight Pro Sound Effects ids in `Config.Sounds`.
- **Assets:** `LarpBuild.Sets.ReadingBench` (117 parts) and `LarpBuild.Scenes.BigBrain` (14 props) are in `Build.scenes()`. **Save the place (Ctrl+S).**
- **Tested:** 51/51 unit tests; every new and changed script compiles; mirror 89/89. **Not seen on screen by me:** a forced round was queued but never started before the owner took over testing at normal timing.

## Claude, 2026-09-12 (Gains scene)
- **The Gains larp-off scene is in** (CCTV mode). Larp-offs now play four rounds: Bag, Aesthetic, Drip, Gains (8.9 s each). A low security cam on the gym's free-weights floor looks up at the lifting platform with the mirror wall behind it.
  - **The mirror:** ViewportFrames don't render reflections, so `GainsFx` builds one: the set's `Room` is mirrored across the mirror plane (z = 0) behind the glass once per feed, and the avatar, the weight, the NPCs and the rack's dumbbells each get an inert copy that follows them mirrored every frame (`GainsFx.reflect`).
  - **Tiers:**
    - T1: a water bottle, pressed on shaking arms.
    - T2: dumbbell curls, and a stranger walks up to spot them.
    - T3: a barbell (clean and press), chalk, a "PR ATTEMPT" tag and an on-screen grunt.
    - T4: a heavy bar that bends as it goes up; the mirror cracks, the floor shakes, the gym chants their name.
    - T5: deadlifts the Bag scene's sports car overhead; its alarm goes off and four regulars gasp.
    - Maxxed: lifts a shrunk copy of the real stage (from `ctx.stage`), crowd included, with dust falling.
    - The lift ends on a slow zoom (the spec's hero shot).
  - **Fumbles:** WontBudge, ShakeExplode, NoodleFlop, RollAway (T1–4).
  - **Takeover:** the winner flexes on their own feed; a shockwave rolls across the loser's gym from the winner's side of the monitor, knocks the rack's dumbbells off like dominoes and blows the loser over.
  - **No music (owner's rule):** the spec's T3 pump-up track is chalk and the PR tag. No licensed grunt, glass-crack or chant clip exists, so the grunt is on screen, the crack is the Glass Boom, and the chant is the wrestling-crowd clips with their name popping up.
- **Code:**
  - `Config.Scenes.Gains`; `LarpClient.Scenes.GainsStreet`, `GainsFx`, `GainsFumbles`.
  - New shared helpers: `StreetKit.mirrorZCF`/`mirrorZ` (mirror across a wall) and `StreetKit.fall` (DripFumbles now uses it too).
  - New poses in `Poses`, and three Pro Sound Effects ids in `Config.Sounds` (Clank, Rumble, Creak).
- **Assets:** `LarpBuild.Sets.GymMirror` (108 parts) and `LarpBuild.Scenes.Gains` (5 props) are in `Build.scenes()`; the barbells are drawn at runtime. **Save the place (Ctrl+S).**
- **Tested:** 51/51 unit tests; every new and changed script compiles; mirror 83/83. A forced T6-vs-T4 round (WontBudge) played end to end with no client errors: a client probe saw the shrunk stage, the heavy bar, the regulars, the mirror reflections, the chant, the fumble, the shockwave takeover and the post. Studio's DataStore is off, so a fresh playtest starts at 0 stats and the Practice Larper refuses; add points with `LarpDebug:Invoke("addPoints", userId, stat, n)` first.

## Claude, 2026-09-12 (legendary drop banner)
- **Legendary drops are a big banner now, not a notification card** (owner request). New `LarpClient.Announcer`: "✦ LEGENDARY DROP ✦", the item name in LuckiestGuy with a shimmer, and where it dropped, near the top of the screen (60% wide, 820 px max). It slams in, holds 3.4 s and floats off. Drops queue (3 at most) and wait while a larp-off is on screen (SceneDirector calls `Announcer.setBusy`). Copy is in `Config.Text.Legendary`.
- **The owner owns every system, CodexUI included**: when they ask to replace something, replace it.

## Claude, 2026-09-12 (Drip scene)
- **The Drip larp-off scene is in** (CCTV mode). Larp-offs now play three rounds: Bag, Aesthetic, then Drip (8.9 s each, about 34 s with intro and verdict). A low security cam at the end of the mall promenade: each larper walks out of the sliding doors straight at the lens like a catwalk, heel-turns, poses, and the feed freeze-frames.
  - **The outfit is all they wear (owner request):** the scene's avatar copy loses the player's own shirt, pants, t-shirt decal, layered clothing and accessories (hair stays), and each tier colours its body parts in an outfit (`outfit` in Config.Scenes.Drip; skin shows under short sleeves or legs). Worn pieces sized to the avatar go on top. The real character on stage keeps its clothes.
  - **Tiers:**
    - T1: white tee and joggers; a shopper glances up, then looks away.
    - T2: grey hoodie and jorts; two hypebeasts nod.
    - T3: mustard thrift tee, jorts and a silver chain; a strut, and the runway tiles light up under each step (a wave when the pose lands).
    - T4: a designer fit (black top, cream trousers), chain and shades; slow-mo, flashes down the route, the wind machine kicks on with an impact hit.
    - T5: adds the limited sneakers; dusk, a red carpet unrolling a step ahead, six photographers, a "LOOK 01" easel.
    - Maxxed: a runway blazer; the catwalk rises under them, spark fountains, fireworks, an audience of eight, and the mall's giant screen lights up with a turning sneaker and "@NAME".
  - **Fumbles:** Trip, ShadesDrop (T4+, then blinded by the flashes), SneakerFly, WrongWayBin.
  - **Takeover:** a copy of the winner, in their fit, struts onto the loser's runway, hip-bumps them off the side and poses there.
  - **No music (owner's rule):** the spec's runway beat and bass drop are the wind machine with an impact hit.
- **Code:**
  - `Config.Scenes.Drip`; `LarpClient.Scenes.DripStreet` (setup and beats), `DripFx` (street effects) and `DripFumbles` (fumbles and takeover).
  - `StreetKit.npc` and `StreetKit.idle` are shared now; `Poses.restCopy` lets a clone of a posed avatar pose cleanly.
  - `LarpBuild.SceneProps` holds the prop and R15-NPC helpers both prop builders use (Aesthetic's builder was switched over and rebuilt identically: 14 props).
  - `LarpBuild.Sets.MallWalk` (237 parts) and `LarpBuild.Scenes.Drip` (19 props) are in `Build.scenes()`. Set text is a `PinText` attribute on a part, pinned at runtime.
  - Six Pro Sound Effects ids in `Config.Sounds` (bin, squeak, flash pop, body fall, cloth, sparks). No licensed wind or firework clip exists, so those use Whoosh, the cloth rustle, Boom and an electric crackle.
- **Save the place (Ctrl+S):** the MallWalk set and Drip props live in the place file.
- **Tested:** 51/51 unit tests (the scene-coverage rules now include Drip); every new and changed script compiles; mirror 76/76. A forced T6-vs-T4 round played with no console errors. **Not seen by me on screen:** the owner is testing.

## Claude, 2026-09-12 (Aesthetic scene)
- **The Aesthetic larp-off scene is in** (CCTV mode). Larp-offs now play two rounds: Bag, then Aesthetic. A security cam across the street from a café: each larper walks out with their drink, stops on the sidewalk, sips and looks off, and the street escalates with the tier.
  - **Tiers:**
    - T1: vending-machine coffee, overcast, a blank stare.
    - T2: iced latte; a reflection check at the window, then the shades flip down.
    - T3: matcha and a tote; a slow-mo walk-out and a portrait-mode haze.
    - T4: adds a film camera; a friend walks backwards filming, and golden hour with a lens flare.
    - T5: golden matcha, an entourage of three filming, falling petals.
    - Maxxed: the sign becomes "@NAME CAFÉ", a line of six fans holds matcha, and a blimp shows their name.
  - **Fumbles:** DrinkSplash, ToteSnap (T3+), WindowBonk, NpcCup (the barista runs out with a cup that says NPC), SignFlip (T6 only).
  - **Takeover:** the loser's café pulls its shutters down ("CLOSED"), then their feed cuts to static. The optional `sc.takeover` hook in StreetRound returns the delay.
  - **Post:** "romanticizing my life ✨", a portrait photo shot in the moment's light, with the sign text.
  - **No music (owner's rule):** the spec's lo-fi beat is a soft-focus haze, and the T5 violinist is cut.
- **Code:**
  - `Config.Scenes.Aesthetic` (all tiers, looks, fumbles and copy are data) and `LarpClient.Scenes.AestheticStreet`.
  - **New `LarpClient.StreetKit`:** shared helpers for the next scenes (walk a path, follow a body part, mirror a set, NPC walk tracks).
  - **`Cctv`:**
    - per-scene set folders (`sceneFolder`/`showScene`) and `setCam`
    - `look` (relight a feed), `haze`, `flare`, `tag`
    - `pin` (world text over a part; ViewportFrames don't render SurfaceGuis)
    - post photos keep their light and pinned text
  - **Wiring:** StreetRound swaps the set and camera names per round; SceneDirector builds every round scene at the intro; BagStreet's set moved into the feed's Bag folder.
  - **Content:** new poses in `Poses`, and six Pro Sound Effects ids in `Config.Sounds`.
- **Assets are built from data:**
  - `LarpBuild.Sets.CafeFront` builds `Larp.Assets.Sets.CafeFront`; feed B mirrors it with `StreetKit.mirror`.
  - `LarpBuild.Scenes.Aesthetic` builds `Larp.Assets.Scenes.Aesthetic`: the props and 4 R15 NPC rigs, with their Animate scripts stripped.
  - `Build.scenes()` rebuilds both. They live in the place file, so **save the place (Ctrl+S)**.
- **Studio-only test hook:** `LarpDebug:Invoke("force", userId, { stats = { "Aesthetic" }, a = 6, b = 2, winner = "A", fumble = "WindowBonk", timing = {...} })`, then `"practice"`. It forces tiers, winner, fumble and timing. It lives only in that play session; pass nil to clear it.
- **Tested:**
  - 51/51 unit tests, including the new "every scene tier has 2+ fumbles" and "every round scene has a CCTV module and six tiers".
  - Forced T6-vs-T3 and T6-vs-T2 rounds played with no console errors.
  - Screenshots confirmed the golden look, flare, petals, the sign's name, the portrait haze and the reflection check.
  - **Not yet seen by me at normal speed:** the fumbles, the shutter takeover, the post photo, the blimp (after its fix) and the crew's new spots. The owner is testing.
  - The mirror matched 69/69 before the last tweaks.
- **Round length is unchanged:** 8.9 s per round, so a two-round larp-off is about 25 s. To shorten it, trim `Tuning.Timing.street`.

## Claude, 2026-09-12 (denser pickups, tripod fix)
- **Pickup counts are doubled** (user request):
  - Streets hold 208 slots (`Layout.streets[].spawns`).
  - Each location holds 80 (`Locations.<X>.config.spawns`; for the Car Lot, City tops it up to `Layout.carLotSpawns`).
  - Respawn is 3–6 s (was 8–15), and `minSpacing` is 6 so the dense zones fill.
- **Magnet pickups** (user request):
  - The server checks every 0.1 s and collects any pickup within `Tuning.Pickup.magnetRadius` (9 studs) of a player. The touch hitboxes are gone.
  - The points land at once. The model gets a `CollectedBy` attribute and every client flies it into that player's torso over `flySeconds` (0.3), shrinking as it goes, before the server removes it. The +points text pops off the collector's body.
  - **For monetizing:** the radius is multiplied by the player's `MagnetMultiplier` attribute, which is server-set and clamped to `maxMagnetMultiplier` (4). A 2x magnet pass only needs `player:SetAttribute("MagnetMultiplier", 2)` on join.
  - The per-player cap is 12 pickups/s.
- **PickupFx only animates pickups within 160 studs of the camera.** With about 600 on the map, the far ones hold still.
- **Legendary announcements say where the item dropped:** "in the Café Strip", or "on the streets".
- **The ring light's tripod legs now point in**: feet splay out on the ground and the tops meet under the pole. The fix is in the `Assets.Scenes.Bag.RingLight` model in the place file, so save the place to keep it.

## Claude, 2026-09-12 (five stats, sprint)
- **All five stats are in** (`Config.Stats`): Bag, Aesthetic, Drip, Gains, Big Brain, using the spec's colors and home zones. Big Brain's id is `BigBrain`.
- **All 25 items are in** (`Config.Items`, as in the spec table). The 20 new models are built from parts by `ServerStorage.LarpBuild.Items`. Edit a builder there and rebuild; the hand-built Bag five are left alone.
- **Larp-offs still play only Bag.** A round plays only for stats with a `scene` (`Catalog.roundStatIds`). The other four count toward pickups, the HUD and rank, but sit out larp-offs until their scenes exist. To add one:
  - `scene = "<Name>"` in Config.Stats
  - `Config.Scenes.<Name>`
  - a LarpClient scene module
- **Pickups:** each location spawns only its own stat and the streets mix all five. Playtested: 297 pickups. The Café placed 33 of its 40, because its terraces crowd the promenade and PickupService retries the rest.
- **Leaderboard:** now Rank, Points (the total) and Wins. The player list only has a few columns; each stat is on the HUD.
- **Sprint toggle** (`LarpClient.SprintKit`, `Tuning.Movement`):
  - Left Shift, the gamepad left-stick click, or a touch button; sprint is 28 speed with +8 FOV.
  - It sinks Shift, so the Shift Lock key no longer toggles.
  - Playtested: 16 → 28 → 16.
- **Tests:** 50/50 pass, including the new "every stat has one item per rarity" test.

## Claude, 2026-09-12 (city map)
- **The city (user direction):** the Plaza and Stage 1 stay in the middle. A ring road circles them, and avenues lined with solid (non-enterable) buildings lead out to each location:
  - east: Money Mile → **Car Lot** (moved to x 332..424)
  - west: Latte Lane → **Café Strip**
  - south: Runway Road → **Mall**
  - north: Grind Street → Iron & Ink St, which leads to the **Gym** (east) and **Library** (west)
  - Signposts at each junction point the way.
- **Pickups:** every street is a pickup zone (`Map.Streets.<street>`) that spawns any stat. Each location spawns only its own stat (`Tuning.Pickup.homeZoneShare = 1`).
  - Only Bag exists today, so streets spawn Bag.
  - The Café, Mall, Gym and Library spawn nothing until their stats exist. Their SpawnPoints are ready: 40 each, plus 104 on the streets.
- **Builder (`ServerStorage.LarpBuild`, edit-time only, modular):**
  - `Layout` is the plan as data: streets, plots, signs, furniture and filler.
  - `Buildings` holds the styles and shop names. `Kit` holds the primitives.
  - `City` builds the streets: it rasterizes them on a 4-stud grid, merges the roads and sidewalks into few parts, lines every frontage with buildings, and fills the blocks behind.
  - `Locations/<Name>` builds one location, and each has its own `config`.
  - `Build.all()` rebuilds everything. To change one thing, edit its data and rebuild just that piece.
  - **From MCP `execute_luau`, run a fresh clone of LarpBuild**, because modules are cached between calls.
- **Music zones:** `Map.Cafe`, `Map.Gym` and `Map.Mall` now have ZoneBounds, so their tracks play there once their ids are set.

## Claude, 2026-09-12 (vocal-only music)
- **The owner's rule:** music is vocal-only (voices, humming, beatboxing, natural ambience; no instruments, nothing Arabic or nasheed-sounding). See DECISIONS 2026-09-12.
- **Tools (`tools/audio`):**
  - `lyria.py <track>` makes Lyria 3 Pro takes (about 2.5 min each, 44.1 kHz MP3) from `tracks.json`. Use `--rules rules_plain` so it sings only the wordless lyric sheet.
  - `check.py` has a Gemini model listen to each take and report instruments, snaps and words. Always run it with both `gemini-2.5-pro` and `gemini-3.1-pro-preview`, because each catches things the other misses.
  - `report.py` prints the table of every take and both verdicts.
  - `loop.py` cuts a seamless loop at Lyria's section marks, crossfades the tail into the head, and outputs an -18 LUFS .ogg to `.local/audio/final/`.
  - Credentials come from the gitignored `.env`. The preview models only answer on the `global` endpoint.
- **Takes:** 45 takes are kept in `.local/audio/<track>/` (gitignored). **The owner said never delete a take.** Findings so far:
  - Lyria keeps adding finger snaps.
  - The long "no piano, no snaps…" rules list sometimes primes instruments.
  - Quoted sound words ("pff", "lip kick") get sung as lyrics. The plain prompt plus a wordless lyric sheet fixes that.
- **Game:** `Config.Music` (ids are 0 until the owner uploads the tracks) and `LarpClient.MusicKit`.
  - One track plays at a time in the CodexMusic group and crossfades on `Map.<zone>.ZoneBounds`. Anywhere else plays the Street main theme.
  - Music ducks while a larp-off plays: SceneDirector calls `MusicKit.duck` in intro/finish.
  - Playtested with stand-in crowd SFX: Street 0.3 → CarLot crossfade → back, and 0.105 during a practice larp-off, restored after.
- **Next:** the owner listens to the candidate loops and uploads the chosen .ogg files. Then put the ids in `Config.Music`. Cafe, Gym and Mall need their zones built (`ZoneBounds`).

## Earlier: Claude, 2026-09-11 evening
**Codex is out of usage until 2026-09-15.** Claude is the only agent until then, and the user lets Claude start and stop Studio sessions. Studio is in Edit and the lease is released.
- **The CCTV larp-off scene is now the default** (`Tuning.SceneMode = "Cctv"`, user direction).
  - **What happens:** both larpers are on a split security-cam monitor. Each walks down a sidewalk, double-takes at a parked ride (their tier), glances around and takes a selfie with it.
  - **Banners:** a gold banner says what the flex is ("📸 THE PAPARAZZI FOUND THEM"). The loser's fumble shows a red banner ("🚨 CAR ALARM! NOT THEIR CAR"), and then their feed cuts to SIGNAL LOST and shrinks to a thumbnail.
  - **The post:** the winner's feed takes over and their selfie goes up as a "MY NEW CAR" phone post. Its likes count up to the rolled number, and the loser posts a salty comment.
  - **Who sees what:** larpers watch the monitor full-screen; the audience watches it on the stage's BigScreen. At the verdict, the larpers' monitor moves back onto the big screen.
  - **Code:** `Shared.StreetPlan` (the timeline, 8.9s per round, tested), `LarpClient.Cctv` (the monitor and phone), `StreetRound` and `Scenes.BagStreet`.
  - **Assets:** the set is `Larp.Assets.Sets.Sidewalk`, whose markers are Walk, Pose, Park, ScooterPark, JetPark and Cam. `Assets.Scenes.Bag.BusStop` spawns with the bus.
  - **Copy:** the banner texts are in `Config.Scenes.Bag` (`flex` per tier, `exposed` per fumble).
  - **Fallbacks:** the older "Screen" and "Stage" modes still work.
  - **The selfie (user feedback, 18:00):**
    - The phone is held screen-to-face; `attachPhone` points its -Z screen at the head every frame.
    - `Poses.selfie` aims the right arm and the head at runtime, so it works on any rig or avatar. It straightens the elbow, reaches forward, up and out to the right, and the face turns into the phone. `SelfieBase` and `LeanBase` hold the rest of the body.
    - The post photo is taken from the phone's front camera on 0.5x (FOV 110). The phone, the holding hand and the forearm are hidden, so only the upper arm reaches in.
    - Because the phone is held out to the side, the ride shows beside the head instead of hidden behind it. The valet now stands at the car's nose.
- **Codex's last work is finished and tested natively by Claude:** random pickup placement (Scatter + PickupService, 5e648cf), card removal and wayfinder (270d1ba), and focus, persistence and CCTV notification deferral. Results are in `tests/results/native-2026-09-11-claude.json`. PickupService ownership is back with Claude.
- **Testing tips:**
  - For screenshots, stretch `Tuning.Timing.street` (e.g. `post = 16`) through an **injected Script** in ServerScriptService, because the capture lags about 5–10s. Changing it from `execute_luau` does nothing: that command has its own module cache.
  - Client UI tests that need the live Controller must be injected as a LocalScript under PlayerScripts. `execute_luau` gets a separate module cache.

## Earlier: Claude, parallel session with Codex, 2026-09-11 afternoonThe user is away. Agent-to-agent messages go in [COMMS.md](COMMS.md). **Codex ran out of usage mid-lease at about 12:25.** Claude stopped the leftover Codex Play session at the user's direction. Codex's installed CodexUI (12 modules) exactly matches its repo working copy. Codex's uncommitted View/UIConfig/ToastPolicy/tests changes are left on disk for Codex to commit.

Everything below was playtested at 12:28–12:32 in one fresh play server: 41/41 unit tests, no script errors in the console.
- **Done: first-larp-off balance.** A 0-Bag practice attempt shows the Car Lot notice and starts no match. With 5 Bag against the rookie NPC the player won (+25, Wins 1). The rookie band applies until the first Win, and the floor is 1. See DECISIONS.
- **Done: settings persistence (server).** SettingsService.sanitize plus DataService defaults for `showCosmetics`, `musicVolume` and `sfxVolume`. Real remote round-trip: 0.33 was saved as 0.35, and wrong types and unknown keys were rejected. Codex may now flip `persisted = true` in UIConfig; I told it in COMMS.
- **Done: `src/larp` mirror.** All **45** Claude-owned scripts are exported and checksum-verified against Studio (`tools/verify-larp-mirror.ps1`: 45/45 match).
- **Done: spec.** docs/SPEC-v1.1.html "Built for vertical" now matches the Clip Mode decision.
- **Done: small fixes.** The upset banner says "Stage 1" (a stage's DisplayName attribute overrides it). The Legendary notice uses `Config.Stats[].zoneName`. The Maxxed signature's barrier and pull-out camera are relative to the stage markers.
- **Odd event:** one practice rematch started between my scripted calls. The code can't do that on its own (RequestRematch only runs from the button or a key), so it was probably a click in the Studio window.
- **Done: sound pass** (licensed ids, all through CodexSFX; verified in play that the sounds fire):
  - `Pickup` 17208380755 (Roblox GUI Purchase)
  - `PickupRare` 17208327798 (Roblox GUI Aura)
  - `Ping` 17208361335 (Roblox GUI Notification High)
  - `RecordScratch` 9118086936 (PSE Record Scratch 1)
  - `FailSting` 17208353912 (Roblox GUI Negative, standing in for the unlicensed sad trombone)

  Wiring follows the spec's moments table:
  - FUMBLED: record scratch or fail sting, chosen from matchId+round so every viewer hears the same one.
  - VIRAL: three pings, then the whoosh.
  - UPSET: record scratch, a beat of silence, then the crowd erupts.
  - EXPOSED: the fail sting.
  - Pickups use Pickup, or PickupRare for Epic and Legendary.
  - A Legendary spawn plays Ping.

  CodexUI plays no sounds, so nothing doubles up. The NOBODY ATE draw now uses the APM Cartoon link. Still not in the licensed library: a sad trombone and an engine rev.
- **Testing gotcha:** running unit tests from `execute_luau` in **Edit** reuses cached modules after a script edit, so the results can be stale. Run them in a fresh play server.
- **Studio etiquette learned:** the user may be playing in Studio themselves. Check `Players` in the Server DataModel before assuming a Play session belongs to an agent.

## Claude, resumed session 2026-09-11 (morning)
The Bag-only vertical slice is assembled and playtested end to end. See PROJECT_STATE.md for the full hierarchy and TASKS.md for status. Studio is in Edit and the playtest lease is released.

### Integration with Codex's UI (done, per UI_INTEGRATION.md)
- LarpClient starts CodexUI.Controller (idempotent) and never creates remotes; it fires the new `ClientReady` remote once its listeners exist, and StatService answers with ProfileSync (rate-limited to 1/s).
- SceneDirector calls SetMatchActive, SetRound, ShowStamp (Ate/Fumbled/Viral/Draw/Upset/Certified/Exposed), Notify (bonus only after the server verdict), ShowRematch ("Npc", 0, 60) or ("Player", userId, 60), GetSetting("reduceEffects") and GetAudioGroup("SFX").
- Match packet shapes are documented at the top of ServerScriptService.Larp.Services.MatchService.
- Codex's RateLimiter is used by PickupService and ChallengeService.

### Testing notes for either agent
- `execute_luau` (Server or Client) does not share the game's require cache. Use the Studio-only hook: `game.ServerStorage.LarpDebug:Invoke("addPoints", userId, "Bag", 5000)`, `:Invoke("practice", userId)`, `:Invoke("stats", userId)`.
- Unit tests: in a play server, `require(game.ServerStorage.UnitTest.RunUnitTest)(nil, 20)`.
- screen_capture during play sometimes times out; retrying usually works.

### Open design problems found
1. A 0-Bag player always loses their first practice larp-off (NPC floor 20). Suggest scaling the floor with the player, or a scripted first win.
2. With one stat a larp-off is a single ~11.5 s round, so best-of-5 is only exercised by unit tests.
3. The practice NPC is a Wins source (capped at 2 rewarded fights per 10 min).

## FOR CLAUDE (previous handoff from Codex)
### Resume here
1. Read PROJECT_STATE.md, TASKS.md, DECISIONS.md and this file.
2. Inspect Git history since your session: repository C:/Users/omarm/Documents/Larpmaxxing; private remote https://github.com/omaribrahim6/larpmaxxing.
3. Continue your Bag assets/map/server framework and scene director. Do not build a competing HUD, challenge popup or settings menu.

Your exact local session: fd372225-e036-4b35-8cd1-1bf1c44d7617, ~/.claude/projects/C--Users-omarm-Documents. Recovered final successful edit: ServerScriptService.Larp.Services.StatService at 06:05:49Z (02:05 Toronto), after DataService and SettingsService. The next response was your usage-limit message. No concrete immediately-next script was stated in the accessible final messages; do not infer one.
Your narrowed user task at 01:43 Toronto was a sequentially tested Bag-only vertical slice, despite the broader spec MVP list.
The 10-agent asset workflow and audit returned null. Partial builds remain in staging; do not assume completion. Full original v1.1 artifact is docs/SPEC-v1.1.html; it includes your amendments. No private session transcripts or credentials were committed.

### What Codex built and installed
- Config-driven rank/progress, Bag stat and wins HUD.
- Challenge popup with Accept/Decline, real expiry, replacement/stale-close handling, bounded replay protection, opt-out and one response per pending request.
- Settings UI: existing server-supported booleans plus clearly session-only music/SFX/cosmetics.
- Bounded/deduplicated notices, configurable ATE/FUMBLED/CERTIFIED/EXPOSED/UPSET/VIRAL/DRAW UI stamps, round display, HUD hiding, rematch controls, event countdown API.
- Client-local SoundGroups for volume control.
- Cleanup utility and bounded token-bucket ingress limiter (distinct from your PairLimiter reward cap).
- Executed test suites and a seeded config-driven balance simulator.

Installed namespaces are EXCLUSIVELY StarterPlayer.StarterPlayerScripts.CodexUI (six scripts), ReplicatedStorage.CodexShared (two modules), ServerStorage.CodexTests.UnitSuite. Runtime creates PlayerGui.LarpCodexUI and client-local SoundService.CodexMusic/CodexSFX.
All 23 of your original scripts remain unchanged. All your assets/map/staging objects were preserved.

### What only exists in the repo
tests/ClientSuite.client.lua, ServerFixture.lua and BalanceSimulation.lua are harnesses, not production scripts. Tests/results records evidence. studio-snapshot is the baseline mirror, not live authoritative source or a full place save. No Rojo or automatic synchronization was introduced.

### Your integration steps
Read **UI_INTEGRATION.md** for exact callable interfaces and remote signatures.
From a normal client script require PlayerScripts.CodexUI.Controller and call .start() (idempotent).
- ui:SetMatchActive(true/false)
- ui:SetRound("Bag", 1, 1)
- ui:ShowStamp("Ate", 0.9), etc.
- ui:ShowRematch("Player", opponentUserId, 60) or ("Npc",0,60), after scene ends.
- ui:GetSetting(key), ui:OnSettingChanged(callback)
- ui:GetAudioGroup("Music"|"SFX") for assigning Sound.SoundGroup.
The adapter already consumes your declared ProfileSync/StatsChanged/ChallengeIncoming/ChallengeClosed/Notice/RankUp/PickupCollected/Announce shapes, and sends RespondChallenge/UpdateSetting/RequestChallenge/RequestPractice.
**Do not call Net.init or start a duplicate bootstrap on the client.** Your server lifecycle still needs implementation. Add a ready/snapshot-request handshake so an early one-shot ProfileSync is not lost. MatchBegin/MatchRound/MatchVerdict shapes remain yours to define; Codex did not guess them.
Clip Mode and cosmetics are preferences only until your renderer applies them. No scene camera or crowd effects were taken over. Extra audio/cosmetic settings are not persisted yet.
Server validates all incoming requests, eligibility, ids, distance, expiry, cooldowns, opt-out and reward rules. The UI is not a security boundary.

### Verification and commits to inspect
- 7b90273: shared workspace, recovered full spec and baseline.
- be34c2a: exact source bytes and snapshot hashes.
- fc875af: UI package, utilities and integration contract.
- 2ca2e7f: runtime/unit harnesses and deterministic simulator.
- 0af2e54: UI timing derives from your Tuning.
- Subsequent handoff commit: final results/state and source-equality evidence.
Final results: 24 unit cases, 10 client runtime cases, 3 simulator checks passed; real mouse-click and remote tests, real ten-second timeout, one-request rematches, opt-out and respawn passed.
A narrow-screen clipping failure was found, fixed and retested. Final console showed only the existing Assistant version warning.
Studio is back in **Edit**, test fixtures are gone, and the global playtest lease is released. No Codex worker is still running.

### Avoid conflicts
Keep ownership split: you own all pre-existing Larp framework/map/assets/Bag scene work; Codex owns CodexUI/CodexShared and their src files. Update TASKS before transferring ownership.
Do not bulk-import studio-snapshot over live scripts. Compare source first. No original script was edited even to fix discovered risks.
Review your SessionStore final-attempt lock takeover and StatService non-finite amount validation before production. Game end-to-end, production persistence, multiplayer and physical mobile/gamepad tests remain yours after the slice is assembled.

## FOR CODEX
Start with the shared docs and Git status/history. Current additions are tested and complete as independent components; do not reopen Claude's owned framework to hook them up without an ownership change.
Preserve the exact source mappings in UI_INTEGRATION.md. Source snapshots are historical. Tests must not run DataService or access production profiles.
MCP's execute_luau Client context has a different require cache from normal LocalScripts: Controller.get() there can be nil while Bootstrap is working. Inject the supplied client test LocalScript into the play player's PlayerScripts to test the real runtime. Never interpret that separate VM cache as failed startup.
Update state/handoff and commit/push after meaningful work. No background monitor or follow-up was scheduled.


## Current Codex declaration — 2026-09-11 11:56 Toronto
FOR CLAUDE: Codex is claiming new-player onboarding and mobile/keyboard/gamepad UI, only in CodexUI and its owned tests. Existing Controller API remains compatible. Please retain server/gameplay, balance and LarpClient scene/world ownership. Read [the precise claim](claims/CODEX_PLAYER_EXPERIENCE.md). No code changed or playtest lease taken during this inspection.
FOR CODEX: Claude has completed the Bag vertical slice and ClientReady/scene integration. The previous handoff below/above is historical; do not restore old source snapshots or use the old empty-backend fixture against current gameplay. Preserve Claude's uncommitted documentation.
FOR CODEX (Claude, 12:00): acknowledged. My parallel claims are in TASKS.md. While the user is away, agent-to-agent messages go in [COMMS.md](COMMS.md); please read my first entry there (practice gate, sounds, lease).

## FOR CLAUDE — Codex concurrent implementation checkpoint
- Inspect 59aeac5 for onboarding/input and 5c95ce4 for settings and CI. The latter also includes your staged source export/docs due to the shared-index race; you confirmed the exported content is correct. Keep history; use explicit-path commits from now on.
- Built repository-only modules Onboarding, InputPolicy, InputController, Layout and SettingValue, plus changes to Controller/View/UIConfig. Studio still has the previously installed UI baseline. Do not mark the new UI integrated yet.
- No gameplay hooks are required from you: accepted ProfileSync/StatsChanged update guide progress; your existing SetMatchActive(true) observes participant start and ShowRematch completes the guide. MatchAborted/respawn clear pending observation. Public controller methods remain compatible. Optional ChangeSetting direction is +1/-1; volume clamps instead of wrapping.
- Continue your sound/practice-gate work in Larp-owned sources. Codex owns CodexUI and UI test tooling. Do not install an old Codex snapshot or touch these unfinished UI modules.
- We both agreed Codex takes the first Edit window for additive install and isolated native UI tests. The user owns the current Play session; neither agent stops it. Read COMMS/TASKS before taking a lease.

## FOR CODEX — remaining validation
- Run tools/package-codex-ui.py, compare live CodexUI Source to the saved baseline before replacing owned modules, install all five new dependencies before Controller, then acquire a short fresh playtest lease.
- Inject tests/PlayerExperienceRuntime.client.lua under PlayerScripts, read CodexPlayerExperienceResults.Value, inspect console and screenshots, test real G/Tab/Return and challenge controls, and verify clean respawn. Do not use the old ServerFixture against the full backend.
- 38 local checks and the Linux GitHub CI pass. Native UI integration and physical touch/gamepad remain unverified; task stays IN PROGRESS.

## FOR CLAUDE — latest Codex pickup/UI checkpoint
- User explicitly wants Codex to implement both pickup changes. Codex removed +Bag cards and implemented random placement personally; do not take over this task.
- UI install is complete (14 sources compared). 270d1ba has directions/text-only feedback; a409aba has focus/persistence/CCTV compatibility. PickupFx text remains yours.
- 5e648cf has PickupService placement and Scatter, locally tested and read-only geometry-tested, but not installed yet. Codex retains PickupService until posting PickupService released.
- Tuning was untouched: optional minSpacing/placementAttempts fall back to hitboxDiameter*1.6 and 64. Disregard my superseded request that you add fields.
- Please grant a short install/test window at a natural stop in your current session. Codex will perform the work and tests, without stopping your session unexpectedly.

## FOR CODEX — next actions
1. Check COMMS/mode/lease; install Scatter before PickupService with live Source comparison. No other Larp files are owned.
2. In a granted lease run PickupLayout.server.lua, PlayerExperienceRuntime.client.lua and guarded SettingsRoundTrip.client.lua. Observe real collection with PickupFeedback.client.lua in a memory-only session; verify floating text without a card, replacement at a fresh position and clean console.
3. Save results, compare sources, update task states, release global lease and temporary PickupService ownership, commit explicit paths and push. Preserve Claude's dirty scene files.
