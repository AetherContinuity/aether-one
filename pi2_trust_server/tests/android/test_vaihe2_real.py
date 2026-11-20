#!/usr/bin/env python3
"""K1/K3 oikeilla tallennetuilla ketjuilla (reference_compare.py layout -hakemisto).

- Auditorin Samsung- ja muut ketjut (2019, vanha RSA-juuri, sama avain kuin
  kiinnitetyssä 2022-juuressa): tuotantojuuria vasten voimassaolohetkellä -> ok;
  päivä viimeisen voimassaolon jälkeen -> failed (negatiivikontrolli).
- Googlen testiketjut: TEE-ketjut päättyvät Googlen RSA-juureen (tuotannossa,
  sama avain) -> ok; StrongBox-ketjujen juuri e35d38c6897d47e8 ei ole
  tuotannossa -> failed. Odotus valitaan juuren avaimen mukaan. Kaikki omaa
  juurta vasten ok.
- Googlen testiresurssin tilalista: yksikään Auditor-ketjun varmenne ei ole
  listalla; listalle lisätty välivarmenne -> failed.

Nämä ketjut eivät ole sidottuja tämän todentajan nonceen: B:tä ei arvioida.
"""

from __future__ import annotations

import json
import sys
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))

from core.trustcore.android_chain import check_chain, load_production_roots, parse_cert, roots_from_ders  # noqa: E402


def main(layout: Path, google_status: Path) -> int:
    prod = load_production_roots()
    fails = []
    c = Counter()
    revoked = json.loads(google_status.read_text())["entries"]
    for d in sorted(p for p in layout.iterdir() if p.is_dir() and not p.name.startswith("synt_")):
        ders = [f.read_bytes() for f in sorted(d.glob("c*.der"), key=lambda p: int(p.stem[1:]))]
        certs = [parse_cert(x) for x in ders]
        t_ok = max(x.not_before for x in certs) + timedelta(seconds=1)
        t_exp = min(x.not_after for x in certs) + timedelta(days=1)
        fresh = t_ok
        if d.name.startswith("auditor_"):
            r = check_chain(ders, prod, t_ok, revoked, fresh)
            c[f"auditor tuotantojuuri: {r.status}"] += 1
            if r.status != "ok":
                fails.append(f"{d.name}: {r.reason}")
            if not r.revocation_known:
                fails.append(f"{d.name}: tuore tilalista ei näy tuoreena")
            r2 = check_chain(ders, prod, t_exp, revoked, t_exp)
            c[f"auditor vanhentunut: {r2.status}"] += 1
            if r2.status != "failed":
                fails.append(f"{d.name}: vanhentunut ketju ei kaatunut")
            mid = dict(revoked)
            mid[format(certs[1].serial, "x")] = {"status": "REVOKED", "reason": "KEY_COMPROMISE"}
            r3 = check_chain(ders, prod, t_ok, mid, fresh)
            c[f"auditor välivarmenne listalle: {r3.status}"] += 1
            if r3.status != "failed":
                fails.append(f"{d.name}: revokoitu välivarmenne ei kaatunut")
        else:
            in_prod = any(certs[-1].spki == p.spki for p in prod.values())
            want = "ok" if in_prod else "failed"
            r = check_chain(ders, prod, t_ok, revoked, fresh)
            c[f"google tuotantojuuri ({'tuotantoavain' if in_prod else 'vieras juuri'}): {r.status}"] += 1
            if r.status != want:
                fails.append(f"{d.name}: tuotantojuuria vasten {r.status}, odotettu {want}: {r.reason}")
            r2 = check_chain(ders, roots_from_ders([ders[-1]]), t_ok, revoked, fresh)
            c[f"google omaa juurta vasten: {r2.status}"] += 1
            if r2.status != "ok":
                fails.append(f"{d.name}: {r2.reason}")
    for k, v in sorted(c.items()):
        print(f"  {k}: {v}")
    if fails:
        print(f"OIKEAT KETJUT: {len(fails)} poikkeamaa")
        for f in fails:
            print("  -", f)
        return 1
    print("OIKEAT KETJUT: kaikki odotetusti")
    return 0


if __name__ == "__main__":
    sys.exit(main(Path(sys.argv[1]), Path(sys.argv[2])))
