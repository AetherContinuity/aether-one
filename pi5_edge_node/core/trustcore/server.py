#!/usr/bin/env python3
"""TrustCore v0.1 – Attestation verification server.

Endpoints:
- GET  /nonce  -> {nonce: hex}
- POST /verify -> verifies CBOR bundle, returns PASS/FAIL

Demo policy:
- First-seen device enrollment is allowed by default.
- Optional baseline PCR enforcement if enrolled with baseline.

Run:
  python -m core.trustcore.server
"""

from __future__ import annotations

import hashlib
import json
import os
import secrets
import time
from pathlib import Path
from typing import Any, Dict, Optional

import cbor2
from fastapi import FastAPI, HTTPException, Request

from .crypto import make_signed_message, sha256_hex

try:
    import oqs  # type: ignore
except Exception:  # pragma: no cover
    oqs = None


APP = FastAPI(title="TrustCore v0.1 Attestation Server")

DATA_DIR = Path(os.environ.get("TRUSTCORE_DATA_DIR", ".trustcore_server"))
DATA_DIR.mkdir(parents=True, exist_ok=True)

DEVICES_FILE = DATA_DIR / "devices.json"
NONCE_TTL_SEC = int(os.environ.get("TRUSTCORE_NONCE_TTL", "120"))
ALLOW_FIRST_SEEN = os.environ.get("TRUSTCORE_ALLOW_FIRST_SEEN", "1") not in ("0", "false", "False")

# nonce_hex -> expires_at
_NONCES: Dict[str, int] = {}


def _load_devices() -> Dict[str, Any]:
    if DEVICES_FILE.exists():
        return json.loads(DEVICES_FILE.read_text(encoding="utf-8"))
    return {"devices": {}}


def _save_devices(db: Dict[str, Any]) -> None:
    DEVICES_FILE.write_text(json.dumps(db, indent=2, sort_keys=True), encoding="utf-8")


def _prune_nonces() -> None:
    now = int(time.time())
    for n, exp in list(_NONCES.items()):
        if exp <= now:
            _NONCES.pop(n, None)


@APP.get("/nonce")
def get_nonce() -> Dict[str, str]:
    _prune_nonces()
    nonce = secrets.token_bytes(32)
    nonce_hex = nonce.hex()
    _NONCES[nonce_hex] = int(time.time()) + NONCE_TTL_SEC
    return {"nonce": nonce_hex}


def _consume_nonce(nonce_hex: str) -> Optional[str]:
    _prune_nonces()
    exp = _NONCES.get(nonce_hex)
    if exp is None:
        return "Nonce unknown/expired"
    _NONCES.pop(nonce_hex, None)
    return None


def _verify_pqc(bundle: Dict[str, Any]) -> Optional[str]:
    if oqs is None:
        return "PQC backend not available on server (liboqs-python missing)"

    pqc = bundle.get("pqc") or {}
    algorithm = pqc.get("algorithm")
    public_key = pqc.get("public_key")
    signature = pqc.get("signature")

    if not (algorithm and public_key and signature):
        return "Missing PQC fields"

    device_id = bundle.get("device_id")
    policy_id = bundle.get("policy_id")
    nonce = bundle.get("nonce")
    pcrs = bundle.get("pcrs") or {}
    sensor_hash = bundle.get("sensor_state_hash") or b""
    decision_hash = bundle.get("decision_hash") or (b"\x00" * 32)

    if not (device_id and policy_id and isinstance(nonce, (bytes, bytearray))):
        return "Missing core fields"

    pcrs_concat = b"".join(pcrs[k] for k in sorted(pcrs.keys())) if isinstance(pcrs, dict) else b""
    msg = make_signed_message(
        device_id=str(device_id),
        policy_id=str(policy_id),
        nonce=bytes(nonce),
        pcrs_concat=pcrs_concat,
        sensor_state_hash=bytes(sensor_hash),
        decision_hash=bytes(decision_hash),
    )
    digest = hashlib.sha256(msg).digest()

    try:
        with oqs.Signature(str(algorithm), public_key=bytes(public_key)) as verifier:
            ok = bool(verifier.verify(digest, bytes(signature)))
    except Exception as e:
        return f"PQC verify error: {e}"

    if not ok:
        return "PQC signature invalid"
    return None


@APP.post("/verify")
async def verify(req: Request) -> Dict[str, Any]:
    raw = await req.body()
    try:
        bundle = cbor2.loads(raw)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid CBOR")

    nonce = bundle.get("nonce")
    if not isinstance(nonce, (bytes, bytearray)):
        raise HTTPException(status_code=400, detail="Missing nonce")
    nonce_hex = bytes(nonce).hex()
    reason = _consume_nonce(nonce_hex)
    if reason:
        return {"status": "FAIL", "reason": reason, "ts": int(time.time())}

    pqc_reason = _verify_pqc(bundle)
    if pqc_reason:
        return {"status": "FAIL", "reason": pqc_reason, "ts": int(time.time())}

    device_id = bundle.get("device_id")
    pqc = bundle.get("pqc") or {}
    pk_hash = pqc.get("public_key_hash") or sha256_hex(pqc.get("public_key") or b"")

    db = _load_devices()
    devices = db.setdefault("devices", {})
    dev = devices.get(device_id)

    if dev is None:
        if not ALLOW_FIRST_SEEN:
            return {"status": "FAIL", "reason": "Device not enrolled", "ts": int(time.time())}
        devices[device_id] = {
            "public_key_hash": pk_hash,
            "algorithm": pqc.get("algorithm"),
            "enrolled_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "baseline_pcrs": None,
        }
        _save_devices(db)
        dev = devices[device_id]
    else:
        if dev.get("public_key_hash") and dev.get("public_key_hash") != pk_hash:
            return {"status": "FAIL", "reason": "Public key mismatch", "ts": int(time.time())}

    baseline = dev.get("baseline_pcrs")
    if baseline:
        pcrs = bundle.get("pcrs") or {}
        for k, expected_hex in baseline.items():
            actual = pcrs.get(k)
            if isinstance(actual, (bytes, bytearray)):
                if bytes(actual).hex() != expected_hex:
                    return {"status": "FAIL", "reason": f"{k} mismatch", "ts": int(time.time())}

    return {
        "status": "PASS",
        "device_id": device_id,
        "policy_id": bundle.get("policy_id"),
        "ts": int(time.time()),
    }


@APP.post("/enroll/{device_id}")
async def enroll(device_id: str, req: Request) -> Dict[str, Any]:
    """Set baseline PCRs for a device.

    Body JSON: {"baseline_pcrs": {"pcr0": "<hex>", ...}}
    """
    try:
        body = await req.json()
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid JSON")

    baseline = body.get("baseline_pcrs")
    if not isinstance(baseline, dict):
        raise HTTPException(status_code=400, detail="baseline_pcrs must be a dict")

    db = _load_devices()
    devices = db.setdefault("devices", {})
    if device_id not in devices:
        raise HTTPException(status_code=404, detail="Device not enrolled yet")
    devices[device_id]["baseline_pcrs"] = baseline
    _save_devices(db)
    return {"status": "OK", "device_id": device_id, "baseline_keys": sorted(baseline.keys())}


def main() -> None:
    import uvicorn

    host = os.environ.get("TRUSTCORE_HOST", "0.0.0.0")
    port = int(os.environ.get("TRUSTCORE_PORT", "5000"))
    uvicorn.run("core.trustcore.server:APP", host=host, port=port, reload=False)


if __name__ == "__main__":
    main()
