#!/usr/bin/env python3
"""M3 Issue #15 (viimeinen osa): testivektorit ML-KEM.KeyGen_internal
RTL:lle."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from mlkem_golden import mlkem_keygen_internal

K_dim, ETA1 = 2, 3
outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")


def pack_bytes(b):
    val = 0
    for i, byte in enumerate(b):
        val |= byte << (i * 8)
    return val


d = bytes(range(1, 33))
z = bytes(range(33, 65))
ek, dk = mlkem_keygen_internal(d, z, K_dim, ETA1)

with open(os.path.join(outdir, "mlkem_keygen_vectors.txt"), "w") as f:
    f.write(f"{pack_bytes(d):064x}\n")
    f.write(f"{pack_bytes(z):064x}\n")
    f.write(f"{pack_bytes(ek):x}\n")
    f.write(f"{pack_bytes(dk):x}\n")

print(f"ML-KEM.KeyGen_internal-vektorit generoitu: ek={len(ek)} tavua, dk={len(dk)} tavua")
