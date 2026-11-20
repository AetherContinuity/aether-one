#!/usr/bin/env python3
"""Googlen Android-attestaatiojuurten kiinnitys ja seuranta (VAIHE2-ENNAKKO K1, K2).

  android_roots.py check PINNED.json   # hakee virallisen listan, vertaa; ero -> exit 1
  android_roots.py show                # tulostaa haetun listan kiinnitysmuodossa

Lähde: https://android.googleapis.com/attestation/root (JSON-taulukko PEM-varmenteita).
Vain vakiokirjasto (urllib). Ajetaan CI:ssä; todentaja ei hae juuria verkosta.
"""

from __future__ import annotations

import base64
import hashlib
import json
import sys
import urllib.request

URL = "https://android.googleapis.com/attestation/root"


def pem_to_der(pem: str) -> bytes:
    body = "".join(l for l in pem.strip().splitlines() if not l.startswith("-----"))
    return base64.b64decode(body)


def fetch() -> list:
    with urllib.request.urlopen(URL, timeout=30) as r:
        data = json.loads(r.read().decode())
    if not isinstance(data, list) or not data:
        raise SystemExit(f"odottamaton vastaus: {str(data)[:200]}")
    return [{"sha256": hashlib.sha256(pem_to_der(p)).hexdigest(), "pem": p.strip() + "\n"} for p in data]


def main(argv: list) -> int:
    if len(argv) >= 1 and argv[0] == "show":
        print(json.dumps({"source": URL, "roots": fetch()}, indent=2))
        return 0
    if len(argv) == 2 and argv[0] == "check":
        got = {r["sha256"] for r in fetch()}
        pinned = {r["sha256"] for r in json.load(open(argv[1]))["roots"]}
        if got != pinned:
            print("JUURIJOUKKO MUUTTUNUT")
            print("  vain virallisessa:", sorted(got - pinned))
            print("  vain kiinnitetyssä:", sorted(pinned - got))
            print(json.dumps({"source": URL, "roots": fetch()}, indent=2))
            return 1
        print(f"juuret täsmäävät ({len(got)} kpl)")
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
