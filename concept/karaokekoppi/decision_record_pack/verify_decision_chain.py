#!/usr/bin/env python3
import json, os, hashlib

DECISION_LOG = "./data/decision_record.jsonl"

def canonical_hash(entry_no_hash: dict) -> str:
    b = json.dumps(entry_no_hash, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    return hashlib.sha256(b).hexdigest()

def verify_chain():
    if not os.path.exists(DECISION_LOG):
        print("[audit] No decision log found.")
        return True

    expected_prev = None
    line_num = 0

    with open(DECISION_LOG, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            line_num += 1
            entry = json.loads(line)

            if entry.get("prev_entry_hash") != expected_prev:
                print(f"[ERROR] Chain broken at line {line_num}! Expected prev {expected_prev}, got {entry.get('prev_entry_hash')}")
                return False

            current_hash = entry.get("entry_hash")
            if not current_hash:
                print(f"[ERROR] Missing entry_hash at line {line_num}!")
                return False

            entry_copy = dict(entry)
            entry_copy.pop("entry_hash", None)
            actual_hash = canonical_hash(entry_copy)

            if current_hash != actual_hash:
                print(f"[ERROR] Integrity failure at line {line_num}! Hash mismatch.")
                return False

            expected_prev = current_hash

    print(f"[OK] Decision chain verified. {line_num} entries checked. Integrity 100%.")
    return True

if __name__ == "__main__":
    verify_chain()
