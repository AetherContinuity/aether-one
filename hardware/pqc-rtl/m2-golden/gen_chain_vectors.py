#!/usr/bin/env python3
"""M2 Vaihe 2c-i: testivektorit taso6->taso5-ketjulle (yksi muisti,
kaksi peräkkäistä RTL-ajoa)."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from kyber_ntt_golden import ntt_level6_only, ntt_level5_only, Q

import random
random.seed(2026)

R = 65536

f = [random.randrange(Q) for _ in range(256)]
after_l6, zeta6 = ntt_level6_only(f)
after_l5, zeta5_g0, zeta5_g1 = ntt_level5_only(after_l6)

def mont(z):
    return (z * R) % Q

def write_memh(path, words):
    with open(path, "w") as fh:
        for w in words:
            fh.write(f"{w & 0xFFFF:04x}\n")

outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")
write_memh(os.path.join(outdir, "chain_init.memh"), f)
write_memh(os.path.join(outdir, "chain_after_l6.memh"), after_l6)  # valitarkistusta varten
write_memh(os.path.join(outdir, "chain_final.memh"), after_l5)

with open(os.path.join(outdir, "chain_zetas.txt"), "w") as fh:
    fh.write(f"{mont(zeta6)}\n")      # taso 6, molemmat lanet
    fh.write(f"{mont(zeta5_g0)}\n")   # taso 5, lane0 (ryhma 0)
    fh.write(f"{mont(zeta5_g1)}\n")   # taso 5, lane1 (ryhma 1)

print(f"zeta6={zeta6} (mont={mont(zeta6)})")
print(f"zeta5_g0={zeta5_g0} (mont={mont(zeta5_g0)}), zeta5_g1={zeta5_g1} (mont={mont(zeta5_g1)})")
