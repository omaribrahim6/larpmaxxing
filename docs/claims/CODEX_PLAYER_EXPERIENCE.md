# Active Codex work claim
Declared September 11, 2026, 11:56 Toronto. Status: IN PROGRESS (implemented locally; native Studio validation pending user playtest ending).

## Work: new-player onboarding and input/accessibility UI
Codex will build:
1. A compact, dismissible first-session guide: collect Bag props in the Car Lot, then try the Practice Larper. Advance from observed profile/pickup/match events, not invented wins or client-granted rewards.
2. Mobile HUD/settings/challenge layout and touch target improvements.
3. Explicit keyboard/gamepad focus, navigation, accept/decline and menu-close behavior; readable input hints.
4. Tests for onboarding transitions, dismissal, respawn, input focus and small viewports.

## Exclusive code boundary
- src/client/CodexUI/** and corresponding StarterPlayer.StarterPlayerScripts.CodexUI instances.
- src/config/UIConfig.lua and the corresponding CodexUI.UIConfig module.
- New Codex-owned UI test files under tests/.
Keep Controller's existing public API compatible with LarpClient and SceneDirector. Consume existing remotes and config read-only.

## Claude boundary
Claude retains all ServerScriptService.Larp services, Larp.Shared/Config gameplay definitions, StarterPlayerScripts.LarpClient and its children, Workspace.Larp, LarpStaging and Larp.Assets.
Codex will not edit practice balance, server settings persistence, rewards, pickups, challenge/match logic, cameras, poses, scene sounds, world prompts, maps or props as part of this claim.
Onboarding does not solve the 0-Bag practice balance issue by changing NPC stats; that remains a server/game-design decision for Claude.
Clip Mode implementation and rank cosmetics remain deferred; this UI work does not expand their scope.

## Simultaneous work protocol
Different source namespaces may be developed concurrently. Whole-session Studio controls are shared: Codex will not start/stop play, reset characters, invoke gameplay debug commands or install old test fixtures while Claude is using Studio.
Do repository development and isolated tests first. Before live installation/playtesting, acquire the global Studio lease through the shared task/handoff channel. Read current live source before any CodexUI edit.
The old ServerFixture refuses existing remotes and must not be used to replace the now-running gameplay backend.
For documentation, this separate claim file is the durable Codex announcement; preserve Claude's currently uncommitted docs and do not sweep them into Codex commits.

## Inspection supporting this split
Read Claude's current PROJECT_STATE/TASKS/DECISIONS/HANDOFF, latest local transcript, and live Studio inventory. Current Studio has 54 scripts, complete map/stage structures, five pickup assets and fourteen Bag scene props. Inspected LarpClient bootstrap, SceneDirector, ChallengeService and MatchService packet documentation.
Confirmed LarpClient starts CodexUI and sends ClientReady after listeners; SceneDirector already calls the existing UI API. No competing onboarding system was identified in the current scripts.
Claude's handoff reports 39 gameplay tests plus 24 Codex unit tests passing and solo end-to-end Bag playtests; these were not rerun during this read-only coordination pass.
No game scripts or instances changed during declaration. Studio was observed in Edit; Codex has not taken the global playtest lease.

## Implementation checkpoint, September 11
- Added Onboarding, InputPolicy, InputController and Layout modules; integrated only into repository CodexUI.
- Guide follows accepted profile Bag points, supports dismiss/reopen, retains session state across respawn, hides during modals/matches, and only completes following a locally observed participant match and the scene owner's ShowRematch callback. MatchAborted clears that observation. Returning winners skip automatically. Guide copy and stat key are config-driven.
- G opens/closes settings, Y/N answer keyboard challenges, Tab/Shift+Tab cycle modal controls, Return activates the selected modal control. Gamepad Y opens settings and B closes/declines; native A activation remains intact. Chat, Roblox menu, active matches, and world E/ButtonX pass through.
- Gamepad challenge focus defaults to Decline. Settings/challenge focus stays within its modal and is restored on closure.
- 24 local Luau tests cover progression, profile validation, input routing/focus and six viewport bounds. Owned Lua sources compile with official Luau CLI 0.737. These are not physical-device or native Studio results.
- Prepared tests/PlayerExperienceRuntime.client.lua: isolated native View/model tests, no gameplay remotes or profile writes. Run only during Codex lease.
- Nothing in this checkpoint is installed in Studio yet. User owns the current Play session. Claude acknowledged Codex installs first when Edit returns; coordination is in docs/COMMS.md.
