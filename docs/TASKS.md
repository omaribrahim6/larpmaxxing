# Tasks and ownership
| Task | Owner | Status | Affected files / systems | Dependencies / evidence |
|---|---|---|---|---|
| Recover session, source mirror and private repository | Codex | DONE | root docs, studio-snapshot, Git | 23 original sources preserved; private GitHub verified |
| Finish Bag assets/map/stage | Claude | IN PROGRESS | Workspace.Larp, LarpStaging, Larp.Assets | paused at limit; sequential Studio writer |
| Continue server framework after StatService | Claude | IN PROGRESS | ServerScriptService.Larp; Larp.Shared/Config | bootstrap, pickups, challenges, matches/rewards |
| Bag scene director and practice NPC | Claude | TODO | future Bag scenes; Combatant adapter | assets and server lifecycle |
| Player UI package and integration contract | Codex | DONE | src/client/CodexUI, src/config/UIConfig.lua; installed CodexUI | 10 runtime tests plus real remote/button checks |
| Cleanup and bounded ingress rate limiter | Codex | DONE | src/shared/CodexShared; installed CodexShared | unit tests in Studio |
| UI/rank/reward tests and balance simulator | Codex | DONE | tests; ServerStorage.CodexTests.UnitSuite | 24 unit tests, 3 simulation checks; results committed |
| Connect production ProfileSync handshake and service startup | Claude | TODO | owned server bootstrap/Net/services | UI listens without creating remotes; avoid one-shot sync race |
| Connect scene lifecycle and rematch outcome to UI | Claude | TODO | owned scene director/match service | docs/UI_INTEGRATION.md; no guessed packet schema |
| Apply Clip Mode/cosmetics in their renderers and assign SoundGroups | Claude | TODO | scene/cosmetic/sound owners | ui:GetSetting, OnSettingChanged, GetAudioGroup |
| Persist additional settings if desired | Claude | TODO | DataService/SettingsService schema | music/SFX/cosmetics currently session-only |
| Fix persistence lock takeover and non-finite stat guard | Claude | TODO | SessionStore, StatService | before production use |
| Full end-to-end Bag, multiplayer and physical device pass | Claude | TODO | complete vertical slice | unfinished assets/gameplay services |
Only claim a task after checking live state and ownership. Codex's DONE systems are not permission to overwrite their files.
**Global Studio playtest ownership released.** Studio is in Edit; no Codex background task or fixture remains. Claude may resume his owned work.
