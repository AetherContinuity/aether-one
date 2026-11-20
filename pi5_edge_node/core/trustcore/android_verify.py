#!/usr/bin/env python3
"""Android-todisteen väitteet A, B, P (docs/VAIHE2-ENNAKKO.md K4-K6).

Todiste (bundle["android"]):
  mode:  "attest_key" | "signed"
  chain: [DER, ...] lehdestä juureen
  k_sig: (vain signed) K:n ECDSA-SHA256-allekirjoitus viestistä
         b"TCA1" ‖ nonce ‖ SHA-256(ketjun DER:t pituusetuliittein)

Rekisteröity laite (devices.json): k_spki_hex, mode, security_level,
verified_boot_key, algorithm, mldsa_public_hex, mldsa_storage.
"""

from __future__ import annotations

import hashlib
import json
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from .android_chain import Cert, ChainParseError, check_chain, parse_cert
from .android_kd import KEY_DESCRIPTION_OID, KDError, parse_key_description

VERIFIED, FAILED, PARTIAL, UNSUPPORTED, UNKNOWN = "VERIFIED", "FAILED", "PARTIAL", "UNSUPPORTED", "UNKNOWN"
HW_LEVELS = ("TRUSTED_ENVIRONMENT", "STRONG_BOX")
LEVEL_RANK = {"SOFTWARE": 0, "TRUSTED_ENVIRONMENT": 1, "STRONG_BOX": 2}
STATUS_URL = "https://android.googleapis.com/attestation/status"

B_SCOPE = ("verifioitu käynnistysketju kokonaisuutena TEE:n raportoimana; "
           "ei ajonaikaista tilaa eikä sovelluskerrosta")


def _c(r: str, reason: str) -> Dict[str, str]:
    return {"result": r, "reason": reason}


def chain_digest(ders: List[bytes]) -> bytes:
    h = hashlib.sha256(b"TCC1")
    for d in ders:
        h.update(len(d).to_bytes(4, "big"))
        h.update(bytes(d))
    return h.digest()


def k_signed_message(nonce: bytes, ders: List[bytes]) -> bytes:
    return b"TCA1" + bytes(nonce) + chain_digest(ders)


# --- revokaatiolista --------------------------------------------------------

def load_status(path: Path) -> Tuple[Optional[Dict[str, dict]], Optional[datetime]]:
    try:
        d = json.loads(path.read_text())
        return d["entries"], datetime.fromisoformat(d["fetched_utc"])
    except Exception:
        return None, None


def fetch_status(path: Path, timeout: float = 20.0) -> bool:
    """Hakee Googlen tilalistan. Epäonnistuminen ei kaada: lista jää vanhaksi."""
    try:
        with urllib.request.urlopen(STATUS_URL, timeout=timeout) as r:
            entries = json.loads(r.read().decode())["entries"]
    except Exception:
        return False
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps({"fetched_utc": datetime.now(timezone.utc).isoformat(),
                               "source": STATUS_URL, "entries": entries}))
    tmp.replace(path)
    return True


# --- KeyDescription-tietueen valinta (K4) ------------------------------------

def _kd(c: Cert) -> Optional[Dict[str, Any]]:
    v = c.extensions.get(KEY_DESCRIPTION_OID)
    return parse_key_description(v) if v is not None else None


def nearest_root_record(certs: List[Cert]) -> Tuple[Optional[int], Optional[Dict[str, Any]]]:
    """Googlen sääntö: juurta lähin varmenne, jossa laajennus on."""
    for i in range(len(certs) - 1, -1, -1):
        kd = _kd(certs[i])
        if kd is not None:
            return i, kd
    return None, None


def _purposes(kd: Dict[str, Any]) -> set:
    return set(kd["hardwareEnforced"]["purpose"]) | set(kd["softwareEnforced"]["purpose"])


# --- väitteet ---------------------------------------------------------------

def _b_claim(kd: Dict[str, Any], dev: Dict[str, Any], bound: bool) -> Dict[str, str]:
    rot = kd["hardwareEnforced"].get("rootOfTrust")
    if rot is None:
        return _c(UNKNOWN, "RootOfTrust puuttuu laitteistossa valvotusta listasta")
    if not rot["deviceLocked"]:
        return _c(FAILED, "bootloader ei ole lukittu (deviceLocked = false)")
    if rot["verifiedBootState"] != "VERIFIED":
        return _c(FAILED, f"verifiedBootState = {rot['verifiedBootState']}")
    if rot["verifiedBootKey"] != dev.get("verified_boot_key"):
        return _c(FAILED, "verifiedBootKey eri kuin rekisteröinnissä (eri käyttöjärjestelmän allekirjoittaja)")
    if not bound:
        return _c(PARTIAL, "lukittu ja Verified, mutta ketjua ei ole sidottu rekisteröityyn "
                           "avaimeen TEE:ssä (tila signed); " + B_SCOPE)
    return _c(VERIFIED, "lukittu, Verified, verifiedBootKey = rekisteröity; " + B_SCOPE)


