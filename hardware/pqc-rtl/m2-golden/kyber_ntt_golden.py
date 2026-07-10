#!/usr/bin/env python3
"""M2 Vaihe 2a — Python-golden-malli: Kyberin/ML-KEM:n oikea NTT + BaseCaseMultiply.

Toteuttaa FIPS 203:n Algoritmit 9 (NTT), 10 (NTT^-1), ja BaseCaseMultiply
tarkalleen sellaisina kuin standardi ne maarittelee (ks. M2_DESIGN_NOTE.md).

RIIPPUMATON TODENNUS (ei vain sisainen johdonmukaisuus):
Konvoluutiolause: INTT(NTT(a) o NTT(b)) taytyy tasmata suoraan laskettuun
negasykliseen konvoluutioon a*b mod (X^256+1), laskettuna KOULUKIRJA-
menetelmalla ilman NTT:ta ollenkaan. Jos NTT/INTT/BaseCaseMultiply
sisaltavat saman virheen molemmissa suunnissa, sisainen NTT(INTT(x))==x
-testi voisi silti lapaista virheellisena - koulukirjavertailu ei voi
tehda tata virhetta koska se ei kaytä NTT:ta lainkaan.
"""

Q = 3329
N = 256
ZETA = 17  # primitiivinen 256. yksikonjuuri mod Q, FIPS 203


def bitrev7(i: int) -> int:
    """7-bittinen bitin kaanto (i in 0..127)."""
    r = 0
    for b in range(7):
        r |= ((i >> b) & 1) << (6 - b)
    return r


def ntt(f: list[int]) -> list[int]:
    """FIPS 203 Algoritmi 9. Muuttaa listan paikallaan (kopio palautetaan)."""
    f = list(f)
    k = 1
    length = 128
    while length >= 2:
        start = 0
        while start < N:
            zeta = pow(ZETA, bitrev7(k), Q)
            k += 1
            for j in range(start, start + length):
                t = (zeta * f[j + length]) % Q
                f[j + length] = (f[j] - t) % Q
                f[j] = (f[j] + t) % Q
            start += 2 * length
        length //= 2
    return f


