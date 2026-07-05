# AO-DECISION-L5 CORE
**FMI Multi-Point Time-Lock + Quiet Case Manager (Auto-Brief trigger)**

## What you get
- `ssa/weather_fmi.py`: pulls FMI observations (temp + wind) for multiple places and computes Time-Lock:
  - status: OK / WEAK / CRITICAL / UNKNOWN
  - time_p: 0..1 (risk probability-like score)
  - metrics: worst-2-of-N t_med and w_med
- `hub/app/case_manager.py`: debounced case_id + trigger decision for auto-brief.

## 1) .env
Add:
```
FMI_PLACES=Helsinki,Kuopio,Oulu,Rovaniemi
```

## 2) SSA snapshot integration (example)
In your SSA adapter loop, after you collect grid/market signals:
```python
from ssa.weather_fmi import calculate_time_lock

tl = calculate_time_lock()
snapshot.setdefault("locks", {})
snapshot.setdefault("locks_p", {})
snapshot.setdefault("signals", {}).setdefault("weather", {})

snapshot["locks"]["Time"] = tl["status"]
snapshot["locks_p"]["Time"] = tl["time_p"]
snapshot["signals"]["weather"] = tl["metrics"]
snapshot["signals"]["weather_points"] = tl["points"]
```

## 3) Hub: case manager integration (example)
```python
from app.case_manager import CaseManager

cm = CaseManager(debounce_seconds=600)  # 10 min
triggered, case_id, reason = cm.evaluate(snapshot)

if triggered:
    # run_llm_consensus(req, case_id=case_id, mode="auto_brief")
    print("AUTO_BRIEF:", case_id, reason)
```

## Operational note
- Don't mandate on Time-Lock UNKNOWN alone.
- Consider adding a trigger on WEAK->CRITICAL transitions per lock for immediate brief.
