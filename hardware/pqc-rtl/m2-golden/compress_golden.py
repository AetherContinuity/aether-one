#!/usr/bin/env python3
"""M3 Issue #6: Compress_d / Decompress_d, FIPS 203 Section 4.2.1 (kaavat
4.7/4.8), lopullinen teksti (ei .ipd-luonnos - luonnoksessa oli
dokumentoitu epaselvyys reunatapauksissa, ks. M3_DESIGN_NOTE.md).

Pyoristys: FIPS 203:n oma round-half-up-maaritelma (jos x=y+1/2, tulos
on y+1). Kokonaislukumuotoinen kaava (ei liukulukua, FIPS 203 vaatii
taman eksplisiittisesti):
  Compress_d(x)   = floor((x*2^d + q//2) / q) mod 2^d
  Decompress_d(y)  = floor((y*q + 2^(d-1)) / 2^d)

Vahvistettu FIPS 203:n oman ominaisuuden kautta ennen kayttoa:
Compress_d(Decompress_d(y)) == y kaikilla y, kaikilla d<12."""

Q = 3329


def compress(d: int, x: int) -> int:
    two_d = 1 << d
    return ((x * two_d + Q // 2) // Q) % two_d


def decompress(d: int, y: int) -> int:
    two_d = 1 << d
    return (y * Q + two_d // 2) // two_d


if __name__ == "__main__":
    # Riippumaton itsetarkistus ennen vektorien generointia: FIPS 203:n
    # oma dokumentoitu ominaisuus, kaikilla d<12 ja kaikilla y.
    for d in range(1, 12):
        for y in range(1 << d):
            assert compress(d, decompress(d, y)) == y, f"FAIL d={d} y={y}"
    print("OK: Compress(Decompress(y))==y kaikilla d=1..11, kaikilla y - FIPS 203:n oma ominaisuus vahvistettu")
