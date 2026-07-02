#!/usr/bin/env python3
"""Itsekonsistentti vektorigeneraattori M1-skoopatulle testille.
SKOOPIN RAJAUS (tietoinen, dokumentoitu): kaikki COUNT butterflya per lane
kayttavat SAMAA zeta-arvoa. Moni-zeta-tuki (yksi zeta per butterfly, kuten
oikeassa 256-pisteen NTT:ssa) vaatisi idx:n tuonnin ulos lane_fsm:sta -
ei tehty tassa iteraatiossa."""

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
zeta = random.randrange(1, Q)  # SAMA zeta kaikille butterflyille tassa skoopissa

lane0_exp = [butterfly(a, b, zeta) for a, b in zip(lane0_a, lane0_b)]
lane1_exp = [butterfly(a, b, zeta) for a, b in zip(lane1_a, lane1_b)]

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

# tw_window[0] = zeta, loput nollia (kaytetaan vain indeksia 0 tassa skoopissa)
write_memh("vectors/twiddles.memh", [zeta] + [0]*15)

expect = [0] * 128
for i in range(COUNT):
    expect[2*i],      expect[2*i+1]  = lane0_exp[i]
    expect[64+2*i],   expect[65+2*i] = lane1_exp[i]
write_memh("vectors/bank0_expect.memh", expect)

print(f"zeta (yhteinen)={zeta}")
print(f"Lane0[0]: a={lane0_a[0]} b={lane0_b[0]} -> {lane0_exp[0]}")
print(f"Lane1[0]: a={lane1_a[0]} b={lane1_b[0]} -> {lane1_exp[0]}")
