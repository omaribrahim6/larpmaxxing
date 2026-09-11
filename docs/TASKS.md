# Tasks and ownership
| Task | Owner | Status | Affected files / Studio systems | Dependencies |
|---|---|---|---|---|
| Recover state and establish shared repository | Codex | IN PROGRESS | docs, root instructions, studio-snapshot, Git | GitHub CLI authentication |
| Finish Bag assets/map/stage | Claude | IN PROGRESS (paused) | Workspace.Larp, Workspace.LarpStaging, ReplicatedStorage.Larp.Assets | sequential Studio writer |
| Continue core server framework after StatService | Claude | IN PROGRESS (paused) | ServerScriptService.Larp; ReplicatedStorage.Larp.Shared and Config | data/bootstrap/pickups/challenges/matches |
| Bag scene director and practice NPC | Claude | TODO (reserved) | future client Bag scenes; Combatant adapter | assets and match lifecycle |
| Player UI package | Codex | IN PROGRESS | src/client/CodexUI, src/config/UIConfig.lua; separate Studio CodexUI | existing Catalog/RankMath/Net contracts; integration tests |
| Cleanup, rate limit and UI state tests | Codex | IN PROGRESS | src/shared/CodexShared, tests | no Claude edits |
| Connect UI to completed server startup and scene lifecycle | Claude | TODO | owned server/bootstrap/scenes | Codex UI contract and completed gameplay services |
| Review persistence lock takeover and non-finite stat guard | Claude | TODO | SessionStore, StatService | before production |
A DONE row needs executed test evidence. Reserved ownership persists after usage resets. Read HANDOFF before acting. Global Studio playtest ownership: Codex during this session; release in handoff when finished.

