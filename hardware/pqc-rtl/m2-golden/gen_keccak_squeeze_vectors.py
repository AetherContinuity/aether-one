#!/usr/bin/env python3
"""M3 Issue #11 Vaihe C: testivektorit puristusmoduulille. Kaksi
testitapausta: 32 tavua (yksi lohko, ei lisapermutaatiota) ja 200
tavua (kaksi lohkoa, SHAKE:n oma monilohko-tarve)."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from keccak_golden import absorb_instrumented, squeeze_instrumented

RATE = 136
MAX_OUT = 200

outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")


def pack_state(state):
    val = 0
    for i in range(25):
        x, y = i % 5, i // 5
        val |= state[x][y] << (i * 64)
    return val


def pack_bytes(b):
    val = 0
    for i, byte in enumerate(b):
        val |= byte << (i * 8)
    return val


state, _ = absorb_instrumented(b"abc", RATE, 0x06)
state_packed = pack_state(state)

with open(os.path.join(outdir, "keccak_squeeze_vectors.txt"), "w") as f:
    for name, out_len in [("32_1block", 32), ("200_2block", 200)]:
        out, _ = squeeze_instrumented(state, RATE, out_len)
        out_buf = out + b"\x00" * (MAX_OUT - len(out))
        f.write(f"{name} {out_len}\n")
        f.write(f"{state_packed:0400x}\n")
        f.write(f"{pack_bytes(out_buf):x}\n")

print("2 testitapausta generoitu (32 tavua 1 lohko, 200 tavua 2 lohkoa)")
