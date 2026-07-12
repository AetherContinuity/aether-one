#!/usr/bin/env python3
"""M3 Issue #7: testivektorit ByteEncode1/ByteDecode1 RTL:lle, PAKATTU
muoto (ks. pqc_byteencode_d1.sv:n oma kommentti porttien pakkaamisesta
- unpacked-taulukko ei toimi porttina tassa iverilog-versiossa)."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from byteencode_golden import byte_encode, byte_decode

import random
random.seed(2026)


def bits_to_packed(bits):
    """256 bitin lista -> 256-bittinen kokonaisluku, bitti i = bits[i]."""
    val = 0
    for i, b in enumerate(bits):
        val |= (b & 1) << i
    return val


def bytes_to_packed(byte_list):
    """32 tavun lista -> 256-bittinen kokonaisluku, tavu k bittipaikassa [8k+7:8k]."""
    val = 0
    for k, byte_val in enumerate(byte_list):
        val |= (byte_val & 0xFF) << (8 * k)
    return val


outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")

with open(os.path.join(outdir, "byteencode_d1_packed_vectors.txt"), "w") as f:
    for trial in range(10):
        F = [random.randrange(2) for _ in range(256)]
        B = byte_encode(1, F)
        F2 = byte_decode(1, B)
        assert F2 == F, "golden-mallin oma round-trip epaonnistui"

        f_packed = bits_to_packed(F)
        b_packed = bytes_to_packed(B)
        # Vahvista etta suora bittikopiointi antaa saman tuloksen (varmistus ennen RTL:aa)
        assert f_packed == b_packed, f"suora bittikopiointi EI vastaa bits_to_bytes:aa! f={f_packed:x} b={b_packed:x}"

        f.write(f"{f_packed:064x}\n")
        f.write(f"{b_packed:064x}\n")

print("10 testitapausta generoitu, suora bittikopiointi vahvistettu oikeaksi kaikilla")
