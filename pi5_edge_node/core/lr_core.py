"""Lex Resiliens demo engine for Pi5.

This version routes KRI + LR-D via TrustCore v1.0 (deterministic C core).
Policy/decision logic is still Python-level for iteration speed.
"""

from dataclasses import dataclass
from typing import Dict, Any

from .kri_engine import compute_kri


@dataclass
class LRResult:
    score: float
    status: str
    details: Dict[str, Any]


def lr_evaluate(sensor_state: Dict[str, Any]) -> LRResult:
    kri = compute_kri(sensor_state)

    flags = []
    if kri.S > 0.6:
        flags.append("Stress korkea")
    if kri.E > 0.3:
        flags.append("Exposure kohonnut")
    if kri.R < 0.3:
        flags.append("Resilienssi matala")
    if not kri.constructive:
        flags.append("Dissonanssi havaittu")

    score = min(1.0, len(flags) * 0.25)

    if score < 0.3:
        status = "OK"
    elif score < 0.7:
        status = "WATCH"
    else:
        status = "ALERT"

    return LRResult(
        score=score,
        status=status,
        details={
            "trustcore_v1": {
                "R": kri.R,
                "S": kri.S,
                "E": kri.E,
                "kri": kri.kri,
                "constructive": kri.constructive,
                "deltas": kri.deltas,
            },
            "components": flags,
            "inputs": sensor_state,
        },
    )
