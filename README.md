# Aether One™

**Dual Raspberry Pi Trust Infrastructure & Edge Intelligence Platform**

Kahden Raspberry Pi:n järjestelmä joka yhdistää trust-infrastruktuurin ja edge-sensorit erillisiksi, optimoiduiksi yksiköiksi.

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
- `NETWORK_SETUP.md` — Verkko­konfiguraatio

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

## Yhteys ACI-projektiin

Perustuu [TN-002 DCEIN](https://aethercontinuity.org) -konseptiin (Duration-Capable Edge Intelligence Node).  
Dokumentaatio: [aethercontinuity.org/aether-one/](https://aethercontinuity.org/aether-one/)

---
*Aether Continuity Institute · 2026*
