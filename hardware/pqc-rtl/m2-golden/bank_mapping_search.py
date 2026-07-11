#!/usr/bin/env python3
"""M2 Vaihe 3a: pankkikuvauksen todennus, 4 pankkia, 256 osoitetta,
7 NTT-tasoa. Taydellinen brute force - ei satunnaistestausta.

Todistettavat ominaisuudet KAIKILLE 7 tasolle:
1. Konfliktittomuus: jokaisella tasolla, jokaisella samanaikaisesti
   luetulla/kirjoitetulla osoiteparilla (lane0: a0,b0; lane1: a1,b1),
   nama NELJA osoitetta eivat koskaan jaa samaa pankkia.
2. Bijektiivisyys: kuvaus osoite -> (pankki, paikallinen_osoite) on
   1-yhteen koko 256 osoitteen yli (ei aliasointia, ei katoamista).
"""

N = 256
NUM_BANKS = 4
LEVELS = [128, 64, 32, 16, 8, 4, 2]  # length per taso, 6..0


def simultaneous_pairs_for_level(length):
    """Palauttaa listan (a0,b0,a1,b1) - nelja osoitetta jotka ovat
    AKTIIVISIA SAMANAIKAISESTI kahdella lanella tallä tasolla.
    Jokainen lane kasittelee yhden ryhman butterflyt jarjestyksessa;
    SAMANAIKAISIA (sama butterfly-indeksi ryhman sisalla) ovat lane0:n
    ja lane1:n j:nnet butterflyt omissa ryhmissaan."""
    groups = list(range(0, N, 2 * length))
    pairs = []
    # kaytetaan samaa ryhmaparitusta kuin RTL: peräkkäiset ryhmät
    # kasitellaan pareittain (group[i], group[i+1]) - tama toistaa
    # 2c-ii:n oman ohjauslogiikan (63 ryhmaparia + taso 6:n erikoistapaus)
    for gi in range(0, len(groups), 2) if len(groups) > 1 else [(0,)]:
        if len(groups) == 1:
            g0 = groups[0]
            g1 = None
        else:
            g0 = groups[gi]
            g1 = groups[gi + 1] if gi + 1 < len(groups) else None
        for j in range(length):
            a0 = g0 + j
            b0 = a0 + length
            if g1 is not None:
                a1 = g1 + j
                b1 = a1 + length
            else:
                a1 = b1 = None
            pairs.append((a0, b0, a1, b1))
    return pairs


def check_mapping(bank_fn, local_fn, verbose=False):
    """bank_fn(addr)->pankki [0,NUM_BANKS), local_fn(addr)->paikallinen osoite.
    Palauttaa (ok:bool, virheet:list[str])."""
    errors = []

    # --- Bijektiivisyys: (bank,local) -> addr on 1-1 ---
    seen = {}
    for addr in range(N):
        b, l = bank_fn(addr), local_fn(addr)
        key = (b, l)
        if key in seen:
            errors.append(f"Bijektiivisyys rikki: osoitteet {seen[key]} ja {addr} molemmat -> (bank={b}, local={l})")
        seen[key] = addr
    if len(seen) != N:
        errors.append(f"Vain {len(seen)}/{N} eri (bank,local)-paria katettu")

    # --- Konfliktittomuus jokaisella tasolla ---
    for length in LEVELS:
        pairs = simultaneous_pairs_for_level(length)
        for (a0, b0, a1, b1) in pairs:
            addrs = [a0, b0]
            if a1 is not None:
                addrs += [a1, b1]
            banks = [bank_fn(a) for a in addrs]
            if len(set(banks)) != len(banks):
                errors.append(f"Konflikti tasolla length={length}: osoitteet {addrs} -> pankit {banks}")
                if not verbose:
                    return False, errors  # lopeta heti ensimmaisesta virheesta jos ei verbose

    return (len(errors) == 0), errors


if __name__ == "__main__":
    import sys

    candidates = {
        "addr mod 4 (naiivi)": (lambda a: a % NUM_BANKS, lambda a: a // NUM_BANKS),
        "addr / 64 (yla-bitit)": (lambda a: a // 64, lambda a: a % 64),
        "XOR-taite (bitit 7,6 xor 1,0)": (
            lambda a: ((a >> 6) ^ a) & 3,
            lambda a: a >> 2  # EI valttamatta bijektiivinen - testataan
        ),
        "bitit [1:0] xor bitit [7:6]": (
            lambda a: (a & 3) ^ ((a >> 6) & 3),
            lambda a: (a >> 2) & 0x3F  # jattaa 2 keskimmaista bittia pois - tarkastellaan
        ),
    }

    for name, (bank_fn, local_fn) in candidates.items():
        ok, errors = check_mapping(bank_fn, local_fn)
        status = "PASS" if ok else f"FAIL ({len(errors)} virhetta, ensimmainen: {errors[0] if errors else ''})"
        print(f"{name}: {status}")
