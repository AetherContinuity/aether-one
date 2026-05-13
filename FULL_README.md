# Aether One™ — Dual Pi Architecture

Kahden Raspberry Pi:n järjestelmä joka yhdistää **trust-infrastruktuurin** ja **edge-sensorit** erillisiksi, optimoiduiksi yksiköiksi.

---

## Paketin sisältö

```
aether_one_dual_pi/
├── pi2_trust_server/          ← Trust Server (Pi 2 Model B)
│   ├── core/trustcore/        → PQC attestation server
│   ├── requirements.txt       → Minimaalinen (FastAPI + crypto)
│   ├── install.sh             → Automaattinen asennus
│   ├── start.sh               → Käynnistys
│   └── README.md              → Pi 2 -spesifiset ohjeet
│
├── pi5_edge_node/             ← Edge Node (Pi 5)
│   ├── core/                  → TrustCore client + LR/KRI engine
│   ├── sensor_reader/         → MQ-9 + AetherCam + mock fallback
│   ├── dashboards/            → Live drift monitor
│   ├── ui/                    → Web UI
│   ├── requirements.txt       → Täysi stack (sensors + attestation)
│   ├── install.sh             → Automaattinen asennus + C-build
│   ├── start.sh               → Käynnistys
│   └── README.md              → Pi 5 -spesifiset ohjeet
│
└── NETWORK_SETUP.md           ← WiFi + IP-konfiguraatio-ohje
```

---

## Arkkitehtuuri

```
    ┌──────────────────────────────────────┐
    │  TRUST LAYER (Pi 2)                  │
    │  ┌────────────────────────────────┐  │
    │  │ TrustCore Server               │  │
    │  │ - Nonce generation             │  │
    │  │ - PQC signature verification   │  │
    │  │ - Device enrollment            │  │
    │  │ - Decision hash audit          │  │
    │  └────────────────────────────────┘  │
    │  Port: 5000                          │
    │  IP: 192.168.1.50 (staattinen)       │
    └──────────────┬───────────────────────┘
                   │
                   │ WiFi (Attestation)
                   │
    ┌──────────────▼───────────────────────┐
    │  EDGE LAYER (Pi 5)                   │
    │  ┌────────────────────────────────┐  │
    │  │ Physical Sensors               │  │
    │  │ - MQ-9 (Gas, ADC)              │  │
    │  │ - AetherCam (S21 IP stream)    │  │
    │  │ - [Future: VOC, Geiger, LiDAR] │  │
    │  └──────────┬─────────────────────┘  │
    │             ▼                         │
    │  ┌────────────────────────────────┐  │
    │  │ sensor_reader module           │  │
    │  │ - Auto hardware detection      │  │
    │  │ - Mock fallback                │  │
    │  │ - Normalized 0.0-1.0 output    │  │
    │  └──────────┬─────────────────────┘  │
    │             ▼                         │
    │  ┌────────────────────────────────┐  │
    │  │ TrustCore v1.0 C-kernel        │  │
    │  │ - tc_calculate_kri()           │  │
    │  │ - tc_calculate_dissonance()    │  │
    │  └──────────┬─────────────────────┘  │
    │             ▼                         │
    │  ┌────────────────────────────────┐  │
    │  │ Aether Relay API               │  │
    │  │ - Real-time sensor endpoints   │  │
    │  │ - KRI/LR computation           │  │
    │  │ - TrustCore CLIENT             │  │
    │  └──────────┬─────────────────────┘  │
    │             │                         │
    │             ├─► Web UI               │
    │             └─► Drift Monitor        │
    │  Port: 8080                          │
    │  IP: 192.168.1.51 (tai DHCP)         │
    └──────────────────────────────────────┘
```

---

## Miksi kaksi Pi:tä?

### **Pi 2 (Trust Server) — Dedikated Trust Anchor**

✅ **Kevyt tehtävä** → vanha rauta riittää
- Ei sensoreita, ei laskentaa
- Vain attestation-operaatiot (PQC + SHA-256)
- 1GB RAM riittää mainiosti

✅ **Fyysisesti erillinen** → parempi turvallisuus
- Trust-ankkuri ei näe sensordataa suoraan
- Ei "judge in its own case" -ongelmaa
- Auditlokit erillisellä laitteella

