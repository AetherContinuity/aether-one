#!/usr/bin/env python3
"""TrustCore v0.1 – TPM2 wrapper using tpm2-tools."""

from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path
from typing import Dict, Iterable, Optional


class TPMError(RuntimeError):
    pass


class TPMWrapper:
    def __init__(self, ak_handle: str = "0x81000000"):
        self.ak_handle = ak_handle
        self._check_tools()

    def _check_tools(self) -> None:
        try:
            subprocess.run(["tpm2_getcap", "properties-fixed"], check=True, capture_output=True)
        except Exception as e:
            raise TPMError("TPM not available or tpm2-tools missing") from e

    def _run(self, cmd: list[str]) -> subprocess.CompletedProcess[str]:
        try:
            return subprocess.run(cmd, check=True, capture_output=True, text=True)
        except subprocess.CalledProcessError as e:
            raise TPMError(e.stderr.strip() or "TPM command failed") from e

    def get_pcrs(self, bank: str = "sha256", indices: Iterable[int] = range(0, 11)) -> Dict[str, bytes]:
        out: Dict[str, bytes] = {}
        for i in indices:
            res = self._run(["tpm2_pcrread", f"{bank}:{i}"])
            hexval: Optional[str] = None
            for line in res.stdout.splitlines():
                line = line.strip()
                if line.startswith("0x"):
                    hexval = line[2:]
                    break
                pos = line.find("0x")
                if pos >= 0:
                    hexval = line[pos + 2 :].strip()
                    break
            if hexval:
                out[f"pcr{i}"] = bytes.fromhex(hexval)
        return out

    def quote(
        self,
        nonce: bytes,
        pcr_selection: str = "sha256:0,1,2,3,4,5,6,7,10",
    ) -> Dict[str, bytes]:
        with tempfile.TemporaryDirectory() as td:
            td_path = Path(td)
            nonce_file = td_path / "nonce.bin"
            quote_file = td_path / "quote.bin"
            sig_file = td_path / "sig.bin"
            pkey_file = td_path / "pkey.bin"
            nonce_file.write_bytes(nonce)

            self._run(
                [
                    "tpm2_quote",
                    "-c",
                    self.ak_handle,
                    "-l",
                    pcr_selection,
                    "-q",
                    str(nonce_file),
                    "-m",
                    str(quote_file),
                    "-s",
                    str(sig_file),
                    "-o",
                    str(pkey_file),
                ]
            )

            return {
                "quote_data": quote_file.read_bytes(),
                "signature": sig_file.read_bytes(),
                "pubkey": pkey_file.read_bytes(),
            }
