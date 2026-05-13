#!/usr/bin/env python3
"""TrustCore v0.1 – Attestation client for Aether One Pi5 stack."""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Dict, Optional

import cbor2

from .crypto import PQCManager, make_signed_message, sha256
from .tpm_wrapper import TPMError, TPMWrapper


def _utc_ts() -> int:
    return int(datetime.now(timezone.utc).timestamp())


def _canon_json_bytes(obj: Any) -> bytes:
    return json.dumps(obj, sort_keys=True, separators=(",", ":")).encode("utf-8")


@dataclass
class TrustCoreConfig:
    server_url: str
    keydir: str = "trustcore_keys"
    policy_id: str = "policy_demo"
    include_sensor_hash: bool = True


class TrustCoreClient:
    def __init__(self, cfg: TrustCoreConfig):
        self.cfg = cfg
        self.pqc = PQCManager(cfg.keydir)

        self.tpm_available = False
        self.tpm: Optional[TPMWrapper] = None
        try:
            self.tpm = TPMWrapper()
            self.tpm_available = True
        except TPMError:
            self.tpm = None
            self.tpm_available = False

    def _sensor_state_hash(self, sensor_state: Dict[str, Any]) -> bytes:
        if not self.cfg.include_sensor_hash:
            return b""
        return sha256(_canon_json_bytes(sensor_state))

    def create_bundle(self, nonce: bytes, sensor_state: Dict[str, Any]) -> bytes:
        device_id = self.pqc.get_device_id()
        policy_id = self.cfg.policy_id

        pcrs: Dict[str, bytes] = {}
        quote: Dict[str, bytes] = {}
        if self.tpm_available and self.tpm is not None:
            pcrs = self.tpm.get_pcrs()
            try:
                quote = self.tpm.quote(nonce)
            except TPMError:
                quote = {}

        pcrs_concat = b"".join(pcrs[k] for k in sorted(pcrs.keys()))
        sensor_hash = self._sensor_state_hash(sensor_state)

        # Optional LR decision hash (hex string) included in signed message.
        dh_hex = str(sensor_state.get("decision_hash") or "")
        try:
            decision_hash = bytes.fromhex(dh_hex) if len(dh_hex) == 64 else (b"\x00" * 32)
        except Exception:
            decision_hash = b"\x00" * 32

        msg = make_signed_message(
            device_id=device_id,
            policy_id=policy_id,
            nonce=nonce,
            pcrs_concat=pcrs_concat,
            sensor_state_hash=sensor_hash,
            decision_hash=decision_hash,
        )
        pqc_sig = self.pqc.sign(msg)

        bundle = {
            "tc_version": 1,
            "timestamp": _utc_ts(),
            "device_id": device_id,
            "policy_id": policy_id,
            "nonce": nonce,
            "pcrs": pcrs,
            "pcr_bank": "sha256",
            "tpm_quote": quote,
            "pqc": {
                "algorithm": self.pqc.algorithm,
                "public_key": self.pqc.public_key,
                "public_key_hash": self.pqc.meta.public_key_hash,
                "signature": pqc_sig,
                "signed_message_hash": hashlib.sha256(msg).digest(),
            },
            "sensor_state_hash": sensor_hash,
            "decision_hash": decision_hash,
        }
        return cbor2.dumps(bundle)

    async def attest(self, sensor_state: Dict[str, Any], server_url: Optional[str] = None) -> Dict[str, Any]:
        import httpx

        url = (server_url or self.cfg.server_url).rstrip("/")
        async with httpx.AsyncClient(timeout=10.0) as client:
            r = await client.get(f"{url}/nonce")
            r.raise_for_status()
            nonce = bytes.fromhex(r.json()["nonce"])

            bundle = self.create_bundle(nonce, sensor_state)
            r2 = await client.post(
                f"{url}/verify",
                content=bundle,
                headers={"Content-Type": "application/cbor"},
            )
            r2.raise_for_status()
            return r2.json()
