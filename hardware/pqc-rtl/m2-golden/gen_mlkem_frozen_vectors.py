#!/usr/bin/env python3
"""M3 Issue #15: pysyva, jaadytetty referenssi ML-KEM:n koko
KeyGen->Encaps->Decaps-ketjulle, kolme testitapausta (kayttajan oma
ehdotus): normaali polku, koko tavun muutos c:ssa, YHDEN BITIN muutos
c:ssa. Kaikki kolme kayttavat SAMAA (ek,dk,m,K_bob,c) - vain Decaps:n
oma syote c vaihtelee."""

import sys
import os
import json
sys.path.insert(0, os.path.dirname(__file__))
from mlkem_golden import mlkem_keygen_internal, mlkem_encaps_internal, mlkem_decaps_internal
from keccak_golden import shake256

K_dim, ETA1, ETA2, DU, DV = 2, 3, 2, 10, 4
outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")
os.makedirs(outdir, exist_ok=True)

d = bytes(range(1, 33))
z = bytes(range(33, 65))
ek, dk = mlkem_keygen_internal(d, z, K_dim, ETA1)
m = bytes(range(65, 97))
K_bob, c = mlkem_encaps_internal(ek, m, K_dim, ETA1, ETA2, DU, DV)

c_byteflip = bytearray(c)
c_byteflip[100] ^= 0xFF
c_byteflip = bytes(c_byteflip)

c_bitflip = bytearray(c)
c_bitflip[50] ^= 0x01
c_bitflip = bytes(c_bitflip)

cases = {
    "valid": c,
    "byte_corrupted": c_byteflip,
    "bit_corrupted": c_bitflip,
}

frozen = {
    "d_hex": d.hex(),
    "z_hex": z.hex(),
    "m_hex": m.hex(),
    "ek_hex": ek.hex(),
    "dk_hex": dk.hex(),
    "K_bob_hex": K_bob.hex(),
    "c_hex": c.hex(),
    "decaps_results": {},
}

for name, c_variant in cases.items():
    K_result = mlkem_decaps_internal(dk, c_variant, K_dim, ETA1, ETA2, DU, DV)
    frozen["decaps_results"][name] = {
        "c_variant_hex": c_variant.hex(),
        "K_result_hex": K_result.hex(),
        "matches_K_bob": K_result == K_bob,
    }

with open(os.path.join(outdir, "mlkem_frozen_vectors.json"), "w") as f:
    json.dump(frozen, f, indent=1)

print("Jaadytetty referenssi tallennettu 3 testitapaukselle:")
for name, data in frozen["decaps_results"].items():
    print(f"  {name}: K_result={data['K_result_hex'][:16]}..., matches_K_bob={data['matches_K_bob']}")


def verify_frozen():
    with open(os.path.join(outdir, "mlkem_frozen_vectors.json")) as f:
        loaded = json.load(f)
    ek_l = bytes.fromhex(loaded["ek_hex"])
    dk_l = bytes.fromhex(loaded["dk_hex"])
    K_bob_l = bytes.fromhex(loaded["K_bob_hex"])
    all_ok = True
    for name, data in loaded["decaps_results"].items():
        c_v = bytes.fromhex(data["c_variant_hex"])
        K_result = mlkem_decaps_internal(dk_l, c_v, K_dim, ETA1, ETA2, DU, DV)
        if K_result.hex() != data["K_result_hex"]:
            print(f"REGRESSIO: {name} K_result poikkeaa jaadytetysta!")
            all_ok = False
    return all_ok


if __name__ == "__main__":
    ok = verify_frozen()
    print()
    print("Jaadytetyn referenssin oma itsetarkistus:", "OK" if ok else "FAIL")
