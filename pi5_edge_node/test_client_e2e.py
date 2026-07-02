#!/usr/bin/env python3
"""test_client_e2e.py - TrustCoreClient (TPM+PQC) oikeaa palvelinta vasten."""
import asyncio
import sys
import shutil
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from core.trustcore.client import TrustCoreClient, TrustCoreConfig

BASE = "http://127.0.0.1:8100"


async def main():
    keydir = Path("test_client_keys")
    if keydir.exists():
        shutil.rmtree(keydir)

    cfg = TrustCoreConfig(server_url=BASE, keydir=str(keydir), policy_id="policy_e2e_test")
    client = TrustCoreClient(cfg)

    print(f"TPM saatavilla: {client.tpm_available}")
    if not client.tpm_available:
        print("FAIL: TPM ei ole saatavilla - swtpm ei vastaa")
        sys.exit(1)

    sensor_state = {"temperature_c": 21.5, "status": "nominal"}
    result = await client.attest(sensor_state)
    print(f"Attestaation tulos: {result}")

    if result.get("status") != "PASS":
        print("FAIL: attestaatio ei lapaissyt")
        sys.exit(1)

    print("PASS: TPM-quote + PQC-allekirjoitus + HTTP-attestaatio onnistui paasta paahan")


if __name__ == "__main__":
    asyncio.run(main())
