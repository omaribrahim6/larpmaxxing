# Handoff
## FOR CLAUDE
### Resume here
1. Read PROJECT_STATE.md, TASKS.md, DECISIONS.md and this file.
2. Inspect Git history since your session: repository C:/Users/omarm/Documents/Larpmaxxing; private remote https://github.com/omaribrahim6/larpmaxxing.
3. Continue your Bag assets/map/server framework and scene director. Do not build a competing HUD, challenge popup or settings menu.

Your exact local session: fd372225-e036-4b35-8cd1-1bf1c44d7617, ~/.claude/projects/C--Users-omarm-Documents. Recovered final successful edit: ServerScriptService.Larp.Services.StatService at 06:05:49Z (02:05 Toronto), after DataService and SettingsService. The next response was your usage-limit message. No concrete immediately-next script was stated in the accessible final messages; do not infer one.
Your narrowed user task at 01:43 Toronto was a sequentially tested Bag-only vertical slice, despite the broader spec MVP list.
The 10-agent asset workflow and audit returned null. Partial builds remain in staging; do not assume completion. Full original v1.1 artifact is docs/SPEC-v1.1.html; it includes your amendments. No private session transcripts or credentials were committed.

### What Codex built and installed
- Config-driven rank/progress, Bag stat and wins HUD.
- Challenge popup with Accept/Decline, real expiry, replacement/stale-close handling, bounded replay protection, opt-out and one response per pending request.
- Settings UI: existing server-supported booleans plus clearly session-only music/SFX/cosmetics.
- Bounded/deduplicated notices, configurable ATE/FUMBLED/CERTIFIED/EXPOSED/UPSET/VIRAL/DRAW UI stamps, round display, HUD hiding, rematch controls, event countdown API.
- Client-local SoundGroups for volume control.
- Cleanup utility and bounded token-bucket ingress limiter (distinct from your PairLimiter reward cap).
- Executed test suites and a seeded config-driven balance simulator.

Installed namespaces are EXCLUSIVELY StarterPlayer.StarterPlayerScripts.CodexUI (six scripts), ReplicatedStorage.CodexShared (two modules), ServerStorage.CodexTests.UnitSuite. Runtime creates PlayerGui.LarpCodexUI and client-local SoundService.CodexMusic/CodexSFX.
All 23 of your original scripts remain unchanged. All your assets/map/staging objects were preserved.

### What only exists in the repo
tests/ClientSuite.client.lua, ServerFixture.lua and BalanceSimulation.lua are harnesses, not production scripts. Tests/results records evidence. studio-snapshot is the baseline mirror, not live authoritative source or a full place save. No Rojo or automatic synchronization was introduced.

### Your integration steps
Read **UI_INTEGRATION.md** for exact callable interfaces and remote signatures.
From a normal client script require PlayerScripts.CodexUI.Controller and call .start() (idempotent).
- ui:SetMatchActive(true/false)
- ui:SetRound("Bag", 1, 1)
- ui:ShowStamp("Ate", 0.9), etc.
- ui:ShowRematch("Player", opponentUserId, 60) or ("Npc",0,60), after scene ends.
- ui:GetSetting(key), ui:OnSettingChanged(callback)
- ui:GetAudioGroup("Music"|"SFX") for assigning Sound.SoundGroup.
The adapter already consumes your declared ProfileSync/StatsChanged/ChallengeIncoming/ChallengeClosed/Notice/RankUp/PickupCollected/Announce shapes, and sends RespondChallenge/UpdateSetting/RequestChallenge/RequestPractice.
**Do not call Net.init or start a duplicate bootstrap on the client.** Your server lifecycle still needs implementation. Add a ready/snapshot-request handshake so an early one-shot ProfileSync is not lost. MatchBegin/MatchRound/MatchVerdict shapes remain yours to define; Codex did not guess them.
Clip Mode and cosmetics are preferences only until your renderer applies them. No scene camera or crowd effects were taken over. Extra audio/cosmetic settings are not persisted yet.
Server validates all incoming requests, eligibility, ids, distance, expiry, cooldowns, opt-out and reward rules. The UI is not a security boundary.

### Verification and commits to inspect
- 7b90273: shared workspace, recovered full spec and baseline.
- be34c2a: exact source bytes and snapshot hashes.
- fc875af: UI package, utilities and integration contract.
- 2ca2e7f: runtime/unit harnesses and deterministic simulator.
- 0af2e54: UI timing derives from your Tuning.
- Subsequent handoff commit: final results/state and source-equality evidence.
Final results: 24 unit cases, 10 client runtime cases, 3 simulator checks passed; real mouse-click and remote tests, real ten-second timeout, one-request rematches, opt-out and respawn passed.
A narrow-screen clipping failure was found, fixed and retested. Final console showed only the existing Assistant version warning.
Studio is back in **Edit**, test fixtures are gone, and the global playtest lease is released. No Codex worker is still running.

### Avoid conflicts
Keep ownership split: you own all pre-existing Larp framework/map/assets/Bag scene work; Codex owns CodexUI/CodexShared and their src files. Update TASKS before transferring ownership.
Do not bulk-import studio-snapshot over live scripts. Compare source first. No original script was edited even to fix discovered risks.
Review your SessionStore final-attempt lock takeover and StatService non-finite amount validation before production. Game end-to-end, production persistence, multiplayer and physical mobile/gamepad tests remain yours after the slice is assembled.

## FOR CODEX
Start with the shared docs and Git status/history. Current additions are tested and complete as independent components; do not reopen Claude's owned framework to hook them up without an ownership change.
Preserve the exact source mappings in UI_INTEGRATION.md. Source snapshots are historical. Tests must not run DataService or access production profiles.
MCP's execute_luau Client context has a different require cache from normal LocalScripts: Controller.get() there can be nil while Bootstrap is working. Inject the supplied client test LocalScript into the play player's PlayerScripts to test the real runtime. Never interpret that separate VM cache as failed startup.
Update state/handoff and commit/push after meaningful work. No background monitor or follow-up was scheduled.
