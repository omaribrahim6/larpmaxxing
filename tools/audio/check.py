"""Has Gemini listen to a take and report every sound source, so any instrument fails it.

Usage: python check.py <audio file>... [--model gemini-2.5-pro]
Writes <take>.check.<model>.json next to each file and prints a one-line verdict.
Run it with two different models (gemini-2.5-pro and gemini-3.1-pro-preview): they catch
different things. This is a screen, not a guarantee: a human listens before anything ships.
"""
import argparse
import base64
import json
from pathlib import Path

import gcp

PROMPT = """You are auditing a background music track for a video game. The owner follows a strict rule:
the ONLY allowed sounds are (1) human voices and mouth sounds (singing, humming, wordless 'ooh'/'bah'
vocals, vocal bass, beatboxing / vocal percussion) and (2) natural or room ambience (wind, leaves,
birds, crowd murmur, cafe noise). ANY musical instrument or electronic sound fails the track: piano, keys,
guitar, bass guitar, synth, pads, strings, brass, organ, bells, chimes, drum kit, drum machine or
programmed drums, 808s, electronic effects that sound like instruments.
Body percussion (finger snaps, hand claps, thigh slaps, stomps) is NOT an instrument: do not list it under
instruments and do not fail the track for it, but report it separately in body_percussion so the owner can
decide.

Listen to the ENTIRE track carefully, start to end. Be skeptical: beatboxing sounds like drums, so judge
whether each percussive sound is plausibly a human mouth or a real/electronic drum. Sub-bass or a smooth
sustained tone that no voice could make counts as an instrument. If you are not sure, say so.

Also report whether any actual words/lyrics are sung (and which), and whether the style sounds Middle
Eastern / Arabic / Islamic (maqam scales, nasheed style, Quranic-style recitation)."""

SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "verdict": {"type": "STRING", "enum": ["pass", "fail", "unsure"]},
        "instruments": {"type": "ARRAY", "items": {"type": "OBJECT", "properties": {
            "sound": {"type": "STRING"}, "start": {"type": "STRING"}, "end": {"type": "STRING"},
            "confidence": {"type": "NUMBER"}}, "required": ["sound", "start", "confidence"]}},
        "body_percussion": {"type": "ARRAY", "items": {"type": "STRING"}},
        "vocal_sounds": {"type": "ARRAY", "items": {"type": "STRING"}},
        "ambience": {"type": "ARRAY", "items": {"type": "STRING"}},
        "sung_words": {"type": "BOOLEAN"},
        "words_heard": {"type": "STRING"},
        "middle_eastern_style": {"type": "BOOLEAN"},
        "mood": {"type": "STRING"},
        "tempo_bpm": {"type": "NUMBER"},
        "summary": {"type": "STRING"},
    },
    "required": ["verdict", "instruments", "body_percussion", "vocal_sounds", "sung_words", "middle_eastern_style", "summary"],
}

MIME = {".mp3": "audio/mpeg", ".wav": "audio/wav", ".ogg": "audio/ogg", ".flac": "audio/flac"}


def check(path: Path, model: str) -> dict:
    body = {
        "contents": [{"role": "user", "parts": [
            {"inlineData": {"mimeType": MIME[path.suffix.lower()], "data": base64.b64encode(path.read_bytes()).decode()}},
            {"text": PROMPT},
        ]}],
        "generationConfig": {"responseMimeType": "application/json", "responseSchema": SCHEMA, "temperature": 0,
                             "maxOutputTokens": 16384},
    }
    for attempt in range(3):  # a reply cut short is not valid JSON: ask again
        result = gcp.post(f"publishers/google/models/{model}:generateContent", body, timeout=600)
        parts = (result.get("candidates") or [{}])[0].get("content", {}).get("parts", [])
        text = "".join(p.get("text", "") for p in parts)
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            if attempt == 2:
                raise


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("files", nargs="+")
    parser.add_argument("--model", default="gemini-2.5-pro")
    args = parser.parse_args()
    for name in args.files:
        path = Path(name)
        report = check(path, args.model)
        path.with_suffix(f".check.{args.model}.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
        flagged = ", ".join(f"{i['sound']}@{i['start']}({i['confidence']})" for i in report["instruments"]) or "none"
        body = ", ".join(report.get("body_percussion", [])) or "none"
        print(f"{path.parent.name}/{path.name}: {report['verdict'].upper()} | instruments: {flagged} | body: {body} "
              f"| words: {report['sung_words']} | ME style: {report['middle_eastern_style']}")
        print(f"   {report['summary']}")


if __name__ == "__main__":
    main()
