#!/usr/bin/env python3
"""M2 Vaihe 3a: MUODOLLINEN todistus (SAT/SMT, Z3) sille onko olemassa
tasoriippumaton kuvaus bank: {0..255} -> {0,1,2,3} joka on konfliktiton
kaikilla seitsemalla NTT-tasolla, tasmalleen samalla 2-lane-aikataululla
jota RTL kayttaa (M2 Vaihe 2c-ii, ks. bank_mapping_search.py:n
simultaneous_pairs_for_level - sama funktio, ei uudelleenkirjoitettu
logiikka).

Vaite testattavaksi:
"Ei ole olemassa tasoriippumatonta kuvausfunktiota bank(),
joka tayttaa konfliktittomuusehdot kaikilla seitsemalla NTT-tasolla
annetulla 2-lane-aikataululla."

Jos Z3 palauttaa UNSAT: vaite on TOSI (todistettu, ei vain havaittu
nelja epaonnistunutta ehdokasta).
Jos Z3 palauttaa SAT: vaite on EPATOSI - loytyy vastaesimerkki
(konkreettinen toimiva kuvaus), joka nayttaa taman."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from bank_mapping_search import simultaneous_pairs_for_level, LEVELS, N, NUM_BANKS

from z3 import Solver, Int, Distinct, sat, unsat

def build_and_solve():
    s = Solver()
    bank = [Int(f"bank_{i}") for i in range(N)]

    # Jokainen bank(addr) valilla [0, NUM_BANKS)
    for i in range(N):
        s.add(bank[i] >= 0, bank[i] < NUM_BANKS)

    total_constraints = 0
    for length in LEVELS:
        pairs = simultaneous_pairs_for_level(length)
        for (a0, b0, a1, b1) in pairs:
            if a1 is None:
                # Taso 6: vain kaksi osoitetta samanaikaisesti (yksi ryhma,
                # molemmat lanet SAMASSA ryhmassa - eri butterfly-indeksi j,
                # ei eri ryhma). Tama taso kasitellaan omalla moduulillaan
                # RTL:ssa (level6_2lane) - sen oma vaatimus on vain etta
                # a0 ja b0 eroavat, koska molemmat lanet KAYTTAVAT SAMAA
                # ryhmaa mutta eri j:ta - ks. huomautus alla.
                s.add(Distinct(bank[a0], bank[b0]))
            else:
                s.add(Distinct(bank[a0], bank[b0], bank[a1], bank[b1]))
            total_constraints += 1

    print(f"Yhteensa {total_constraints} rajoitetta (kaikki 7 tasoa, N={N} osoitetta, {NUM_BANKS} pankkia)")
    result = s.check()
    return result, s

if __name__ == "__main__":
    result, s = build_and_solve()
    print(f"Z3-tulos: {result}")
    if result == sat:
        print("VAITE EPATOSI - loytyi vastaesimerkki (toimiva kiintea kuvaus):")
        m = s.model()
        example = [m.evaluate(Int(f"bank_{i}")).as_long() for i in range(256)]
        print(example[:32], "...")
    elif result == unsat:
        print("VAITE TOSI (UNSAT, muodollisesti todistettu):")
        print("Ei ole olemassa tasoriippumatonta 4-pankkista kuvausta joka on")
        print("konfliktiton kaikilla seitsemalla NTT-tasolla tallä 2-lane-")
        print("aikataululla.")
