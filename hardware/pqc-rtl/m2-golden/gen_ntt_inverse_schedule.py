#!/usr/bin/env python3
"""M3 Issue #8, Vaihe 3: NTT^-1:n aikataulu. Sama periaate kuin
gen_full_ntt_vectors.py (eteenpain-NTT), mutta KAANTEISESSA
jarjestyksessa (len: 2->128, zeta-indeksi k: 127->1 vaheneva) - FIPS
203 Algoritmi 10:n oma silmukkarakenne, EI mielivaltainen kaannos.

Aikataulu on DATA-RIIPPUMATON (sama kuin eteenpain-NTT:lla) - riippuu
vain tasorakenteesta, ei laskettavasta datasta."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from kyber_ntt_golden import Q, ZETA, bitrev7

R = 65536


def mont(z):
    return (z * R) % Q


outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")

# Rakennetaan aikataulu TASMALLEEN ntt_inv():n omalla silmukkarakenteella
k = 127
length = 2
schedule = []
while length <= 128:
    groups = []
    start = 0
    while start < 256:
        zeta = pow(ZETA, bitrev7(k), Q)
        k -= 1
        groups.append((start, zeta))
        start += 2 * length
    schedule.append((length, groups))
    length *= 2

with open(os.path.join(outdir, "ntt_inverse_schedule.txt"), "w") as fh:
    for length, groups in schedule:
        if length == 128:
            continue  # taso 6 (1 ryhma) ajetaan erikseen, sama periaate kuin eteenpain-NTT:lla
        for i in range(0, len(groups), 2):
            start0, zeta0 = groups[i]
            start1, zeta1 = groups[i + 1]
            fh.write(f"{length} {start0} {mont(zeta0)} {start1} {mont(zeta1)}\n")

level6_length, level6_groups = schedule[-1]
assert level6_length == 128 and len(level6_groups) == 1
level6_zeta = level6_groups[0][1]
with open(os.path.join(outdir, "ntt_inverse_level6_zeta.txt"), "w") as fh:
    fh.write(f"{mont(level6_zeta)}\n")

total_pairs = sum(len(g) // 2 for l, g in schedule if l != 128)
print(f"NTT^-1-aikataulu: {total_pairs} ryhmaparia (tasot 0..5) + taso 6 erikseen")
print(f"Ensimmainen zeta-indeksi k=127 (taso 0), viimeinen k=1 (taso 6, ennen final_scalea)")
