#!/usr/bin/env python3
"""M3 Issue #15 (jatko): testivektorit Decaps TB B:lle - m',r',ek,z
syotteina (jo laskettu TB A:ssa/golden-mallissa) -> K-PKE.Encrypt ->
c', vertailu c==c', FO-valinta. Kaikki 3 jaadytettya tapausta."""

import sys
import os
import json
sys.path.insert(0, os.path.dirname(__file__))
from mlkem_golden import kpke_decrypt
from keccak_golden import sha3_512, shake256
from kpke_encrypt_golden import kpke_encrypt

K_dim, ETA1, ETA2, DU, DV = 2, 3, 2, 10, 4
outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")


def pack_bytes(b):
    val = 0
    for i, byte in enumerate(b):
        val |= byte << (i * 8)
    return val


with open(os.path.join(outdir, "mlkem_frozen_vectors.json")) as f:
    frozen = json.load(f)

dk = bytes.fromhex(frozen["dk_hex"])
dkPKE = dk[0:384 * K_dim]
ek = dk[384 * K_dim:768 * K_dim + 32]
h = dk[768 * K_dim + 32:768 * K_dim + 64]
z = dk[768 * K_dim + 64:768 * K_dim + 96]

with open(os.path.join(outdir, "mlkem_decaps_b_vectors.txt"), "w") as f:
    f.write(f"{pack_bytes(ek):x}\n")
    f.write(f"{pack_bytes(z):064x}\n")
    for name, data in frozen["decaps_results"].items():
        c_variant = bytes.fromhex(data["c_variant_hex"])
        m_prime = kpke_decrypt(dkPKE, c_variant, K_dim, DU, DV)
        G_out = sha3_512(m_prime + h)
        K_prime, r_prime = G_out[:32], G_out[32:]
        c_prime, _, _ = kpke_encrypt(ek, m_prime, r_prime, K_dim, ETA1, ETA2, DU, DV)
        K_bar = shake256(z + c_variant, 32)
        match = (c_variant == c_prime)
        K_final = K_prime if match else K_bar

        f.write(f"{name}\n")
        f.write(f"{pack_bytes(m_prime):064x}\n")
        f.write(f"{pack_bytes(r_prime):064x}\n")
        f.write(f"{pack_bytes(K_prime):064x}\n")
        f.write(f"{pack_bytes(c_variant):x}\n")
        f.write(f"{pack_bytes(c_prime):x}\n")
        f.write(f"{1 if match else 0}\n")
        f.write(f"{pack_bytes(K_final):064x}\n")

print("Decaps TB B -vektorit generoitu (3 tapausta)")
