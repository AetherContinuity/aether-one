#!/usr/bin/env python3
"""M3 Issue #12: testivektorit SHA3-256-huippumoduulille. Golden-malli
on kaksinkertaisesti ulkoisesti ankkuroitu: (1) Pythonin hashlib
(riippumaton OpenSSL-pohjainen toteutus), (2) NIST:n oma julkaistu
Msg0-esimerkki (tyhja viesti, csrc.nist.gov/.../SHA3-256_Msg0.txt,
haettu ja tarkistettu tata dokumenttia kirjoitettaessa - tasmasi
taydellisesti).

Nelja testitapausta:
- empty: NIST:n oma julkaistu esimerkki
- abc: klassinen, laajalti julkaistu testivektori
- 200_bytes: monilohko-absorbointi (2 lohkoa, sama kuin Issue #11
  Vaihe B:n oma testi, mutta nyt taydellisen SHA3-256-rajapinnan kautta)
- 32_bytes_fixed: KAYTTAJAN OMA EHDOTUS - API-tason regressiotesti,
  vastaa TASMALLEEN miten ML-KEM:n H(s)-funktio kutsuu SHA3-256:ta
  myohemmin (Issue #15) - kiintea 32 tavun syote, yksi kutsu, 32 tavun
  ulostulo."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from keccak_golden import sha3_256

RATE = 136
MAX_BLOCKS = 2
TOTAL_BYTES = RATE * MAX_BLOCKS

outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")


def pack_bytes(b):
    val = 0
    for i, byte in enumerate(b):
        val |= byte << (i * 8)
    return val


test_cases = [
    ("empty", b""),
    ("abc", b"abc"),
    ("200_bytes", b"A" * 200),
    ("32_bytes_fixed_ML_KEM_style", bytes(range(32))),  # kiintea 32-tavuinen syote, ML-KEM:n H(s):n oma tyyli
]

with open(os.path.join(outdir, "sha3_256_vectors.txt"), "w") as f:
    for name, msg in test_cases:
        digest = sha3_256(msg)
        msg_buf = msg + b"\x00" * (TOTAL_BYTES - len(msg))
        f.write(f"{name} {len(msg)}\n")
        f.write(f"{pack_bytes(msg_buf):x}\n")
        f.write(f"{pack_bytes(digest):x}\n")

print(f"{len(test_cases)} testitapausta generoitu")
for name, msg in test_cases:
    print(f"  {name}: SHA3-256 = {sha3_256(msg).hex()}")