✅ **Arkkitehtuurinen selkeys** → IP-arvo
- Muistuttaa oikeaa trust infra -jaottelua
- HSM / TPM -rinnastus
- Helpompi selittää asiakkaille / sijoittajille

### **Pi 5 (Edge Node) — Compute & Sensors**

✅ **Teho tarvitaan** → uusi rauta
- Sensorien luku (ADC, I2C, IP-stream)
- TrustCore v1.0 C-kernel (KRI, LR-D)
- Mahdollinen ML-päättely (32 TOPS suunnitelma)

✅ **Reaaliaikainen** → Pi 5:n parannettu I/O
- USB 3.0 → ulkoiset kamerat
- PCI Express → tulevat lidar/radar-moduulit
- Dual HDMI → live dashboard

---

## Nopea aloitus (Quick Start)

### 1. Pi 2 setup (5 min)

```bash
# Kopioi paketti Pi 2:lle
scp -r pi2_trust_server/ pi@<pi2_ip>:~/

# Kirjaudu Pi 2:lle
ssh pi@<pi2_ip>
cd ~/pi2_trust_server

# Asenna
./install.sh

# Aseta staattinen IP (valinnainen mutta suositus)
sudo nmcli con mod "Wired connection 1" ipv4.addresses 192.168.1.50/24
sudo nmcli con mod "Wired connection 1" ipv4.method manual
sudo nmcli con up "Wired connection 1"

# Käynnistä
./start.sh
```

### 2. Pi 5 setup (10 min)

```bash
# Kopioi paketti Pi 5:lle
scp -r pi5_edge_node/ pi@<pi5_ip>:~/

# Kirjaudu Pi 5:lle
ssh pi@<pi5_ip>
cd ~/pi5_edge_node

# Asenna
./install.sh

# Konfiguroi Pi 2 IP (jos eri kuin 192.168.1.50)
nano core/config.py
# → Vaihda AETHER_ATTESTATION_SERVER_URL

# (Valinnainen) Konfiguroi S21 IP
nano sensor_reader/aethercam_reader.py
# → Vaihda DEFAULT_STREAM_URL

# Käynnistä
./start.sh
```

### 3. Tarkista (2 min)

```bash
# Pi 5:ltä → Pi 2:lle
curl http://192.168.1.50:5000/nonce
# → {"nonce": "..."}

# Pi 5 API
curl http://localhost:8080/attestation
# → {"status": "PASS", ...}

# Pi 5 Dashboard (selaimessa)
http://<pi5_ip>:8080/ui/
```

**Valmis!** 🎉

---

## Mitä kukin paketti sisältää

### **pi2_trust_server/** (10 tiedostoa, ~50 KB)

| Tiedosto | Kuvaus |
|----------|--------|
| `core/trustcore/server.py` | Attestation server (FastAPI) |
| `core/trustcore/crypto.py` | PQC (Dilithium3) wrapper |
| `core/trustcore/tpm_wrapper.py` | TPM 2.0 support (valinnainen) |
| `requirements.txt` | FastAPI, cbor2, pycryptodome |
| `install.sh` | Asennus (venv + pip) |
| `start.sh` | Käynnistys (portti 5000) |
| `README.md` | Pi 2 -spesifiset ohjeet |

**Ei sisällä:**
- ❌ Sensoreita
- ❌ Dashboardeja
- ❌ C-kerneliä
- ❌ UI:ta

### **pi5_edge_node/** (~40 tiedostoa, ~300 KB)

| Komponentti | Kuvaus |
|-------------|--------|
| `core/aether_relay.py` | FastAPI relay (TrustCore client + sensors) |
| `core/kri_engine.py` | TrustCore v1.0 KRI laskenta |
| `core/lr_core.py` | LR (Lex Resiliens) päätöslogiikka |
| `core/trustcore/client.py` | PQC attestation client |
| `sensor_reader/mq9_reader.py` | MQ-9 kaasusensori (Explorer HAT / ADS1115) |
| `sensor_reader/aethercam_reader.py` | S21 IP-kamera stream |
| `sensor_reader/base_sensor.py` | Yhteinen sensor-rajapinta |
| `dashboards/global_drift_monitor.html` | Live dashboard (standalone) |
| `ui/web_ui.py` | FastAPI web UI (runtime-clean alkuperäinen) |
| `requirements.txt` | Täysi stack (sensors + attestation + ML) |

