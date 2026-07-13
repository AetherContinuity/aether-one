#!/usr/bin/env python3
"""M3 Issue #15 (jatko): testivektorit ML-KEM.Encaps_internal RTL:lle.
FIPS 203 Algoritmi 17: (K,r) <- G(m||H(ek)); c <- K-PKE.Encrypt(ek,m,r).

Kayttaa jaadytettya mlkem_frozen_vectors.json:ia (SAMA ek, m, K_bob, c
kuin siella - varmistaa etta Encaps-testi ja Decaps-testi (seuraava
vaihe) kayttavat JOHDONMUKAISIA arvoja, valttaen aiemman Kerros 3:n
oman siemen-epajohdonmukaisuusbugin toistumisen)."""

import sys
import os
import json
sys.path.insert(0, os.path.dirname(__file__))
from keccak_golden import sha3_256, sha3_512
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

ek = bytes.fromhex(frozen["ek_hex"])
m = bytes.fromhex(frozen["m_hex"])

H_ek = sha3_256(ek)
G_out = sha3_512(m + H_ek)
K_expect, r_expect = G_out[:32], G_out[32:]
c_expect, _, _ = kpke_encrypt(ek, m, r_expect, K_dim, ETA1, ETA2, DU, DV)

assert K_expect.hex() == frozen["K_bob_hex"], "K poikkeaa jaadytetysta referenssista!"
assert c_expect.hex() == frozen["c_hex"], "c poikkeaa jaadytetysta referenssista!"

with open(os.path.join(outdir, "mlkem_encaps_vectors.txt"), "w") as f:
    f.write(f"{pack_bytes(ek):x}\n")
    f.write(f"{pack_bytes(m):064x}\n")
    f.write(f"{pack_bytes(H_ek):064x}\n")
    f.write(f"{pack_bytes(K_expect):064x}\n")
    f.write(f"{pack_bytes(r_expect):064x}\n")
    f.write(f"{pack_bytes(c_expect):x}\n")

print(f"ML-KEM.Encaps_internal-vektorit generoitu ja vahvistettu jaadytettya referenssia vasten")
print(f"K={K_expect.hex()[:16]}..., c pituus={len(c_expect)} tavua")
