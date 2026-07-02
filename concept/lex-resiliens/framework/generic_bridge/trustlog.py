#!/usr/bin/env python3
"""
trustlog.py

Geneerinen hash-ketjutettu audit-loki. Erotettu Lex Resiliens -putkesta:
ei tiedä mitään PSA:sta, R/S/E:sta tai skenaarioista. Ottaa vastaan minkä
tahansa JSON-serialisoituvan dictin, ketjuttaa sen sha256:lla edelliseen
tietueeseen, ja tunnistaa jälkikäteisen peukaloinnin.

Kayttotarkoitus: mika tahansa deterministinen putki jonka ulostulon
eheytta halutaan todentaa - ei sidottu energiaan, resilienssiin tai
mihinkaan tiettyyn domainiin.
"""

from __future__ import annotations
import json
import hashlib
import shutil
from pathlib import Path
from typing import Any, Dict, List, Optional


class TrustLog:
    """Append-only, hash-ketjutettu JSONL-loki."""

    def __init__(self, log_path: str | Path):
        self.log_path = Path(log_path)
        self.log_path.parent.mkdir(parents=True, exist_ok=True)

    @staticmethod
    def _compute_hash(record: Dict[str, Any]) -> str:
        payload = json.dumps(record, sort_keys=True, ensure_ascii=False).encode("utf-8")
        return hashlib.sha256(payload).hexdigest()

    def _last_hash(self) -> str:
        if not self.log_path.exists():
            return ""
        last = ""
        with self.log_path.open("r", encoding="utf-8") as f:
            for line in f:
                if line.strip():
                    last = line.strip()
        if not last:
            return ""
        try:
            return json.loads(last).get("record_hash", "")
        except json.JSONDecodeError:
            return ""

    def append(self, payload: Dict[str, Any]) -> str:
        """Lisaa tietueen ketjuun. payload voi olla mika tahansa
        JSON-serialisoituva dict - kutsuja paattaa skeeman."""
        prev_hash = self._last_hash()
        record = dict(payload)
        record["prev_hash"] = prev_hash
        record_hash = self._compute_hash(record)
        wrapped = {"record_hash": record_hash, "record": record}
        with self.log_path.open("a", encoding="utf-8") as f:
            f.write(json.dumps(wrapped, ensure_ascii=False) + "\n")
        return record_hash

    def read_all(self) -> List[Dict[str, Any]]:
        """Palauttaa kaikki tietueet (pelkat 'record'-osiot) jarjestyksessa."""
        if not self.log_path.exists():
            return []
        out = []
        with self.log_path.open("r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    out.append(json.loads(line)["record"])
                except (json.JSONDecodeError, KeyError):
                    continue
        return out

    def verify(self) -> tuple[bool, Optional[str]]:
        """Tarkistaa koko ketjun eheyden. Palauttaa (ok, virhe_tai_None)."""
        if not self.log_path.exists():
            return True, None  # tyhja loki on triviaalisti eheä
        prev_expected = ""
        with self.log_path.open("r", encoding="utf-8") as f:
            for lineno, line in enumerate(f, 1):
                line = line.strip()
                if not line:
                    continue
                try:
                    wrapped = json.loads(line)
                except json.JSONDecodeError as e:
                    return False, f"Rivi {lineno}: virheellinen JSON: {e}"

                record = wrapped.get("record")
                stored_hash = wrapped.get("record_hash")
                if record is None or stored_hash is None:
                    return False, f"Rivi {lineno}: puuttuu 'record' tai 'record_hash'"

                computed_hash = self._compute_hash(record)
                if computed_hash != stored_hash:
                    return False, (
                        f"Rivi {lineno}: record_hash ei tasmaa "
                        f"(tallennettu={stored_hash[:12]}..., laskettu={computed_hash[:12]}...)"
                    )

                prev_in_record = record.get("prev_hash", "")
                if lineno == 1 and prev_in_record not in ("", None):
                    return False, f"Rivi {lineno}: ensimmaisen tietueen prev_hash ei ole tyhja"
                if lineno > 1 and prev_in_record != prev_expected:
                    return False, f"Rivi {lineno}: prev_hash ei vastaa edellisen tietueen hashia"

                prev_expected = stored_hash

        return True, None

    def tamper_test(self, mutate_fn=None) -> bool:
        """Peukaloi yhta tietuetta, varmistaa etta verify() huomaa sen,
        palauttaa alkuperaisen. Palauttaa True jos tamperointi havaittiin
        oikein. mutate_fn(record_dict) -> muokattu record_dict; oletuksena
        lisaa merkin ensimmaiseen string-kenttaan."""
        if not self.log_path.exists():
            raise FileNotFoundError(f"Lokia ei ole: {self.log_path}")

        backup = self.log_path.with_suffix(self.log_path.suffix + ".bak")
        shutil.copy2(self.log_path, backup)

        lines = [l for l in self.log_path.read_text(encoding="utf-8").splitlines() if l.strip()]
        if not lines:
            backup.unlink()
            raise RuntimeError("Loki on tyhja, ei mitaan tamperoitavaa")

        idx = 1 if len(lines) > 1 else 0
        wrapped = json.loads(lines[idx])
        record = wrapped["record"]

        if mutate_fn:
            record = mutate_fn(record)
        else:
            for k, v in record.items():
                if isinstance(v, str) and k != "prev_hash":
                    record[k] = v + " [TAMPEROITU]"
                    break

        wrapped["record"] = record
        # HUOM: record_hash ei paivity -> ketju rikkoutuu tarkoituksella
        lines[idx] = json.dumps(wrapped, ensure_ascii=False)
        self.log_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

        ok, err = self.verify()
        detected = not ok

        shutil.copy2(backup, self.log_path)
        backup.unlink()

        return detected
