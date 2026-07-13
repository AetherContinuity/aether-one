#!/usr/bin/env python3
"""M3 Issue #13: testivektorit SHA3-512-huippumoduulille. Sama
verifiointipolku kuin SHA3-256:ssa (Issue #12): golden-malli
(hashlib-ankkuroitu), nelja testitapausta mukaan lukien monilohko-
absorbointi (rate=72, 150 tavua -> 3 lohkoa) ja ML-KEM-tyylinen
32-tavun API-testi (G(c)-funktion oma kayttotapa)."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from keccak_golden import sha3_512

RATE = 72
MAX_BLOCKS = 3
TOTAL_BYTES = RATE * MAX_BLOCKS

outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")


def pack_bytes(b):
    val = 0
    for i, byte in enumerate(b):
        val |= byte << (i * 8)
    return val


test_cases = [
    ("empty", b""),
    ("abc", b"abc"),
    ("150_bytes_3block", b"B" * 150),
    ("32_bytes_fixed_G_style", bytes(range(32))),  # ML-KEM:n G(c)-funktion oma tyyli
]

with open(os.path.join(outdir, "sha3_512_vectors.txt"), "w") as f:
    for name, msg in test_cases:
        digest = sha3_512(msg)
        msg_buf = msg + b"\x00" * (TOTAL_BYTES - len(msg))
        f.write(f"{name} {len(msg)}\n")
        f.write(f"{pack_bytes(msg_buf):x}\n")
        f.write(f"{pack_bytes(digest):x}\n")

print(f"{len(test_cases)} testitapausta generoitu")
for name, msg in test_cases:
    print(f"  {name}: SHA3-512 = {sha3_512(msg).hex()}")
