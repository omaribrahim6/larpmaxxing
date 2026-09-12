# Handoff
## LATEST: Claude, 2026-09-12 (city map)
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
