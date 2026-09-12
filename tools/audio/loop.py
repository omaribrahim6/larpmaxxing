"""Turns a Lyria take into a seamless, loudness-matched game loop (.ogg).

Usage: python loop.py <take.mp3> [--out name] [--xfade 2.0] [--lufs -18]

Lyria 3 Pro reports its sections ([[A0]] [0.0:], [[B1]] [30.0:], ...) in the take's
meta text. The loop runs from the first section to the start of the last one (the
last is an outro that fades), and the first seconds of that outro are crossfaded over
the loop's head, so the end flows back into the start with no gap or click.
Output goes to .local/audio/final/<out>.ogg.
"""
import argparse
import json
import re
import subprocess
from pathlib import Path

import numpy as np

import gcp

RATE = 44100
FINAL = gcp.ROOT / ".local" / "audio" / "final"


def decode(path: Path) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le", "-ac", "2", "-ar", str(RATE), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).copy()


def sections(meta_text: str) -> list[float]:
    starts = [float(m) for m in re.findall(r"\[\[[A-Z]\d+\]\]\s*\n\[(\d+(?:\.\d+)?):\]", meta_text)]
    return sorted(set(starts))


def loudness(path: Path) -> float:
    log = subprocess.run(["ffmpeg", "-v", "info", "-nostats", "-i", str(path), "-af", "ebur128", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    return float(re.findall(r"I:\s+(-?\d+(?:\.\d+)?) LUFS", log)[-1])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("take")
    parser.add_argument("--out")
    parser.add_argument("--xfade", type=float, default=2.0)
    parser.add_argument("--lufs", type=float, default=-18.0)
    parser.add_argument("--start", type=float, help="override loop start (s)")
    parser.add_argument("--end", type=float, help="override loop end (s)")
    args = parser.parse_args()

    take = Path(args.take)
    meta = json.loads(take.with_name(take.stem + ".meta.json").read_text(encoding="utf-8"))
    marks = sections(meta["text"])
    audio = decode(take)
    total = len(audio) / RATE
    start = args.start if args.start is not None else (marks[0] if marks else 0.0)
    end = args.end if args.end is not None else (marks[-1] if len(marks) > 1 else total - args.xfade)
    if end + args.xfade > total:
        raise SystemExit(f"loop end {end}s + crossfade runs past the take ({total:.1f}s)")

    a, b, x = int(start * RATE), int(end * RATE), int(args.xfade * RATE)
    loop = audio[a:b].copy()
    # equal-power crossfade: the audio just after the loop end fades out over the head
    t = np.linspace(0, np.pi / 2, x, dtype=np.float32)[:, None]
    loop[:x] = loop[:x] * np.sin(t) + audio[b:b + x] * np.cos(t)

    FINAL.mkdir(parents=True, exist_ok=True)
    name = args.out or f"{take.parent.name}_{take.stem}"
    wav = FINAL / f"{name}.wav"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ac", "2", "-ar", str(RATE), "-i", "-", str(wav)],
                   input=loop.astype(np.float32).tobytes(), check=True)
    gain = args.lufs - loudness(wav)
    peak = float(np.abs(loop).max()) * 10 ** (gain / 20)
    if peak > 0.97:  # never clip: settle for a quieter loop
        gain -= 20 * np.log10(peak / 0.97)
    ogg = FINAL / f"{name}.ogg"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-af", f"volume={gain:.2f}dB",
                    "-c:a", "libvorbis", "-q:a", "6", str(ogg)], check=True)
    wav.unlink()
    print(f"{ogg.name}: loop {start:.1f}-{end:.1f}s ({end - start:.1f}s), sections {marks}, gain {gain:+.1f} dB, "
          f"{ogg.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
