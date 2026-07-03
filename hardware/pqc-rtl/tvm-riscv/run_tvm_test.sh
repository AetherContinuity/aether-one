#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/3] Rakennetaan malli (x86-referenssi + RISC-V-ristikaannos)..."
python3 build_model.py

echo "[2/3] Kaannetaan C-harness ja linkataan malliin..."
riscv64-linux-gnu-gcc -O2 harness.c -o harness_riscv -L. -l:model_riscv.so -Wl,-rpath,'$ORIGIN'

echo "[3/3] Ajetaan QEMU:ssa..."
qemu-riscv64-static -L /usr/riscv64-linux-gnu -E LD_LIBRARY_PATH=. ./harness_riscv
