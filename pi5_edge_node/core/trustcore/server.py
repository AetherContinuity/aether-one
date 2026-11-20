#!/usr/bin/env python3
"""TrustCore v0.2 - todentajan HTTP-pinta (Trust Server, Pi 2).

Endpointit:
- GET  /nonce  -> {nonce: hex}, kertakäyttöinen, TTL TRUSTCORE_NONCE_TTL s
- POST /verify -> CBOR-todistepaketti; vastaus väitekohtaisesti (verifier.evaluate)

Vastauksessa ei ole yhteistä status-kenttää (docs/ATTESTATION-LEVELS.md).
Laitteet rekisteröidään käsin: python -m core.trustcore.admin enroll ...
v0.1:n /enroll ja first-seen-rekisteröinti on poistettu (KORJAUSLISTA A16).

Ajo:
  python -m core.trustcore.server
"""

from __future__ import annotations

import json
import os
import secrets
import time
from pathlib import Path
from typing import Any, Dict, Optional

import cbor2
from fastapi import FastAPI, Request

from .verifier import evaluate

APP = FastAPI(title="TrustCore v0.2 Attestation Verifier")

DATA_DIR = Path(os.environ.get("TRUSTCORE_DATA_DIR", ".trustcore_server"))
DEVICES_FILE = DATA_DIR / "devices.json"
NONCE_TTL_SEC = int(os.environ.get("TRUSTCORE_NONCE_TTL", "120"))

# nonce_hex -> expires_at
_NONCES: Dict[str, int] = {}


def load_devices(path: Path = DEVICES_FILE) -> Dict[str, Any]:
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return {"devices": {}}


def _prune_nonces() -> None:
    now = int(time.time())
    for n, exp in list(_NONCES.items()):
        if exp <= now:
            _NONCES.pop(n, None)


@APP.get("/nonce")
def get_nonce() -> Dict[str, str]:
    _prune_nonces()
    nonce = secrets.token_bytes(32)
    _NONCES[nonce.hex()] = int(time.time()) + NONCE_TTL_SEC
    return {"nonce": nonce.hex()}


def _consume_nonce(nonce: Any) -> Optional[str]:
    if not isinstance(nonce, (bytes, bytearray)):
        return "puuttuu"
    _prune_nonces()
    if _NONCES.pop(bytes(nonce).hex(), None) is None:
        return "tuntematon, vanhentunut tai jo käytetty"
    return None


def verify_bytes(raw: bytes) -> Dict[str, Any]:
    try:
        bundle = cbor2.loads(raw)
    except Exception:
        bundle = None
    if not isinstance(bundle, dict):
        return {**evaluate(None, None, None), "ts": int(time.time())}
    nonce_error = _consume_nonce(bundle.get("nonce"))
    dev = load_devices().get("devices", {}).get(str(bundle.get("device_id")))
    return {**evaluate(bundle, dev, nonce_error), "ts": int(time.time())}


@APP.post("/verify")
async def verify(req: Request) -> Dict[str, Any]:
    return verify_bytes(await req.body())


def main() -> None:
    import uvicorn

    host = os.environ.get("TRUSTCORE_HOST", "0.0.0.0")
    port = int(os.environ.get("TRUSTCORE_PORT", "5000"))
    uvicorn.run("core.trustcore.server:APP", host=host, port=port, reload=False)


if __name__ == "__main__":
    main()
