#!/usr/bin/env python3
"""M3 Issue #11 Vaihe B: testivektorit absorbointiohjaimelle. Kaksi
testitapausta: 'abc' (1 lohko) ja 'A'*136 (2 lohkoa, testaa monilohko-
absorbointia)."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from keccak_golden import pad_message, absorb_instrumented

RATE = 136
MAX_BLOCKS = 2
TOTAL_BYTES = RATE * MAX_BLOCKS

outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")


def pack_bytes(b):
    val = 0
    for i, byte in enumerate(b):
        val |= byte << (i * 8)
    return val


def pack_state(state):
    val = 0
    for i in range(25):
        x, y = i % 5, i // 5
        val |= state[x][y] << (i * 64)
    return val


test_cases = [
    ("abc_1block", b"abc"),
    ("A136_2block", b"A" * RATE),
]

with open(os.path.join(outdir, "keccak_absorb_vectors.txt"), "w") as f:
    for name, msg in test_cases:
        padded = pad_message(msg, RATE, 0x06)
        num_blocks = len(padded) // RATE
        final_state, snapshots = absorb_instrumented(msg, RATE, 0x06)

        padded_buf = padded + b"\x00" * (TOTAL_BYTES - len(padded))
        f.write(f"{name} {num_blocks}\n")
        f.write(f"{pack_bytes(padded_buf):x}\n")
        for snap in snapshots:
            f.write(f"{pack_state(snap):0400x}\n")

print(f"{len(test_cases)} testitapausta generoitu")
