# Larpmaxxing collaboration
Read docs/PROJECT_STATE.md, TASKS.md, DECISIONS.md, HANDOFF.md and ARCHITECTURE.md before work. Read docs/SPEC.md for scope. Inspect Git history and status; claim a task in TASKS.md before editing.
Only one agent may mutate a Studio subsystem at a time. Claude owns the existing Larp framework, Bag scenes, map, assets and staging. Codex owns the explicitly listed CodexUI package and independent utilities. Never overwrite unfinished work. Coordinate play/stop globally; only one Studio writer/test operator.
The repo is a snapshot plus additive source, NOT authoritative live sync. No Rojo or bulk replacement. Compare live Source before editing; add only owned instances. Tests and temporary fixtures must not write production profiles.
Test before DONE. Commit meaningful work frequently. Update PROJECT_STATE.md and HANDOFF.md at the end of every meaningful session and push commits. Preserve data-driven trend definitions, server authority, and the Bag-only vertical slice. Never commit tokens, credentials, raw session logs, or unrelated private files.

