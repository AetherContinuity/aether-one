#!/usr/bin/env python3
"""TrustCore v0.2 - attestaatioasiakas (Linux-laite, docs/VAIHE1-ENNAKKO.md).

Muutos v0.1:stä: TPM-virhe ei enää tuota hiljaa tyhjää quotea. Virhe
kirjataan kenttään tpm_error, jolloin todentaja vastaa A: UNKNOWN.
ML-DSA-allekirjoitus kattaa quoten tiivisteen (TC02-viesti).
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Dict, Optional

import cbor2

from .crypto import PQCManager, make_attestation_message, quote_hash, sha256
from .tpm_wrapper import TPMError, TPMWrapper


def _utc_ts() -> int:
    return int(datetime.now(timezone.utc).timestamp())


def _canon_json_bytes(obj: Any) -> bytes:
    return json.dumps(obj, sort_keys=True, separators=(",", ":")).encode("utf-8")


@dataclass
class TrustCoreConfig:
    server_url: str
    keydir: str = "trustcore_keys"
    policy_id: str = "trustcore-v0.2"
    include_sensor_hash: bool = True


class TrustCoreClient:
    def __init__(self, cfg: TrustCoreConfig):
        self.cfg = cfg
        self.pqc = PQCManager(cfg.keydir)

        self.tpm: Optional[TPMWrapper] = None
        self.tpm_init_error: Optional[str] = None
        try:
            self.tpm = TPMWrapper()
        except TPMError as e:
            self.tpm_init_error = str(e)

    def _sensor_state_hash(self, sensor_state: Dict[str, Any]) -> bytes:
        if not self.cfg.include_sensor_hash:
            return b""
        return sha256(_canon_json_bytes(sensor_state))

    def create_bundle(self, nonce: bytes, sensor_state: Dict[str, Any]) -> bytes:
        device_id = self.pqc.get_device_id()
        policy_id = self.cfg.policy_id

        quote: Dict[str, bytes] = {}
        tpm_error: Optional[str] = None
        if self.tpm is None:
            tpm_error = f"TPM ei käytettävissä: {self.tpm_init_error}"
        else:
            try:
                quote = self.tpm.quote(nonce)
            except TPMError as e:
                tpm_error = f"tpm2_quote epäonnistui: {e}"

        sensor_hash = self._sensor_state_hash(sensor_state)

        # Optional LR decision hash (hex string) included in signed message.
        dh_hex = str(sensor_state.get("decision_hash") or "")
        try:
            decision_hash = bytes.fromhex(dh_hex) if len(dh_hex) == 64 else (b"\x00" * 32)
        except Exception:
            decision_hash = b"\x00" * 32

        msg = make_attestation_message(
            device_id=device_id,
            policy_id=policy_id,
            nonce=nonce,
            quote_hash=quote_hash(quote),
            sensor_state_hash=sensor_hash,
            decision_hash=decision_hash,
        )
        pqc_sig = self.pqc.sign(msg)

        bundle: Dict[str, Any] = {
            "tc_version": 2,
            "timestamp": _utc_ts(),
            "device_id": device_id,
            "policy_id": policy_id,
            "nonce": nonce,
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
        if tpm_error:
            bundle["tpm_error"] = tpm_error
        return cbor2.dumps(bundle)

    def export_enrollment(self, platform: str, tpm_kind: str) -> Dict[str, Any]:
        """Rekisteröintitiedot omistajalle. Viedään todentajalle käsin (admin.py enroll).

        Laite ei rekisteröi itseään verkon yli (K4).
        """
        if self.tpm is None:
            raise TPMError(f"TPM ei käytettävissä: {self.tpm_init_error}")
        ak = self.tpm.read_ak_public()
        return {
            "device_id": self.pqc.get_device_id(),
            "platform": platform,
            "tpm_kind": tpm_kind,
            "ak_public_tss_hex": ak["ak_public_tss"].hex(),
            "ak_readpublic": ak["readpublic"],  # vain luettavaksi; todentaja ei käytä
            "algorithm": self.pqc.algorithm,
            "mldsa_public_hex": bytes(self.pqc.public_key).hex(),
            "mldsa_storage": "ohjelmisto (tiedosto, 0600)",
        }

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
