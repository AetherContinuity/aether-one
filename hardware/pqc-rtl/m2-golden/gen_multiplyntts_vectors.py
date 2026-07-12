#!/usr/bin/env python3
"""M3 Issue #8 (esityo): testivektorit MultiplyNTTs RTL:lle. Kayttaa
suoraan m2-golden/kyber_ntt_golden.py:n jo todennettua multiply_ntts-
funktiota (todennettu M2 Vaihe 2a:ssa konvoluutiolauseella)."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from kyber_ntt_golden import multiply_ntts, Q

import random
random.seed(2026)


def pack(coeffs):
    val = 0
    for i, c in enumerate(coeffs):
        val |= (c & 0xFFFF) << (i * 16)
    return val


outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")
with open(os.path.join(outdir, "multiplyntts_vectors.txt"), "w") as f:
    for trial in range(5):
        f_hat = [random.randrange(Q) for _ in range(256)]
        g_hat = [random.randrange(Q) for _ in range(256)]
        h_hat = multiply_ntts(f_hat, g_hat)
        f.write(f"{pack(f_hat):x}\n")
        f.write(f"{pack(g_hat):x}\n")
        f.write(f"{pack(h_hat):x}\n")

print("5 testitapausta generoitu")
