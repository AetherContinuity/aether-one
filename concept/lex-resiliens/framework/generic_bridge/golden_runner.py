#!/usr/bin/env python3
"""
golden_runner.py

Geneerinen golden-test-ajuri TrustLog-lokille. Ei tieda mitaan PSA:sta,
alert_modesta tai R/S/E:sta - kutsuja maarittelee mita tarkistetaan.

Kaytto:
    from trustlog import TrustLog
    from golden_runner import GoldenCheck, run_golden_checks

    checks = [
        GoldenCheck(
            name="DEEP_CRISIS",
            scenario_key_field="scenario",   # minka kentan arvolla tunnistetaan
            scenario_key_value="DEEP_CRISIS",
            assertions=[
                lambda r: (r["relay"]["psa"] < 0.55, f"PSA={r['relay']['psa']}"),
                lambda r: (r["relay"]["alert_mode"] == "CRISIS", r["relay"]["alert_mode"]),
            ],
        ),
    ]
    results = run_golden_checks(TrustLog("audit_logs/x.log"), checks)
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import Any, Callable, Dict, List, Tuple


AssertionFn = Callable[[Dict[str, Any]], Tuple[bool, str]]


@dataclass
class GoldenCheck:
    name: str
    scenario_key_field: str
    scenario_key_value: str
    assertions: List[AssertionFn] = field(default_factory=list)


@dataclass
class GoldenResult:
    name: str
    passed: bool
    details: List[str]


def _find_last_matching(records: List[Dict[str, Any]], field: str, value: str):
    for record in reversed(records):
        if record.get(field) == value:
            return record
    return None


def run_golden_checks(log, checks: List[GoldenCheck]) -> List[GoldenResult]:
    """log: TrustLog-instanssi. Palauttaa listan GoldenResult-olioita."""
    records = log.read_all()
    results = []

    for check in checks:
        record = _find_last_matching(records, check.scenario_key_field, check.scenario_key_value)
        if record is None:
            results.append(GoldenResult(
                name=check.name, passed=False,
                details=[f"Ei loydetty tietuetta jossa {check.scenario_key_field}={check.scenario_key_value}"],
            ))
            continue

        details = []
        all_ok = True
        for assertion in check.assertions:
            try:
                ok, msg = assertion(record)
            except Exception as e:
                ok, msg = False, f"Poikkeus tarkistuksessa: {e}"
            if not ok:
                all_ok = False
            details.append(("OK " if ok else "FAIL ") + msg)

        results.append(GoldenResult(name=check.name, passed=all_ok, details=details))

    return results


def summarize(results: List[GoldenResult]) -> str:
    lines = []
    all_pass = True
    for r in results:
        status = "PASS" if r.passed else "FAIL"
        if not r.passed:
            all_pass = False
        lines.append(f"[{status}] {r.name}")
        for d in r.details:
            lines.append(f"    {d}")
    lines.append("")
    lines.append("KAIKKI LAPI" if all_pass else "EPAONNISTUMISIA")
    return "\n".join(lines)