def _p_claim(kd: Dict[str, Any], bound: bool) -> Dict[str, str]:
    hw = kd["hardwareEnforced"]
    names = ("osPatchLevel", "vendorPatchLevel", "bootPatchLevel")
    # Arvo 0 = tasoa ei ilmoitettu (esim. Samsung Galaxy A70: vendor ja boot = 0).
    have = {n: hw.get(n) for n in names if hw.get(n)}
    if not have:
        sw = [n for n in names if kd["softwareEnforced"].get(n) is not None]
        return _c(UNKNOWN, "päivitystaso puuttuu laitteistossa valvotusta listasta"
                  + (f" (vain ohjelmiston ilmoittama: {', '.join(sw)})" if sw else ""))
    vals = ", ".join(f"{n}={v}" for n, v in have.items())
    missing = [n + (" (=0)" if hw.get(n) == 0 else "") for n in names if n not in have]
    if missing:
        return _c(PARTIAL, f"{vals}; puuttuu: {', '.join(missing)}")
    if not bound:
        return _c(PARTIAL, f"{vals}; ketjua ei sidottu rekisteröityyn avaimeen (tila signed)")
    return _c(VERIFIED, vals)


def _verify_k_sig(spki: bytes, sig: bytes, msg: bytes) -> bool:
    from cryptography.exceptions import InvalidSignature
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography.hazmat.primitives.serialization import load_der_public_key
    key = load_der_public_key(spki)
    if not isinstance(key, ec.EllipticCurvePublicKey):
        return False
    try:
        key.verify(sig, msg, ec.ECDSA(hashes.SHA256()))
    except InvalidSignature:
        return False
    return True


def evaluate_android(bundle: Dict[str, Any], dev: Dict[str, Any], nonce: bytes, roots,
                     now: datetime, status_entries, status_fetched) -> Dict[str, Dict[str, str]]:
    """Palauttaa väitteet A, B, P. Q arvioidaan yhteisessä verifier-koodissa."""
    ev = bundle.get("android")
    if not isinstance(ev, dict) or not isinstance(ev.get("chain"), list):
        u = _c(UNKNOWN, "Android-todiste puuttuu")
        return {"A": u, "B": u, "P": u}
    mode = ev.get("mode")
    if mode not in ("attest_key", "signed"):
        u = _c(UNKNOWN, f"tuntematon tila {mode!r}")
        return {"A": u, "B": u, "P": u}
    if mode != dev.get("mode"):
        f = _c(FAILED, f"tila {mode} ≠ rekisteröity {dev.get('mode')}")
        return {"A": f, "B": _c(UNKNOWN, "A epäonnistui"), "P": _c(UNKNOWN, "A epäonnistui")}
    ders = [bytes(d) for d in ev["chain"] if isinstance(d, (bytes, bytearray))]
    if len(ders) != len(ev["chain"]):
        u = _c(UNKNOWN, "ketjussa muuta kuin tavuja")
        return {"A": u, "B": u, "P": u}

    ch = check_chain(ders, roots, now, status_entries, status_fetched)
    if ch.status == "unknown":
        u = _c(UNKNOWN, ch.reason)
        return {"A": u, "B": u, "P": u}
    if ch.status == "failed":
        dep = _c(UNKNOWN, "ketju ei kelpaa (ks. A); todisteeseen ei voi luottaa")
        return {"A": _c(FAILED, ch.reason), "B": dep, "P": dep}
    certs = ch.certs
    k_spki = bytes.fromhex(dev["k_spki_hex"])

    try:
        if mode == "attest_key":
            if len(certs) < 2 or certs[1].spki != k_spki:
                dep = _c(UNKNOWN, "A epäonnistui")
                return {"A": _c(FAILED, "lehteä ei ole allekirjoittanut rekisteröity avain K"), "B": dep, "P": dep}
            k_kd = _kd(certs[1])
            # K4: lehden tietueeseen luotetaan vain, jos K on pelkkä ATTEST_KEY.
            if k_kd is None or _purposes(k_kd) != {"ATTEST_KEY"}:
                f = _c(FAILED, "K:n tarkoitus ei ole pelkkä ATTEST_KEY; lehden tietueeseen ei luoteta")
                return {"A": _c(FAILED, "K ei ole attestaatioavain"), "B": f, "P": f}
            kd = _kd(certs[0])
            if kd is None:
                u = _c(UNKNOWN, "lehdestä puuttuu KeyDescription")
                return {"A": u, "B": u, "P": u}
            k_level = k_kd["attestationSecurityLevel"]
            bound = True
        else:
            sig = ev.get("k_sig")
            if not isinstance(sig, (bytes, bytearray)) or not sig:
                u = _c(UNKNOWN, "K:n allekirjoitus puuttuu")
                return {"A": u, "B": u, "P": u}
            if not _verify_k_sig(k_spki, bytes(sig), k_signed_message(nonce, ders)):
                dep = _c(UNKNOWN, "A epäonnistui")
                return {"A": _c(FAILED, "K:n allekirjoitus ei täsmää"), "B": dep, "P": dep}
            _, kd = nearest_root_record(certs)
            if kd is None:
                u = _c(UNKNOWN, "ketjusta puuttuu KeyDescription")
                return {"A": u, "B": u, "P": u}
            k_level = dev.get("security_level")
            bound = False
    except (KDError, ChainParseError) as e:
        u = _c(UNKNOWN, f"KeyDescription ei jäsenny: {e}")
        return {"A": u, "B": u, "P": u}

    if kd["attestationChallenge"] != bytes(nonce).hex():
        f = _c(FAILED, "attestationChallenge ≠ pyynnön nonce (vanha tai toistettu todiste)")
        return {"A": f, "B": f, "P": f}
    lvl = kd["attestationSecurityLevel"]
    if lvl not in HW_LEVELS or k_level not in HW_LEVELS:
        dep = _c(UNKNOWN, "A epäonnistui")
        return {"A": _c(FAILED, f"turvataso {lvl} (K: {k_level}); ei laitteistoa"), "B": dep, "P": dep}
    if LEVEL_RANK[k_level] < LEVEL_RANK.get(dev.get("security_level", ""), 99):
        dep = _c(UNKNOWN, "A epäonnistui")
        return {"A": _c(FAILED, f"K:n turvataso {k_level} alempi kuin rekisteröity "
                               f"{dev.get('security_level')}"), "B": dep, "P": dep}

    a_reason = f"K ({k_level}) = rekisteröity; ketju Googlen juureen; challenge = nonce"
    if ch.notes:
        a_reason += "; huomiot: " + "; ".join(ch.notes)
    a = _c(VERIFIED, a_reason) if ch.revocation_known else \
        _c(PARTIAL, a_reason + "; revokaatiotila tuntematon (tilalista puuttuu tai yli 24 h vanha)")
    return {"A": a, "B": _b_claim(kd, dev, bound), "P": _p_claim(kd, bound)}


