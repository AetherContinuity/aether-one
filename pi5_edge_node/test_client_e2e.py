#!/usr/bin/env python3
"""test_client_e2e.py - TrustCoreClient (TPM+ML-DSA) HTTP:n yli todentajaa vasten.

Kulku: vienti -> käsinrekisteröinti admin-CLI:llä -> /nonce -> /verify.
Odotus swtpm:llä (docs/VAIHE1-ENNAKKO.md): A PARTIAL, B UNSUPPORTED,
P UNSUPPORTED, Q VERIFIED, eikä yhteistä status-kenttää.
Negatiivikontrolli: rekisteröimätön laite saa samalta palvelimelta UNKNOWN.

Palvelin: TRUSTCORE_DATA_DIR=$DATA uvicorn core.trustcore.server:APP --port 8100
"""
import asyncio
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from core.trustcore.client import TrustCoreClient, TrustCoreConfig  # noqa: E402

BASE = "http://127.0.0.1:8100"
DATA = os.environ.get("TRUSTCORE_DATA_DIR", ".trustcore_server")
WANT = {"A": "PARTIAL", "B": "UNSUPPORTED", "P": "UNSUPPORTED", "Q": "VERIFIED"}


def results(resp):
    return {k: resp.get("claims", {}).get(k, {}).get("result") for k in "ABPQ"}


async def main() -> int:
    for d in ("test_client_keys", "test_client_keys_unenrolled"):
        shutil.rmtree(d, ignore_errors=True)

    client = TrustCoreClient(TrustCoreConfig(server_url=BASE, keydir="test_client_keys"))
    if client.tpm is None:
        print(f"FAIL: TPM ei käytettävissä: {client.tpm_init_error}")
        return 1

    exp = Path("test_enrollment.json")
    exp.write_text(json.dumps(client.export_enrollment(platform="swtpm", tpm_kind="swtpm")))
    r = subprocess.run([sys.executable, "-m", "core.trustcore.admin", "--data-dir", DATA,
                        "enroll", str(exp), "--replace"], capture_output=True, text=True)
    print(r.stdout.strip(), r.stderr.strip())
    if r.returncode != 0:
        print("FAIL: rekisteröinti epäonnistui")
        return 1

    fails = []
    resp = await client.attest({"temperature_c": 21.5, "status": "nominal"})
    print(f"Rekisteröity: {json.dumps(resp, ensure_ascii=False)}")
    if "status" in resp:
        fails.append("vastauksessa yhteinen status-kenttä")
    if results(resp) != WANT:
        fails.append(f"rekisteröity: odotettu {WANT}, saatu {results(resp)}")

    other = TrustCoreClient(TrustCoreConfig(server_url=BASE, keydir="test_client_keys_unenrolled"))
    resp2 = await other.attest({"status": "nominal"})
    print(f"Rekisteröimätön: {results(resp2)}")
    if results(resp2) != dict.fromkeys("ABPQ", "UNKNOWN"):
        fails.append(f"rekisteröimätön: odotettu kaikki UNKNOWN, saatu {results(resp2)}")

    for f in fails:
        print("FAIL:", f)
    if not fails:
        print("OK: HTTP-polku, käsinrekisteröinti ja väitekohtainen vastaus")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
