#!/usr/bin/env python3
"""M3 Issue #15 Vaihe 2: testivektorit pqc_samplentt_reject.sv:lle.
Kayttaa jaadytettya referenssia (samplentt_frozen_reference.json),
laskee kunkin testitapauksen XOF-tavuvirran uudestaan (koska RTL-
moduuli ottaa valmiiksi lasketun XOF-datan sisaan, ei laske sita
itse - Vaihe 2 testaa VAIN hylkaysnaytteenottoa, XOF erikseen jo
todennettu Issue #14:ssa)."""

import sys
import os
import json
sys.path.insert(0, os.path.dirname(__file__))
from keccak_golden import shake128

XOF_BYTES = 1008

outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")

with open(os.path.join(outdir, "samplentt_frozen_reference.json")) as f:
    frozen = json.load(f)


def pack_bytes(b):
    val = 0
    for i, byte in enumerate(b):
        val |= byte << (i * 8)
    return val


def pack_coeffs(coeffs):
    val = 0
    for i, c in enumerate(coeffs):
        val |= (c & 0xFFFF) << (i * 16)
    return val


with open(os.path.join(outdir, "samplentt_reject_vectors.txt"), "w") as f:
    for name, data in frozen.items():
        rho = bytes.fromhex(data["rho_hex"])
        B = rho + bytes([data["j"], data["i"]])
        xof_data = shake128(B, XOF_BYTES)

        f.write(f"{name} {data['info']['accepted_count']} {data['info']['rejected_count']} {data['info']['xof_bytes_consumed']}\n")
        f.write(f"{pack_bytes(xof_data):x}\n")
        f.write(f"{pack_coeffs(data['a_hat']):x}\n")

print(f"{len(frozen)} testitapausta generoitu (jaadytetysta referenssista)")
