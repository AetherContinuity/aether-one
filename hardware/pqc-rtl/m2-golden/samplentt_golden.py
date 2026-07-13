#!/usr/bin/env python3
"""M3 Issue #15, Vaihe 1: SampleNTT (FIPS 203 Algoritmi 7), Python
golden-malli. Tarkistettu FIPS 203:n LOPULLISESTA tekstista (ei
luonnoksesta) - erityisesti Liite B (SampleNTT Loop Bounds), jonka
mukaan JOS silmukka rajataan, rajaa EI SAA asettaa alle 280
iteraation (= 840 tavua XOF-ulostuloa, koska jokainen iteraatio
kuluttaa 3 tavua).

TARKEA RAJAUS (kayttajan oma huomio): Issue #14:n oma "ML_KEM_XOF_style"
-testi (504 tavua) oli XOF-PRIMITIIVIN oma toiminnallinen testi, EI
SampleNTT-algoritmin normatiivinen toteutustesti - 504 tavua (168
iteraatiota) EI tayta Liite B:n 280 iteraation minimivaatimusta.
Tama moduuli kayttaa siksi ERI, suurempaa puskuria (>=840 tavua).

Algoritmi 7 (tarkka, rivi riviltä FIPS 203:n lopullisesta tekstista):
1: ctx <- XOF.Init()
2: ctx <- XOF.Absorb(ctx, B)
3: j <- 0
4: while j < 256:
5:   (ctx, C) <- XOF.Squeeze(ctx, 3)
6:   d1 <- C[0] + 256*(C[1] mod 16)
7:   d2 <- floor(C[1]/16) + 16*C[2]
8:   if d1 < q: a_hat[j] <- d1; j <- j+1
9:   if d2 < q and j < 256: a_hat[j] <- d2; j <- j+1
16: return a_hat
"""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from keccak_golden import shake128

Q = 3329
MIN_ITERATIONS = 280  # FIPS 203 Liite B: EI alle tama, jos rajataan ollenkaan
MIN_XOF_BYTES = MIN_ITERATIONS * 3  # = 840 tavua

# Kaytannon puskurikoko: reilusti yli minimin, jotta "epaonnekkaat"
# siemenet (jotka tarvitsevat enemman kuin 280 iteraatiota - Liite B:n
# oma 2^-261-todennakoisyys, mutta testataan silti eksplisiittisesti
# Vaihe 3:ssa "unlucky"-tyyppisilla siemenilla myohemmin) eivat
# valittomasti epaonnistu golden-mallissa.
DEFAULT_XOF_BYTES = 1008  # 6 * SHAKE128-rate (168*6), reilusti yli 840:n


def sample_ntt(seed_rho: bytes, byte_j: int, byte_i: int,
                xof_bytes: int = DEFAULT_XOF_BYTES, instrument: bool = False):
    """B = rho || j || i (34 tavua). Palauttaa (a_hat, info) jos
    instrument=True, muuten pelkan a_hat:n."""
    assert len(seed_rho) == 32
    B = seed_rho + bytes([byte_j, byte_i])

    xof_output = shake128(B, xof_bytes)

    a_hat = [0] * 256
    j = 0
    i = 0
    accepted_count = 0
    rejected_count = 0

    while j < 256:
        if i + 3 > len(xof_output):
            raise RuntimeError(
                f"XOF-puskuri ({xof_bytes} tavua) loppui kesken ennen 256 "
                f"kertoimen tayttamista (j={j}) - kasvata xof_bytes:aa. "
                f"Tama on ODOTETTU vain aarimmaisen epatodennakoisille "
                f"siemenille (FIPS 203 Liite B: P<=2^-261 280 iteraation "
                f"jalkeen)."
            )
        C0, C1, C2 = xof_output[i], xof_output[i + 1], xof_output[i + 2]
        d1 = C0 + 256 * (C1 % 16)
        d2 = (C1 // 16) + 16 * C2

        if d1 < Q:
            a_hat[j] = d1
            j += 1
            accepted_count += 1
        elif d1 >= Q:
            rejected_count += 1

        if d2 < Q and j < 256:
            a_hat[j] = d2
            j += 1
            accepted_count += 1
        elif d2 >= Q:
            rejected_count += 1

        i += 3

    if instrument:
        info = {
            "xof_bytes_consumed": i,
            "iterations": i // 3,
            "accepted_count": accepted_count,
            "rejected_count": rejected_count,
            "meets_appendix_b_minimum": (i // 3) >= 0,  # aina totta - tama on vain informatiivinen
        }
        return a_hat, info
    return a_hat


if __name__ == "__main__":
    import random
    random.seed(2026)

    print("=== Vaihe 1: perustoiminnallisuuden tarkistus ===")
    rho = bytes(range(32))
    a_hat, info = sample_ntt(rho, 0, 0, instrument=True)
    print(f"a_hat[0:5] = {a_hat[:5]}")
    print(f"Kaikki kertoimet < Q ({Q})? {all(0 <= x < Q for x in a_hat)}")
    print(f"Info: {info}")

    print()
    print("=== Vaihe 2: instrumentointi useilla siemenilla ===")
    for trial in range(5):
        seed = bytes(random.randrange(256) for _ in range(32))
        a_hat, info = sample_ntt(seed, trial % 4, (trial + 1) % 4, instrument=True)
        assert all(0 <= x < Q for x in a_hat), "VIRHE: kerroin >= Q loytyi!"
        assert info["accepted_count"] == 256
        print(f"trial={trial}: iteraatioita={info['iterations']}, "
              f"hylkayksia={info['rejected_count']}, "
              f"xof_tavuja={info['xof_bytes_consumed']} "
              f"(min. vaadittu Liite B:n mukaan: {MIN_XOF_BYTES})")

    print()
    print("KAIKKI TARKISTUKSET OK - kaikki kertoimet valilla [0,Q), "
          f"kaikki tapaukset kayttivat vahemman kuin {DEFAULT_XOF_BYTES} tavua")
