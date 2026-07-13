#!/usr/bin/env python3
"""M3 Issue #15 (loppuunsaattaminen): koko K-PKE.Encrypt, FIPS 203
Algoritmi 14 rivit 1-24, yhdesta ekPKE:sta (Kerros 3:n tuotoksesta)
+ viestista m + satunnaisuudesta r."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from kpke_encrypt_golden import kpke_keygen, kpke_encrypt

K, ETA1, ETA2, DU, DV = 2, 3, 2, 10, 4
outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")


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
ekPKE, dkPKE, A, t_hat, rho = kpke_keygen(d_seed, K, ETA1)

m_msg = bytes(range(32))
r_seed = bytes(range(64, 96))
c, u_vec, v_poly = kpke_encrypt(ekPKE, m_msg, r_seed, K, ETA1, ETA2, DU, DV)

with open(os.path.join(outdir, "kpke_encrypt_full_vectors.txt"), "w") as f:
    f.write(f"ekPKE\n{pack_bytes(ekPKE):x}\n")
    f.write(f"m\n{pack_bytes(m_msg):x}\n")
    f.write(f"r\n{int.from_bytes(r_seed,'little'):064x}\n")
    for i in range(K):
        f.write(f"u_{i}\n{pack_coeffs(u_vec[i]):x}\n")
    f.write(f"v\n{pack_coeffs(v_poly):x}\n")
    f.write(f"c\n{pack_bytes(c):x}\n")

print(f"Koko K-PKE.Encrypt laskettu: c ({len(c)} tavua) = {c.hex()[:32]}...")
