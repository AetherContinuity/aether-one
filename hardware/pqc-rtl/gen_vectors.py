#!/usr/bin/env python3
"""Itsekonsistentti vektorigeneraattori M2 Vaihe 1 -testille.
M2 VAIHE 1: per-butterfly zeta-indeksointi. Jokainen COUNT butterflyista
(molemmissa laneissa) kayttaa OMAA zeta-arvoaan idx:n mukaan indeksoiden,
ei enaa yhteista tw_window[0]:aa (M1:n rajaus).

SKOOPIN RAJAUS (tietoinen, dokumentoitu): lane0 ja lane1 kayttavat SAMAA
tw_window-taulukkoa samalla idx:lla (molemmat butterfly-indeksit 0..15
kayttavat tw_window[sama idx]) - tama ei viela mallinna oikeaa 256-pisteen
NTT:n globaalia butterfly-asemointia jossa eri lanet kasittelisivat eri
zetoilla varustettuja butterfly-alueita. Se on M2 Vaihe 2:n laajuus.
"""

Q = 3329
R = 1 << 16
QINV = 62209
COUNT = 16

def montgomery_reduce(a: int) -> int:
    u = ((a & (R - 1)) * QINV) & (R - 1)
    t = (a + u * Q) >> 16
    if t >= Q:
        t -= Q
    return t

def butterfly(a: int, b: int, zeta: int):
    t = montgomery_reduce(b * zeta)
    ap = (a + t) % Q
    bp = (a - t) % Q
    return ap, bp

import random
random.seed(42)

lane0_a = [random.randrange(Q) for _ in range(COUNT)]
lane0_b = [random.randrange(Q) for _ in range(COUNT)]
lane1_a = [random.randrange(Q) for _ in range(COUNT)]
lane1_b = [random.randrange(Q) for _ in range(COUNT)]

# ERI zeta jokaiselle butterfly-indeksille (M2 Vaihe 1:n koko pointti).
# Pakotettu kaikki eri arvoiksi (ei duplikaatteja) jotta vaarinindeksointi
# (esim. aina idx=0:n zeta) tuottaisi VARMASTI vaaran tuloksen, ei vain
# sattumalta oikean.
zetas = random.sample(range(1, Q), COUNT)

lane0_exp = [butterfly(a, b, zetas[i]) for i, (a, b) in enumerate(zip(lane0_a, lane0_b))]
lane1_exp = [butterfly(a, b, zetas[i]) for i, (a, b) in enumerate(zip(lane1_a, lane1_b))]

# Vaara ennuste JOS idx-indeksointi EI toimisi (M1:n vanha kayttays -
# kaikki butterflyt kayttaisivat tw_window[0]:aa eli zetas[0]:aa).
# Kaytetaan negatiivikontrollissa: todellinen tulos EI SAA tasmata tahan.
lane0_wrong = [butterfly(a, b, zetas[0]) for a, b in zip(lane0_a, lane0_b)]
lane1_wrong = [butterfly(a, b, zetas[0]) for a, b in zip(lane1_a, lane1_b)]

def write_memh(path, words):
    with open(path, "w") as f:
        for w in words:
            f.write(f"{w & 0xFFFF:04x}\n")

mem = [0] * 128
for i in range(COUNT):
    mem[2*i]      = lane0_a[i]
    mem[2*i + 1]  = lane0_b[i]
    mem[64 + 2*i] = lane1_a[i]
    mem[65 + 2*i] = lane1_b[i]
write_memh("vectors/bank0_init.memh", mem)

# tw_window[0..15] = 16 ERI zetaa (M1:ssa vain indeksi 0 oli kaytossa)
write_memh("vectors/twiddles.memh", zetas)

expect = [0] * 128
for i in range(COUNT):
    expect[2*i],      expect[2*i+1]  = lane0_exp[i]
    expect[64+2*i],   expect[65+2*i] = lane1_exp[i]
write_memh("vectors/bank0_expect.memh", expect)

# Vaara-ennuste-vektori negatiivikontrollia varten (ei kirjoiteta RTL:lle,
# vain testipenkin oman tarkistuksen dokumentoinniksi - ks. tb: tarkistaa
# ettei todellinen tulos tasmaa tahan)
expect_wrong = [0] * 128
for i in range(COUNT):
    expect_wrong[2*i],    expect_wrong[2*i+1]  = lane0_wrong[i]
    expect_wrong[64+2*i], expect_wrong[65+2*i] = lane1_wrong[i]
write_memh("vectors/bank0_expect_wrong_if_idx0_only.memh", expect_wrong)

print(f"16 eri zetaa (M2 Vaihe 1): {zetas[:4]}...")
print(f"Lane0[0]: a={lane0_a[0]} b={lane0_b[0]} zeta={zetas[0]} -> {lane0_exp[0]}")
print(f"Lane0[5]: a={lane0_a[5]} b={lane0_b[5]} zeta={zetas[5]} -> {lane0_exp[5]}")
print(f"Lane1[0]: a={lane1_a[0]} b={lane1_b[0]} zeta={zetas[0]} -> {lane1_exp[0]}")

