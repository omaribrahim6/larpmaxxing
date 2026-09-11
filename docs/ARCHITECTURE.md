# Actual architecture
## Existing (Claude)
ReplicatedStorage.Larp.Config holds Bag-only trend definitions and balancing. Shared.Catalog indexes those definitions. RankMath, Resolver, Tiers, SceneRules, ClimbPlan and PairLimiter are reusable calculation modules. Net defines 18 RemoteEvent names and server-only init; no Remotes folder exists at baseline.
ServerScriptService.Larp.Services contains DataService, SettingsService, StatService. Each expects Init/Start lifecycle from an absent bootstrap. StatService subscribes to DataService.ProfileLoaded and publishes ProfileSync/StatsChanged; subscribe consumers before starting loads. SessionStore wraps DataStore locking. Combatant abstracts player/NPC participants.
Workspace.Larp and LarpStaging hold unfinished world work. No running scene renderer, pickup/challenge/match service or client UI was found.
## Snapshot mapping
Each baseline Studio path maps to studio-snapshot/scripts/<dot path split into folders>.lua, preserving class in script-map.json. Treat these as historical and owned by Claude.
## Additive Codex package (in progress)
src/client/CodexUI -> StarterPlayer/StarterPlayerScripts/CodexUI (folder with ModuleScripts and Bootstrap LocalScript).
src/config/UIConfig.lua -> CodexUI/UIConfig.
src/shared/CodexShared -> ReplicatedStorage/CodexShared.
tests -> ServerStorage/CodexTests, manually invoked; no automatic test Script in published play.
UI waits for existing remotes through a nonblocking adapter; it does not call Net.init or start game services.

