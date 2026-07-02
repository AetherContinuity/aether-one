#!/usr/bin/env python3
"""
test_enroll_live.py

Oikea ajotesti /enroll-korjaukselle. Ei py_compile - oikea HTTP-liikenne
oikeaa PQC-allekirjoitusta vastaan.

HUOM algoritmista: crypto.py:ssa on kovakoodattu "Dilithium3", mutta
tamassa ymparistossa kaannetty liboqs (0.16.0-rc1) ei tunne enaa tata
nimea - liboqs nimesi Dilithiumin uudelleen ML-DSA:ksi. Tama testi kayttaa
"ML-DSA-65":ta suoraan ohittaen crypto.py:n oletuksen. Tama on ERILLINEN,
todellinen loyto: crypto.py:n PQCManager(algorithm="Dilithium3") EI TOIMI
liboqs >=0.16:n kanssa sellaisenaan. Katso raportin loppu.
"""
import asyncio
import hashlib
import secrets
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import cbor2
import httpx
import oqs

from core.trustcore.crypto import make_signed_message

BASE = "http://127.0.0.1:8100"
ALG = "ML-DSA-65"  # vastaa nyt crypto.py:n oletusta


async def main():
    results = {"pass": 0, "fail": 0}

    def check(name, cond, detail=""):
        status = "PASS" if cond else "FAIL"
        results["pass" if cond else "fail"] += 1
        print(f"[{status}] {name}" + (f" - {detail}" if detail else ""))

    # ---- Avaingenerointi (oikea PQC, ei mock) ----
    with oqs.Signature(ALG) as sig:
        pub = sig.generate_keypair()
        sec = sig.export_secret_key()
    device_id = hashlib.sha256(pub).hexdigest()[:16]

    async with httpx.AsyncClient(timeout=10.0) as client:

        # ---- 1) Rekisteroi laite /verify:lla (first-seen) ----
        r = await client.get(f"{BASE}/nonce")
        nonce = bytes.fromhex(r.json()["nonce"])
        msg = make_signed_message(
            device_id=device_id, policy_id="policy_demo", nonce=nonce,
            pcrs_concat=b"", sensor_state_hash=b"", decision_hash=b"\x00"*32,
        )
        digest = hashlib.sha256(msg).digest()
        with oqs.Signature(ALG, secret_key=sec) as signer:
            signature = signer.sign(digest)

        bundle = cbor2.dumps({
            "tc_version": 1, "timestamp": int(time.time()), "device_id": device_id,
            "policy_id": "policy_demo", "nonce": nonce, "pcrs": {}, "pcr_bank": "sha256",
            "tpm_quote": {},
            "pqc": {"algorithm": ALG, "public_key": pub, "public_key_hash": hashlib.sha256(pub).hexdigest(),
                    "signature": signature, "signed_message_hash": digest},
            "sensor_state_hash": b"", "decision_hash": b"\x00"*32,
        })
        r = await client.post(f"{BASE}/verify", content=bundle, headers={"Content-Type": "application/cbor"})
        resp = r.json()
        check("Laite rekisteroitynyt /verify:n kautta", resp.get("status") == "PASS", str(resp))

        # ---- 2) LAILLINEN /enroll: oikea allekirjoitus, oikea laite ----
        r = await client.get(f"{BASE}/nonce")
        nonce2 = bytes.fromhex(r.json()["nonce"])
        baseline = {"pcr0": "aa"*32, "pcr7": "bb"*32}
        pcrs_canon = b"".join(f"{k}:{v}".encode() for k, v in sorted(baseline.items()))
        baseline_hash = hashlib.sha256(pcrs_canon).digest()
        enroll_msg = make_signed_message(
            device_id=device_id, policy_id="ENROLL", nonce=nonce2,
            pcrs_concat=b"", sensor_state_hash=b"", decision_hash=baseline_hash,
        )
        enroll_digest = hashlib.sha256(enroll_msg).digest()
        with oqs.Signature(ALG, secret_key=sec) as signer:
            enroll_sig = signer.sign(enroll_digest)

        enroll_bundle = cbor2.dumps({
            "device_id": device_id, "nonce": nonce2, "baseline_pcrs": baseline,
            "pqc": {"algorithm": ALG, "signature": enroll_sig},
        })
        r = await client.post(f"{BASE}/enroll/{device_id}", content=enroll_bundle,
                               headers={"Content-Type": "application/cbor"})
        resp = r.json()
        check("Laillinen /enroll onnistuu", resp.get("status") == "OK", str(resp))

        # ---- 3) HYOKKAYS A: vaara allekirjoitus (toisen laitteen avaimella) ----
        with oqs.Signature(ALG) as attacker_sig:
            attacker_pub = attacker_sig.generate_keypair()
            attacker_sec = attacker_sig.export_secret_key()

        r = await client.get(f"{BASE}/nonce")
        nonce3 = bytes.fromhex(r.json()["nonce"])
        fake_baseline = {"pcr0": "00"*32}
        fake_canon = b"".join(f"{k}:{v}".encode() for k, v in sorted(fake_baseline.items()))
        fake_hash = hashlib.sha256(fake_canon).digest()
        fake_msg = make_signed_message(
            device_id=device_id, policy_id="ENROLL", nonce=nonce3,
            pcrs_concat=b"", sensor_state_hash=b"", decision_hash=fake_hash,
        )
        fake_digest = hashlib.sha256(fake_msg).digest()
        with oqs.Signature(ALG, secret_key=attacker_sec) as attacker:
            forged_sig = attacker.sign(fake_digest)  # allekirjoitettu VAARALLA avaimella

        attack_bundle = cbor2.dumps({
            "device_id": device_id, "nonce": nonce3, "baseline_pcrs": fake_baseline,
            "pqc": {"algorithm": ALG, "signature": forged_sig},
        })
        r = await client.post(f"{BASE}/enroll/{device_id}", content=attack_bundle,
                               headers={"Content-Type": "application/cbor"})
        resp = r.json()
        check("HYOKKAYS A torjuttu (vaara avain)", resp.get("status") == "FAIL", str(resp))

        # Varmista ettei hyokkays A muuttanut baselinea
        r = await client.get(f"{BASE}/nonce")  # vain tarkistus ettei palvelin kaatunut
        check("Palvelin elossa hyokkays A:n jalkeen", r.status_code == 200)

        # ---- 4) HYOKKAYS B: vanhentunut/uudelleenkaytetty nonce (replay) ----
        replay_bundle = cbor2.dumps({
            "device_id": device_id, "nonce": nonce2,  # KAYTETTY jo vaiheessa 2
            "baseline_pcrs": baseline,
            "pqc": {"algorithm": ALG, "signature": enroll_sig},
        })
        r = await client.post(f"{BASE}/enroll/{device_id}", content=replay_bundle,
                               headers={"Content-Type": "application/cbor"})
        resp = r.json()
        check("HYOKKAYS B torjuttu (nonce-replay)", resp.get("status") == "FAIL", str(resp))

        # ---- 5) HYOKKAYS C: rekisteroimaton laite ----
        with oqs.Signature(ALG) as ghost_sig:
            ghost_pub = ghost_sig.generate_keypair()
            ghost_sec = ghost_sig.export_secret_key()
        ghost_id = hashlib.sha256(ghost_pub).hexdigest()[:16]

        r = await client.get(f"{BASE}/nonce")
        nonce4 = bytes.fromhex(r.json()["nonce"])
        ghost_baseline = {"pcr0": "11"*32}
        ghost_canon = b"".join(f"{k}:{v}".encode() for k, v in sorted(ghost_baseline.items()))
        ghost_hash = hashlib.sha256(ghost_canon).digest()
        ghost_msg = make_signed_message(
            device_id=ghost_id, policy_id="ENROLL", nonce=nonce4,
            pcrs_concat=b"", sensor_state_hash=b"", decision_hash=ghost_hash,
        )
        ghost_digest = hashlib.sha256(ghost_msg).digest()
        with oqs.Signature(ALG, secret_key=ghost_sec) as gs:
            ghost_sig_val = gs.sign(ghost_digest)

        ghost_bundle = cbor2.dumps({
            "device_id": ghost_id, "nonce": nonce4, "baseline_pcrs": ghost_baseline,
            "pqc": {"algorithm": ALG, "signature": ghost_sig_val},
        })
        r = await client.post(f"{BASE}/enroll/{ghost_id}", content=ghost_bundle,
                               headers={"Content-Type": "application/cbor"})
        check("HYOKKAYS C torjuttu (rekisteroimaton laite, HTTP 404)", r.status_code == 404, f"HTTP {r.status_code}")

    print(f"\n--- {results['pass']} PASS, {results['fail']} FAIL ---")
    if results["fail"] > 0:
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