def ntt_inv(f_hat: list[int]) -> list[int]:
    """FIPS 203 Algoritmi 10."""
    f = list(f_hat)
    k = 127
    length = 2
    while length <= 128:
        start = 0
        while start < N:
            zeta = pow(ZETA, bitrev7(k), Q)
            k -= 1
            for j in range(start, start + length):
                t = f[j]
                f[j] = (t + f[j + length]) % Q
                f[j + length] = (zeta * (f[j + length] - t)) % Q
            start += 2 * length
        length *= 2
    n_inv = pow(N // 2, Q - 2, Q)  # 128^{-1} mod Q (Fermat, Q on alkuluku)
    return [(x * n_inv) % Q for x in f]


def base_case_multiply(a0: int, a1: int, b0: int, b1: int, gamma: int):
    """FIPS 203: (a0+a1*X)*(b0+b1*X) mod (X^2-gamma)."""
    c0 = (a0 * b0 + a1 * b1 * gamma) % Q
    c1 = (a0 * b1 + a1 * b0) % Q
    return c0, c1


def multiply_ntts(f_hat: list[int], g_hat: list[int]) -> list[int]:
    """Pistetulo NTT-alueessa, kayttaen BaseCaseMultiply per 128 paria."""
    h_hat = [0] * N
    for i in range(128):
        gamma = pow(ZETA, 2 * bitrev7(i) + 1, Q)
        c0, c1 = base_case_multiply(
            f_hat[2 * i], f_hat[2 * i + 1],
            g_hat[2 * i], g_hat[2 * i + 1],
            gamma
        )
        h_hat[2 * i] = c0
        h_hat[2 * i + 1] = c1
    return h_hat


def negacyclic_convolution(a: list[int], b: list[int]) -> list[int]:
    """RIIPPUMATON tarkistus: suora koulukirja-negasyklinen konvoluutio
    mod (X^256+1), EI KAYTA NTT:ta ollenkaan. O(n^2), hidas mutta
    tarkoituksella yksinkertainen jotta virhe ei voi piiloutua tanne."""
    h = [0] * N
    for i in range(N):
        if a[i] == 0:
            continue
        for j in range(N):
            if b[j] == 0:
                continue
            idx = i + j
            val = (a[i] * b[j]) % Q
            if idx >= N:
                idx -= N
                val = (-val) % Q  # X^256 = -1
            h[idx] = (h[idx] + val) % Q
    return h


if __name__ == "__main__":
    import random
    random.seed(2026)

    errors = 0

    # --- Testi 1: NTT^-1(NTT(f)) == f (round-trip identiteetti) ---
    for trial in range(5):
        f = [random.randrange(Q) for _ in range(N)]
        f_rt = ntt_inv(ntt(f))
        if f_rt != f:
            print(f"FAIL (round-trip, trial {trial}): NTT^-1(NTT(f)) != f")
            for i in range(N):
                if f_rt[i] != f[i]:
                    print(f"  index {i}: {f_rt[i]} != {f[i]}")
                    break
            errors += 1
    if errors == 0:
        print("OK: NTT^-1(NTT(f)) == f, 5/5 satunnaista polynomia")

    # --- Testi 2: KONVOLUUTIOLAUSE (riippumaton, ei kayta NTT:ta molemmin puolin) ---
    conv_errors = 0
    for trial in range(5):
        a = [random.randrange(Q) for _ in range(N)]
        b = [random.randrange(Q) for _ in range(N)]

        # Reitti A: NTT-pohjainen
        a_hat = ntt(a)
        b_hat = ntt(b)
        h_hat = multiply_ntts(a_hat, b_hat)
        h_via_ntt = ntt_inv(h_hat)

        # Reitti B: suora koulukirja-konvoluutio, EI NTT:ta
        h_direct = negacyclic_convolution(a, b)

        if h_via_ntt != h_direct:
            print(f"FAIL (convolution theorem, trial {trial}): NTT-reitti != suora konvoluutio")
            for i in range(N):
                if h_via_ntt[i] != h_direct[i]:
                    print(f"  index {i}: NTT-reitti={h_via_ntt[i]}, suora={h_direct[i]}")
            conv_errors += 1
    if conv_errors == 0:
        print("OK: INTT(NTT(a) o NTT(b)) == suora negasyklinen konvoluutio, 5/5 satunnaista paria")
    errors += conv_errors

    # --- NEGATIIVIKONTROLLI: tahallaan rikottu BaseCaseMultiply (vaara etumerkki gammalle) ---
    a = [random.randrange(Q) for _ in range(N)]
    b = [random.randrange(Q) for _ in range(N)]
    a_hat = ntt(a)
    b_hat = ntt(b)

    def broken_multiply_ntts(f_hat, g_hat):
        h_hat = [0] * N
        for i in range(128):
            gamma = pow(ZETA, 2 * bitrev7(i) + 1, Q)
            # TAHALLINEN VIRHE: vaara etumerkki gammalle (kuin sekoittaisi
            # Dilithiumin ja Kyberin gamma-konvention)
            c0 = (a_hat[2*i] * b_hat[2*i] - a_hat[2*i+1] * b_hat[2*i+1] * gamma) % Q
            c1 = (a_hat[2*i] * b_hat[2*i+1] + a_hat[2*i+1] * b_hat[2*i]) % Q
            h_hat[2*i], h_hat[2*i+1] = c0, c1
        return h_hat

    h_broken = ntt_inv(broken_multiply_ntts(a_hat, b_hat))
    h_direct = negacyclic_convolution(a, b)
    if h_broken == h_direct:
        print("FAIL: rikottu BaseCaseMultiply tuotti silti oikean tuloksen - negatiivikontrolli ei toimi")
        errors += 1
    else:
        diffs = sum(1 for i in range(N) if h_broken[i] != h_direct[i])
        print(f"OK: rikottu BaseCaseMultiply tuottaa VAARAN tuloksen ({diffs}/256 sanaa eroaa) - negatiivikontrolli toimii")

    print("--------------------------------------------------")
    if errors == 0:
        print("PASS: kaikki testit lapaisivat")
    else:
        print(f"FAIL: {errors} testijoukkoa epaonnistui")
        exit(1)
