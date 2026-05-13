#!/usr/bin/env python3
"""TrustCore v0.1 – PQC crypto helpers.

Goals:
- Use OQS-native key bytes (no PEM dependency).
- Canonical message construction for signing/verifying.
- Graceful failure if liboqs-python is missing.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

try:
    import oqs  # type: ignore
except Exception:  # pragma: no cover
    oqs = None


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def sha256(data: bytes) -> bytes:
    return hashlib.sha256(data).digest()


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def make_signed_message(
    *,
    device_id: str,
    policy_id: str,
    nonce: bytes,
    pcrs_concat: bytes,
    sensor_state_hash: bytes,
    decision_hash: bytes,
) -> bytes:
    """Canonical bytes to sign.

    If you change this, bump bundle version.
    """
    parts = [
        b"TC01\x00",
        device_id.encode("utf-8"),
        b"\x00",
        policy_id.encode("utf-8"),
        b"\x00",
        nonce,
        b"\x00",
        pcrs_concat,
        b"\x00",
        sensor_state_hash,
        b"\x00",
        decision_hash,
    ]
    return b"".join(parts)


@dataclass
class PQCKeyMeta:
    algorithm: str
    public_key_hash: str
    created_utc: str


class PQCManager:
    """Manage Dilithium keys and signatures (OQS native key bytes)."""

    def __init__(self, keydir: str = "trustcore_keys", algorithm: str = "Dilithium3"):
        self.keydir = Path(keydir)
        self.keydir.mkdir(parents=True, exist_ok=True)
        self.algorithm = algorithm

        self.pub_path = self.keydir / "pqc_pub.bin"
        self.sec_path = self.keydir / "pqc_sec.bin"
        self.meta_path = self.keydir / "pqc_meta.json"

        self.public_key: bytes
        self.secret_key: bytes
        self.meta: PQCKeyMeta

        self._load_or_create_keys()

    @property
    def available(self) -> bool:
        return oqs is not None

    def _load_or_create_keys(self) -> None:
        if self.pub_path.exists() and self.sec_path.exists() and self.meta_path.exists():
            self.public_key = self.pub_path.read_bytes()
            self.secret_key = self.sec_path.read_bytes()
            meta = json.loads(self.meta_path.read_text(encoding="utf-8"))
            self.meta = PQCKeyMeta(
                algorithm=meta.get("algorithm", self.algorithm),
                public_key_hash=meta.get("public_key_hash", sha256_hex(self.public_key)),
                created_utc=meta.get("created_utc", ""),
            )
            return
        self._generate_keys()

    def _generate_keys(self) -> None:
        if oqs is None:
            raise ImportError("liboqs-python not installed. pip install liboqs-python")
        with oqs.Signature(self.algorithm) as sig:
            self.public_key = sig.generate_keypair()
            self.secret_key = sig.export_secret_key()

        self.pub_path.write_bytes(self.public_key)
        self.sec_path.write_bytes(self.secret_key)

        self.meta = PQCKeyMeta(
            algorithm=self.algorithm,
            public_key_hash=sha256_hex(self.public_key),
            created_utc=_utc_now_iso(),
        )
        self.meta_path.write_text(
            json.dumps(self.meta.__dict__, indent=2, sort_keys=True), encoding="utf-8"
        )

    def get_device_id(self) -> str:
        return sha256_hex(self.public_key)[:16]

    def sign(self, message: bytes) -> bytes:
        if oqs is None:
            raise ImportError("liboqs-python not installed")
        digest = sha256(message)
        with oqs.Signature(self.algorithm, secret_key=self.secret_key) as sig:
            return sig.sign(digest)

    def verify(self, message: bytes, signature: bytes, public_key: Optional[bytes] = None) -> bool:
        if oqs is None:
            raise ImportError("liboqs-python not installed")
        pk = public_key if public_key is not None else self.public_key
        digest = sha256(message)
        with oqs.Signature(self.algorithm, public_key=pk) as sig:
            return bool(sig.verify(digest, signature))
