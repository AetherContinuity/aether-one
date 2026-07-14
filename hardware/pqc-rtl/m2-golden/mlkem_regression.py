#!/usr/bin/env python3
"""M3 Release Candidate, Vaihe 1: koko ML-KEM:n (d,z,m) -> KeyGen ->
Encaps -> Decaps -> K_alice==K_bob -paastapaahan-regressio N
satunnaisella syotteella + jokaisen c:n bitin korruptointi + FO-
hylkayksen varmistus.

TAMA ON GOLDEN-MALLIN OMA REGRESSIO (Python), EI RTL:aa - nopea,
ei tyokaluriskeja (Icarus Verilogin oma segmentointivirhe suurilla
yhdistetyilla RTL-testeilla, ks. ML-KEM_PIPELINE.md). RTL-tasolla
sama laajuus katetaan jo erikseen (KeyGen/Encaps/Decaps TB A+B) -
tama regressio varmistaa ETTA ITSE ALGORITMI (ei RTL-toteutus) on
oikein LAAJALLA syotejoukolla, taydentaen RTL:n oman, suppeamman
mutta syvemman todennuksen."""

import sys
import os
import random
sys.path.insert(0, os.path.dirname(__file__))
from mlkem_golden import mlkem_keygen_internal, mlkem_encaps_internal, mlkem_decaps_internal
from keccak_golden import shake256

K_dim, ETA1, ETA2, DU, DV = 2, 3, 2, 10, 4


def run_regression(n_trials=100, seed=2026):
    random.seed(seed)
    failures = []

    for trial in range(n_trials):
        d = bytes(random.randrange(256) for _ in range(32))
        z = bytes(random.randrange(256) for _ in range(32))
        m = bytes(random.randrange(256) for _ in range(32))

        ek, dk = mlkem_keygen_internal(d, z, K_dim, ETA1)
        K_bob, c = mlkem_encaps_internal(ek, m, K_dim, ETA1, ETA2, DU, DV)
        K_alice = mlkem_decaps_internal(dk, c, K_dim, ETA1, ETA2, DU, DV)

        if K_alice != K_bob:
            failures.append((trial, "normaali polku: K_alice != K_bob", d.hex(), z.hex(), m.hex()))
            continue

        # Korruptoi YKSI satunnainen bitti c:ssa, varmista FO-hylkays
        bit_pos = random.randrange(len(c) * 8)
        byte_idx, bit_idx = divmod(bit_pos, 8)
        c_corrupted = bytearray(c)
        c_corrupted[byte_idx] ^= (1 << bit_idx)
        c_corrupted = bytes(c_corrupted)

        K_alice_corrupted = mlkem_decaps_internal(dk, c_corrupted, K_dim, ETA1, ETA2, DU, DV)

        dkPKE_dummy = dk[0:384 * K_dim]
        z_from_dk = dk[768 * K_dim + 64:768 * K_dim + 96]
        K_bar_expect = shake256(z_from_dk + c_corrupted, 32)

        if K_alice_corrupted != K_bar_expect:
            failures.append((trial, "FO-hylkays: ei anna J(z||c_corrupted):ta", d.hex(), z.hex(), m.hex()))
            continue
        if K_alice_corrupted == K_bob:
            failures.append((trial, "FO-hylkays: K_alice_corrupted == alkuperainen K_bob (EI PITAISI)", d.hex(), z.hex(), m.hex()))
            continue

    return failures, n_trials


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 100
    print(f"Ajetaan {n} satunnaista (d,z,m)-testitapausta...")
    failures, total = run_regression(n_trials=n)

    if not failures:
        print(f"PASS: kaikki {total} testitapausta lapaisivat (normaali polku + bitin-hylkays jokaiselle)")
    else:
        print(f"FAIL: {len(failures)}/{total} testitapausta epaonnistuivat:")
        for trial, reason, d_hex, z_hex, m_hex in failures:
            print(f"  Trial {trial}: {reason}")
            print(f"    d={d_hex}, z={z_hex}, m={m_hex}")
        sys.exit(1)
