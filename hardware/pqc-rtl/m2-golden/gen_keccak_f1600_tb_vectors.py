#!/usr/bin/env python3
"""M3 Issue #10: muuntaa jaadytetyn kierrostilareferenssin
(vectors/keccak_round_snapshots.json) testipenkin lukemaan hex-
pakattuun muotoon. Deterministinen muunnos - itse JSON on pysyva
referenssi (committoitu), tama tiedosto on vain sen kayttomuoto
testipenkille."""

import json
import os

outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")

with open(os.path.join(outdir, "keccak_round_snapshots.json")) as f:
    frozen = json.load(f)


def pack_state(state_hex):
    val = 0
    for i in range(25):
        x, y = i % 5, i // 5
        val |= int(state_hex[x][y], 16) << (i * 64)
    return val


with open(os.path.join(outdir, "keccak_f1600_test_vectors.txt"), "w") as out:
    for name in ["all_zero", "sha3_256_abc_block", "all_ff"]:
        tc = frozen[name]
        initial = pack_state(tc["initial_state"])
        out.write(f"{initial:0400x}\n")
        for r in range(24):
            round_state = pack_state(tc["round_states"][r])
            out.write(f"{round_state:0400x}\n")

print("Testivektorit generoitu 3 testitapaukselle (1 initial + 24 kierrosta kukin)")
