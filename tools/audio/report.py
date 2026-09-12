"""One table of every take and what each listener heard. Writes .local/audio/report.json.

A take is CLEAN when every listener that checked it found no instruments, no Middle
Eastern style and (for reports that track it) no body percussion; it still needs a
human listen. Old reports that lumped snaps/claps in with instruments count them there.
"""
import json

import gcp

AUDIO = gcp.ROOT / ".local" / "audio"
LISTENERS = ["gemini-2.5-pro", "gemini-3.1-pro-preview"]


def main():
    rows = []
    for take in sorted(AUDIO.glob("*/take*.mp3")):
        meta = json.loads(take.with_name(take.stem + ".meta.json").read_text(encoding="utf-8"))
        row = {"track": take.parent.name, "take": take.stem, "rules": meta.get("rules", "rules"), "listeners": {}}
        clean = True
        for model in LISTENERS:
            path = take.with_suffix(f".check.{model}.json")
            if not path.exists():
                row["listeners"][model] = "unchecked"
                clean = False
                continue
            r = json.loads(path.read_text(encoding="utf-8"))
            bad = [i["sound"] for i in r["instruments"] if "vocal" not in i["sound"].lower() and "singing" not in i["sound"].lower()]
            body = r.get("body_percussion", [])
            words = r.get("words_heard") if r.get("sung_words") else ""
            row["listeners"][model] = {"instruments": bad, "body": body, "words": words, "me": r["middle_eastern_style"]}
            clean = clean and not bad and not body and not r["middle_eastern_style"]
        row["clean"] = clean
        rows.append(row)
    (AUDIO / "report.json").write_text(json.dumps(rows, indent=2), encoding="utf-8")
    for row in rows:
        cells = []
        for model, v in row["listeners"].items():
            short = model.replace("gemini-", "").replace("-preview", "")
            if v == "unchecked":
                cells.append(f"{short}: -")
            else:
                issues = v["instruments"] + [f"body:{b}" for b in v["body"]] + (["ME"] if v["me"] else [])
                cells.append(f"{short}: {', '.join(issues) or 'ok'}" + (f" [words: {v['words']}]" if v["words"] else ""))
        print(f"{'CLEAN' if row['clean'] else '     '} {row['track']:7} {row['take']} ({row['rules']:14}) " + " | ".join(cells))


if __name__ == "__main__":
    main()
