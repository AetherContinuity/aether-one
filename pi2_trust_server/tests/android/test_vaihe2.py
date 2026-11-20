#!/usr/bin/env python3
"""Vaihe 2 hyväksymistesti (docs/VAIHE2-ENNAKKO.md K4-K9), synteettiset ketjut.

Ajo: cd pi2_trust_server && python3 tests/android/test_vaihe2.py
Vaatii: cryptography, liboqs-python (ML-DSA-65, Q-väite).
"""

from __future__ import annotations

import copy
import hashlib
import os
import sys
import tempfile
from datetime import timedelta
from pathlib import Path

HERE = Path(__file__).resolve().parent
DATA = Path(tempfile.mkdtemp(prefix="tc_v2_"))
os.environ["TRUSTCORE_DATA_DIR"] = str(DATA)
sys.path.insert(0, str(HERE.parents[1]))
sys.path.insert(0, str(HERE))

import oqs  # noqa: E402

from core.trustcore import admin  # noqa: E402
from core.trustcore.android_chain import load_production_roots, roots_from_ders  # noqa: E402
from core.trustcore.android_verify import k_signed_message  # noqa: E402
from core.trustcore.crypto import evidence_hash, make_attestation_message  # noqa: E402
from core.trustcore.verifier import evaluate  # noqa: E402
from synth import GOOD_ROT, NOW, Device, Pki, spki  # noqa: E402

V, F, P, U = "VERIFIED", "FAILED", "PARTIAL", "UNKNOWN"
FAILS: list = []
PKI = Pki()
TEST_ROOTS = roots_from_ders([PKI.root])
FRESH = {"status_entries": {}, "status_fetched": NOW - timedelta(hours=1)}
SIG = oqs.Signature("ML-DSA-65")
MLDSA_PK = SIG.generate_keypair()


def ctx(**kw):
    return {"roots": TEST_ROOTS, "now": NOW, **FRESH, **kw}


def enroll(dev: Device, data: Path) -> tuple:
    return enroll_with(dev, data, TEST_ROOTS)


def enroll_with(dev: Device, data: Path, roots) -> tuple:
    en = os.urandom(32)
    k = dev.k_chain(en)
    did = hashlib.sha256(spki(dev.k_key)).hexdigest()[:16]
    exp = {"device_id": did, "mode": dev.mode, "k_chain_hex": [d.hex() for d in k],
           "algorithm": "ML-DSA-65", "mldsa_public_hex": MLDSA_PK.hex()}
    rec = admin.enroll_android(data / "devices.json", exp, en, ctx(roots=roots), replace=True)
    return did, rec


def bundle(dev: Device, did: str, nonce: bytes, chain, k_sig=None, sign_q=True) -> dict:
    b = {"tc_version": 2, "device_id": did, "policy_id": "trustcore-v0.2", "nonce": nonce,
         "android": {"mode": dev.mode, "chain": chain}, "pqc": {},
         "sensor_state_hash": b"", "decision_hash": b"\x00" * 32}
    if dev.mode == "signed":
        b["android"]["k_sig"] = k_sig if k_sig is not None else dev.k_sign(k_signed_message(nonce, chain))
    if sign_q:
        msg = make_attestation_message(device_id=did, policy_id=b["policy_id"], nonce=nonce,
                                       quote_hash=evidence_hash(b), sensor_state_hash=b"",
                                       decision_hash=b["decision_hash"])
        b["pqc"]["signature"] = SIG.sign(hashlib.sha256(msg).digest())
    return b


def check(name, resp, want: dict) -> None:
    got = {k: resp["claims"][k]["result"] for k in want}
    ok = got == want
    print(f"{'OK  ' if ok else 'FAIL'} {name}: {got}")
    if not ok:
        FAILS.append(f"{name}: odotettu {want}, saatu {got}")
        for k in "ABPQ":
            print(f"       {k}: {resp['claims'][k]}")


def flip_sig(der: bytes) -> bytes:
    x = bytearray(der)
    x[-5] ^= 1  # allekirjoitus on varmenteen lopussa
    return bytes(x)


