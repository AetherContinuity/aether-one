#!/usr/bin/env python3
"""M3 Issue #15: testivektorit SamplePolyCBD RTL:lle, jaadytetysta
referenssista, eroteltuna eta=2 ja eta=3 -tiedostoihin (eri B-koko)."""

import sys
import os
import json
sys.path.insert(0, os.path.dirname(__file__))

outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")

with open(os.path.join(outdir, "samplepolycbd_frozen_reference.json")) as f:
    frozen = json.load(f)


def pack_coeffs(coeffs):
    val = 0
    for i, c in enumerate(coeffs):
        val |= (c & 0xFFFF) << (i * 16)
    return val


for eta in [2, 3]:
    cases = {k: v for k, v in frozen.items() if v["eta"] == eta}
    with open(os.path.join(outdir, f"samplepolycbd_eta{eta}_vectors.txt"), "w") as f:
        for name, data in cases.items():
            B = bytes.fromhex(data["B_hex"])
            f.write(f"{name}\n")
            f.write(f"{int.from_bytes(B, 'little'):0{64*eta*2}x}\n")
            f.write(f"{pack_coeffs(data['f']):x}\n")
    print(f"eta={eta}: {len(cases)} testitapausta")
