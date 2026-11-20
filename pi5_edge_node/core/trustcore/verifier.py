#!/usr/bin/env python3
"""TrustCore v0.2 - todentajan ydin (docs/ATTESTATION-LEVELS.md).

Puhdas arviointifunktio: ei verkkoa eikä tilaa. Palauttaa jokaisesta
väitteestä (A, B, P, Q) oman tuloksen. Yhteistä OK-statusta ei ole.

Tulokset: VERIFIED, FAILED, PARTIAL, UNSUPPORTED, UNKNOWN.
Puuttuva tai tulkitsematon todiste ei ole koskaan VERIFIED.
"""

from __future__ import annotations

import hashlib
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Dict, Optional

from .crypto import make_attestation_message, quote_hash

try:
    import oqs  # type: ignore
except Exception:  # pragma: no cover
    oqs = None

VERIFIED = "VERIFIED"
FAILED = "FAILED"
PARTIAL = "PARTIAL"
UNSUPPORTED = "UNSUPPORTED"
UNKNOWN = "UNKNOWN"

CLAIMS = ("A", "B", "P", "Q")
POLICY_ID = "trustcore-v0.2"

# Alustat, joilla on laitteistoon ankkuroitu mitattu käynnistys.
# Tyhjä: yhdelläkään rekisteröitävällä Linux-laitteella ei ole sitä
# (docs/ATTESTATION-ARCHITECTURE.md). Lisätään vasta kun B toteutetaan.
MEASURED_BOOT_PLATFORMS: frozenset[str] = frozenset()


def _c(result: str, reason: str) -> Dict[str, str]:
    return {"result": result, "reason": reason}


def all_claims(result: str, reason: str) -> Dict[str, Dict[str, str]]:
    return {k: _c(result, reason) for k in CLAIMS}


def _check_quote(q: Dict[str, Any], ak_pem: str, nonce: bytes) -> Dict[str, str]:
    """A:n kryptografinen osa: tpm2_checkquote (allekirjoitus, extraData, PCR-digest)."""
    for k in ("msg", "sig", "pcrs"):
        if not isinstance(q.get(k), (bytes, bytearray)) or not q.get(k):
            return _c(UNKNOWN, f"quote: kenttä {k} puuttuu")
    with tempfile.TemporaryDirectory() as td:
        t = Path(td)
        (t / "ak.pem").write_text(ak_pem)
        (t / "msg").write_bytes(bytes(q["msg"]))
        (t / "sig").write_bytes(bytes(q["sig"]))
        (t / "pcrs").write_bytes(bytes(q["pcrs"]))
        try:
            r = subprocess.run(
                ["tpm2_checkquote", "-u", str(t / "ak.pem"), "-m", str(t / "msg"),
                 "-s", str(t / "sig"), "-f", str(t / "pcrs"), "-g", "sha256",
                 "-q", nonce.hex()],
                capture_output=True, text=True, timeout=30,
            )
        except FileNotFoundError:
            return _c(UNKNOWN, "tpm2_checkquote puuttuu todentajalta")
        except subprocess.TimeoutExpired:
            return _c(UNKNOWN, "tpm2_checkquote aikakatkaisu")
    if r.returncode != 0:
        err = (r.stderr or r.stdout).strip().splitlines()
        return _c(FAILED, "quote ei täsmää: " + (err[-1] if err else f"rc={r.returncode}"))
    return _c(VERIFIED, "quote: AK-allekirjoitus, nonce ja PCR-digest täsmäävät")


def _check_mldsa(bundle: Dict[str, Any], dev: Dict[str, Any], nonce: bytes) -> Dict[str, str]:
    pqc = bundle.get("pqc")
    if not isinstance(pqc, dict) or not pqc.get("signature"):
        return _c(UNKNOWN, "ML-DSA-allekirjoitus puuttuu")
    if oqs is None:
        return _c(UNKNOWN, "liboqs puuttuu todentajalta")
    alg = dev.get("algorithm") or "ML-DSA-65"
    msg = make_attestation_message(
        device_id=str(bundle.get("device_id")),
        policy_id=str(bundle.get("policy_id") or ""),
        nonce=nonce,
        quote_hash=quote_hash(bundle.get("tpm_quote") or {}),
        sensor_state_hash=bytes(bundle.get("sensor_state_hash") or b""),
        decision_hash=bytes(bundle.get("decision_hash") or b""),
    )
    try:
        with oqs.Signature(alg) as v:
            # PQCManager.sign allekirjoittaa sha256(viesti).
            ok = bool(v.verify(hashlib.sha256(msg).digest(), bytes(pqc["signature"]),
                               bytes.fromhex(dev["mldsa_public_hex"])))
    except Exception as e:  # jäsennys- tai kirjastovirhe ei ole onnistuminen
        return _c(UNKNOWN, f"ML-DSA-tarkistusvirhe: {e}")
    if not ok:
        return _c(FAILED, "ML-DSA-allekirjoitus ei täsmää rekisteröityyn avaimeen")
    return _c(VERIFIED, f"{alg}-allekirjoitus täsmää; avain: {dev.get('mldsa_storage', 'ohjelmisto')}")


def evaluate(bundle: Any, dev: Optional[Dict[str, Any]], nonce_error: Optional[str]) -> Dict[str, Any]:
    """Arvioi todistepaketin. dev = rekisteröity laite tai None. nonce_error = syy tai None."""
    out: Dict[str, Any] = {"policy_id": POLICY_ID}
    if not isinstance(bundle, dict):
        out["claims"] = all_claims(UNKNOWN, "todiste ei ole jäsennettävissä")
        return out
    out["device_id"] = bundle.get("device_id")
    if nonce_error:
        out["claims"] = all_claims(UNKNOWN, f"nonce: {nonce_error}")
        return out
    if not bundle.get("device_id"):
        out["claims"] = all_claims(UNKNOWN, "device_id puuttuu")
        return out
    if dev is None:
        out["claims"] = all_claims(UNKNOWN, "laitetta ei ole rekisteröity (rekisteröinti käsin, admin.py)")
        return out
    nonce = bytes(bundle["nonce"])

    q = bundle.get("tpm_quote")
    if not isinstance(q, dict) or not q:
        terr = bundle.get("tpm_error")
        a = _c(UNKNOWN, "TPM-quote puuttuu" + (f" ({terr})" if terr else ""))
    else:
        a = _check_quote(q, dev["ak_pem"], nonce)
        if a["result"] == VERIFIED and dev.get("tpm_kind") != "hardware":
            a = _c(PARTIAL, a["reason"] + "; AK ohjelmisto-TPM:ssä (swtpm), ei laitteistoa")

    platform = dev.get("platform", "")
    if platform in MEASURED_BOOT_PLATFORMS:  # pragma: no cover - ei vielä yhtään
        b = _c(UNKNOWN, "PCR-lähtötilan vertailu ei ole toteutettu")
    else:
        b = _c(UNSUPPORTED, f"alustalla {platform or '?'} ei ole mitattua käynnistystä")

    p = _c(UNSUPPORTED, "Linux-laite ei raportoi laitteistoon ankkuroitua päivitystasoa")
    qc = _check_mldsa(bundle, dev, nonce)

    out["claims"] = {"A": a, "B": b, "P": p, "Q": qc}
    return out
