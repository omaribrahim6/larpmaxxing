# Tasks and ownership
| Task | Owner | Status | Affected files / systems | Dependencies / evidence |
|---|---|---|---|---|
| Recover session, source mirror and private repository | Codex | DONE | root docs, studio-snapshot, Git | 23 original sources preserved; private GitHub verified |
| Finish Bag assets/map/stage | Claude | DONE (vertical slice) | Workspace.Larp.Map, Workspace.Larp.Stages.Stage1, Larp.Assets | 14 Bag scene props, 5 item props, plaza + Car Lot (40 spawn points), neon-street stage with crowd; staging emptied |
| Server framework: bootstrap, pickups, challenges, matches/rewards, nameplates | Claude | DONE (vertical slice) | ServerScriptService.Larp (Main, Services, Lib) | playtested end to end vs the practice NPC; 39 Larp unit tests |
| Bag scene director and practice NPC | Claude | DONE (vertical slice) | StarterPlayerScripts.LarpClient; PracticeNpcService | all 6 tiers, signatures, takeovers, 6 fumbles, verdict moments playtested |
| Player UI package and integration contract | Codex | DONE | src/client/CodexUI, src/config/UIConfig.lua; installed CodexUI | 10 runtime tests plus real remote/button checks |
| Cleanup and bounded ingress rate limiter | Codex | DONE | src/shared/CodexShared; installed CodexShared | unit tests in Studio; RateLimiter now used by Pickup/Challenge services |
| UI/rank/reward tests and balance simulator | Codex | DONE | tests; ServerStorage.CodexTests.UnitSuite | 24 unit tests still pass after Claude's changes |
| ProfileSync handshake and service startup | Claude | DONE | Net (ClientReady), StatService.SendSync, Main | client fires ClientReady after CodexUI start; rate-limited 1/s |
| Connect scene lifecycle and rematch outcome to UI | Claude | DONE | SceneDirector | SetMatchActive, SetRound, ShowStamp, ShowRematch, Notify, GetSetting, GetAudioGroup; real Rematch click verified |
| Apply Clip Mode/cosmetics in their renderers | Claude | DEFERRED | scene/cosmetic owners | Clip Mode redesign decided 2026-09-11 (see DECISIONS); rank cosmetics not in slice |
| Assign SoundGroups | Claude | DONE | LarpClient.SoundKit | all scene sounds use CodexSFX |
| Persist additional settings (showCosmetics, musicVolume, sfxVolume) | Claude | DONE (server side); Codex to flip UIConfig `persisted` | DataService/SettingsService schema | contract proposed in COMMS 12:40; Codex flips UIConfig `persisted` after Claude posts "settings persisted" |
| Persistence lock takeover and non-finite stat guard | Claude | DONE | SessionStore, StatService | infinity guard added; takeover kept by decision (see DECISIONS) and unit-tested |
| Multiplayer (2 real players) and physical device pass | Claude | TODO | challenge flow, spectators | needs Studio multi-client test or a live server |
| New-player onboarding and mobile/gamepad UI controls | Codex | IN PROGRESS (claimed by Codex, 2026-09-11) | CodexUI only | Claude will not touch CodexUI/CodexShared |
| First-larp-off balance for 0-stat players + "collect Bag first" gate | Claude | DONE (playtested) | Config.Tuning.Practice, PracticeNpcService, DataService defaults | server-only; sends existing Notice remote, no new UI |
| Scene/pickup sound pass (pickup, record scratch, ping, fail sting) | Claude | DONE (playtested; no licensed sad trombone/engine rev exists) | Config.Sounds, LarpClient.SoundKit/PickupFx/Scenes.Bag | licensed library audio only; all via CodexSFX group |
| Mirror Claude-owned Studio scripts into repo (src/larp) | Claude | IN PROGRESS | src/larp/** (new, read-only export) | Studio stays authoritative; no sync tooling |
Only claim a task after checking live state and ownership. Codex's DONE systems are not permission to overwrite their files.
**Agent-to-agent messages: [COMMS.md](COMMS.md)** (the user is away; talk there, not through the user).
**Parallel work (2026-09-11):** Codex and Claude are working at the same time. Edits to different scripts in Edit mode are fine. **Play mode is shared**: before starting a playtest, set the lease line below to your name, and set it back to released when you stop. Never stop a playtest you did not start.
**Global Studio playtest lease: released** by Claude at 12:32. Studio is in Edit.


## Codex concurrent-work claim (2026-09-11 11:56 Toronto)
- **IN PROGRESS â€” owner: Codex:** new-player onboarding and mobile/keyboard/gamepad UI. Affected: src/client/CodexUI/**, src/config/UIConfig.lua, Codex-owned UI tests; corresponding Studio CodexUI namespace only. Dependencies: existing profile/pickup/match interfaces; a coordinated Studio lease for live testing. Scope and exclusions: [active Codex claim](claims/CODEX_PLAYER_EXPERIENCE.md).
- Claude retains gameplay/balance, server services, LarpClient scenes/camera, map and assets. No Codex play/stop or debug calls while Claude uses Studio.

## Codex local UI test tooling (claimed September 11)
- Owner: Codex. Status: IN PROGRESS. Files: tools/test-codex-ui.py, tools/package-codex-ui.py, tests/InputControllerFixture.luau, .github/workflows/codex-ui.yml. Dependencies: CodexUI source, official pinned Luau CLI. This task does not access Studio or overlap Claude's tools/verify-larp-mirror.ps1 export validator.

## Codex notification readability (claimed September 11)
- Owner: Codex. Status: IN PROGRESS. Affected: CodexUI/View, new ToastPolicy, UIConfig, owned UI tests. Dependencies: existing Notice/Notify interface unchanged. Make long notices readable, preserve important errors during pickup bursts, and bound toast layout on small screens. Repository work while Studio is in user Play; native validation remains required.
