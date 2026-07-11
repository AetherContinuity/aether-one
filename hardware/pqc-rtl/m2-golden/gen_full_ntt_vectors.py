#!/usr/bin/env python3
"""M2 Vaihe 2c-ii: koko 7-tasoinen Kyber-NTT RTL:ssa.

Generoi TARKAN aikataulun (taso, ryhmapari, osoitteet, zetat) suoraan
samasta silmukkarakenteesta jota jo todennettu ntt()-funktio kayttaa -
ei erillista, kasin johdettua osoite/zeta-logiikkaa RTL-puolella, jotta
kaksi kielta eivat voi laskea samaa asiaa hienovaraisesti eri tavalla.

Taso 6 (length=128, 1 ryhma, PARITON): ajetaan olemassa olevalla,
jo todennetulla pqc_ntt_level6_2lane-moduulilla (ei muuteta).
Tasot 5..0 (length=64..2, kaikki PARILLISET ryhmamaarat): ajetaan
pqc_ntt_stage_2lane-moduulilla toistuvasti, 2 ryhmaa kerrallaan
(yksi per lane)."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from kyber_ntt_golden import Q, ZETA, bitrev7, ntt

import random
random.seed(2026)

R = 65536

def mont(z):
    return (z * R) % Q

f = [random.randrange(Q) for _ in range(256)]
expect = ntt(f)  # koko 7-tasoinen, jo aiemmin riippumattomasti todennettu

# Rakennetaan aikataulu TASMALLEEN samalla silmukkarakenteella kuin ntt()
schedule = []  # lista: (length, group_start_addrs=[...], zetas=[...])
k = 1
length = 128
while length >= 2:
    groups = []
    start = 0
    while start < 256:
        zeta = pow(ZETA, bitrev7(k), Q)
        k += 1
        groups.append((start, zeta))
        start += 2 * length
    schedule.append((length, groups))
    length //= 2

def write_memh(path, words):
    with open(path, "w") as fh:
        for w in words:
            fh.write(f"{w & 0xFFFF:04x}\n")

outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")
write_memh(os.path.join(outdir, "full_init.memh"), f)
write_memh(os.path.join(outdir, "full_expect.memh"), expect)

# Kirjoita aikataulu tekstitiedostoon testipenkin luettavaksi:
# rivi per (taso, ryhmapari): length, base0, zeta0_mont, base1, zeta1_mont
# (base1/zeta1 = -1 jos ryhmaa ei ole, esim. taso 6:n YKSI ryhma - ei kayteta
# talla tiedostolla, taso 6 ajetaan erikseen level6-moduulilla)
with open(os.path.join(outdir, "full_schedule.txt"), "w") as fh:
    for length, groups in schedule:
        if length == 128:
            continue  # taso 6 ajetaan erikseen pqc_ntt_level6_2lane:lla
        for i in range(0, len(groups), 2):
            start0, zeta0 = groups[i]
            start1, zeta1 = groups[i + 1]
            fh.write(f"{length} {start0} {mont(zeta0)} {start1} {mont(zeta1)}\n")

# Taso 6:n oma zeta erikseen (level6-moduulia varten)
level6_length, level6_groups = schedule[0]
assert level6_length == 128 and len(level6_groups) == 1
level6_zeta = level6_groups[0][1]
with open(os.path.join(outdir, "full_level6_zeta.txt"), "w") as fh:
    fh.write(f"{mont(level6_zeta)}\n")

total_pairs = sum(len(g) // 2 for l, g in schedule if l != 128)
print(f"Taso 6: 1 ryhma (oma moduuli). Tasot 5..0: {total_pairs} ryhmaparia yhteensa.")
print(f"Odotettu NTT-tulos (ensimmaiset 4 sanaa): {expect[:4]}")
