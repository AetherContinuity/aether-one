#!/usr/bin/env python3
"""M3 Issue #15, Kerros 2 (osa 2/3): s- ja e-vektorien testivektorit,
k=2, eta1=3 (ML-KEM-512). N-laskuri jatkuu s:sta e:hen (0,1 -> 2,3),
FIPS 203 Algoritmi 13 rivit 8-15 (LOPULLINEN teksti)."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from keccak_golden import shake256
from samplepolycbd_golden import sample_poly_cbd

K = 2
ETA1 = 3
outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")


def prf(eta, s, b):
    return shake256(s + bytes([b]), 64 * eta)


def pack_coeffs(coeffs):
    val = 0
    for i, c in enumerate(coeffs):
        val |= (c & 0xFFFF) << (i * 16)
    return val


sigma = bytes(range(32, 64))

N = 0
s_vec, e_vec = [], []
for i in range(K):
    s_vec.append(sample_poly_cbd(prf(ETA1, sigma, N), ETA1))
    N += 1
for i in range(K):
    e_vec.append(sample_poly_cbd(prf(ETA1, sigma, N), ETA1))
    N += 1

with open(os.path.join(outdir, "se_vectors_k2.txt"), "w") as f:
    f.write(f"{int.from_bytes(sigma, 'little'):064x}\n")
    for i in range(K):
        f.write(f"s {i} {i}\n")  # N=i sekvenssin s-osalle
        f.write(f"{pack_coeffs(s_vec[i]):x}\n")
    for i in range(K):
        f.write(f"e {i} {K+i}\n")  # N=K+i sekvenssin e-osalle
        f.write(f"{pack_coeffs(e_vec[i]):x}\n")

print(f"s+e -vektorit generoitu (k={K}, eta1={ETA1}), N paattyy {2*K}:aan")
