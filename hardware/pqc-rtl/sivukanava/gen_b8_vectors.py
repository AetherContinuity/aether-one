#!/usr/bin/env python3
"""B8-otoksen vektorit (ks. B8-ENNAKKO.md).

Kaytto (hardware/pqc-rtl-hakemistosta):
  python3 -I sivukanava/gen_b8_vectors.py 512|768 <ulostulo>

Lahde: fpga/tau/acvp/decaps_<sarja>.txt (NIST ACVP 975de31).
Muoto: ensimmainen rivi = tapausmaara. Per tapaus:
  "<tcId> <muunnelma> <match_odotus>", dk, c, K_odotus
Muunnelma: 0=V 1=R0 2=R1 3=R2 4=R3 5=RN 6=SWAP.
Heksat little-endian pakattuina kuten fpga/tau/acvp/*.txt.
K_odotus ja match_odotus lasketaan golden-mallilla (mlkem_golden.py)."""
import hashlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "m2-golden"))
from mlkem_golden import (mlkem_encaps_internal, mlkem_decaps_internal,  # noqa: E402
                          kpke_decrypt, kpke_encrypt, sha3_512)

PARAMS = {"512": dict(K=2, E1=3, E2=2, DU=10, DV=4),
          "768": dict(K=3, E1=2, E2=2, DU=10, DV=4)}
NAMES = ["V", "R0", "R1", "R2", "R3", "RN", "SWAP"]


def unpack(h, nbytes):
    return int(h, 16).to_bytes(nbytes, "little")


def pack(b):
    return f"{int.from_bytes(b, 'little'):0{len(b) * 2}x}"


def flip(c, idx, mask):
    b = bytearray(c)
    b[idx] ^= mask
    return bytes(b)


def golden_match(dk, c, p):
    """c == c' golden-mallin omalla FO-laskennalla (FIPS 203 alg. 18)."""
    K = p["K"]
    dkpke = dk[:384 * K]
    ek = dk[384 * K:768 * K + 32]
    h = dk[768 * K + 32:768 * K + 64]
    m2 = kpke_decrypt(dkpke, c, K, p["DU"], p["DV"])
    r2 = sha3_512(m2 + h)[32:]
    c2, _, _ = kpke_encrypt(ek, m2, r2, K, p["E1"], p["E2"], p["DU"], p["DV"])
    return int(c2 == c)


def main(pset, out):
    p = PARAMS[pset]
    K, DU, DV = p["K"], p["DU"], p["DV"]
    dk_len, c_len = 768 * K + 96, 32 * (DU * K + DV)
    c1_len = 32 * DU * K

    lines = [l.strip() for l in open(f"fpga/tau/acvp/decaps_{pset}.txt") if l.strip()]
    n = int(lines[0])
    keys = []
    for i in range(n):
        hdr, dk_h, c_h, _k = lines[1 + 4 * i:5 + 4 * i]
        tc, rej = map(int, hdr.split())
        keys.append((tc, rej, unpack(dk_h, dk_len), unpack(c_h, c_len)))

    rows = []
    valid_c = {}
    for tc, rej, dk, c_nist in keys:
        ek = dk[384 * K:768 * K + 32]
        if rej == 0:
            v = c_nist
        else:
            m = hashlib.sha3_256(b"B8" + tc.to_bytes(4, "big")).digest()
            _, v = mlkem_encaps_internal(ek, m, K, p["E1"], p["E2"], DU, DV)
        valid_c[tc] = v
        variants = [(0, v), (1, flip(v, 0, 0x01)), (2, flip(v, c_len - 1, 0x80)),
                    (3, flip(v, c1_len // 2, 0x10)), (4, flip(v, c1_len, 0xFF))]
        if rej == 1:
            variants.append((5, c_nist))
        for vid, c in variants:
            rows.append((tc, vid, dk, c))

    for i, (tc, _rej, dk, _c) in enumerate(keys):
        tc2, _r2, dk2, _c2 = keys[(i + 1) % n]
        dk_swap = dk2[:384 * K] + dk[384 * K:768 * K + 64] + dk2[768 * K + 64:]
        rows.append((tc, 6, dk_swap, valid_c[tc]))

    with open(out, "w") as f:
        f.write(f"{len(rows)}\n")
        for tc, vid, dk, c in rows:
            k = mlkem_decaps_internal(dk, c, K, p["E1"], p["E2"], DU, DV)
            mt = golden_match(dk, c, p)
            if vid == 0 and mt != 1:
                sys.exit(f"tcId={tc}: V-muunnelma ei ole validi golden-mallissa")
            if vid in (1, 2, 3, 4, 5) and mt != 0:
                sys.exit(f"tcId={tc} {NAMES[vid]}: korruptoitu c hyvaksyttiin golden-mallissa")
            f.write(f"{tc} {vid} {mt}\n{pack(dk)}\n{pack(c)}\n{pack(k)}\n")
    print(f"{out}: {len(rows)} tapausta ({n} avainta)")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(*sys.argv[1:])
