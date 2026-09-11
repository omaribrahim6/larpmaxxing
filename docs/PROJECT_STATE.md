# Project state
## Baseline discovery — September 11, 2026
Connected Studio: d820b236-d917-475d-b27f-ed5faa20ce7a, Untitled Experience, placeId 140202351497067, Edit mode. Confirmed same id as Claude's transcript. Observed 2642 descendants, including Studio internal UI, and 23 LuaSourceContainers. All 23 script sources exported. Complete observed hierarchy: studio-snapshot/hierarchy.json; script mapping: studio-snapshot/script-map.json.
## Hierarchy and assets
Workspace: Baseplate, SpawnLocation, AI_Test, Larp (Map, Stages/Stage1/Markers, Pickups), LarpStaging.
Map is empty. Stage1 has markers but is not a finished set. Staging Slots 1,2,3,4,5,6,7,8,10 include partial bus, scooter, hatchback, tow truck and MonopolyMoney work; preserve all.
ReplicatedStorage/Larp: Config (Game, Stats, Rarities, Items, Ranks, Tuning, Text, Scenes/Bag); Shared (Resolver, Tiers, RankMath, PairLimiter, Format, ClimbPlan, Net, Signal, Catalog, SceneRules); Assets/Items and Assets/Scenes/Bag.
ServerScriptService/Larp: Services (DataService, SettingsService, StatService); Lib (SessionStore, Combatant).
ServerStorage/UnitTest/Cases is present but has no scripts. No gameplay Script bootstrap, LocalScript or client scene exists at baseline.
## Implemented versus partial
Existing module source implements math/config, session profiles, settings validation, stat/leaderstats updates and combatant abstraction. Module presence does not mean systems run: no bootstrap starts them.
Bag pickups, challenges, match orchestration, rewards integration, nameplates, practice NPC, scene playback, map and assets remain incomplete.
No baseline end-to-end gameplay test was recovered. Workflow returned null for all 10 builders and its audit, with all 11 agents hitting usage errors.
## Known errors and limits
Console: Studio API access disabled on DataStore probe; privileged Lighting.Technology inspection failed; Assistant plugin version mismatch warning; share-access failure followed by continued publish. These predate Codex changes. Do not restart Studio or enable APIs merely to hide them.
Code inspection flags for Claude: SessionStore force-takes a live lock on final acquisition attempt; StatService:AddPoints rejects NaN but not infinity. These are unmodified and need owning-developer review before production.
The snapshot is not a full restorable place save; asset metadata is partial. Original live instances preserved.

