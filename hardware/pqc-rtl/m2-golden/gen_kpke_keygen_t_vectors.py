#!/usr/bin/env python3
"""M3 Issue #15, Kerros 3 (osa 1): t_hat = A.s_hat + e_hat, FIPS 203
Algoritmi 13 rivit 16-18 (LOPULLINEN teksti). HUOM (tarkennus
kayttajan omaan hahmotelmaan): t_hat pysyy KOKONAAN NTT-alueessa -
EI tarvita NTT^-1:ta KeyGenissa (toisin kuin Decrypt, joka tarvitsee).
ekPKE = ByteEncode12(t_hat)||rho koodaa t_hat:n SUORAAN NTT-muodossa.

Tallettaa JOKAISEN valivaiheen (kayttajan oma ohje): s_hat=NTT(s),
e_hat=NTT(e), MultiplyNTTs-osatulot, kumulatiivinen summa, lopullinen
t_hat[i]."""

import sys
import os
import json
sys.path.insert(0, os.path.dirname(__file__))
from keccak_golden import sha3_512, shake256
from samplentt_golden import sample_ntt
from samplepolycbd_golden import sample_poly_cbd
from kyber_ntt_golden import ntt, multiply_ntts, Q

K = 2
ETA1 = 3
outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")


def prf(eta, s, b):
    return shake256(s + bytes([b]), 64 * eta)


def mod_add_poly(a, b):
    return [(x + y) % Q for x, y in zip(a, b)]


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
trace = {}
for i in range(K):
    acc = [0] * 256
    products = []
    for j in range(K):
        prod = multiply_ntts(A[i][j], s_hat[j])
        products.append(prod)
        acc = mod_add_poly(acc, prod)
    sum_before_e = list(acc)
    t_i = mod_add_poly(acc, e_hat[i])
    t_hat.append(t_i)
    trace[f"t{i}"] = {
        "products": products,
        "sum_before_e": sum_before_e,
        "e_hat_i": e_hat[i],
        "t_hat_i": t_i,
    }

with open(os.path.join(outdir, "kpke_keygen_t_vectors.txt"), "w") as f:
    for i in range(K):
        for j in range(K):
            f.write(f"A {i} {j}\n{pack_coeffs(A[i][j]):x}\n")
    for i in range(K):
        f.write(f"s {i}\n{pack_coeffs(s_vec[i]):x}\n")
    for i in range(K):
        f.write(f"e {i}\n{pack_coeffs(e_vec[i]):x}\n")
    for i in range(K):
        f.write(f"s_hat {i}\n{pack_coeffs(s_hat[i]):x}\n")
    for i in range(K):
        f.write(f"e_hat {i}\n{pack_coeffs(e_hat[i]):x}\n")
    for i in range(K):
        f.write(f"t_hat {i}\n{pack_coeffs(t_hat[i]):x}\n")
    for j in range(K):
        f.write(f"product_t0_{j}\n{pack_coeffs(trace['t0']['products'][j]):x}\n")
    f.write(f"sum_before_e_t0\n{pack_coeffs(trace['t0']['sum_before_e']):x}\n")

print(f"t_hat lasketttu k={K}:lle. t_hat[0][0:5]={t_hat[0][:5]}")
print(f"t_hat[1][0:5]={t_hat[1][:5]}")
