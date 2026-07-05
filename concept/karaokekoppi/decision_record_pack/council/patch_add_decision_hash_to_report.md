# Patch: include latest Decision hash into council_report_latest.json

Goal: make decisions visible/auditable from National View without heavy coupling.

## Minimal approach
In `council_v0_2.py` (or your current `council_v0_1.py`) after building `report`:

1) read tail of `./data/decision_record.jsonl`
2) set:
- `report["national"]["latest_decision_entry_hash"] = "<hash>"`
- optionally `report["national"]["latest_decision_id"] = "<id>"`

Pseudo:
```python
latest = tail_jsonl("./data/decision_record.jsonl", 1)
if latest:
    report.setdefault("national", {})
    report["national"]["latest_decision_entry_hash"] = latest[0].get("entry_hash")
    report["national"]["latest_decision_id"] = latest[0].get("decision_id")
```
