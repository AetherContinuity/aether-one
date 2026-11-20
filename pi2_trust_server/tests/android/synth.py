#!/usr/bin/env python3
"""Synteettiset Android-attestaatioketjut testijuuren alle (VAIHE2-ENNAKKO K8).

Testijuuri ei ole tuotannon luottamusjoukossa. Ketjut ajetaan myös Googlen
jäsentimellä (K7), jotta tämä kooderi ei ole oman jäsentimen ainoa tuomari.

  python3 synth.py OUTDIR   # kirjoittaa vertailuketjut OUTDIR/<nimi>/c<i>.der
"""

from __future__ import annotations

import os
import sys
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Dict, List, Optional

from cryptography import x509
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
from cryptography.x509.oid import NameOID

KD_OID = x509.ObjectIdentifier("1.3.6.1.4.1.11129.2.1.17")
T0 = datetime(2026, 1, 1, tzinfo=timezone.utc)
NOW = datetime(2026, 11, 20, 12, 0, tzinfo=timezone.utc)
LEVEL = {"SOFTWARE": 0, "TRUSTED_ENVIRONMENT": 1, "STRONG_BOX": 2}
STATE = {"VERIFIED": 0, "SELF_SIGNED": 1, "UNVERIFIED": 2, "FAILED": 3}
PURPOSE = {"SIGN": 2, "VERIFY": 3, "ATTEST_KEY": 7}


# --- DER-kooderi ------------------------------------------------------------

def _len(n: int) -> bytes:
    if n < 0x80:
        return bytes([n])
    b = n.to_bytes((n.bit_length() + 7) // 8, "big")
    return bytes([0x80 | len(b)]) + b


def tlv(tag: int, body: bytes) -> bytes:
    return bytes([tag]) + _len(len(body)) + body


def der_int(v: int) -> bytes:
    n = max(1, (v.bit_length() + 8) // 8)
    return tlv(0x02, v.to_bytes(n, "big", signed=True))


def der_enum(v: int) -> bytes:
    return tlv(0x0A, der_int(v)[2:])


def explicit(tag: int, inner: bytes) -> bytes:
    if tag < 31:
        head = bytes([0xA0 | tag])
    else:
        t, out = tag, [tag & 0x7F]
        t >>= 7
        while t:
            out.insert(0, 0x80 | (t & 0x7F))
            t >>= 7
        head = bytes([0xBF]) + bytes(out)
    return head + _len(len(inner)) + inner


def der_set_of(items: List[bytes]) -> bytes:
    return tlv(0x31, b"".join(sorted(items)))


def auth_list(purposes=(), algorithm: Optional[int] = None, rot: Optional[dict] = None,
              os_version: Optional[int] = None, patches: Optional[Dict[str, int]] = None) -> bytes:
    parts = []
    if purposes:
        parts.append(explicit(1, der_set_of([der_int(PURPOSE[p]) for p in purposes])))
    if algorithm is not None:
        parts.append(explicit(2, der_int(algorithm)))
    if rot is not None:
        body = (tlv(0x04, rot["key"]) + tlv(0x01, b"\xff" if rot["locked"] else b"\x00")
                + der_enum(STATE[rot["state"]]) + tlv(0x04, rot.get("hash", b"\x11" * 32)))
        parts.append(explicit(704, tlv(0x30, body)))
    if os_version is not None:
        parts.append(explicit(705, der_int(os_version)))
    patches = patches or {}
    for tag, name in ((706, "os"), (718, "vendor"), (719, "boot")):
        if name in patches:
            parts.append(explicit(tag, der_int(patches[name])))
    return tlv(0x30, b"".join(parts))


def key_description(challenge: bytes, level: str = "TRUSTED_ENVIRONMENT", hw: bytes = b"",
                    sw: bytes = b"", version: int = 300) -> bytes:
    return tlv(0x30, der_int(version) + der_enum(LEVEL[level]) + der_int(version)
               + der_enum(LEVEL[level]) + tlv(0x04, challenge) + tlv(0x04, b"")
               + (sw or tlv(0x30, b"")) + (hw or tlv(0x30, b"")))


# --- varmenteet -------------------------------------------------------------

def _name(cn: str) -> x509.Name:
    return x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, cn)])


def cert(subject: str, key, issuer: str, issuer_key, kd: Optional[bytes] = None,
         nb: datetime = T0, na: datetime = T0 + timedelta(days=3650), serial: Optional[int] = None,
         ca: bool = False) -> bytes:
    b = (x509.CertificateBuilder().subject_name(_name(subject)).issuer_name(_name(issuer))
         .public_key(key.public_key()).serial_number(serial or x509.random_serial_number())
         .not_valid_before(nb).not_valid_after(na))
    if ca:
        b = b.add_extension(x509.BasicConstraints(ca=True, path_length=None), critical=True)
    if kd is not None:
        b = b.add_extension(x509.UnrecognizedExtension(KD_OID, kd), critical=False)
    return b.sign(issuer_key, hashes.SHA256()).public_bytes(Encoding.DER)


