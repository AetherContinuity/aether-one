#!/usr/bin/env python3
"""M3 Issue #15: SamplePolyCBD (FIPS 203 Algoritmi 8), Python golden-
malli. Tarkistettu FIPS 203:n lopullisesta tekstista.

Algoritmi 8 (tarkka, rivi riviltä):
1: b <- BytesToBits(B)
2: for (i <- 0; i < 256; i++)
3:   x <- sum_{j=0}^{eta-1} b[2*i*eta+j]
4:   y <- sum_{j=0}^{eta-1} b[2*i*eta+eta+j]
5:   f[i] <- x - y mod q
6: return f

Syote: B, 64*eta tavua (eta=2: 128 tavua, eta=3: 192 tavua).
Ulostulo: f, 256 kerrointa mod q.

Kayttaa jo todennettua bytes_to_bits-funktiota (byteencode_golden.py,
Algoritmi 4 - sama BytesToBits kuin ByteEncode/Decodessa, FIPS 203:n
oma yhteinen apufunktio)."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from byteencode_golden import bytes_to_bits

Q = 3329


def sample_poly_cbd(B: bytes, eta: int, instrument: bool = False):
    assert len(B) == 64 * eta, f"B:n pituus vaarin: {len(B)}, odotettu {64*eta}"
    b = bytes_to_bits(list(B))

    f = [0] * 256
    for i in range(256):
        x = sum(b[2 * i * eta + j] for j in range(eta))
        y = sum(b[2 * i * eta + eta + j] for j in range(eta))
        f[i] = (x - y) % Q

    if instrument:
        # Tilastollinen tarkistus: kaikki arvot pitaisi olla valilla
        # [0,eta] tai [q-eta, q-1] (keskitetyn binomijakauman oma
        # ominaisuus - taman TAYTYY patea joka ikiselle kertoimelle)
        valid_range = all(0 <= x <= eta or (Q - eta) <= x <= Q - 1 for x in f)
        info = {
            "num_coefficients": 256,
            "input_bits_consumed": 512 * eta,
            "all_in_valid_cbd_range": valid_range,
        }
        return f, info
    return f


if __name__ == "__main__":
    import random
    random.seed(2026)

    print("=== Perustoiminnallisuuden ja jakauman rajojen tarkistus ===")
    for eta in [2, 3]:
        for trial in range(10):
            B = bytes(random.randrange(256) for _ in range(64 * eta))
            f, info = sample_poly_cbd(B, eta, instrument=True)
            assert info["all_in_valid_cbd_range"], f"eta={eta} trial={trial}: arvo CBD-rajojen ulkopuolella!"
            assert all(0 <= x < Q for x in f), f"eta={eta} trial={trial}: arvo >= Q!"
        print(f"eta={eta}: 10 satunnaista testitapausta OK, kaikki arvot CBD-jakauman rajoissa "
              f"([0,{eta}] tai [{Q-eta},{Q-1}])")

    print()
    print("=== Kasin laskettu tarkistus (eta=2, kaikki bitit=0 -> f=0 kaikkialla) ===")
    B_zero = bytes(64 * 2)
    f_zero = sample_poly_cbd(B_zero, 2)
    assert all(x == 0 for x in f_zero), "VIRHE: kaikki-nolla-syote ei antanut kaikki-nolla-tulosta!"
    print("OK: B=kaikki nollat -> f=kaikki nollat (x=0,y=0 jokaiselle kertoimelle)")

    print()
    print("=== Kasin laskettu tarkistus (eta=2, kaikki bitit=1 -> x=y=eta -> f=0) ===")
    B_ones = bytes([0xFF] * (64 * 2))
    f_ones = sample_poly_cbd(B_ones, 2)
    assert all(x == 0 for x in f_ones), "VIRHE: kaikki-yksi-syote ei antanut kaikki-nolla-tulosta (x-y=eta-eta=0)!"
    print("OK: B=kaikki ykkoset -> f=kaikki nollat (x=eta,y=eta, x-y=0 jokaiselle kertoimelle)")

    print()
    print("KAIKKI TARKISTUKSET OK")
