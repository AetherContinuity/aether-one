#!/usr/bin/env python3
"""M2 Vaihe 2b: testivektorit yhdelle NTT-tasolle (taso 6, length=128).
Kayttaa m2-golden/kyber_ntt_golden.py:n ntt_level6_only()-funktiota,
joka on itse jo ristiintarkistettu taydelliseen ntt()-funktioon
(ks. kyber_ntt_golden.py:n oma testiajo)."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from kyber_ntt_golden import ntt_level6_only, Q

import random
random.seed(2026)

f = [random.randrange(Q) for _ in range(256)]
expect, zeta = ntt_level6_only(f)

# Montgomery-esiskaalaus RTL:lle syotettavaa zeta-arvoa varten.
# RTL:n montgomery_reduce (KORJATTU 2026-07-10, tasmaa pq-crystals/kyber
# ref/reduce.c:hen) laskee a*R^-1 mod Q oikein, joten standardi
# esiskaalaus zeta_mont = zeta*R mod Q riittaa (ei tarvitse negaatiota).
R = 65536
zeta_mont = (zeta * R) % Q

def write_memh(path, words):
    with open(path, "w") as fh:
        for w in words:
            fh.write(f"{w & 0xFFFF:04x}\n")

outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")
write_memh(os.path.join(outdir, "level6_init.memh"), f)
write_memh(os.path.join(outdir, "level6_expect.memh"), expect)
# tw_window: sama zeta_mont joka indeksissa 0..63 (taso 6:lla on vain 1 zeta,
# esiskaalattu Montgomery-domainiin RTL:aa varten)
write_memh(os.path.join(outdir, "level6_twiddles.memh"), [zeta_mont] * 64)

print(f"Taso 6 zeta (FIPS 203): {zeta}, esiskaalattu RTL:lle: {zeta_mont}")
print(f"f[0]={f[0]} f[128]={f[128]} -> ({expect[0]}, {expect[128]})")
print(f"f[63]={f[63]} f[191]={f[191]} -> ({expect[63]}, {expect[191]})")
