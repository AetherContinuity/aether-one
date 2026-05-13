# TrustCore NX — Custom RISC-V SoC Concept

**Status: Concept / Pre-Silicon**

## Spesifikaatio (tavoitetila)

| Komponentti | Kuvaus |
|-------------|--------|
| Prosessori | 12-ydin RISC-V "AetherCore" |
| Performance cores | 4× RV64GC + Vector (RVV 1.0) |
| Efficiency cores | 8× RV32IMC |
| Neural coprocessor | 32 TOPS |
| PQC accelerators | Kyber + Dilithium (RVV-kiihdytetty) |
| Valmistusprosessi | 7nm FinFET (tavoite) |
| TPM | 2.0 integroitu |

## Polku silikoniin

1. ✅ Ohjelmistoprototyyppi (Pi stack)
2. 🔲 FPGA-prototyyppi (Xilinx Versal / Intel Agilex)
3. 🔲 RTL (SystemVerilog, RVV 1.0 + PQC cores)
4. 🔲 Gate-level (Synopsys / Cadence)
5. 🔲 Engineering sample 7nm

Dokumentaatio: katso repo-juuren PDF-tiedostot.
