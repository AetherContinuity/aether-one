#!/usr/bin/env python3
"""M3 Issue #15, Kerros 2 (osa 1): A-matriisin generointi, k=2
(ML-KEM-512). A[i][j] = SampleNTT(rho||j||i), FIPS 203 Algoritmi 13
rivi 5 (LOPULLINEN teksti, vahvistettu Liite C.2:sta - luonnoksessa
oli i/j vaihdettuna, korjattu lopulliseen versioon)."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from samplentt_golden import sample_ntt, Q

K = 2
outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")


def pack_coeffs(coeffs):
    val = 0
    for i, c in enumerate(coeffs):
        val |= (c & 0xFFFF) << (i * 16)
    return val


rho = bytes(range(32))

A = [[None] * K for _ in range(K)]
with open(os.path.join(outdir, "amatrix_k2_vectors.txt"), "w") as f:
    f.write(f"{int.from_bytes(rho, 'little'):064x}\n")
    for i in range(K):
        for j in range(K):
            A[i][j] = sample_ntt(rho, byte_j=j, byte_i=i)
            f.write(f"{i} {j}\n")
            f.write(f"{pack_coeffs(A[i][j]):x}\n")

print(f"A-matriisi (k={K}) generoitu, {K*K} alkiota")
print(f"A[0][0][0:3]={A[0][0][:3]}, A[0][1][0:3]={A[0][1][:3]}")
print(f"A[1][0][0:3]={A[1][0][:3]}, A[1][1][0:3]={A[1][1][:3]}")
assert A[0][1] != A[1][0], "A[0][1] == A[1][0] - matriisi vaikuttaa symmetriselta, tarkista indeksointi!"
print("Vahvistettu: A[0][1] != A[1][0] (matriisi ei symmetrinen, oikein)")