**Sisältää:**
- ✅ TrustCore attestation CLIENT
- ✅ Fyysiset sensorit (mock-fallback)
- ✅ C-kernel support (optional build)
- ✅ Dual UI (web + drift monitor)

---

## Tekninen yhteenveto

| Metriikka | Pi 2 | Pi 5 |
|-----------|------|------|
| **Tehtävä** | Trust anchor | Edge compute + sensors |
| **Prosessori** | ARM Cortex-A7, 900 MHz | ARM Cortex-A76, 2.4 GHz |
| **RAM** | 1 GB | 4-8 GB |
| **Verkko** | Ethernet suositus | WiFi tai Ethernet |
| **Portti** | 5000 | 8080 |
| **IP** | Staattinen suositus | DHCP ok |
| **Latenssi** | <10ms (PQC verify) | <50ms (sensor → KRI) |
| **Kuormitus** | ~5% CPU | ~20-40% CPU (sensorit + UI) |
| **Sensorit** | ❌ Ei | ✅ MQ-9 + AetherCam + mock |
| **Dashboard** | ❌ Ei | ✅ Web UI + Drift Monitor |
| **C-kernel** | ❌ Ei tarvita | ✅ TrustCore v1.0 (optional) |
| **TPM** | ⚠️ Valinnainen | ⚠️ Valinnainen |

---

## Edistyneet ominaisuudet

### A) TPM 2.0 tuki (molemmat Pi:t)

Jos Raspberry Pi:ssä on TPM-moduuli (esim. Infineon SLB 9670):

```bash
# Asenna tools
sudo apt install tpm2-tools

# Testaa
tpm2_getcap properties-fixed

# Pi 2 + Pi 5 automaattisesti käyttävät TPM:ää jos löytyy
```

### B) C-kernel build (Pi 5)

```bash
cd ~/pi5_edge_node/core/trustcore_native
bash build.sh
# → tuottaa libtrustcore.so

# Relay käyttää automaattisesti jos .so löytyy
```

### C) Systemd autostart

**Pi 2:**
```bash
sudo nano /etc/systemd/system/aether-trust.service
```
```ini
[Unit]
Description=Aether One Trust Server
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/pi2_trust_server
ExecStart=/home/pi/pi2_trust_server/.venv/bin/python -m core.trustcore.server
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable aether-trust
sudo systemctl start aether-trust
```

**Pi 5:** Sama prosessi, korvaa `core.trustcore.server` → `core.aether_relay`

---

## Tiedostojen siirto

### Tietokoneelta molemmille Pi:ille:

```bash
# Pi 2
scp -r pi2_trust_server/ pi@192.168.1.50:~/

# Pi 5
scp -r pi5_edge_node/ pi@192.168.1.51:~/
```

### USB-tikulla (jos ei SSH:ta):

1. Kopioi molemmat kansiot USB-tikulle
2. Pi 2: `cp -r /media/usb/pi2_trust_server ~/ `
3. Pi 5: `cp -r /media/usb/pi5_edge_node ~/`

---

## Liitteet

- 📄 **NETWORK_SETUP.md** — Yksityiskohtainen verkko-ohje
- 📄 **pi2_trust_server/README.md** — Pi 2 -spesifiset ohjeet
- 📄 **pi5_edge_node/README.md** — Pi 5 -spesifiset ohjeet

---

## Yhteenveto

```
✅ Pi 2 (Trust) — Vanha rauta, uusi tehtävä (attestation)
✅ Pi 5 (Edge) — Uusi rauta, raskas työ (sensorit + laskenta)
✅ Kaksi erillistä pakettia — optimoitu kummallekin
✅ Mock-fallback — toimii ilman rautaa
✅ Täysi attestation stack — PQC + TPM + decision hash
✅ Live dashboards — Web UI + Drift Monitor
✅ 15 min setup — install.sh + start.sh
```

**Aether One™ dual-Pi arkkitehtuuri on valmis käyttöön.** 🚀
