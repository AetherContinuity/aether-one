#!/usr/bin/env python3
"""M3 Issue #15, Kerros 1: testivektorit PRF+SamplePolyCBD-kytkennalle.
Testaa useita N-arvoja (varmistaa etta N-laskuri vaikuttaa oikein -
sama sigma, eri N pitaa antaa ERI tulos, matching K-PKE.KeyGenin
oman N++-konvention)."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from keccak_golden import shake256
from samplepolycbd_golden import sample_poly_cbd

outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")


def prf(eta, s, b):
    return shake256(s + bytes([b]), 64 * eta)


def pack_coeffs(coeffs):
    val = 0
    for i, c in enumerate(coeffs):
        val |= (c & 0xFFFF) << (i * 16)
    return val


sigma = bytes(range(32))

with open(os.path.join(outdir, "prf_samplepolycbd_vectors.txt"), "w") as f:
    for eta in [2, 3]:
        for N in [0, 1, 5]:
            prf_out = prf(eta, sigma, N)
            f_coeffs, info = sample_poly_cbd(prf_out, eta, instrument=True)
            assert info["all_in_valid_cbd_range"]
            f.write(f"eta{eta}_N{N} {eta} {N}\n")
            f.write(f"{int.from_bytes(sigma, 'little'):064x}\n")
            f.write(f"{pack_coeffs(f_coeffs):x}\n")

print("6 testitapausta generoitu (eta=2,3 x N=0,1,5)")
