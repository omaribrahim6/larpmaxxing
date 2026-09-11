# Project state
Updated September 11, 2026, approximately 02:55 Toronto, before Claude's expected 03:01 return.

## Live Studio and repository
Studio d820b236-d917-475d-b27f-ed5faa20ce7a: Untitled Experience, placeId 140202351497067. Returned to **Edit** after testing. No active Codex playtest or background worker remains.
Repository: C:/Users/omarm/Documents/Larpmaxxing; private remote https://github.com/omaribrahim6/larpmaxxing.
Studio remains the live place. The repo contains historical source snapshots plus installed additive source, not a complete restorable place file or an automatic synchronization system.

## Baseline preserved
2642 descendants were inventoried, including Studio internal UI. All 23 original LuaSourceContainers were read and mirrored exactly under studio-snapshot/scripts. script-map.json records Studio paths, classes, repository paths and SHA-256 file hashes. hierarchy.json records every observed instance path/class and selected asset properties; it is not exhaustive serialization.
Final comparison found all 23 original script sources unchanged. No original instances were moved, deleted or reparented.

### Existing hierarchy (Claude-owned)
- Workspace: Baseplate, SpawnLocation, AI_Test, Larp, LarpStaging.
- Workspace.Larp.Map and Pickups: empty folders.
- Workspace.Larp.Stages.Stage1: Root and eight markers (StagePivot, MarkL, MarkR, VehicleL, VehicleR, JetL, JetR, CameraFocus). No finished stage set.
- LarpStaging: Slots 1,2,3,4,5,6,7,8,10; partial T1_Bus, T2_EScooter, T3_Hatchback, TowTruck/Boom and MonopolyMoney. Preserve staging.
- ReplicatedStorage.Larp.Config: Game, Stats, Rarities, Items, Ranks, Tuning, Text, Scenes/Bag.
- ReplicatedStorage.Larp.Shared: Resolver, Tiers, RankMath, PairLimiter, Format, ClimbPlan, Net, Signal, Catalog, SceneRules.
- ReplicatedStorage.Larp.Assets.Items and Assets.Scenes.Bag: empty destination folders.
- ServerScriptService.Larp.Services: DataService, SettingsService, StatService.
- ServerScriptService.Larp.Lib: SessionStore, Combatant.
- ServerStorage.UnitTest.Cases: no test scripts at baseline.

### Existing implementation status
Math/config and service module sources exist. No Script starts the server lifecycle. There is no running pickup, challenge, match/reward, practice NPC, nameplate or Bag scene director system. The end-to-end Bag slice remains unfinished.
Claude's last successful edit was StatService at 06:05:49Z. Asset workflow ultimately returned null for every builder and its audit.

## Codex additions in Studio
Three new owned folders, nine new scripts:
- StarterPlayer.StarterPlayerScripts.CodexUI: Bootstrap (LocalScript), Controller, View, Model, RemoteAdapter, UIConfig (ModuleScripts).
- ReplicatedStorage.CodexShared: Cleanup, RateLimiter.
- ServerStorage.CodexTests: UnitSuite (manual test module only).

Runtime UI creates PlayerGui.LarpCodexUI: rank/progress, configured stat values, wins, timed challenge Accept/Decline, settings, bounded notices, stamp presentations, rematch controls and optional event countdown shell. It survives respawn and cleans up on teardown.
Audio controls drive new client-local CodexMusic/CodexSFX SoundGroups. Sounds must be assigned by the scene owner. Reduce Effects already suppresses stamp motion.
No production remotes were added. Adapter attaches to Claude's remotes when available. At rest the actual game shows “Waiting for profile”; test balances were not installed as player data.

## Repo-only tools and pending integration
ClientSuite, ServerFixture and BalanceSimulation are repo-only harnesses; their injected play-session instances vanished on Stop.
Claude must start his services, add a reliable ProfileSync ready/request handshake, and connect his scene director using docs/UI_INTEGRATION.md. Match packet shapes are undefined; no guessed packet adapters were added.
Clip Mode and Show Cosmetics expose preferences/listeners but camera/cosmetic application awaits their owning renderers. Music/SFX/cosmetics are session-only, explicitly stated in Settings. Only existing acceptLarpOffs/clipMode/reduceEffects settings use UpdateSetting.
Stamp visuals are UI presentation components; no new crowd/camera choreography or licensed audio assets were added. Challenge uses numeric countdown and linear progress, not the spec's final circular timer. Touch Grass count, Codes and actual events remain out of scope.

## Verification
- 24/24 unit cases in a fresh Studio play server.
- 10/10 client runtime cases: real ProfileSync rendering, settings, notices, stamps, HUD/round lifecycle, audio groups, callbacks, 640x360/360x640 layout constraints and teardown/restart.
- Real mouse clicks recorded exact Accept/Decline/UpdateSetting arguments. Ten-second expiry sent one decline; double Rematch clicks sent one player request; NPC rematch and opt-out each sent once.
- Character respawn retained one GUI and loaded total while clearing rematch.
- Seeded simulator: two identical 10,000-match runs, outcome conservation, zero-stat draws. Current Bag-only 20%-behind sample won 2497/10000 (24.97%); this is NOT the full five-stat spec probability.
- Source/file equality checks and removal of all temporary play fixtures.
Evidence and reproduction: tests/README.md and tests/results/.

## Known errors / risks
Final play console contained only the pre-existing Assistant plugin version mismatch warning. Earlier baseline output also included disabled Studio DataStore API access, privileged Lighting.Technology inspection failures, and a share-access failure followed by continued publishing. Codex did not change API settings or restart Studio.
Unmodified Claude code flags: SessionStore force-takes a live lock on its final acquire attempt; StatService:AddPoints rejects NaN but not infinity. Review these before production.
Physical device/gamepad and multi-client gameplay tests remain pending. Layout checks resized the UI root in Studio; they were not hardware touch tests. No production saving or full battle/reward integration was claimed.
