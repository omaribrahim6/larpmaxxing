"""Generates vocal-only background music with Lyria 3 on Vertex AI.

Usage: python lyria.py <track> [--takes N] [--model pro|clip]
Tracks and prompts live in tracks.json. Takes are saved (with any text the model
returns, e.g. its structure notes) to .local/audio/<track>/ at the repo root, which is
gitignored. Each take must still pass check.py and a human listen before it ships.
"""
import argparse
import base64
import json
import mimetypes
import time
from pathlib import Path

import gcp

HERE = Path(__file__).resolve().parent
OUT = gcp.ROOT / ".local" / "audio"
MODELS = {"pro": "lyria-3-pro-preview", "clip": "lyria-3-clip-preview"}


def prompt_for(track: dict, rules: str, plain: bool) -> str:
    # plain: the prompt without quoted sound words (Lyria tends to sing those as lyrics),
    # plus the track's lyric sheet of wordless vocables
    if plain and "prompt_plain" in track:
        return f"{track['prompt_plain']}\n\n{rules}\n\nLyrics:\n{track['lyrics']}"
    return f"{track['prompt']}\n\n{rules}"


def generate(prompt: str, model: str) -> tuple[bytes, str, str]:
    body = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "generationConfig": {"responseModalities": ["AUDIO", "TEXT"]},
    }
    result = gcp.post(f"publishers/google/models/{model}:generateContent", body, timeout=600)
    audio, mime, text = b"", "", []
    candidate = (result.get("candidates") or [{}])[0]
    for part in candidate.get("content", {}).get("parts", []):
        if "inlineData" in part:
            audio = base64.b64decode(part["inlineData"]["data"])
            mime = part["inlineData"].get("mimeType", "")
        elif "text" in part:
            text.append(part["text"])
    if not audio:
        raise RuntimeError(f"no audio in response: {json.dumps(result)[:600]}")
    return audio, mime, "\n".join(text)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("track")
    parser.add_argument("--takes", type=int, default=1)
    parser.add_argument("--model", default="pro", choices=MODELS)
    parser.add_argument("--rules", default="rules", help="which rules block in tracks.json to append")
    args = parser.parse_args()

    config = json.loads((HERE / "tracks.json").read_text(encoding="utf-8"))
    track = config["tracks"][args.track]
    prompt = prompt_for(track, config[args.rules], args.rules == "rules_plain")
    folder = OUT / args.track
    folder.mkdir(parents=True, exist_ok=True)
    existing = len(list(folder.glob("take*.meta.json")))
    n = existing
    for _ in range(args.takes):
        n += 1
        started = time.time()
        try:
            audio, mime, text = generate(prompt, MODELS[args.model])
        except RuntimeError as e:  # e.g. a filtered generation: skip it, keep going
            print(f"take skipped: {e}")
            n -= 1
            continue
        ext = mimetypes.guess_extension(mime) or ".bin"
        ext = {".mpga": ".mp3", ".x-wav": ".wav"}.get(ext, ext)
        path = folder / f"take{n:02d}{ext}"
        path.write_bytes(audio)
        (folder / f"take{n:02d}.meta.json").write_text(json.dumps({
            "model": MODELS[args.model], "rules": args.rules, "mime": mime, "prompt": prompt, "text": text,
            "seconds_to_generate": round(time.time() - started, 1),
        }, indent=2), encoding="utf-8")
        print(f"{path} ({len(audio) // 1024} KB, {mime}, {time.time() - started:.0f}s)")


if __name__ == "__main__":
    main()
