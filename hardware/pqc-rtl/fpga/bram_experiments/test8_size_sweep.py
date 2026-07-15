#!/usr/bin/env python3
"""Kokeilu 8: kokoraja-analyysi - milla muistikoolla (entries x
leveys) Yosys alkaa inferoida DP16KD:n hajautetun RAM:n sijaan,
yhdella yksinkertaisella 1w+1r-muistilla (sama perusrakenne kuin
kokeessa 1, joka toimi 256x16-koolla)."""

import subprocess
import os

sizes = [16, 32, 64, 128, 256, 512]
results = {}

for n in sizes:
    aw = max(1, (n - 1).bit_length())
    rtl = f'''
module test_size_{n} (
    input  logic clk,
    input  logic we,
    input  logic [{aw-1}:0] waddr,
    input  logic [15:0] wdata,
    input  logic re,
    input  logic [{aw-1}:0] raddr,
    output logic [15:0] rdata
);
  logic [15:0] mem [0:{n-1}];
  always_ff @(posedge clk) begin
    if (we) mem[waddr] <= wdata;
  end
  always_ff @(posedge clk) begin
    if (re) rdata <= mem[raddr];
  end
endmodule
'''
    fname = f"/tmp/test_size_{n}.sv"
    with open(fname, "w") as f:
        f.write(rtl)

    log = f"/tmp/test_size_{n}.log"
    subprocess.run(
        ["yosys", "-q", "-l", log, "-p",
         f"read_verilog -sv {fname}; synth_ecp5 -top test_size_{n} -json /tmp/test_size_{n}.json"],
        timeout=60
    )
    with open(log) as f:
        content = f.read()
    dp16kd = "DP16KD" in content
    trellis_dpr = "TRELLIS_DPR16X4" in content
    results[n] = "DP16KD" if dp16kd else ("TRELLIS_DPR16X4" if trellis_dpr else "MUU/EI KUMPIKAAN")

for n, r in results.items():
    print(f"{n:4d} alkiota x 16 bittia ({n*16:6d} bittia yhteensa): {r}")
