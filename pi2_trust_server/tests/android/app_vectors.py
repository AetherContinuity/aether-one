#!/usr/bin/env python3
"""Vaihe 3 S1/S2: sovelluksen tavut = todentajan tavut.

  gen FILE      # kultaiset vektorit Kotlinin yksikkötestille (avain=hex-rivit)
  check DIR     # Kotlin-testin tuottamat tiedostot: CBOR-paketti jäsentyy,
                # TC02-viesti lasketaan todentajan koodilla, ML-DSA verifioituu
                # liboqs:llä, turmeltu allekirjoitus ei verifioidu.

Todentajan koodi (core.trustcore.crypto) on lähde; Kotlin seuraa sitä.
"""

from __future__ import annotations

import hashlib
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))

from core.trustcore.android_verify import chain_digest, k_signed_message  # noqa: E402
from core.trustcore.crypto import evidence_hash, make_attestation_message  # noqa: E402

DEVICE_ID = "0123456789abcdef"
POLICY = "trustcore-v0.2"
NONCE = bytes(range(32))
CHAIN = [bytes.fromhex("3003020101"), b"abc", bytes(range(200))]
KSIG = bytes.fromhex("0102")
DECISION = b"\x00" * 32


def vectors() -> dict:
    out = {}
    for mode, ksig in (("attest_key", None), ("signed", KSIG)):
        ev = {"mode": mode, "chain": CHAIN}
        if ksig is not None:
            ev["k_sig"] = ksig
        b = {"android": ev}
        eh = evidence_hash(b)
        out[f"{mode}.evidence_hash"] = eh.hex()
        out[f"{mode}.tc02"] = make_attestation_message(
            device_id=DEVICE_ID, policy_id=POLICY, nonce=NONCE, quote_hash=eh,
            sensor_state_hash=b"", decision_hash=DECISION).hex()
    out["chain_digest"] = chain_digest(CHAIN).hex()
    out["k_signed_message"] = k_signed_message(NONCE, CHAIN).hex()
    out["device_id_from_spki"] = hashlib.sha256(b"spki-esimerkki").hexdigest()[:16]
    return out


def gen(path: Path) -> None:
    v = vectors()
    path.write_text("".join(f"{k}={v[k]}\n" for k in sorted(v)))


def check(d: Path) -> int:
    import cbor2
    import oqs
    fails = []
    pk = (d / "mldsa_public.bin").read_bytes()
    for mode in ("attest_key", "signed"):
        raw = (d / f"bundle_{mode}.cbor").read_bytes()
        b = cbor2.loads(raw)
        need = {"tc_version", "device_id", "policy_id", "nonce", "android", "pqc",
                "sensor_state_hash", "decision_hash"}
        if not need <= set(b):
            fails.append(f"{mode}: puuttuvat kentät {need - set(b)}")
            continue
        if b["android"]["mode"] != mode or not all(isinstance(x, bytes) for x in b["android"]["chain"]):
            fails.append(f"{mode}: android-kenttä väärin")
        msg = make_attestation_message(device_id=b["device_id"], policy_id=b["policy_id"], nonce=b["nonce"],
                                       quote_hash=evidence_hash(b), sensor_state_hash=b["sensor_state_hash"],
                                       decision_hash=b["decision_hash"])
        sig = b["pqc"]["signature"]
        with oqs.Signature("ML-DSA-65") as v:
            ok = v.verify(hashlib.sha256(msg).digest(), sig, pk)
            bad = bytearray(sig)
            bad[10] ^= 1
            ok_bad = v.verify(hashlib.sha256(msg).digest(), bytes(bad), pk)
        print(f"{mode}: CBOR jäsentyi, ML-DSA (Kotlin -> liboqs) {'ok' if ok else 'EI'}, "
              f"turmeltu {'HYVÄKSYTTIIN' if ok_bad else 'hylätty'}")
        if not ok:
            fails.append(f"{mode}: Kotlinin ML-DSA-allekirjoitus ei verifioidu")
        if ok_bad:
            fails.append(f"{mode}: turmeltu allekirjoitus verifioitui")
        if mode == "signed" and b["android"].get("k_sig") is None:
            fails.append("signed: k_sig puuttuu")
    for f in fails:
        print("FAIL:", f)
    return 1 if fails else 0


if __name__ == "__main__":
    if sys.argv[1] == "gen":
        gen(Path(sys.argv[2]))
    elif sys.argv[1] == "check":
        sys.exit(check(Path(sys.argv[2])))