def main() -> int:
    data = DATA
    dev = Device(PKI)
    did, rec = enroll(dev, data)
    n = os.urandom(32)

    r = evaluate(bundle(dev, did, n, dev.fresh(n)), rec, None, ctx())
    check("positiivinen attest_key", r, {"A": V, "B": V, "P": V, "Q": V})
    if "status" in r:
        FAILS.append("yhteinen status-kenttä")

    check("challenge ≠ nonce", evaluate(bundle(dev, did, n, dev.fresh(os.urandom(32))), rec, None, ctx()),
          {"A": F, "B": F, "P": F})
    check("deviceLocked = false", evaluate(bundle(dev, did, n, dev.fresh(n, rot={**GOOD_ROT, "locked": False})),
                                           rec, None, ctx()), {"A": V, "B": F, "P": V})
    for st in ("UNVERIFIED", "SELF_SIGNED", "FAILED"):
        check(f"verifiedBootState {st}", evaluate(bundle(dev, did, n, dev.fresh(n, rot={**GOOD_ROT, "state": st})),
                                                  rec, None, ctx()), {"B": F})
    check("verifiedBootKey ≠ rekisteröity",
          evaluate(bundle(dev, did, n, dev.fresh(n, rot={**GOOD_ROT, "key": b"\xbb" * 32})), rec, None, ctx()),
          {"A": V, "B": F})
    check("turvataso Software", evaluate(bundle(dev, did, n, dev.fresh(n, level="SOFTWARE")), rec, None, ctx()),
          {"A": F})

    ch = dev.fresh(n)
    ch[1] = flip_sig(ch[1])
    r = evaluate(bundle(dev, did, n, ch), rec, None, ctx())
    check("ketjun allekirjoitus turmeltu (K:n varmenne)", r, {"A": F, "B": U, "P": U})
    if "varmenteen 1 allekirjoitus" not in r["claims"]["A"]["reason"]:
        FAILS.append(f"allekirjoitus turmeltu: väärä syy: {r['claims']['A']['reason']}")

    check("synteettinen ketju tuotantojuuria vasten",
          evaluate(bundle(dev, did, n, dev.fresh(n)), rec, None, ctx(roots=load_production_roots())),
          {"A": F})
    check("välivarmenne revokoitu",
          evaluate(bundle(dev, did, n, dev.fresh(n)), rec, None,
                   ctx(status_entries={format(PKI.inter_serial, "x"): {"status": "REVOKED",
                                                                       "reason": "KEY_COMPROMISE"}})),
          {"A": F})
    check("välivarmenne SUSPENDED",
          evaluate(bundle(dev, did, n, dev.fresh(n)), rec, None,
                   ctx(status_entries={format(PKI.inter_serial, "x"): {"status": "SUSPENDED"}})), {"A": F})
    check("tilalista puuttuu", evaluate(bundle(dev, did, n, dev.fresh(n)), rec, None,
                                        ctx(status_entries=None, status_fetched=None)), {"A": P, "B": V})
    check("tilalista 25 h vanha", evaluate(bundle(dev, did, n, dev.fresh(n)), rec, None,
                                           ctx(status_fetched=NOW - timedelta(hours=25))), {"A": P})
    # Välivarmenne vanhenee ennen muita (30 pv), joten tulos mittaa juuri sitä.
    pki2 = Pki(inter_na=NOW + timedelta(days=30))
    d2 = Device(pki2)
    roots2 = roots_from_ders([pki2.root])
    did2, rec2 = enroll_with(d2, data, roots2)
    later = NOW + timedelta(days=31)
    r = evaluate(bundle(d2, did2, n, d2.fresh(n)), rec2, None,
                 ctx(roots=roots2, now=later, status_fetched=later))
    check("välivarmenne vanhentunut", r, {"A": F})
    if "varmenne 2 ei voimassa" not in r["claims"]["A"]["reason"]:
        FAILS.append(f"välivarmenne vanhentunut: väärä syy: {r['claims']['A']['reason']}")

    other = Device(PKI)
    check("K ≠ rekisteröity", evaluate(bundle(other, did, n, other.fresh(n)), rec, None, ctx()),
          {"A": F, "B": U, "P": U})

    # K4: rekisteröity K, jolla myös SIGN-tarkoitus (rekisteröinti ohitettu), allekirjoittaa
    # väärennetyn lehden: lehden tietueeseen ei saa luottaa.
    bad = Device(PKI, k_purposes=("SIGN", "ATTEST_KEY"))
    bad_rec = {**rec, "k_spki_hex": spki(bad.k_key).hex()}
    check("väärennetty lehti, K:lla SIGN-tarkoitus (K4)",
          evaluate(bundle(bad, did, n, bad.fresh(n)), bad_rec, None, ctx()), {"A": F, "B": F, "P": F})
    # Lisä: väärennetty lehti toisella attestoidulla avaimella (ei K) -> A FAILED, B/P ei VERIFIED.
    forged = Device(PKI, k_purposes=("SIGN",))
    check("väärennetty lehti vieraalla SIGN-avaimella",
          evaluate(bundle(forged, did, n, forged.fresh(n)), rec, None, ctx()), {"A": F, "B": U, "P": U})

    sdev = Device(PKI, mode="signed", k_purposes=("SIGN",))
    sdid, srec = enroll(sdev, data)
    check("tila signed, ehjä", evaluate(bundle(sdev, sdid, n, sdev.fresh(n)), srec, None, ctx()),
          {"A": V, "B": P, "P": P, "Q": V})
    sch = sdev.fresh(n)
    bs = bytearray(sdev.k_sign(k_signed_message(n, sch)))
    bs[-3] ^= 1
    check("tila signed, K:n allekirjoitus turmeltu",
          evaluate(bundle(sdev, sdid, n, sch, k_sig=bytes(bs)), srec, None, ctx()), {"A": F})
    check("tila signed, K:n allekirjoitus puuttuu",
          evaluate(bundle(sdev, sdid, n, sch, k_sig=b""), srec, None, ctx()), {"A": U})

    check("RootOfTrust puuttuu", evaluate(bundle(dev, did, n, dev.fresh(n, rot=None)), rec, None, ctx()),
          {"A": V, "B": U})
    check("patch-tasot puuttuvat", evaluate(bundle(dev, did, n, dev.fresh(n, patches={})), rec, None, ctx()),
          {"P": U})
    check("patch-tasoista osa", evaluate(bundle(dev, did, n, dev.fresh(n, patches={"os": 202610})), rec, None,
                                         ctx()), {"P": P})
    check("patch-tasot vain ohjelmiston listassa",
          evaluate(bundle(dev, did, n, dev.fresh(n, patches_sw_only=True)), rec, None, ctx()), {"P": U})

    ch = dev.fresh(n)
    ch[0] = ch[0][:60]
    check("katkaistu DER", evaluate(bundle(dev, did, n, ch), rec, None, ctx()), {"A": U, "B": U, "P": U})
    check("rekisteröimätön laite", evaluate(bundle(dev, did, n, dev.fresh(n)), None, None, ctx()),
          dict.fromkeys("ABPQ", U))

    # Q kattaa Android-todisteen: ketju vaihdettu toiseen ehjään ilman uudelleenallekirjoitusta.
    b = bundle(dev, did, n, dev.fresh(n))
    b["android"]["chain"] = dev.fresh(n)
    check("ketju vaihdettu, ML-DSA:ta ei allekirjoitettu uudelleen", evaluate(b, rec, None, ctx()),
          {"A": V, "B": V, "Q": F})

    # Palvelinpolku: tuotannon kontekstilla (kiinnitetyt Googlen juuret) synteettinen
    # testijuuri ei mene läpi, vaikka laite on rekisteröity ja Q ehjä.
    import cbor2
    from core.trustcore import server
    sn = bytes.fromhex(server.get_nonce()["nonce"])
    r = server.verify_bytes(cbor2.dumps(bundle(dev, did, sn, dev.fresh(sn))))
    check("palvelin: synteettinen ketju tuotantokontekstissa", r, {"A": F, "B": U, "P": U, "Q": V})
    if "kiinnitettyyn Googlen juureen" not in r["claims"]["A"]["reason"]:
        FAILS.append(f"palvelin: väärä syy: {r['claims']['A']['reason']}")

    # Rekisteröinti kieltäytyy (K6)
    def refuse(name, d: Device, en_ok=True, roots=None, rot=GOOD_ROT):
        en = os.urandom(32)
        exp = {"device_id": hashlib.sha256(spki(d.k_key)).hexdigest()[:16], "mode": d.mode,
               "k_chain_hex": [x.hex() for x in d.k_chain(en, rot=rot)], "algorithm": "ML-DSA-65",
               "mldsa_public_hex": MLDSA_PK.hex()}
        try:
            admin.enroll_android(data / "d2.json", exp, en if en_ok else os.urandom(32),
                                 ctx(**({"roots": roots} if roots else {})))
            FAILS.append(f"rekisteröinti hyväksyi: {name}")
            print(f"FAIL rekisteröinti hyväksyi: {name}")
        except admin.EnrollError as e:
            print(f"OK   rekisteröinti kieltäytyy: {name}: {e}")

    refuse("turvataso Software", Device(PKI, k_level="SOFTWARE"))
    refuse("bootloader auki", Device(PKI), rot={**GOOD_ROT, "locked": False})
    refuse("verifiedBootState UNVERIFIED", Device(PKI), rot={**GOOD_ROT, "state": "UNVERIFIED"})
    refuse("vieras juuri (tuotantojuuret)", Device(PKI), roots=load_production_roots())
    refuse("väärä challenge", Device(PKI), en_ok=False)
    refuse("attest_key + SIGN-tarkoitus", Device(PKI, k_purposes=("SIGN", "ATTEST_KEY")))

    print()
    if FAILS:
        print(f"VAIHE 2: {len(FAILS)} poikkeamaa")
        for f in FAILS:
            print("  -", f)
        return 1
    print("VAIHE 2: kaikki tapaukset odotetusti")
    return 0


if __name__ == "__main__":
    sys.exit(main())
