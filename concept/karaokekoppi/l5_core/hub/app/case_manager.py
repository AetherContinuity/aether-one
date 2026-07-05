import time

class CaseManager:
    """Quiet Case Manager: creates/updates case_id and decides when to trigger auto-brief.

    Rules (v1):
      - Trigger if resilience_index drops >= 0.07 since last evaluation OR any lock is CRITICAL
      - Debounce: at most once / 10 minutes (default)
      - Returns: (triggered: bool, case_id: str|None, reason: str)
    """

    def __init__(self, debounce_seconds: int = 600):
        self.last_index = 1.0
        self.last_brief_ts = 0.0
        self.current_case_id = None
        self.debounce_seconds = debounce_seconds

    def evaluate(self, snapshot: dict):
        now = time.time()
        idx = float(snapshot.get("resilience_index", 1.0))
        locks = snapshot.get("locks", {}) or {}

        delta = self.last_index - idx
        critical_lock = any(v == "CRITICAL" for v in locks.values())

        reason_parts = []
        trigger = False
        if delta >= 0.07:
            trigger = True
            reason_parts.append(f"INDEX_DROP_{delta:.2f}")
        if critical_lock:
            trigger = True
            reason_parts.append("LOCK_CRITICAL")

        if trigger and (now - self.last_brief_ts > self.debounce_seconds):
            self.last_brief_ts = now
            self.current_case_id = f"CASE-{int(now)}"
            self.last_index = idx
            return True, self.current_case_id, "+".join(reason_parts)

        self.last_index = idx
        return False, self.current_case_id, ""