def spki(key) -> bytes:
    return key.public_key().public_bytes(Encoding.DER, PublicFormat.SubjectPublicKeyInfo)


def newkey():
    return ec.generate_private_key(ec.SECP256R1())


@dataclass
class Pki:
    """Testijuuri ja välivarmenne (simuloi Googlen juurta ja laitteen erävarmennetta)."""
    root_key: object = field(default_factory=newkey)
    inter_key: object = field(default_factory=newkey)
    inter_serial: int = 0x5EED0001
    inter_na: datetime = T0 + timedelta(days=3650)

    def __post_init__(self):
        self.root = cert("TC TESTIJUURI (ei tuotanto)", self.root_key, "TC TESTIJUURI (ei tuotanto)",
                         self.root_key, ca=True)
        self.inter = cert("TC testivälivarmenne TEE", self.inter_key, "TC TESTIJUURI (ei tuotanto)",
                          self.root_key, serial=self.inter_serial, na=self.inter_na, ca=True)


VBK = bytes.fromhex("aa" * 32)
GOOD_ROT = {"key": VBK, "locked": True, "state": "VERIFIED"}
GOOD_PATCH = {"os": 202610, "vendor": 20261005, "boot": 20261005}


@dataclass
class Device:
    pki: Pki
    mode: str = "attest_key"
    k_level: str = "TRUSTED_ENVIRONMENT"
    k_purposes: tuple = ("ATTEST_KEY",)
    k_key: object = field(default_factory=newkey)

    def k_chain(self, enroll_nonce: bytes, rot: dict = GOOD_ROT) -> List[bytes]:
        kd = key_description(enroll_nonce, self.k_level,
                             hw=auth_list(self.k_purposes, 3, rot, 170000, GOOD_PATCH))
        kc = cert("K", self.k_key, "TC testivälivarmenne TEE", self.pki.inter_key, kd)
        return [kc, self.pki.inter, self.pki.root]

    def fresh(self, nonce: bytes, rot: Optional[dict] = GOOD_ROT, patches: Optional[dict] = GOOD_PATCH,
              level: str = "TRUSTED_ENVIRONMENT", patches_sw_only: bool = False,
              signer=None, enroll_nonce: bytes = b"\x00" * 32) -> List[bytes]:
        """Tuore avain challenge = nonce. attest_key: K allekirjoittaa lehden."""
        hw = auth_list(("SIGN",), 3, rot, 170000, None if patches_sw_only else patches)
        sw = auth_list(patches=patches) if patches_sw_only else b""
        kd = key_description(nonce, level, hw=hw, sw=sw)
        leaf_key = newkey()
        if self.mode == "attest_key":
            kc = self.k_chain(enroll_nonce)[0]
            sk = signer or self.k_key
            leaf = cert("Android Keystore Key", leaf_key, "K", sk, kd)
            return [leaf, kc, self.pki.inter, self.pki.root]
        leaf = cert("Android Keystore Key", leaf_key, "TC testivälivarmenne TEE", self.pki.inter_key, kd)
        return [leaf, self.pki.inter, self.pki.root]

    def k_sign(self, msg: bytes) -> bytes:
        return self.k_key.sign(msg, ec.ECDSA(hashes.SHA256()))


def reference_set(out: Path) -> None:
    """Kirjoittaa Googlen jäsentimen vertailuun kattavan joukon synteettisiä ketjuja."""
    pki = Pki()
    n = bytes(range(32))
    variants = {
        "synt_attest_ok": Device(pki).fresh(n),
        "synt_strongbox": Device(pki, k_level="STRONG_BOX").fresh(n, level="STRONG_BOX"),
        "synt_unlocked": Device(pki).fresh(n, rot={**GOOD_ROT, "locked": False}),
        "synt_unverified": Device(pki).fresh(n, rot={**GOOD_ROT, "state": "UNVERIFIED"}),
        "synt_selfsigned": Device(pki).fresh(n, rot={**GOOD_ROT, "state": "SELF_SIGNED"}),
        "synt_no_rot": Device(pki).fresh(n, rot=None),
        "synt_patch_partial": Device(pki).fresh(n, patches={"os": 202610}),
        "synt_patch_sw": Device(pki).fresh(n, patches_sw_only=True),
        "synt_software": Device(pki).fresh(n, level="SOFTWARE"),
        "synt_signed_mode": Device(pki, mode="signed", k_purposes=("SIGN",)).fresh(n),
        "synt_k_enroll": Device(pki).k_chain(os.urandom(32)),
    }
    for name, ders in variants.items():
        d = out / name
        d.mkdir(parents=True, exist_ok=True)
        for i, der in enumerate(ders):
            (d / f"c{i}.der").write_bytes(der)


if __name__ == "__main__":
    reference_set(Path(sys.argv[1]))
