# Active Codex work claim
Declared September 11, 2026, 11:56 Toronto. Status: IN PROGRESS (claimed; implementation has not started in this pass).

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

