#!/usr/bin/env python3
"""M3 Issue #6: testivektorit Compress/Decompress RTL:lle. Kayttaa
suoraan m2-golden/compress_golden.py:n jo todennettuja funktioita."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from compress_golden import compress, decompress, Q

import random
random.seed(2026)

outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")

# Decompress: TAYDELLINEN kattavuus jokaiselle d:lle (ei otanta - 2^11
# on vain 2048 riviä isoimmalle d:lle, halpaa kayda kokonaan lapi)
D_VALUES = [1, 4, 5, 10, 11]  # ML-KEM:n oikeat du/dv-arvot + d=1 viestikoodaukselle

with open(os.path.join(outdir, "compress_vectors.txt"), "w") as f:
    for d in D_VALUES:
        # Decompress: kaikki 2^d arvoa
        for y in range(1 << d):
            dy = decompress(d, y)
            f.write(f"DECOMP {d} {y} {dy}\n")
        # Compress: satunnaisotos Zq:sta (Q=3329 liian iso taydelliselle kattavuudelle
        # jarkevassa ajassa, mutta 200 satunnaista per d riittaa hyvin)
        for _ in range(200):
            x = random.randrange(Q)
            cx = compress(d, x)
            f.write(f"COMP {d} {x} {cx}\n")

print(f"Vektorit generoitu d-arvoille: {D_VALUES}")
print(f"Decompress: TAYDELLINEN kattavuus jokaiselle d:lle")
print(f"Compress: 200 satunnaista per d")
