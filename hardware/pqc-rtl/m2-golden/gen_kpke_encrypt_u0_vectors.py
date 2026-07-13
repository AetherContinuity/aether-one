#!/usr/bin/env python3
"""M3 Issue #15 (jatko), K-PKE.Encrypt Vaihe 1: u[0] = NTT^-1(sum_j A[j][0]*y_hat[j]) + e1[0].
Kayttajan oma ehdotus: yksi matriisi-vektoritulo + yksi INTT + yksi +e1,
verrattuna golden-malliin ennen u[1]:n lisaamista."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from kpke_encrypt_golden import kpke_keygen, prf
from samplepolycbd_golden import sample_poly_cbd
from kyber_ntt_golden import ntt, ntt_inv, multiply_ntts, Q

K, ETA1, ETA2 = 2, 3, 2
outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")


def mod_add_poly(a, b):
    return [(x + y) % Q for x, y in zip(a, b)]


def pack_coeffs(coeffs):
    val = 0
    for i, c in enumerate(coeffs):
        val |= (c & 0xFFFF) << (i * 16)
    return val


d_seed = bytes(range(1, 33))
ekPKE, dkPKE, A, t_hat, rho = kpke_keygen(d_seed, K, ETA1)

r_seed = bytes(range(64, 96))
N = 0
y_vec = []
for i in range(K):
    y_vec.append(sample_poly_cbd(prf(ETA1, r_seed, N), ETA1))
    N += 1
e1_vec = []
for i in range(K):
    e1_vec.append(sample_poly_cbd(prf(ETA2, r_seed, N), ETA2))
    N += 1

y_hat = [ntt(y_vec[i]) for i in range(K)]

# u[0] = NTT^-1( sum_j A[j][0] * y_hat[j] ) + e1[0]  (A^T - transponoitu)
acc = [0] * 256
for j in range(K):
    acc = mod_add_poly(acc, multiply_ntts(A[j][0], y_hat[j]))
sum_before_e1 = list(acc)
u0 = mod_add_poly(ntt_inv(acc), e1_vec[0])

with open(os.path.join(outdir, "kpke_encrypt_u0_vectors.txt"), "w") as f:
    for j in range(K):
        f.write(f"A_transposed_col0_{j}\n{pack_coeffs(A[j][0]):x}\n")
    for j in range(K):
        f.write(f"y_hat_{j}\n{pack_coeffs(y_hat[j]):x}\n")
    f.write(f"sum_before_e1\n{pack_coeffs(sum_before_e1):x}\n")
    f.write(f"e1_0\n{pack_coeffs(e1_vec[0]):x}\n")
    f.write(f"u0\n{pack_coeffs(u0):x}\n")

print(f"u[0] laskettu: u0[0:5]={u0[:5]}")
