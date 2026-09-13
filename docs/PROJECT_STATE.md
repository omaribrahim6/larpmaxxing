# Project state
Updated September 11, 2026 by Claude, at the end of the resumed session (Bag vertical slice assembled and playtested).

## Live Studio and repository
Studio d820b236-d917-475d-b27f-ed5faa20ce7a: Untitled Experience, placeId 140202351497067. In **Edit**, playtest lease released.
Repository: C:/Users/omarm/Documents/Larpmaxxing; private remote https://github.com/omaribrahim6/larpmaxxing.
Studio is the live, authoritative source for all Claude-owned scripts and assets. studio-snapshot/ still holds only the 23-script baseline from before this session; it is now out of date for Claude's files (compare against Studio, never import it).

## What the vertical slice does (Bag stat only)
Collect Bag props in the Car Lot, rank up, walk to the Practice Larper (or another player) and larp-off. Every round plays the Bag scene (six escalating tiers, the winner's takeover, the loser's fumble), then a verdict (UPSET!, CERTIFIED, EXPOSED), rewards, and a rematch offer. Profiles are session-locked and saved when DataStores are available; in Studio without API access they fall back to memory with a "Session progress only" notice.

## Claude-owned hierarchy
- ReplicatedStorage.Larp.Config: Game, Stats (Bag only), Rarities, Items, Ranks, Tuning, Text, Sounds, Scenes/Bag.
- ReplicatedStorage.Larp.Shared: Catalog, Resolver, Tiers, RankMath, PairLimiter, Format, ClimbPlan, SceneRules, Net (19 remotes incl. ClientReady), Signal.
- ReplicatedStorage.Larp.Assets.Items: MonopolyMoney, FakeWatch, RentedCarKeys, DesignerBag, BlackCard.
- ReplicatedStorage.Larp.Assets.Scenes.Bag: T1_Bus, T2_EScooter, T3_Hatchback, T4_SportsCar, T5_Supercar (scissor doors), T6_PrivateJet (airstairs both sides), MoneyCounter, Pigeon, RingLight, Valet, Paparazzi, StreetBarrier, TowTruck, Phone.
- ServerScriptService.Larp: Main (bootstrap; Studio-only LarpDebug hook), Lib/{SessionStore, Combatant}, Services/{DataService, SettingsService, StatService, NameplateService, MatchService, ChallengeService, PickupService, PracticeNpcService}.
- StarterPlayer.StarterPlayerScripts.LarpClient (LocalScript) + SoundKit, PickupFx, ChallengePrompts, SceneKit, Poses, Crowd, SceneDirector, Scenes/Bag.
- Workspace.Larp.Map: Plaza, Road, CarLot (SpawnPoints x40, ZoneBounds), PracticeNpcSpot. Workspace.Larp.Stages.Stage1: Markers, Set, Stands, Crowd (12 mannequins), BillboardL/R, SpotlightL/R. Workspace.Larp.Pickups is filled at runtime. Workspace.LarpStaging is empty.
- ServerStorage.UnitTest (RunUnitTest + Cases: Resolver_Test, ClimbPlan_Test, SessionStore_Test, Rules_Test); ServerScriptService.UnitTestRunner (Disabled).
- Untouched: Baseplate, SpawnLocation, AI_Test, and every Codex instance.

## Verification (this session)
- 39/39 Larp unit tests and Codex's 24/24 UnitSuite pass in a fresh play server.
- Playtested with one player: pickups and rate limits, rank-ups, nameplates, E-prompt larp-off vs the practice NPC, all six Bag tiers (forced via the debug hook), viral/face-off beats, takeover, fumbles, UPSET/CERTIFIED/EXPOSED, rewards and the pair cap, EXPOSED tag, return-to-position, real Rematch button click, abort on death mid-match, and camera restore.
- Final console: only the DataStore-disabled notice (expected in Studio) and the Assistant plugin version warning. Roblox's own chat CorePackages logged a timeout once; not our code.

## Known gaps / risks
- Not tested: two real players (challenge prompts, accept/decline, spectators), physical mobile/gamepad, real DataStore saving (Studio API access is off).
- Sounds: only licensed-library ids are used. The record scratch, notification ping, pickup sounds and a fail sting were added in the afternoon session. A sad trombone and an engine rev still aren't in the licensed library (the fail sting and whoosh stand in).
- Afternoon session (Claude): rookie practice band plus 0-stat gate, settings persistence (showCosmetics/musicVolume/sfxVolume), stamp sounds per the spec table, "Stage 1" banner, zoneName in Config.Stats, stage-relative Maxxed positions. src/larp mirrors all 45 Claude scripts (checksum-verified). 41/41 Larp unit tests in a fresh play server. See HANDOFF.
- Since built (see HANDOFF): the other four stats and their scenes, stat rushes, Touch Grass, the shop and codes, and the leaderboard wall. Still not built: VIP/Elite areas, rank cosmetics, the Ultimate LARPer, Touch Grass prestige rewards and Clip Mode.

## Coordination inspection — Codex, 2026-09-11 11:56 Toronto
Live Studio inventory: 54 scripts and assembled map/stage/assets, matching Claude's latest handoff. ClientReady and SceneDirector integration confirmed by reading current source. No gameplay mutation or test rerun in this pass. Codex's next isolated work is [onboarding and input UI](claims/CODEX_PLAYER_EXPERIENCE.md); Studio session controls remain available to Claude.

## Codex UI implementation checkpoint (September 11, repository only)
- New session onboarding, keyboard/gamepad modal controls, responsive rectangles, bounded volume controls, and focus scrolling are in CodexUI source. No new Studio instances have been installed during this concurrent session because the user's Play session remains active.
- Local verification: 28 pure tests plus 10 input-adapter tests; all UI sources compile. GitHub Actions run 34620889607 passed against commit 5c95ce4. These checks do not establish native rendering or physical device correctness.
- Native isolated View tests are prepared in tests/PlayerExperienceRuntime.client.lua and remain pending. No production profiles, gameplay remotes, or Claude-owned scripts were mutated by Codex.
- Exact ownership, interfaces and pending steps: docs/claims/CODEX_PLAYER_EXPERIENCE.md. Generated install manifest: run tools/package-codex-ui.py; it only writes .local JSON.

## Latest Codex checkpoint — September 11, 17:27 Toronto
- Current Studio lease belongs to Claude for CCTV scene work; query mode and read TASKS/COMMS before acting. Earlier released/Edit statements are historical.
- All 14 current UI scripts were installed and source-compared during an explicitly granted Edit window. The +Bag card subscription is removed; floating text remains in PickupFx. Guide directions, guarded focus, persisted preference flags and CCTV notification deferral are installed, with native regression pending.
- Morning baseline: 8 native checks and real G/Down/Return, volume/audio, guide dismissal/reopen and respawn passed. Evidence: tests/results/player-experience-native.json. Physical touch/gamepad not verified.
- Codex personally implemented random PickupService placement after temporary ownership transfer. Commit 5e648cf is not installed yet because Claude is playtesting; Scatter is repository-only until installation. Reward validation, weights, rate limits, respawn delays and map Parts are unchanged.
- Fresh positions stay within ZoneBounds, have an 8-stud default gap and exclude solid map obstacles. SpawnPoints determine population/floor height instead of grid coordinates. Crowded zones retry after the existing respawn minimum.
- 67 local checks and GitHub run 34649348517 pass. Twenty read-only native geometry trials placed 40/40 items with zero failures; minimum observed gap 8.0019 studs. Actual collection/respawn checks remain pending.
