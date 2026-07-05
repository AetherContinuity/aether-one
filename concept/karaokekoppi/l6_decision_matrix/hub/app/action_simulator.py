from __future__ import annotations

"""KaraokeKoppi™ L6 Action Simulator

Pure "what-if" simulator: ottaa viimeisimmän snapshotin ja action_id:n,
palauttaa before/after (index + locks).

Huom: deterministinen malli, ei ennuste.
"""

from typing import Any, Dict

from .decision_matrix import action_by_id, clamp, nudge_lock


def _infer_alert(index: float, locks: Dict[str, str]) -> str:
    if any(v == "CRITICAL" for v in locks.values()) and index < 0.4:
        return "ADMINISTRATIVE_MANDATE"
    if index < 0.25:
        return "CRISIS"
    if index < 0.55:
        return "PREALERT"
    return "STABLE"


def simulate_action(current_snapshot: Dict[str, Any], action_id: str) -> Dict[str, Any]:
    action = action_by_id(action_id)
    if action is None:
        return {"ok": False, "error": f"Unknown action_id: {action_id}"}

    before_index = float(current_snapshot.get("metrics", {}).get("resilience_index", 1.0))
    before_locks = dict(current_snapshot.get("locks", {}) or {})

    reserve = before_locks.get("Reserve", "WEAK")
    inertia = before_locks.get("Inertia", "WEAK")
    time = before_locks.get("Time", "WEAK")
    governance = before_locks.get("Governance", "WEAK")

    after_index = clamp(before_index + action.effect.delta_index, 0.0, 1.0)

    after_locks = dict(before_locks)
    after_locks["Reserve"] = nudge_lock(reserve, action.effect.reserve)
    after_locks["Inertia"] = nudge_lock(inertia, action.effect.inertia)
    after_locks["Time"] = nudge_lock(time, action.effect.time)
    after_locks["Governance"] = nudge_lock(governance, action.effect.governance)

    after_alert = _infer_alert(after_index, after_locks)

    return {
        "ok": True,
        "action": {
            "id": action.id,
            "title": action.title,
            "description": action.description,
            "rationale": action.effect.rationale,
            "political_cost": action.effect.political_cost,
            "economic_cost": action.effect.economic_cost,
            "tags": action.tags,
        },
        "before": {
            "resilience_index": before_index,
            "locks": before_locks,
            "alert": current_snapshot.get("alert", "STABLE"),
        },
        "after": {
            "resilience_index": after_index,
            "locks": after_locks,
            "alert": after_alert,
        },
        "delta": {"resilience_index": round(after_index - before_index, 3)},
        "note": "Deterministinen what-if. Kalibroi vaikutukset audit-datalla.",
    }
