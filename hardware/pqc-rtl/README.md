# PQC RTL — NTT256 Kiihdytin (TrustCore NX -polku)

SystemVerilog RTL-prototyyppi NTT256-kiihdyttimelle.
Pi 5 toimii simulointiympäristönä ennen FPGA-siirtymää.

## Tila

| Milestone | Kuvaus | Tila |
|-----------|--------|------|
| M1 | 2-Lane cluster + conflict validation | ❌ EI TODENNETTU — ks. alla |
| M2 | 256-point NTT korrektisuus Pi5:llä | ⛔ EI ALOITETTU (riippuu M1:stä) |
| M3 | FPGA-prototyyppi (Pynq-Z2 / Basys 3) | Q2 2026 |
| M4 | TrustCore NX integraatio (7nm) | Q3 2026 |

**Huomio (2026-07-02):** Tässä hakemistossa ei ole yhtään `.sv`-lähdetiedostoa
`rtl/`-alla. Aiemmat statusdokumentit (neljä pakettia, 2026-02) merkitsivät
M1:n valmiiksi, mutta `sim/verify_all.sh` epäonnistuu suoraan ensimmäisessä
askeleessa: `ERROR: rtl/*.sv not found`. Testipenkit (`tb/*.sv`) ja Python-
golden-malli (`GENERATE_VECTORS.py`, Kyber-NTT + Montgomery-reduktio) ovat
olemassa ja vaikuttavat oikeilta, mutta niillä ei ole mitään mitä vastaan
verrata. M1-status palautetaan "VALMIS"-tilaan vasta kun `rtl/*.sv` on
olemassa JA `sim/verify_all.sh conflict` on ajettu vihreäksi CI:ssä
(ks. `.github/workflows/verify.yml`), ei käsin kirjoitettuna.

## Arkkitehtuuri (suunniteltu, ei toteutettu)

- Modular Montgomery Multiplier (pipelined)
- Banked Memory Subsystem (4-bank, rinnakkainen)
- Round-Robin Arbiter (deterministinen)
- 2-Lane Cluster Top

## Toolchain

- Icarus Verilog (ARM64, Pi 5)
- GTKWave (waveform)
- Python GENERATE_VECTORS.py → .memh → SV testbench (golden-malli olemassa)

## Yhteys TrustCore NX:ään

NTT256 on Kyber/Dilithium PQC-operaatioiden ydin.
Tämä RTL siirtyy suoraan TrustCore NX ASIC:iin — kun se on olemassa.

