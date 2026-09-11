# Testing
## Current Codex UI checks
Run `python tools/test-codex-ui.py --luau PATH_TO_LUAU` using the official Luau 0.737 CLI release (the compiler must be alongside it). This runs 28 pure state/input/layout/setting tests, 10 tests of the actual InputController with mocked Roblox services, and compiles all owned UI source. The GitHub workflow runs the same checks with a checksum-verified Linux CLI.

Native validation for the new onboarding/input changes remains pending while the user's Studio playtest is active. After taking the Studio lease and installing the owned modules, inject `PlayerExperienceRuntime.client.lua` as a temporary LocalScript under PlayerScripts. It creates an isolated disabled View and synthetic Model, performs native layout checks, destroys its fixture, and writes JSON to `CodexPlayerExperienceResults`. It never sends gameplay remotes or changes a real profile. Physical gamepad/touch behavior still requires a device test.

`python tools/package-codex-ui.py` generates `.local/codex-ui-manifest.json` with source, Studio paths and normalized hashes for review. It does not synchronize or modify Studio. Compare live Source before every installation.

## Historical baseline evidence
The following describes the original UI baseline and the then-incomplete gameplay backend. Claude has since completed the Bag vertical slice. **Do not run the old ServerFixture against the current full backend or follow its final no-remotes expectation on the live place.**

Executed September 11, 2026 in the existing Studio instance. See results/*.json.
- UnitSuite: 24 cases, 24 passed in a fresh play server.
- ClientSuite: 10 cases, 10 passed after fixing narrow-screen rank clipping.
- BalanceSimulation: 3 checks (seed reproducibility, outcome conservation, zero-stat draws).
- Real MCP mouse clicks tested Accept, Decline, settings and duplicate Rematch input. Server recorder verified exact arguments.
- Full real ten-second timeout, opt-out, NPC rematch and actual character respawn passed.
- Final console: only pre-existing Assistant plugin version mismatch warning.

## Reproduce without production data
1. Coordinate Studio ownership and read TASKS.md. Do not run fixtures while Claude is writing/playtesting.
2. Pure tests can run in Edit: require(game.ServerStorage.CodexTests.UnitSuite).run(). For fresh dependency caches, use a new Studio play session and run it on Server.
3. For UI tests use a play session whose Larp.Remotes does NOT exist. Inject ServerFixture.lua as a ModuleScript under ServerStorage.CodexTests, require it on Server, and call .start(). It refuses to take over existing remotes and refuses non-Studio/non-play contexts.
4. After client Bootstrap runs, call fixture.profile(). Click Settings, then Reduce Effects (the client suite expects this real toggle).
5. Inject ClientSuite.client.lua as a LocalScript directly into LocalPlayer.PlayerScripts in the Client DataModel. Read PlayerScripts.CodexClientTestResult.Value for JSON. The suite tests and restarts the UI; resend fixture.profile() afterward if continuing interactive tests.
6. Use fixture.challenge("unique-id",10) and real UI clicks to inspect request records via fixture.results(). Don't click for at least ten seconds to verify auto-decline. Each id must be unique because completed ids are replay-protected.
7. To show a rematch call Controller.start():ShowRematch from a normal test LocalScript, then click it twice and verify exactly one request. Use ("Npc",0,60) to test RequestPractice.
8. Stop play. Verify Edit has no Larp.Remotes, CodexFixtureLog, injected client test script or ServerFixture. No DataService, real profile or DataStore was started.

MCP execute_luau's Client require cache differs from LocalScript runtime. A nil Controller.get() in that tooling VM does not indicate Bootstrap failed. Use the injected normal LocalScript to test runtime state.

## Balance simulation
Load tests/BalanceSimulation.lua as a temporary ModuleScript and call .run({matches=10000,seed=1729,deficit=0.2,base=1000}). Options bounded to 100000 matches; uses Catalog.statIds and current Tuning.Upset.
The recorded sample is **Bag-only**: 2497 underdog wins / 10000. Do not compare that one-round rate to the five-round spec's match odds or treat it as production telemetry.

## Limits
UI root dimensions were tested at 640x360 and 360x640 with 44px minimum button heights and text fitting checks. This is layout testing inside Studio, not physical touch/gamepad testing.
No multiplayer battle, end-to-end pickup/reward flow or production saving was tested because those Claude-owned systems are incomplete.
