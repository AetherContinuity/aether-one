#!/usr/bin/env python3
import argparse, os, json, hashlib, time, base64
from datetime import datetime, timezone

DATA_DIR = "./data"
DECISION_LOG = os.path.join(DATA_DIR, "decision_record.jsonl")
BRIEF_PATH = os.path.join(DATA_DIR, "case_brief_latest.md")
COUNCIL_PATH = os.path.join(DATA_DIR, "council_report_latest.json")
SNAPSHOTS_PATH = os.path.join(DATA_DIR, "snapshots_verified.jsonl")

def now_iso():
    return datetime.now(timezone.utc).isoformat()

def sha256_bytes(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()

def sha256_file(path: str) -> str | None:
    if not os.path.exists(path):
        return None
    with open(path, "rb") as f:
        return sha256_bytes(f.read())

def load_json(path: str):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

def tail_jsonl_payload_hashes(path: str, n: int = 5) -> list[str]:
    if not os.path.exists(path):
        return []
    try:
        with open(path, "r", encoding="utf-8") as f:
            lines = [ln.strip() for ln in f.readlines() if ln.strip()]
        out = []
        for ln in lines[-n:]:
            try:
                rec = json.loads(ln)
                # cloud ingest stores: {"received_at", "node_id", "key_id", "payload": {...}, "payload_hash": "..."}
                h = rec.get("payload_hash")
                if h:
                    out.append(h)
            except Exception:
                continue
        return out
    except Exception:
        return []

def canonical_bytes(obj: dict) -> bytes:
    s = json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return s.encode("utf-8")

def last_entry_hash(path: str) -> str | None:
    """Palauttaa edellisen merkinnän OMAN entry_hash-kentan suoraan -
    ei laske uutta hajautusta raakatavuista. Aiempi versio hajautti
    tiedostoon kirjoitetun rivin RAA'AT tavut (ei sort_keys=True), joka
    ei koskaan tasmannyt entry_hash-kentan omaan, kanonisoituun
    (sort_keys=True) laskentaan - ketju epaonnistui varmennuksessa
    jopa koskemattomana. Loydetty ja korjattu 2026-07-05."""
    if not os.path.exists(path):
        return None
    with open(path, "r", encoding="utf-8") as f:
        lines = [ln.strip() for ln in f.readlines() if ln.strip()]
    if not lines:
        return None
    last = json.loads(lines[-1])
    return last.get("entry_hash")

def compute_entry_hash(entry_no_hash: dict) -> str:
    return sha256_bytes(canonical_bytes(entry_no_hash))

# Optional signing (Ed25519)
def sign_bytes_ed25519(priv_path: str, msg: bytes) -> str:
    from cryptography.hazmat.primitives.asymmetric import ed25519
    with open(priv_path, "rb") as f:
        raw = f.read()
    priv = ed25519.Ed25519PrivateKey.from_private_bytes(raw)
    sig = priv.sign(msg)
    return base64.b64encode(sig).decode("ascii")

def build_record(args) -> dict:
    os.makedirs(DATA_DIR, exist_ok=True)

    linked = {
        "linked_brief_sha256": sha256_file(BRIEF_PATH),
        "linked_council_sha256": sha256_file(COUNCIL_PATH),
        "linked_snapshot_tail": tail_jsonl_payload_hashes(SNAPSHOTS_PATH, n=args.link_tail),
        "linked_trends": None,
    }

    # If council report exists, optionally attach trends for convenience
    if os.path.exists(COUNCIL_PATH):
        try:
            c = load_json(COUNCIL_PATH)
            if isinstance(c, dict) and "trends" in c:
                linked["linked_trends"] = c.get("trends")
        except Exception:
            pass

    record_core = {
        "ts": now_iso(),
        "decision_id": args.decision_id or f"DEC-{datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S-%f')}",
        "made_by": args.made_by,
        "summary": args.summary,
        "details": args.details,
        "tags": [t.strip() for t in (args.tags.split(",") if args.tags else []) if t.strip()],
        "severity": args.severity,
        "linked": linked,
        "prev_entry_hash": last_entry_hash(DECISION_LOG),
        "version": "0.2.3",
    }

    # Optional signature over canonical core (without entry_hash)
    if args.sign:
        if not args.priv or not args.key_id:
            raise SystemExit("--sign requires --priv and --key-id")
        msg = canonical_bytes(record_core)
        record_core["_meta"] = {
            "sig_alg": "ed25519",
            "key_id": args.key_id,
        }
        record_core["_signature"] = sign_bytes_ed25519(args.priv, msg)

    # Add entry_hash (hash of canonical core including signature fields if present)
    record_with_hash = dict(record_core)
    record_with_hash["entry_hash"] = compute_entry_hash(record_core)
    return record_with_hash

def append_record(rec: dict):
    os.makedirs(DATA_DIR, exist_ok=True)
    with open(DECISION_LOG, "a", encoding="utf-8") as f:
        f.write(json.dumps(rec, ensure_ascii=False, separators=(",", ":")) + "\n")

def main():
    ap = argparse.ArgumentParser(description="Append a Decision Record (append-only).")
    ap.add_argument("--made-by", required=True)
    ap.add_argument("--summary", required=True)
    ap.add_argument("--details", default="")
    ap.add_argument("--tags", default="")
    ap.add_argument("--severity", default="NORMAL", choices=["LOW","NORMAL","HIGH","CRITICAL"])
    ap.add_argument("--decision-id", default=None)
    ap.add_argument("--link-tail", type=int, default=5, help="How many snapshot payload_hash values to link.")
    ap.add_argument("--sign", action="store_true", help="Sign the decision record with Ed25519.")
    ap.add_argument("--priv", default=None, help="Path to Ed25519 private key (raw 32 bytes).")
    ap.add_argument("--key-id", default=None, help="Key id used for signing (for audit).")
    args = ap.parse_args()

    rec = build_record(args)
    append_record(rec)
    print(f"[decision] appended decision_id={rec['decision_id']} entry_hash={rec['entry_hash'][:12]}…")

if __name__ == "__main__":
    main()
