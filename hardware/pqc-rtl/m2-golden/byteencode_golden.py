#!/usr/bin/env python3
"""M3 Issue #7: ByteEncode_d / ByteDecode_d, FIPS 203 Algoritmit 5/6
(+ apualgoritmit 3/4: BitsToBytes/BytesToBits), lopullinen teksti.

ERIKOISTAPAUS d=12: ByteDecode12 laskee 12-bittisen segmentin
kokonaisluvuksi mod 4096, sitten REDUSOI SEN VIELA modulo q=3329 -
tama EI ole 1-1-kuvaus (jotkut 12-bittiset arvot 3329..4095 kuvautuvat
pienemmiksi). d<12: kuvaus on 1-1, modulo 2^d."""

Q = 3329


def bits_to_bytes(b: list[int]) -> list[int]:
    """Algoritmi 3. b: bittitaulukko (pituus 8*ell). Palauttaa tavutaulukon."""
    ell = len(b) // 8
    B = [0] * ell
    for i in range(len(b)):
        B[i // 8] += b[i] * (2 ** (i % 8))
    return B


def bytes_to_bits(B: list[int]) -> list[int]:
    """Algoritmi 4. Kaanteinen operaatio."""
    ell = len(B)
    C = list(B)
    b = [0] * (8 * ell)
    for i in range(ell):
        for j in range(8):
            b[8 * i + j] = C[i] % 2
            C[i] //= 2
    return b


def byte_encode(d: int, F: list[int]) -> list[int]:
    """Algoritmi 5. F: 256 kokonaislukua mod m (m=2^d jos d<12, m=q jos d=12)."""
    b = [0] * (256 * d)
    for i in range(256):
        a = F[i]
        for j in range(d):
            b[i * d + j] = a % 2
            a = (a - b[i * d + j]) // 2
    return bits_to_bytes(b)


def byte_decode(d: int, B: list[int]) -> list[int]:
    """Algoritmi 6. Palauttaa 256 kokonaislukua mod m."""
    m = Q if d == 12 else (1 << d)
    b = bytes_to_bits(B)
    F = [0] * 256
    for i in range(256):
        val = 0
        for j in range(d):
            val += b[i * d + j] * (2 ** j)
        F[i] = val % m
    return F


if __name__ == "__main__":
    import random
    random.seed(2026)

    # Itsetarkistus ennen kayttoa: ByteDecode(ByteEncode(F)) == F kaikilla d<12
    # (d=12 EI ole 1-1, joten tata identiteettia ei testata sille - eri testi alla)
    ok = True
    for d in [1, 4, 5, 10, 11]:
        for trial in range(5):
            m = 1 << d
            F = [random.randrange(m) for _ in range(256)]
            B = byte_encode(d, F)
            F2 = byte_decode(d, B)
            if F != F2:
                print(f"FAIL d={d} trial={trial}: ByteDecode(ByteEncode(F)) != F")
                ok = False
    print(f"ByteDecode(ByteEncode(F))==F kaikilla d<12 (5 satunnaista/d): {'OK' if ok else 'FAIL'}")

    # d=12: F on mod q, ByteEncode12(F) -> ByteDecode12(...) pitaisi antaa F takaisin
    # KOSKA ByteEncode12:n TULO on jo valilla [0,q), joten segmentin arvo < q < 4096,
    # eika reduktio mod q vaikuta (ks. FIPS 203: "this cannot occur for arrays
    # produced by ByteEncode12")
    ok12 = True
    for trial in range(20):
        F = [random.randrange(Q) for _ in range(256)]
        B = byte_encode(12, F)
        F2 = byte_decode(12, B)
        if F != F2:
            print(f"FAIL d=12 trial={trial}")
            ok12 = False
    print(f"ByteDecode12(ByteEncode12(F))==F kaikilla F mod q (20 satunnaista): {'OK' if ok12 else 'FAIL'}")

    if not (ok and ok12):
        exit(1)
