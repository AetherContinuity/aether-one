# Aether One™

**Dual Raspberry Pi Trust Infrastructure & Edge Intelligence Platform**

Kahden Raspberry Pi:n järjestelmä joka yhdistää trust-infrastruktuurin ja edge-sensorit erillisiksi, optimoiduiksi yksiköiksi.

## Project Context

```
Research Program
        │
        ▼
WP-006 — Continuity Computing
        │
        ├── WP-007 — Situational Awareness Persistence
        │
        ▼
TN-002 — DCEIN Architecture
        │
        ▼
Aether One
Reference Implementation
        │
        ├── Pi 2 — Trust Anchor
        ├── Pi 5 — Edge Compute
        └── TrustCore NX (Concept / Pre-Silicon)
```

Aether One on yksi konkreettinen **Reference Implementation** DCEIN-arkkitehtuurista (Duration-Capable Edge Intelligence Node), ei ainoa mahdollinen toteutus. `hardware/pqc-rtl/` sisältää RISC-V-vektorikiihdytettyä Dilithium/ML-DSA-kehitystyötä, joka on linjassa TrustCore NX -konseptin kanssa ja voi muodostaa sen kryptografisen perustan — tätä ei ole vielä vahvistettu piiksi asti, ja `concept/trustcore-nx/README.md` merkitsee sen avoimesti pre-silicon-konseptiksi.

- **WP-006** — [Continuity Computing](https://aethercontinuity.org/papers/wp-006-continuity-computing.html): teoreettinen perusta (päätöskapasiteetti järjestelmäinvarianttina)
- **WP-007** — [Situational Awareness Persistence](https://aethercontinuity.org/papers/wp-007-situational-awareness-persistence.html): D5-komponentin (Awareness Externalization) perustelu
- **TN-002** — [DCEIN Architecture](https://aethercontinuity.org/supplements/tn-002-dcein.html): arkkitehtoninen spesifikaatio, ECU/TAU-erottelu

## Arkkitehtuuri

```
Pi 2 (Trust Server) ←── WiFi attestation ──→ Pi 5 (Edge Node)
  PQC + SHA-256                               Sensors → KRI → UI
  Erillinen laite                             Reaaliaikainen laskenta
  Port 5000 · IP 192.168.1.50                Port 8080
```

## Sisältö

- `pi2_trust_server/` — Trust Server (Pi 2 Model B)
- `pi5_edge_node/` — Edge Node (Pi 5)
- `hardware/pqc-rtl/` — RISC-V-vektorikiihdytetty PQC-kehitystyö (RTL, ks. Project Context yllä)
- `NETWORK_SETUP.md` — Verkkokonfiguraatio

## Nopea aloitus

```bash
# Pi 2
scp -r pi2_trust_server/ pi@192.168.1.50:~/
ssh pi@192.168.1.50 "cd ~/pi2_trust_server && ./install.sh && ./start.sh"

# Pi 5
scp -r pi5_edge_node/ pi@192.168.1.51:~/
ssh pi@192.168.1.51 "cd ~/pi5_edge_node && ./install.sh && ./start.sh"

# Tarkistus
curl http://192.168.1.50:5000/nonce
curl http://192.168.1.51:8080/attestation
```

## Tekninen yhteenveto

| | Pi 2 (Trust) | Pi 5 (Edge) |
|---|---|---|
| Tehtävä | Trust anchor | Compute + sensors |
| Prosessori | ARM Cortex-A7, 900 MHz | ARM Cortex-A76, 2.4 GHz |
| RAM | 1 GB | 4–8 GB |
| Sensorit | — | MQ-9 + AetherCam |
| Dashboard | — | Web UI + Drift Monitor |
| Portti | 5000 | 8080 |

## PQC-algoritmi

Trust Server käyttää **ML-DSA-65** (Dilithium) allekirjoituksiin `liboqs`-kirjaston kautta (`oqs.Signature("ML-DSA-65")`). `hardware/pqc-rtl/rvv-dilithium/` kehittää saman algoritmiperheen RISC-V-vektorikiihdytystä — ks. Project Context yllä yhteydestä TrustCore NX -konseptiin.

---
*Aether Continuity Institute · 2026*
