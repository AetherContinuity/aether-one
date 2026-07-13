#!/usr/bin/env python3
"""M3 Issue #15, Kerros 2 regressio: yksi siemen d, koko K-PKE.KeyGenin
Algoritmi 13 rivit 1-15 (G(d||k) -> rho,sigma -> A,s,e). Tama EI VIELA
laske t=A.s+e (lineaarialgebra, Kerros 3) - vain kaikki kolme
lahtoobjektia yhdesta siemenesta, kayttajan oma ehdotus."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from keccak_golden import sha3_512, shake256
from samplentt_golden import sample_ntt
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


d_seed = bytes(range(1, 33))  # Yksi kiintea 32-tavuinen KeyGen-siemen d

# Algoritmi 13 rivi 1: (rho,sigma) <- G(d||k)
G_out = sha3_512(d_seed + bytes([K]))
rho, sigma = G_out[:32], G_out[32:]

# Rivit 3-7: A-matriisi
A = [[sample_ntt(rho, byte_j=j, byte_i=i) for j in range(K)] for i in range(K)]

# Rivit 8-15: s,e (N jatkuu)
N = 0
s_vec, e_vec = [], []
for i in range(K):
    s_vec.append(sample_poly_cbd(prf(ETA1, sigma, N), ETA1))
    N += 1
for i in range(K):
    e_vec.append(sample_poly_cbd(prf(ETA1, sigma, N), ETA1))
    N += 1

with open(os.path.join(outdir, "layer2_regression_vectors.txt"), "w") as f:
    f.write(f"{int.from_bytes(d_seed, 'little'):064x}\n")
    f.write(f"{int.from_bytes(rho, 'little'):064x}\n")
    f.write(f"{int.from_bytes(sigma, 'little'):064x}\n")
    for i in range(K):
        for j in range(K):
            f.write(f"{pack_coeffs(A[i][j]):x}\n")
    for i in range(K):
        f.write(f"{pack_coeffs(s_vec[i]):x}\n")
    for i in range(K):
        f.write(f"{pack_coeffs(e_vec[i]):x}\n")

print(f"Kerros 2 -regressio generoitu: d -> G -> (rho,sigma) -> A({K}x{K}) + s({K}) + e({K})")
print(f"rho={rho.hex()[:16]}..., sigma={sigma.hex()[:16]}...")
