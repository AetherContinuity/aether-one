#!/usr/bin/env python3
"""M3 Issue #7 (jatko-osa): testivektorit ByteEncode_d/ByteDecode_d
RTL:lle, d=4,5,10,11,12. PAKATTU muoto (ks. pqc_byteencode_dparam.sv).

d=12 saa lisaksi oman reunatapaustestin, jossa kaikki 12-bittiset
segmentit ovat valilla [Q, 4095] - taman on TARKOITUS reduosoitua
mod Q:lla ByteDecode12:ssa (FIPS 203:n oma dokumentoitu erikoistapaus,
ei satunnaisesti onnistu koska data sattuu jo olemaan < Q)."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from byteencode_golden import byte_decode, Q

import random
random.seed(2026)

D_VALUES = [4, 5, 10, 11, 12]
N_TRIALS = 5

outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")


def bits_to_packed_d(F, d):
    val = 0
    for i, x in enumerate(F):
        val |= (x & ((1 << d) - 1)) << (i * d)
    return val


for d in D_VALUES:
    m = Q if d == 12 else (1 << d)
    with open(os.path.join(outdir, f"byteencode_d{d}_packed_vectors.txt"), "w") as f:
        for trial in range(N_TRIALS):
            F = [random.randrange(m) for _ in range(256)]
            f_packed = bits_to_packed_d(F, d)
            f.write(f"{f_packed:x}\n")

print(f"Vektorit generoitu d-arvoille: {D_VALUES}, {N_TRIALS} testitapausta per d")

with open(os.path.join(outdir, "byteencode_d12_edge_vectors.txt"), "w") as f:
    for trial in range(10):
        segments = [random.randrange(Q, 4096) for _ in range(256)]
        raw_packed = bits_to_packed_d(segments, 12)
        expected = [s % Q for s in segments]
        expected_packed = bits_to_packed_d(expected, 12)
        f.write(f"{raw_packed:x}\n")
        f.write(f"{expected_packed:x}\n")

print("d=12 reunatapaustestit generoitu (segmentit >= Q, pitaisi reduosoitua)")
