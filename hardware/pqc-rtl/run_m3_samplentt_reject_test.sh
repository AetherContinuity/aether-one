#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/3] Generoidaan vektorit..."
python3 m2-golden/gen_samplentt_reject_vectors.py

echo "[2/3] Kaannetaan RTL + testipenkki..."
iverilog -g2012 -o sim/m3_samplentt_reject_sim rtl/pqc_samplentt_reject.sv tb/pqc_samplentt_reject_tb.sv

echo "[3/3] Ajetaan simulaatio..."
vvp sim/m3_samplentt_reject_sim
