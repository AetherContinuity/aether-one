#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/3] Generoidaan vektorit..."
python3 gen_vectors.py

echo "[2/3] Ristikaannetaan RVV-koodi..."
riscv64-linux-gnu-gcc -march=rv64gcv -O2 mont_rvv.c -o mont_rvv

echo "[3/3] Ajetaan QEMU:ssa (VLEN=256, sitten VLEN=128 - molemmat testataan)..."
echo "-- VLEN=256 --"
qemu-riscv64-static -cpu rv64,v=true,vlen=256,elen=64 -L /usr/riscv64-linux-gnu ./mont_rvv
echo "-- VLEN=128 (oletus) --"
qemu-riscv64-static -L /usr/riscv64-linux-gnu ./mont_rvv
