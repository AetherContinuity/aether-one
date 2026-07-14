#!/usr/bin/env python3
"""M3 Issue #15: pysyva, jaadytetty referenssi SamplePolyCBD:lle.
Sama periaate kuin SampleNTT/Keccak - kiintea, ei satunnainen."""

import sys
import os
import json
sys.path.insert(0, os.path.dirname(__file__))
from samplepolycbd_golden import sample_poly_cbd, Q

outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")
os.makedirs(outdir, exist_ok=True)

test_cases = {
    "eta2_all_zero": {"eta": 2, "B": bytes(64 * 2)},
    "eta2_all_ones": {"eta": 2, "B": bytes([0xFF] * (64 * 2))},
    "eta2_sequential": {"eta": 2, "B": bytes(i % 256 for i in range(64 * 2))},
    "eta3_all_zero": {"eta": 3, "B": bytes(64 * 3)},
    "eta3_sequential": {"eta": 3, "B": bytes(i % 256 for i in range(64 * 3))},
}

if "--regenerate" in sys.argv:
    frozen = {}
    for name, params in test_cases.items():
        f, info = sample_poly_cbd(params["B"], params["eta"], instrument=True)
        assert info["all_in_valid_cbd_range"], f"{name}: CBD-rajojen ulkopuolella!"
        frozen[name] = {
            "eta": params["eta"],
            "B_hex": params["B"].hex(),
            "f": f,
            "info": info,
        }

    with open(os.path.join(outdir, "samplepolycbd_frozen_reference.json"), "w") as f_out:
        json.dump(frozen, f_out, indent=1)

    print(f"Tallennettu {len(test_cases)} jaadytettya testitapausta")
    for name, data in frozen.items():
        print(f"  {name}: f[0:5]={data['f'][:5]}, valid_range={data['info']['all_in_valid_cbd_range']}")


def verify_frozen():
    with open(os.path.join(outdir, "samplepolycbd_frozen_reference.json")) as f_in:
        loaded = json.load(f_in)
    all_ok = True
    for name, data in loaded.items():
        B = bytes.fromhex(data["B_hex"])
        f, info = sample_poly_cbd(B, data["eta"], instrument=True)
        if f != data["f"]:
            print(f"REGRESSIO: {name} f poikkeaa jaadytetysta!")
            all_ok = False
    return all_ok


if __name__ == "__main__":
    ok = verify_frozen()
    print()
    print("Jaadytetyn referenssin oma itsetarkistus:", "OK" if ok else "FAIL")
    if not ok:
        import sys
        sys.exit(1)
