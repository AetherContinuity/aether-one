#!/usr/bin/env python3
"""M3 (Issue #1): BaseCaseMultiply RTL -testivektorit. Kayttaa suoraan
m2-golden/kyber_ntt_golden.py:n jo todennettua base_case_multiply-
funktiota - ei uutta, erillista Python-toteutusta."""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "m2-golden"))
from kyber_ntt_golden import base_case_multiply, Q

import random
random.seed(2026)

N_CASES = 20
cases = []
for _ in range(N_CASES):
    a0 = random.randrange(Q)
    a1 = random.randrange(Q)
    b0 = random.randrange(Q)
    b1 = random.randrange(Q)
    gamma = random.randrange(Q)
    c0, c1 = base_case_multiply(a0, a1, b0, b1, gamma)
    cases.append((a0, a1, b0, b1, gamma, c0, c1))

outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")
with open(os.path.join(outdir, "basecasemul_vectors.txt"), "w") as f:
    for (a0, a1, b0, b1, gamma, c0, c1) in cases:
        f.write(f"{a0} {a1} {b0} {b1} {gamma} {c0} {c1}\n")

print(f"{N_CASES} testitapausta generoitu")
print(f"Ensimmainen: a0={cases[0][0]} a1={cases[0][1]} b0={cases[0][2]} b1={cases[0][3]} gamma={cases[0][4]} -> c0={cases[0][5]} c1={cases[0][6]}")
