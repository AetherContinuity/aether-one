#!/usr/bin/env python3
"""M3 Issue #8 / NTT_INVERSE: golden-mallin valitilat jokaisen
kaanteis-NTT-tason jalkeen, differentiaalista tasokohtaista vertailua
varten. Kayttaa SAMAA LCG-testidataa kuin testipenkki (seed=12345),
vahvistettu identtiseksi SystemVerilogin oman LCG:n kanssa erikseen."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from kyber_ntt_golden import ntt, Q, ZETA, bitrev7


def gen_test_f():
    seed = 12345
    f = []
    for i in range(256):
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        f.append(seed % Q)
    return f


def ntt_inv_instrumented(f_hat):
    f = list(f_hat)
    k = 127
    length = 2
    snapshots = []
    while length <= 128:
        start = 0
        while start < 256:
            zeta = pow(ZETA, bitrev7(k), Q)
            k -= 1
            for j in range(start, start + length):
                t = f[j]
                f[j] = (t + f[j + length]) % Q
                f[j + length] = (zeta * (f[j + length] - t)) % Q
            start += 2 * length
        snapshots.append((length, list(f)))
        length *= 2
    n_inv = pow(128, Q - 2, Q)
    final = [(x * n_inv) % Q for x in f]
    return snapshots, final


def pack(coeffs, width=16):
    val = 0
    for i, c in enumerate(coeffs):
        val |= (c & ((1 << width) - 1)) << (i * width)
    return val


if __name__ == "__main__":
    f_test = gen_test_f()
    f_hat = ntt(f_test)
    snapshots, final = ntt_inv_instrumented(f_hat)
    assert final == f_test, "ntt_inv_instrumented:n oma round-trip epaonnistui!"

    outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")
    with open(os.path.join(outdir, "ntt_inverse_stage_snapshots.txt"), "w") as fh:
        for length, snap in snapshots:
            fh.write(f"{length} {pack(snap):x}\n")

    print("Valitilat generoitu (round-trip vahvistettu ennen tallennusta)")
    print(f"f_hat[0..3] = {f_hat[0]} {f_hat[1]} {f_hat[2]} {f_hat[3]}")
