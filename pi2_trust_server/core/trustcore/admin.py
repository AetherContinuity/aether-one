#!/usr/bin/env python3
"""TrustCore v0.2 - laitteiden käsinrekisteröinti (K4).

  python -m core.trustcore.admin enroll laite.json [--data-dir DIR] [--replace]
  python -m core.trustcore.admin list   [--data-dir DIR]
  python -m core.trustcore.admin remove DEVICE_ID [--data-dir DIR]
  python -m core.trustcore.admin android-nonce [--data-dir DIR]
  python -m core.trustcore.admin enroll-android laite.json [--data-dir DIR] [--replace]

Android (docs/VAIHE2-ENNAKKO.md): android-nonce luo rekisteröintinoncen
(voimassa 15 min), jonka omistaja syöttää puhelimen sovellukseen. Sovellus
luo avaimen K tällä challengella ja vie K:n ketjun (laite.json).
enroll-android tarkistaa ketjun Googlen juuriin ja kuluttaa noncen.

laite.json = TrustCoreClient.export_enrollment(), siirretty omistajan
käsissä (ei verkon yli laitteelta). AK:n attribuutit luetaan
TPM2B_PUBLIC-binääristä; rajoittamaton AK hylätään (K2).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
from pathlib import Path
from typing import Any, Dict, List

from .tpm_public import TPMPublicError, ak_policy_violations, parse_rsa_public, rsa_pem

PLATFORMS = ("rpi5", "swtpm", "linux")
ANDROID_NONCE_TTL = 15 * 60
TPM_KINDS = ("swtpm", "hardware")


class EnrollError(ValueError):
    pass


def build_record(exp: Dict[str, Any]) -> Dict[str, Any]:
    """Tarkistaa vientitiedot ja muodostaa devices.json-tietueen."""
    errs: List[str] = []
    for k in ("device_id", "platform", "tpm_kind", "ak_public_tss_hex", "algorithm", "mldsa_public_hex"):
        if not exp.get(k):
            errs.append(f"{k} puuttuu")
    if errs:
        raise EnrollError("; ".join(errs))
    if exp["platform"] not in PLATFORMS:
        raise EnrollError(f"tuntematon platform {exp['platform']!r}")
    if exp["tpm_kind"] not in TPM_KINDS:
        raise EnrollError(f"tuntematon tpm_kind {exp['tpm_kind']!r}")
    if exp["platform"] == "swtpm" and exp["tpm_kind"] != "swtpm":
        raise EnrollError("platform swtpm vaatii tpm_kind swtpm")
    try:
        info = parse_rsa_public(bytes.fromhex(exp["ak_public_tss_hex"]))
    except (ValueError, TPMPublicError) as e:
        raise EnrollError(f"AK:n TPM2B_PUBLIC ei jäsenny: {e}")
    viol = ak_policy_violations(info)
    if viol:
        raise EnrollError("AK ei kelpaa attestaatioavaimeksi: " + ", ".join(viol)
                          + f" (attribuutit: {'|'.join(info['attribute_names'])})")  # type: ignore[arg-type]
    pk = bytes.fromhex(exp["mldsa_public_hex"])
    return {
        "platform": exp["platform"],
        "tpm_kind": exp["tpm_kind"],
        "ak_pem": rsa_pem(info["modulus"], int(info["exponent"])),  # type: ignore[arg-type]
        "ak_attributes": "|".join(info["attribute_names"]),  # type: ignore[arg-type]
        "algorithm": exp["algorithm"],
        "mldsa_public_hex": pk.hex(),
        "mldsa_public_sha256": hashlib.sha256(pk).hexdigest(),
        "mldsa_storage": exp.get("mldsa_storage") or "ohjelmisto",
        "enrolled_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }


def _load(path: Path) -> Dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {"devices": {}}


def _save(path: Path, db: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(db, indent=2, sort_keys=True), encoding="utf-8")
    os.replace(tmp, path)


def enroll(devices_file: Path, exp: Dict[str, Any], replace: bool = False) -> Dict[str, Any]:
    rec = build_record(exp)
    db = _load(devices_file)
    devs = db.setdefault("devices", {})
    if exp["device_id"] in devs and not replace:
        raise EnrollError(f"{exp['device_id']} on jo rekisteröity (--replace korvaa)")
    devs[exp["device_id"]] = rec
    _save(devices_file, db)
    return rec


def android_nonce(data_dir: Path) -> str:
    import secrets
    n = secrets.token_bytes(32).hex()
    _save(data_dir / "android_enroll_nonce.json", {"nonce": n, "expires": int(time.time()) + ANDROID_NONCE_TTL})
    return n


def enroll_android(devices_file: Path, exp: Dict[str, Any], nonce: bytes, android_ctx: Dict[str, Any],
                   replace: bool = False) -> Dict[str, Any]:
    from .android_verify import AndroidEnrollError, build_android_record
    for k in ("device_id", "mode", "k_chain_hex", "algorithm", "mldsa_public_hex"):
        if not exp.get(k):
            raise EnrollError(f"{k} puuttuu")
    try:
        rec = build_android_record(exp, nonce, android_ctx["roots"], android_ctx["now"],
                                   android_ctx.get("status_entries"), android_ctx.get("status_fetched"))
    except AndroidEnrollError as e:
        raise EnrollError(str(e))
    pk = bytes.fromhex(exp["mldsa_public_hex"])
    rec.update({
        "tpm_kind": None,
        "algorithm": exp["algorithm"],
        "mldsa_public_hex": pk.hex(),
        "mldsa_public_sha256": hashlib.sha256(pk).hexdigest(),
        "mldsa_storage": exp.get("mldsa_storage") or "ohjelmisto",
        "enrolled_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    })
    db = _load(devices_file)
    devs = db.setdefault("devices", {})
    if exp["device_id"] in devs and not replace:
        raise EnrollError(f"{exp['device_id']} on jo rekisteröity (--replace korvaa)")
    devs[exp["device_id"]] = rec
    _save(devices_file, db)
    return rec


def main(argv: List[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="trustcore-admin")
    ap.add_argument("--data-dir", default=os.environ.get("TRUSTCORE_DATA_DIR", ".trustcore_server"))
    sub = ap.add_subparsers(dest="cmd", required=True)
    e = sub.add_parser("enroll")
    e.add_argument("export_json")
    e.add_argument("--replace", action="store_true")
    sub.add_parser("list")
    r = sub.add_parser("remove")
    r.add_argument("device_id")
    sub.add_parser("android-nonce")
    ea = sub.add_parser("enroll-android")
    ea.add_argument("export_json")
    ea.add_argument("--replace", action="store_true")
    a = ap.parse_args(argv)
    path = Path(a.data_dir) / "devices.json"

    if a.cmd == "enroll":
        try:
            rec = enroll(path, json.loads(Path(a.export_json).read_text(encoding="utf-8")), a.replace)
        except EnrollError as err:
            print(f"HYLÄTTY: {err}", file=sys.stderr)
            return 2
        print(f"Rekisteröity: AK {rec['ak_attributes']}, {rec['algorithm']} {rec['mldsa_public_sha256'][:16]}")
        return 0
    if a.cmd == "android-nonce":
        print(android_nonce(Path(a.data_dir)))
        return 0
    if a.cmd == "enroll-android":
        npath = Path(a.data_dir) / "android_enroll_nonce.json"
        pend = _load(npath) if npath.exists() else {}
        if not pend.get("nonce") or pend.get("expires", 0) < time.time():
            print("HYLÄTTY: voimassa olevaa rekisteröintinoncea ei ole (android-nonce)", file=sys.stderr)
            return 2
        npath.unlink()  # kertakäyttöinen, myös hylätyllä yrityksellä
        from .server import android_context
        try:
            rec = enroll_android(path, json.loads(Path(a.export_json).read_text(encoding="utf-8")),
                                 bytes.fromhex(pend["nonce"]), android_context(Path(a.data_dir)), a.replace)
        except EnrollError as err:
            print(f"HYLÄTTY: {err}", file=sys.stderr)
            return 2
        print(f"Rekisteröity: Android {rec['mode']}, {rec['security_level']}")
        return 0
    db = _load(path)
    if a.cmd == "list":
        for k, v in sorted(db.get("devices", {}).items()):
            print(f"{k}\t{v.get('platform')}\t{v.get('tpm_kind')}\t{v.get('enrolled_utc')}")
        return 0
    if db.get("devices", {}).pop(a.device_id, None) is None:
        print(f"ei löydy: {a.device_id}", file=sys.stderr)
        return 1
    _save(path, db)
    return 0


if __name__ == "__main__":
    sys.exit(main())
