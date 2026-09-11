# Actual architecture
## Existing (Claude)
ReplicatedStorage.Larp.Config holds Bag-only trend definitions and balancing. Shared.Catalog indexes them. RankMath, Resolver, Tiers, SceneRules, ClimbPlan and PairLimiter provide reusable calculations. Net defines 18 RemoteEvent names and server-only init; no Remotes folder exists in Edit at this handoff.
ServerScriptService.Larp.Services contains DataService, SettingsService and StatService, expecting Init/Start from an absent bootstrap. StatService subscribes to DataService.ProfileLoaded and publishes ProfileSync/StatsChanged; subscribe consumers before loading profiles. A client-ready/snapshot handshake still needs implementation.
SessionStore wraps DataStore locking; Combatant abstracts players/NPCs. Workspace.Larp and LarpStaging contain unfinished world work. No running Bag scene renderer, pickup/challenge/match service or server bootstrap has been added by Codex.

## Additive client and shared packages (Codex)
StarterPlayer.StarterPlayerScripts.CodexUI.Bootstrap starts an idempotent Controller in the player's script VM. Controller composes pure Model state, native Roblox View, a nonblocking RemoteAdapter and Cleanup. Rank/format/catalog/text/tuning are read from Claude's existing modules.
UIConfig owns presentation colours, labels and preference metadata; deadline limits derive from existing Tuning. Model makes no rewards or eligibility decisions. RemoteAdapter binds current and later-created RemoteEvents; missing remotes never block drawing the UI.
View owns only PlayerGui.LarpCodexUI. It has no authority over world assets, camera, player movement or server data. Controller exposes scene lifecycle/stamp/rematch and preference hooks; there are no guessed Match packet adapters.
Client-owned CodexMusic and CodexSFX SoundGroups expose volume controls to future scene sounds. Clip/cosmetic renderers remain separate.
ReplicatedStorage.CodexShared contains Cleanup (resource ownership) and RateLimiter (bounded ingress token bucket). RateLimiter is not wired into unfinished Claude services; those services can opt in. Existing PairLimiter still owns anti-trading reward limits.
ServerStorage.CodexTests.UnitSuite is invoked manually; no automatic test Script exists.

## Source and synchronization
Exact baseline mapping and hashes: studio-snapshot/script-map.json. Baseline Studio path -> studio-snapshot/scripts/<dot path split into folders>.lua.
New source/Studio mapping and APIs: docs/UI_INTEGRATION.md. src/client/CodexUI plus src/config/UIConfig.lua mirror the installed client package; src/shared/CodexShared mirrors the installed utilities. Source equality was verified after installation.
Studio remains the live place. No Rojo, importer, bulk replacement or authoritative filesystem synchronization is configured.

## Tests
UnitSuite tests pure state/math/utilities in Studio. ClientSuite executes as a normal LocalScript against a temporary play-only ServerFixture, exercising the real client VM. BalanceSimulation calls the current Resolver with seeded Random and configured stat ids, never granting rewards. All fixtures vanish on Stop. tests/results contains captured reports, and tests/README.md explains reproduction.
