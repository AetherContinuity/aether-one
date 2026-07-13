#!/usr/bin/env python3
"""M3 Issue #15 Vaihe 2 (loppuunsaattaminen): testivektorit koko
SampleNTT-moduulille (XOF+hylkaysnaytteenotto yhdessa). Kayttaa
jaadytettya referenssia suoraan (rho,j,i -> odotettu a_hat+info)."""

import sys
import os
import json
sys.path.insert(0, os.path.dirname(__file__))

outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")

with open(os.path.join(outdir, "samplentt_frozen_reference.json")) as f:
    frozen = json.load(f)


def pack_coeffs(coeffs):
    val = 0
    for i, c in enumerate(coeffs):
        val |= (c & 0xFFFF) << (i * 16)
    return val


with open(os.path.join(outdir, "samplentt_full_vectors.txt"), "w") as f:
    for name, data in frozen.items():
        rho = bytes.fromhex(data["rho_hex"])
        rho_int = int.from_bytes(rho, "little")
        f.write(f"{name} {data['j']} {data['i']} {data['info']['accepted_count']} {data['info']['rejected_count']} {data['info']['xof_bytes_consumed']}\n")
        f.write(f"{rho_int:064x}\n")
        f.write(f"{pack_coeffs(data['a_hat']):x}\n")

print(f"{len(frozen)} testitapausta generoitu (koko SampleNTT, rho+j+i syotteena)")
