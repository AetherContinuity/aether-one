#!/usr/bin/env python3
"""M3 Issue #15 (jatko), K-PKE.Encrypt Vaihe 2: v = NTT^-1(sum_j
t_hat[j]*y_hat[j]) + e2 + mu. Pistetulo (EI transponoitu, t_hat
kaytetaan suoraan) - rakenteeltaan sama kuin K-PKE.Decryptin oma
w-laskenta (Issue #8)."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from kpke_encrypt_golden import kpke_keygen, prf
from samplepolycbd_golden import sample_poly_cbd
from kyber_ntt_golden import ntt, ntt_inv, multiply_ntts, Q
from byteencode_golden import byte_decode
from compress_golden import decompress

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
m_msg = bytes(range(32))

N = 0
y_vec = []
for i in range(K):
    y_vec.append(sample_poly_cbd(prf(ETA1, r_seed, N), ETA1))
    N += 1
e1_vec = []
for i in range(K):
    e1_vec.append(sample_poly_cbd(prf(ETA2, r_seed, N), ETA2))
    N += 1
e2 = sample_poly_cbd(prf(ETA2, r_seed, N), ETA2)
y_hat = [ntt(y_vec[i]) for i in range(K)]

acc_v = [0] * 256
for j in range(K):
    acc_v = mod_add_poly(acc_v, multiply_ntts(t_hat[j], y_hat[j]))
sum_before_e2 = list(acc_v)

m_bits = byte_decode(1, list(m_msg))
mu = [decompress(1, b) for b in m_bits]

v_poly = mod_add_poly(mod_add_poly(ntt_inv(acc_v), e2), mu)

with open(os.path.join(outdir, "kpke_encrypt_v_vectors.txt"), "w") as f:
    for j in range(K):
        f.write(f"t_hat_{j}\n{pack_coeffs(t_hat[j]):x}\n")
    for j in range(K):
        f.write(f"y_hat_{j}\n{pack_coeffs(y_hat[j]):x}\n")
    f.write(f"sum_before_e2\n{pack_coeffs(sum_before_e2):x}\n")
    f.write(f"e2\n{pack_coeffs(e2):x}\n")
    f.write(f"mu\n{pack_coeffs(mu):x}\n")
    f.write(f"v_poly\n{pack_coeffs(v_poly):x}\n")

print(f"v laskettu: v_poly[0:5]={v_poly[:5]}")
