"""Vertex AI access for the asset tools: reads the gitignored .env at the repo root and
mints an OAuth token from the service-account key it names (no gcloud config changes)."""
import base64
import json
import os
import time
from pathlib import Path

import requests
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding

ROOT = Path(__file__).resolve().parents[2]


def env() -> dict:
    values = {}
    path = ROOT / ".env"
    if path.exists():
        for line in path.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                values[key.strip()] = value.strip()
    values.update({k: v for k, v in os.environ.items() if k in values})
    return values


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


_cache = {"token": None, "until": 0}


def token() -> str:
    if _cache["token"] and time.time() < _cache["until"]:
        return _cache["token"]
    key = json.loads(Path(env()["GOOGLE_APPLICATION_CREDENTIALS"]).read_text())
    now = int(time.time())
    header = _b64(json.dumps({"alg": "RS256", "typ": "JWT"}).encode())
    claims = _b64(json.dumps({
        "iss": key["client_email"],
        "scope": "https://www.googleapis.com/auth/cloud-platform",
        "aud": key["token_uri"],
        "iat": now,
        "exp": now + 3600,
    }).encode())
    signing_key = serialization.load_pem_private_key(key["private_key"].encode(), password=None)
    signature = signing_key.sign(f"{header}.{claims}".encode(), padding.PKCS1v15(), hashes.SHA256())
    jwt = f"{header}.{claims}.{_b64(signature)}"
    response = requests.post(key["token_uri"], data={
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": jwt,
    }, timeout=30)
    response.raise_for_status()
    _cache["token"] = response.json()["access_token"]
    _cache["until"] = time.time() + 3000
    return _cache["token"]


def base_url(version: str = "v1", location: str | None = None) -> str:
    e = env()
    location = location or e.get("GCP_LOCATION", "us-central1")
    host = "aiplatform.googleapis.com" if location == "global" else f"{location}-aiplatform.googleapis.com"
    return f"https://{host}/{version}/projects/{e['GCP_PROJECT']}/locations/{location}"


# Preview models (Lyria 3, Gemini 3) are served from the global endpoint only.
def post(path: str, body: dict, version: str = "v1", timeout: int = 300, location: str | None = "global") -> dict:
    for attempt in range(6):
        response = requests.post(f"{base_url(version, location)}/{path}", json=body, timeout=timeout,
                                 headers={"Authorization": f"Bearer {token()}"})
        if response.status_code not in (429, 503):
            break
        time.sleep(10 * 2 ** attempt)  # rate limited: back off 10, 20, 40... s
    if not response.ok:
        raise RuntimeError(f"{response.status_code}: {response.text[:800]}")
    return response.json()