# --- rekisteröinti (K6) ------------------------------------------------------

class AndroidEnrollError(ValueError):
    pass


def build_android_record(exp: Dict[str, Any], expected_nonce: bytes, roots, now: datetime,
                         status_entries=None, status_fetched=None) -> Dict[str, Any]:
    mode = exp.get("mode")
    if mode not in ("attest_key", "signed"):
        raise AndroidEnrollError(f"tuntematon tila {mode!r}")
    try:
        ders = [bytes.fromhex(h) for h in exp["k_chain_hex"]]
    except Exception as e:
        raise AndroidEnrollError(f"k_chain_hex: {e}")
    ch = check_chain(ders, roots, now, status_entries, status_fetched)
    if ch.status != "ok":
        raise AndroidEnrollError(f"K:n ketju ei kelpaa: {ch.reason}")
    try:
        idx, kd = nearest_root_record(ch.certs)
    except KDError as e:
        raise AndroidEnrollError(f"KeyDescription ei jäsenny: {e}")
    if kd is None or idx != 0:
        raise AndroidEnrollError("K:n oma varmenne ei ole ketjun juurta lähin attestaatiotietue")
    errs = []
    if kd["attestationChallenge"] != expected_nonce.hex():
        errs.append("challenge ≠ rekisteröintinonce")
    lvl = kd["attestationSecurityLevel"]
    if lvl not in HW_LEVELS:
        errs.append(f"turvataso {lvl}")
    rot = kd["hardwareEnforced"].get("rootOfTrust")
    if rot is None:
        errs.append("RootOfTrust puuttuu")
    else:
        if not rot["deviceLocked"]:
            errs.append("bootloader ei lukittu")
        if rot["verifiedBootState"] != "VERIFIED":
            errs.append(f"verifiedBootState {rot['verifiedBootState']}")
    p = _purposes(kd)
    if mode == "attest_key" and p != {"ATTEST_KEY"}:
        errs.append(f"tila attest_key vaatii pelkän ATTEST_KEY-tarkoituksen (nyt {sorted(p)})")
    if mode == "signed" and "SIGN" not in p:
        errs.append(f"tila signed vaatii SIGN-tarkoituksen (nyt {sorted(p)})")
    k = ch.certs[0]
    dev_id = hashlib.sha256(k.spki).hexdigest()[:16]
    if exp.get("device_id") != dev_id:
        errs.append(f"device_id ≠ SHA-256(K)[:16] ({dev_id})")
    if errs:
        raise AndroidEnrollError("; ".join(errs))
    return {
        "platform": "android",
        "mode": mode,
        "k_spki_hex": k.spki.hex(),
        "security_level": lvl,
        "verified_boot_key": rot["verifiedBootKey"],  # type: ignore[index]
        "enroll_patch_levels": {n: kd["hardwareEnforced"].get(n) for n in
                                ("osPatchLevel", "vendorPatchLevel", "bootPatchLevel")},
    }
