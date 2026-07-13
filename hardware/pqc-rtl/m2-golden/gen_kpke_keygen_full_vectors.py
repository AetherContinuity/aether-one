#!/usr/bin/env python3
"""M3 Issue #15, Kerros 3 (osa 2): koko K-PKE.KeyGen, FIPS 203
Algoritmi 13 rivit 1-20 (LOPULLINEN teksti), yhdesta siemenesta d.
ekPKE = ByteEncode12(t_hat)||rho, dkPKE = ByteEncode12(s_hat)."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from keccak_golden import sha3_512, shake256
from samplentt_golden import sample_ntt
from samplepolycbd_golden import sample_poly_cbd
from kyber_ntt_golden import ntt, multiply_ntts, Q
from byteencode_golden import byte_encode

K = 2
ETA1 = 3
outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")


def prf(eta, s, b):
    return shake256(s + bytes([b]), 64 * eta)


def mod_add_poly(a, b):
    return [(x + y) % Q for x, y in zip(a, b)]


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


d_seed = bytes(range(1, 33))
G_out = sha3_512(d_seed + bytes([K]))
rho, sigma = G_out[:32], G_out[32:]

A = [[sample_ntt(rho, byte_j=j, byte_i=i) for j in range(K)] for i in range(K)]

N = 0
s_vec, e_vec = [], []
for i in range(K):
    s_vec.append(sample_poly_cbd(prf(ETA1, sigma, N), ETA1))
    N += 1
for i in range(K):
    e_vec.append(sample_poly_cbd(prf(ETA1, sigma, N), ETA1))
    N += 1

s_hat = [ntt(s_vec[i]) for i in range(K)]
e_hat = [ntt(e_vec[i]) for i in range(K)]

t_hat = []
for i in range(K):
    acc = [0] * 256
    for j in range(K):
        acc = mod_add_poly(acc, multiply_ntts(A[i][j], s_hat[j]))
    t_hat.append(mod_add_poly(acc, e_hat[i]))

ekPKE = b"".join(bytes(byte_encode(12, t_hat[i])) for i in range(K)) + rho
dkPKE = b"".join(bytes(byte_encode(12, s_hat[i])) for i in range(K))

with open(os.path.join(outdir, "kpke_keygen_full_vectors.txt"), "w") as f:
    f.write(f"{int.from_bytes(d_seed, 'little'):064x}\n")
    for i in range(K):
        f.write(f"t_hat {i}\n{pack_coeffs(t_hat[i]):x}\n")
    for i in range(K):
        f.write(f"s_hat {i}\n{pack_coeffs(s_hat[i]):x}\n")
    f.write(f"rho\n{int.from_bytes(rho, 'little'):064x}\n")
    f.write(f"ekPKE\n{pack_bytes(ekPKE):x}\n")
    f.write(f"dkPKE\n{pack_bytes(dkPKE):x}\n")

print(f"Koko K-PKE.KeyGen laskettu k={K}:lle")
print(f"ekPKE ({len(ekPKE)} tavua): {ekPKE.hex()[:32]}...")
print(f"dkPKE ({len(dkPKE)} tavua): {dkPKE.hex()[:32]}...")
