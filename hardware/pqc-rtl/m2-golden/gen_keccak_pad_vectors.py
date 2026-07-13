#!/usr/bin/env python3
"""M3 Issue #11 Vaihe A: testivektorit pad10*1-moduulille, kolme
kriittista reunatapausta (kayttajan oma ehdotus): tyhja viesti,
rate-1 tavua, tasan rate tavua."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from keccak_golden import pad_message

RATE = 136
MAX_BLOCKS = 2
TOTAL_BYTES = RATE * MAX_BLOCKS

outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")


def pack_bytes(b):
    val = 0
    for i, byte in enumerate(b):
        val |= byte << (i * 8)
    return val


test_cases = [
    ("empty", b""),
    ("rate_minus_1", b"A" * (RATE - 1)),
    ("exact_rate", b"A" * RATE),
]

with open(os.path.join(outdir, "keccak_pad_vectors.txt"), "w") as f:
    for name, msg in test_cases:
        padded = pad_message(msg, RATE, 0x06)
        num_blocks = len(padded) // RATE
        # msg_in on TAYDEN MAX_BLOCKS*RATE-kokoinen puskuri, alkuosa=msg, loput=0
        msg_buf = msg + b"\x00" * (TOTAL_BYTES - len(msg))
        padded_buf = padded + b"\x00" * (TOTAL_BYTES - len(padded))
        f.write(f"{name} {len(msg)} {num_blocks}\n")
        f.write(f"{pack_bytes(msg_buf):x}\n")
        f.write(f"{pack_bytes(padded_buf):x}\n")

print(f"{len(test_cases)} reunatapausta generoitu")
