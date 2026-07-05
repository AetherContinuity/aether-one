# Patch: Decision Log panel for National View (optional)

## Backend
Extend `national_dashboard_server.py` to tail decision_record.jsonl similarly to audit feed, e.g.
- `DECISIONS = ./data/decision_record.jsonl`
- include `payload["decisions"] = tail_jsonl(DECISIONS, 20)`

## Frontend
Add a new box under Audit Feed titled "Decision Log", and render rows:
- ts, decision_id, made_by, severity, summary, entry_hash prefix
