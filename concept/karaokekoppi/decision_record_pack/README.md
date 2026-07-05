# Lex Resiliens / Aether Cloud v0.2.3 — Decision Record Pack

**KORJATTU 2026-07-05:** alkuperäinen `decision_record.py` laski
`prev_entry_hash`:n raakojen tiedostotavujen SHA256:na, mutta jokaisen
merkinnän oman `entry_hash`:n kanonisoidusta (sort_keys=True) muodosta -
nämä eivät koskaan täsmänneet, ja ketjun varmennus epäonnistui jopa
täysin koskemattomalle datalle. Korjattu: `prev_entry_hash` lukee nyt
suoraan edellisen merkinnän oman `entry_hash`-kentän, ei laske uutta
hajautusta. Myös `decision_id` sai mikrosekuntitarkkuuden (oli sekunti,
törmäsi jos kaksi merkintää samalla sekunnilla). Testattu: 3 merkinnän
puhdas ketju läpäisee, turmeltu merkintä havaitaan oikein.

This pack adds **Decision Record (append-only)** with optional **Ed25519 signing**, plus
**chain verification** and a simple **Decision Log** panel for National View.

## What you get
- `decision_record.py` — CLI to append decisions into `./data/decision_record.jsonl`
- `decision_schema.md` — fields + linking rules
- `verify_decision_chain.py` — validates chain integrity (prev_entry_hash + entry_hash)
- `council/patch_add_decision_hash_to_report.md` — minimal patch to include latest decision hash in `council_report_latest.json`
- `dashboard/patch_decision_panel.md` — adds Decision Log to National View and shows latest decision hash
- `scripts/decision_keygen.py` — optional: create Ed25519 keypair for decision signing

## Quick start
1) Append a decision (unsigned):
```bash
python3 decision_record.py --made-by "Duty Officer" --summary "Re-route traffic" --tags OPS,TRAFFIC
```

2) Append a signed decision (recommended):
```bash
python3 scripts/decision_keygen.py --out ./keys
python3 decision_record.py --made-by "Duty Officer" --summary "Start backup gen" --tags OPS,POWER \
  --sign --priv ./keys/decision_private.key --key-id DEC-OPS-001-KEY-2026-02
```

3) Verify decision chain:
```bash
python3 verify_decision_chain.py
```

## Linking rules
Each decision links to:
- `linked_brief_sha256` (hash of `./data/case_brief_latest.md` if present)
- `linked_council_sha256` (hash of `./data/council_report_latest.json` if present)
- `linked_snapshot_tail` (list of last N payload_hash values from `./data/snapshots_verified.jsonl` if present)
- `linked_trends` (optional: trends block from council report if present)

This makes the chain: **Snapshots → Council → Brief → Decision** auditable.
