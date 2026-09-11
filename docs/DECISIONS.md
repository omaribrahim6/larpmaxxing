# Decisions
- 2026-09-11: Reuse existing C:/Users/omarm/Documents/Larpmaxxing as repository root; no redundant nested directory. Remote requested as private larpmaxxing.
- Snapshot existing scripts under their full Studio paths; do not import them into new active source locations or install destructive sync.
- Preserve Claude ownership of all baseline scripts, map, assets and staging. Add UI under separate CodexUI namespace and independent utilities under CodexShared.
- UI reuses Catalog, RankMath and current remote names; no duplicate rank ladder, Signal or reward engine.
- Claude's services are not bootstrapped by Codex. Test fixtures run only in play sessions and never call DataStore APIs.
- No client decides rewards, eligibility or battle results. UI input is a request; the server must validate identity, distance, timeout, cooldown, rate limits and settings.
- Music/SFX/cosmetics remain client-session preferences until explicitly added to the existing server schema; Clip Mode/Reduce Effects are exposed to scene code without taking over its camera.
- Current scope is the Bag-only vertical slice authorized after the broader spec. Events and monetization are deferred.


- 2026-09-11 (Claude): Clip Mode is NOT a centre-strip composition rule. Default larp-off cinematography is full widescreen. Clip Mode, when built, switches the camera instead (tight single-subject cuts or a stacked top/bottom duet in a 9:16 frame). Out of the vertical slice; spec v1.1 "Built for vertical" needs this update.
- 2026-09-11 (Claude): Poses are procedural and client-local: they offset each R15 joint's parent-side frame (Motor6D.C0, or Attachment0.CFrame on AnimationConstraint rigs, which current Roblox avatars use). Custom Animation Editor clips replace them for launch.
- 2026-09-11 (Claude): SessionStore keeps its final-attempt lock takeover. Without cross-server messaging this is the standard compromise: the new server takes the profile after ~12 s of retries, and the old server's saves are refused ("lost lock") so it can never overwrite. Worst case loses the old session's last <60 s of progress. Covered by SessionStore_Test.
- 2026-09-11 (Claude): Practice-NPC wins count as Wins (subject to the same 2-per-10-minutes reward cap as players), so single-player sessions can progress.
- 2026-09-11 (Claude): Server-authoritative round packets carry rolled values and tiers; scene tiers follow the ROLLED value so spectators see the real result. Fumble beats run before takeover beats at the same instant.
- 2026-09-11 (Claude): A Studio-only BindableFunction ServerStorage.LarpDebug (created by Main only when RunService:IsStudio()) lets playtests add points and start practice matches. It never exists on live servers.
- Final handoff: client deadline caps derive from Claude's Tuning. New SoundGroups are client-local and affect only sounds explicitly assigned by their owner. No production remotes/bootstrap or guessed match packet adapters were added. Temporary fixtures are removed and Studio playtest ownership is released.
- 2026-09-11 (Claude): The Practice Larper uses a weaker "rookie" band (Tuning.Practice.rookie, 0.45-0.6x the player's stats) until the player's first Win, so a new player's first larp-off is a win about 95% of the time; upsets stay possible. The NPC's minimum dropped from 20 to 1, and a stat the player has 0 of stays 0. A player with 0 total stats can't start a practice larp-off; the server sends a Notice pointing them at the Car Lot. Covered by Rules_Test.
- 2026-09-11 (Claude): src/larp is a read-only export of Claude-owned Studio scripts, checked by FNV-1a checksums (tools/verify-larp-mirror.ps1). Studio stays authoritative; nothing imports from the repo.
