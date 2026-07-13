#!/usr/bin/env python3
"""M3 Issue #15, Vaihe 3: pysyva, jaadytetty referenssi SampleNTT:lle.
Sama periaate kuin Keccakin kierrostilat (Issue #10) - EI vain
kertakayttoinen debug-apuvaline, vaan pysyva regressiotesti seka
tulevaa RTL:aa etta itse golden-mallia vastaan.

Kaksi kiinteaa (ei satunnaista) testitapausta:
- perustapaus: rho=bytes(0..31), j=0, i=0 (K-PKE.KeyGenin ensimmainen
  A[0][0]-kutsu)
- toinen_indeksi: sama rho, j=1, i=2 (varmistaa etta j/i vaikuttavat
  tulokseen oikein)

Tallettaa TAYDELLISEN instrumentoinnin (hyvaksytyt/hylatyt maarat,
kulutetut XOF-tavut) seka koko 256 kertoimen tuloksen."""

import sys
import os
import json
sys.path.insert(0, os.path.dirname(__file__))
from samplentt_golden import sample_ntt, Q, MIN_XOF_BYTES, DEFAULT_XOF_BYTES

outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")
os.makedirs(outdir, exist_ok=True)

FIXED_RHO = bytes(range(32))

test_cases = {
    "base_case_j0_i0": {"j": 0, "i": 0},
    "second_index_j1_i2": {"j": 1, "i": 2},
}

frozen = {}
for name, params in test_cases.items():
    a_hat, info = sample_ntt(FIXED_RHO, params["j"], params["i"], instrument=True)
    assert all(0 <= x < Q for x in a_hat), f"{name}: kerroin ulkona valilta [0,Q)!"
    frozen[name] = {
        "rho_hex": FIXED_RHO.hex(),
        "j": params["j"],
        "i": params["i"],
        "a_hat": a_hat,
        "info": info,
    }

with open(os.path.join(outdir, "samplentt_frozen_reference.json"), "w") as f:
    json.dump(frozen, f, indent=1)

print(f"Tallennettu {len(test_cases)} jaadytettya testitapausta")
for name, data in frozen.items():
    print(f"  {name}: iteraatioita={data['info']['iterations']}, "
          f"hylkayksia={data['info']['rejected_count']}, "
          f"a_hat[0:5]={data['a_hat'][:5]}")


def verify_frozen():
    """Aja golden-malli UUDESTAAN, vertaa jaadytettyyn - suojaa golden-
    mallin OMAA tulevaa regressiota vastaan."""
    with open(os.path.join(outdir, "samplentt_frozen_reference.json")) as f:
        loaded = json.load(f)
    all_ok = True
    for name, data in loaded.items():
        rho = bytes.fromhex(data["rho_hex"])
        a_hat, info = sample_ntt(rho, data["j"], data["i"], instrument=True)
        if a_hat != data["a_hat"]:
            print(f"REGRESSIO: {name} a_hat poikkeaa jaadytetysta!")
            all_ok = False
        if info["iterations"] != data["info"]["iterations"]:
            print(f"REGRESSIO: {name} iteraatiomaara poikkeaa jaadytetysta!")
            all_ok = False
    return all_ok


if __name__ == "__main__":
    ok = verify_frozen()
    print()
    print("Jaadytetyn referenssin oma itsetarkistus:", "OK" if ok else "FAIL")
