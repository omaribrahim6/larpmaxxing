# Decisions
- 2026-09-11: Reuse existing C:/Users/omarm/Documents/Larpmaxxing as repository root; no redundant nested directory. Remote requested as private larpmaxxing.
- Snapshot existing scripts under their full Studio paths; do not import them into new active source locations or install destructive sync.
- Preserve Claude ownership of all baseline scripts, map, assets and staging. Add UI under separate CodexUI namespace and independent utilities under CodexShared.
- UI reuses Catalog, RankMath and current remote names; no duplicate rank ladder, Signal or reward engine.
- Claude's services are not bootstrapped by Codex. Test fixtures run only in play sessions and never call DataStore APIs.
- No client decides rewards, eligibility or battle results. UI input is a request; the server must validate identity, distance, timeout, cooldown, rate limits and settings.
- Music/SFX/cosmetics remain client-session preferences until explicitly added to the existing server schema; Clip Mode/Reduce Effects are exposed to scene code without taking over its camera.
- Current scope is the Bag-only vertical slice authorized after the broader spec. Events and monetization are deferred.


- Final handoff: client deadline caps derive from Claude's Tuning. New SoundGroups are client-local and affect only sounds explicitly assigned by their owner. No production remotes/bootstrap or guessed match packet adapters were added. Temporary fixtures are removed and Studio playtest ownership is released.
