# PQC RTL — NTT256 Kiihdytin (TrustCore NX -polku)

SystemVerilog RTL-prototyyppi NTT256-kiihdyttimelle.
Pi 5 toimii simulointiympäristönä ennen FPGA-siirtymää.

## Tila

| Milestone | Kuvaus | Tila |
|-----------|--------|------|
| M1 | 2-Lane cluster + conflict validation | ✅ VALMIS |
| M2 | 256-point NTT korrektisuus Pi5:llä | 🟡 KÄYNNISSÄ |
| M3 | FPGA-prototyyppi (Pynq-Z2 / Basys 3) | Q2 2026 |
| M4 | TrustCore NX integraatio (7nm) | Q3 2026 |

## Arkkitehtuuri

- Modular Montgomery Multiplier (pipelined)
- Banked Memory Subsystem (4-bank, rinnakkainen)
- Round-Robin Arbiter (deterministinen)
- 2-Lane Cluster Top

## Toolchain

- Icarus Verilog (ARM64, Pi 5)
- GTKWave (waveform)
- Python GENERATE_VECTORS.py → .memh → SV testbench

## Yhteys TrustCore NX:ään

NTT256 on Kyber/Dilithium PQC-operaatioiden ydin.
Tämä RTL siirtyy suoraan TrustCore NX ASIC:iin.
