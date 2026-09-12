"""Checks which Google models this project can call on the global endpoint (preview models
like Lyria 3 and Gemini 3.1 only answer there)."""
import gcp

TEXT = ["gemini-2.5-pro", "gemini-3.1-pro-preview", "gemini-3-flash-preview"]
MUSIC = ["lyria-3-pro-preview", "lyria-3-clip-preview"]

for name in TEXT:
    try:
        r = gcp.post(f"publishers/google/models/{name}:generateContent",
                     {"contents": [{"role": "user", "parts": [{"text": "Say OK"}]}]}, timeout=60)
        print(name, "OK", r.get("modelVersion"))
    except Exception as e:
        print(name, str(e)[:80])
print("music models (not called, each call costs a generation):", ", ".join(MUSIC))
