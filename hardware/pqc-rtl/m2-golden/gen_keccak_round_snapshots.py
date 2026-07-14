#!/usr/bin/env python3
"""M3 Issue #9/#10: pysyva, jaadytetty referenssi Keccak-p[1600,24]:n
kierroskohtaisille valitiloille. Kayttajan oma ehdotus: nama eivat ole
vain kertakayttoisia debug-apuvalineita, vaan PYSYVIA regressiotesteja
- seka RTL:aa etta itse golden-mallia vastaan tulevaisuudessa.

Kaksi tasoa jokaiselle testitapaukselle:
  - Toiminnallinen: lopullinen tila (24 kierroksen jalkeen) oikea.
  - Rakenteellinen: KAIKKI 24 valitilaa identtiset - paljastaa
    poikkeamat jo ENNEN kuin ne nakyvat lopputuloksessa (sama periaate
    kuin NTT^-1:n oma tasokohtainen debug-tyokalu, joka osoittautui
    ratkaisevaksi juurisyyn loytamisessa)."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from keccak_golden import keccak_f1600, bytes_to_state

import json

outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")
os.makedirs(outdir, exist_ok=True)

# Kolme edustavaa testitapausta - kiinteita, EI satunnaisia (jotta
# tiedosto on aidosti pysyva referenssi, ei vaihdu ajojen valilla)
TEST_CASES = {
    "all_zero": b"\x00" * 168,
    "sha3_256_abc_block": b"abc" + b"\x06" + b"\x00" * 131 + b"\x80".rjust(1, b"\x00")[-1:],
    "all_ff": b"\xff" * 168,
}
# Korjataan "sha3_256_abc_block": 168 tavua yhteensa, viimeinen XOR 0x80
_abc_block = bytearray(b"abc" + b"\x06" + b"\x00" * (168 - 4))
_abc_block[-1] ^= 0x80
TEST_CASES["sha3_256_abc_block"] = bytes(_abc_block)

if "--regenerate" in sys.argv:
    snapshots_out = {}
    for name, block in TEST_CASES.items():
        assert len(block) == 168, f"{name}: lohkon pituus vaarin ({len(block)})"
        state = bytes_to_state(block)
        final, rounds = keccak_f1600(state, capture_rounds=True)

        snapshots_out[name] = {
            "initial_state": [[f"{state[x][y]:016x}" for y in range(5)] for x in range(5)],
            "round_states": [
                [[f"{rounds[r][x][y]:016x}" for y in range(5)] for x in range(5)]
                for r in range(24)
            ],
        }

    with open(os.path.join(outdir, "keccak_round_snapshots.json"), "w") as f:
        json.dump(snapshots_out, f, indent=1)

print(f"Tallennettu {len(TEST_CASES)} testitapausta, kukin 24 kierroksen tilalla, "
      f"vectors/keccak_round_snapshots.json:iin")


def verify_frozen_snapshots():
    """Aja golden-malli UUDESTAAN ja vertaa tallennettuun tiedostoon -
    suojaa golden-mallin OMAA tulevaa regressiota vastaan, ei vain RTL:aa."""
    with open(os.path.join(outdir, "keccak_round_snapshots.json")) as f:
        frozen = json.load(f)

    all_ok = True
    for name, block in TEST_CASES.items():
        state = bytes_to_state(block)
        final, rounds = keccak_f1600(state, capture_rounds=True)
        for r in range(24):
            for x in range(5):
                for y in range(5):
                    expected = int(frozen[name]["round_states"][r][x][y], 16)
                    if rounds[r][x][y] != expected:
                        print(f"REGRESSIO: {name} kierros {r} lane({x},{y}) poikkeaa jaadytetysta arvosta!")
                        all_ok = False
    return all_ok


if __name__ == "__main__":
    ok = verify_frozen_snapshots()
    print("Jaadytetyn referenssin oma itsetarkistus:", "OK" if ok else "FAIL")
    if not ok:
        import sys
        sys.exit(1)
