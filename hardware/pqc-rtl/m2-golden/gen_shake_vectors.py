#!/usr/bin/env python3
"""M3 Issue #14: testivektorit SHAKE128/SHAKE256:lle.
Vaihe B (kayttajan oma ehdotus): 16, 32, rate tavua tasan, rate+1
tavua (ensimmainen monilohkotapaus), ja 512 tavua (useita squeeze-
kierroksia) - kiintealla "abc"-syotteella.
Vaihe C: ML-KEM:n oma XOF/PRF-kayttotyyli, eri syote ja pituus."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from keccak_golden import shake128, shake256

outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")
MAX_OUT = 512
MAX_MSG_BYTES = 40  # riittaa "abc":lle (3) ja ML-KEM-tyyliselle syotteelle (34)


def pack_bytes(b, total_len):
    buf = b + b"\x00" * (total_len - len(b))
    val = 0
    for i, byte in enumerate(buf):
        val |= byte << (i * 8)
    return val


shake128_cases = [
    ("abc_16", b"abc", 16),
    ("abc_32", b"abc", 32),
    ("abc_168_exact_rate", b"abc", 168),
    ("abc_169_first_multiblock", b"abc", 169),
    ("abc_512_multi_squeeze", b"abc", 512),
    ("ML_KEM_XOF_style", bytes(range(32)) + bytes([1, 2]), 504),
]

with open(os.path.join(outdir, "shake128_vectors.txt"), "w") as f:
    for name, msg, out_len in shake128_cases:
        digest = shake128(msg, out_len)
        f.write(f"{name} {len(msg)} {out_len}\n")
        f.write(f"{pack_bytes(msg, MAX_MSG_BYTES):x}\n")
        f.write(f"{pack_bytes(digest, MAX_OUT):x}\n")

shake256_cases = [
    ("abc_16", b"abc", 16),
    ("abc_32", b"abc", 32),
    ("abc_136_exact_rate", b"abc", 136),
    ("abc_137_first_multiblock", b"abc", 137),
    ("abc_512_multi_squeeze", b"abc", 512),
    ("ML_KEM_PRF_style", bytes(range(32)) + bytes([7]), 128),
]

with open(os.path.join(outdir, "shake256_vectors.txt"), "w") as f:
    for name, msg, out_len in shake256_cases:
        digest = shake256(msg, out_len)
        f.write(f"{name} {len(msg)} {out_len}\n")
        f.write(f"{pack_bytes(msg, MAX_MSG_BYTES):x}\n")
        f.write(f"{pack_bytes(digest, MAX_OUT):x}\n")

print(f"SHAKE128: {len(shake128_cases)} testitapausta (viimeinen: ML-KEM XOF-tyyli)")
print(f"SHAKE256: {len(shake256_cases)} testitapausta (viimeinen: ML-KEM PRF-tyyli)")
