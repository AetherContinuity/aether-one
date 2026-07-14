# Aether One™ — Roadmap

## Taso 1: Prototyyppi (valmis)
- [x] Pi 2 Trust Server (PQC attestation, Dilithium3)
- [x] Pi 5 Edge Node (KRI/LR, MQ-9, AetherCam)
- [x] TrustCore v1.0 C-kernel
- [x] Web UI + Drift Monitor

## Taso 2: FPGA-validointi
- [x] RTL TrustCore NX (SystemVerilog) — **M3 valmis (2026-07-14):**
      taydellinen ML-KEM-512 (FIPS 203) toiminnallisesti verifioituna
      RTL:ssa (KeyGen/Encaps/Decaps, kaikki primitiivit itsenaisesti
      todennettu + koko ketju regressiotestattu 1000 satunnaisella
      syotteella). Ks. hardware/pqc-rtl/ - ei viela ECP5-spesifista
      resurssi-/ajoitusraporttia (M4:n oma tyo).
- [ ] RVV 1.0 toolchain + TVM
- [ ] Kyber/Dilithium RVV-optimointi
- [ ] FPGA bring-up (Xilinx Versal / Intel Agilex)

## Taso 3: ASIC
- [ ] Gate-level implementation
- [ ] 7nm engineering sample
- [ ] Patentti (v0.9 → filing)

## Taso 4: Laite
- [ ] Hardware device -konseptin spesifikaatio
- [ ] Valmistuskumppani
