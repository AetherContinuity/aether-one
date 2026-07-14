#!/usr/bin/env python3
"""M3 Issue #15 (jatko): testivektorit Decaps TB A:lle - K-PKE.Decrypt
-> m', G(m'||h) -> (K',r'). Kaikki 3 jaadytettya tapausta."""

import sys
import os
import json
sys.path.insert(0, os.path.dirname(__file__))
from mlkem_golden import kpke_decrypt
from keccak_golden import sha3_512

K_dim, DU, DV = 2, 10, 4
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
h = dk[768 * K_dim + 32:768 * K_dim + 64]

with open(os.path.join(outdir, "mlkem_decaps_a_vectors.txt"), "w") as f:
    f.write(f"{pack_bytes(dkPKE):x}\n")
    f.write(f"{pack_bytes(h):064x}\n")
    for name, data in frozen["decaps_results"].items():
        c_variant = bytes.fromhex(data["c_variant_hex"])
        m_prime = kpke_decrypt(dkPKE, c_variant, K_dim, DU, DV)
        G_out = sha3_512(m_prime + h)
        K_prime, r_prime = G_out[:32], G_out[32:]
        f.write(f"{name}\n")
        f.write(f"{pack_bytes(c_variant):x}\n")
        f.write(f"{pack_bytes(m_prime):064x}\n")
        f.write(f"{pack_bytes(K_prime):064x}\n")
        f.write(f"{pack_bytes(r_prime):064x}\n")

print("Decaps TB A -vektorit generoitu (3 tapausta)")
