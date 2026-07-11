#!/usr/bin/env python3
"""M2 Vaihe 3a: MUODOLLINEN todistus (SAT/SMT, Z3), versio 2 - AIDOSTI
RIIPPUMATON aikataulun lahteesta.

Ero edelliseen versioon (bank_mapping_sat_proof.py): edellinen versio
kaytti simultaneous_pairs_for_level()-funktiota, joka on ERI Python-
koodi kuin todellinen RTL-aikataulu mutta SAMAN kirjoittajan kasin
uudelleenrakentama - ei aidosti riippumaton.

Tama versio lukee aikataulun SUORAAN vectors/full_schedule.txt ja
vectors/full_level6_zeta.txt -tiedostoista, jotka ovat ne TARKAT
tiedostot jotka jo ajoivat ja lapaisivat oikean, todennetun 2c-ii-
RTL-simulaation (tb/pqc_ntt_full_tb.sv). Jos taman version tulos
tasmaa edelliseen, se ei ole enaa sattumaa kahden samanlaisen
uudelleenkirjoituksen valilla - se on sidottu oikeasti ajettuun
laitteistoon.

HUOM: full_schedule.txt itsessaan on Python-generoitu
(gen_full_ntt_vectors.py, joka kayttaa ntt()-funktion silmukka-
rakennetta) - talla ei tavoitella talteista, kielirajat ylittavaa
riippumattomuutta (esim. C-referenssitoteutusta vasten), vaan
sitomista SIIHEN TARKKAAN aikatauluun jota oikea, simuloitu RTL
tosiasiassa suoritti - eri asia kuin taysin toisesta lahteesta
(esim. FIPS 203 -referenssikoodista) johdettu aikataulu olisi."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from z3 import Solver, Int, Distinct, sat, unsat

N = 256
NUM_BANKS = 4

VECTORS_DIR = os.path.join(os.path.dirname(__file__), "..", "vectors")


def load_quadruples_from_real_schedule():
    """Lukee TODELLISEN, jo ajetun RTL-aikataulun tiedostoista.
    Palauttaa listan (a0,b0,a1,b1) tai (a0,b0,None,None) taso 6:lle."""
    quads = []

    # --- Taso 6: erikoistapaus, sama kuin pqc_ntt_level6_2lane:n oma
    # kytkenta (base_addr_lane0=0, base_addr_lane1=64, count=64,
    # pair_dist=128) - luettu suoraan RTL-instansioinnista, ei arvattu ---
    for j in range(64):
        a0 = 0 + j
        b0 = a0 + 128
        a1 = 64 + j
        b1 = a1 + 128
        quads.append((a0, b0, a1, b1))

    # --- Tasot 5..0: luetaan SUORAAN full_schedule.txt:sta, joka on
    # sama tiedosto jota tb/pqc_ntt_full_tb.sv luki ja ajoi ---
    schedule_path = os.path.join(VECTORS_DIR, "full_schedule.txt")
    with open(schedule_path) as fh:
        for line in fh:
            parts = line.split()
            if len(parts) != 5:
                continue
            length, base0, _zeta0, base1, _zeta1 = map(int, parts)
            for j in range(length):
                a0 = base0 + j
                b0 = a0 + length
                a1 = base1 + j
                b1 = a1 + length
                quads.append((a0, b0, a1, b1))

    return quads


def build_and_solve(quads):
    s = Solver()
    bank = [Int(f"bank_{i}") for i in range(N)]
    for i in range(N):
        s.add(bank[i] >= 0, bank[i] < NUM_BANKS)
    for (a0, b0, a1, b1) in quads:
        s.add(Distinct(bank[a0], bank[b0], bank[a1], bank[b1]))
    return s.check(), s, bank


if __name__ == "__main__":
    quads = load_quadruples_from_real_schedule()
    print(f"Ladattu {len(quads)} nelikkoa SUORAAN todellisesta, ajetusta RTL-aikataulusta")
    print(f"(vectors/full_schedule.txt + level6-instansioinnin tunnetut osoitteet)")

    result, s, bank = build_and_solve(quads)
    print(f"Z3-tulos: {result}")

    if result == sat:
        m = s.model()
        solution = [m.evaluate(bank[i]).as_long() for i in range(N)]

        # Riippumaton brute force -uudelleentarkistus TALLA SAMALLA,
        # tiedostosta luetulla nelikkolistalla
        errors = 0
        for (a0, b0, a1, b1) in quads:
            vals = [solution[a0], solution[b0], solution[a1], solution[b1]]
            if len(set(vals)) != 4:
                errors += 1
        print(f"Brute force -uudelleenvarmennus (sama nelikkolista): {errors} virhetta")

        from collections import Counter
        dist = Counter(solution)
        print(f"Pankkien jakauma: {dict(dist)}")

        # Vertailu edelliseen (simultaneous_pairs_for_level -pohjaiseen) versioon
        try:
            from bank_mapping_sat_proof import build_and_solve as build_v1
            r1, s1 = build_v1()
            print(f"Vertailu: edellisen (v1, simultaneous_pairs_for_level) version tulos: {r1}")
            print("Molemmat versiot antavat saman SAT/UNSAT-tuloksen:", result == r1)
        except Exception as e:
            print(f"(Vertailua v1:een ei voitu tehda: {e})")
    else:
        print("UNSAT tiedostopohjaisella aikataululla - tama olisi ristiriidassa")
        print("aiemman v1-tuloksen kanssa, tutkittava tarkemmin.")
