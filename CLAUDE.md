# Shared developer workspace
Whenever resuming: (1) read docs/PROJECT_STATE.md, (2) docs/TASKS.md, (3) docs/DECISIONS.md, (4) docs/HANDOFF.md, (5) inspect Git history since your last session, (6) continue your owned tasks instead of rebuilding Codex's completed systems.
Read AGENTS.md and docs/ARCHITECTURE.md as well. Claim ownership before edits. One writer per subsystem; one global Studio playtest at a time. Never overwrite the other developer's unfinished changes.
Claude retains ownership of the pre-existing ReplicatedStorage.Larp, ServerScriptService.Larp, Workspace.Larp, Workspace.LarpStaging and future Bag SceneDirector. Codex owns separate CodexUI/CodexShared instances and sources explicitly mapped in docs.
Keep content in config, math and rewards on the server. No destructive sync, mass replace, or asset cleanup without checking live state. Run tests before marking DONE; update state and handoff, commit often and push. Source snapshots are historical; compare against Studio before use.

