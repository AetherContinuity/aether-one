# Decision Record schema (v0.2.3)

Decision records are **append-only JSONL** entries in `./data/decision_record.jsonl`.

## Core fields
- `ts` (ISO UTC)
- `decision_id` (string)
- `made_by` (string)
- `summary` (string)
- `details` (string)
- `tags` (array of strings)
- `severity` (LOW | NORMAL | HIGH | CRITICAL)

## Linking block: `linked`
- `linked_brief_sha256`: sha256 of `case_brief_latest.md` if present
- `linked_council_sha256`: sha256 of `council_report_latest.json` if present
- `linked_snapshot_tail`: last N `payload_hash` values from `snapshots_verified.jsonl`
- `linked_trends`: optional trends object from council report (if present)

## Chain integrity
- `prev_entry_hash`: sha256(line-by-line) of the previous JSONL line (or null for first)
- `entry_hash`: sha256 of the **canonical JSON** of this entry (without entry_hash)

## Optional signing
If `--sign` is used:
- `_meta`: `{ "sig_alg": "ed25519", "key_id": "..." }`
- `_signature`: Base64 Ed25519 signature over canonical bytes of the record core (before entry_hash)

Signing is optional but recommended for high-stakes operational decisions.
