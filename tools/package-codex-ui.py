"""Produce a reviewable source manifest. This does NOT write into Studio."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    paths = sorted((ROOT / "src/client/CodexUI").glob("*.lua"))
    paths.append(ROOT / "src/config/UIConfig.lua")
    entries = []
    for path in paths:
        source = path.read_text(encoding="utf-8").replace("\r\n", "\n")
        name = path.name.removesuffix(".client.lua").removesuffix(".lua")
        entries.append({
            "repositoryPath": path.relative_to(ROOT).as_posix(),
            "studioPath": "game.StarterPlayer.StarterPlayerScripts.CodexUI." + name,
            "className": "LocalScript" if path.name.endswith(".client.lua") else "ModuleScript",
            "normalizedSha256": hashlib.sha256(source.encode()).hexdigest(),
            "source": source,
        })
    output = ROOT / ".local/codex-ui-manifest.json"
    output.parent.mkdir(exist_ok=True)
    output.write_text(json.dumps({
        "authority": "repository additions; compare each live Source before installation",
        "requiresEditLease": True,
        "entries": entries,
    }, indent=2), encoding="utf-8")
    print(f"Prepared {len(entries)} sources: {output}")


if __name__ == "__main__":
    main()
