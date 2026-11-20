# Aether One™ Dual-Pi — QUICK START

Ennen `install.sh`:ta: `sudo apt install -y git cmake ninja-build build-essential libssl-dev`.
`install.sh` rakentaa liboqs:n (ML-DSA-65) ja ajaa itsetestin; ARM-laitteella (Pi) asennusta ei ole testattu.

---

## Vaihe 1: Hae repo

```bash
git clone https://github.com/AetherContinuity/aether-one.git
cd aether-one
```

Pi-ohjelmistot ovat repon juuressa:
```
pi2_trust_server/       ← Kopioi Pi 2:lle
pi5_edge_node/          ← Kopioi Pi 5:lle
README.md               ← Tila ja rajaukset
NETWORK_SETUP.md        ← Verkko-ohjeet
```

Vaihtoehtoisesti kloonaa repo suoraan kummallekin Pi:lle ja ohita vaihe 2.

---

## Vaihe 2: Siirrä Pi:lle

### Vaihtoehto A: SSH (helpoin)

```bash
# Pi 2
scp -r pi2_trust_server/ pi@<pi2_ip>:~/

# Pi 5
scp -r pi5_edge_node/ pi@<pi5_ip>:~/
```

### Vaihtoehto B: USB-tikku

1. Kopioi `pi2_trust_server/` USB-tikulle
2. Pi 2:lla: `cp -r /media/usb/pi2_trust_server ~/`
3. Toista Pi 5:lle

---

## Vaihe 3: Asenna ja käynnistä

### Pi 2 (Trust Server):

```bash
ssh pi@<pi2_ip>
cd ~/pi2_trust_server
./install.sh
./start.sh
```

Näet:
```
🔐 Aether One — TrustCore Trust Server
======================================
📡 Server IP: 192.168.1.50
🔌 Server URL: http://192.168.1.50:5000
```

**Jätä terminaali pyörimään!**

### Pi 5 (Edge Node):

Uusi terminaali:
```bash
ssh pi@<pi5_ip>
cd ~/pi5_edge_node

# Konfiguroi Pi 2 IP (jos eri kuin 192.168.1.50)
nano core/config.py
# → Vaihda AETHER_ATTESTATION_SERVER_URL

./install.sh
./start.sh
```

Näet:
```
🔬 Aether One — Pi5 Edge Node
==============================
📡 Edge Node IP: 192.168.1.51
🔌 API URL: http://192.168.1.51:8080
```

---

## Vaihe 4: Testaa

### Terminaalista:

```bash
# Pi 5:ltä → Pi 2:lle
curl http://192.168.1.50:5000/nonce
# → {"nonce": "abc123..."}

# Pi 5 API
curl http://localhost:8080/attestation
# → {"status": "A:PARTIAL B:UNSUPPORTED P:UNSUPPORTED Q:VERIFIED", "claims": {...}, ...}
#   (väitekohtainen; ei PASS-tilaa, docs/ATTESTATION-LEVELS.md. Laite on ensin
#   rekisteröitävä käsin: pi2_trust_server/README.md)

# Sensorit
curl http://localhost:8080/sensor/mq9
# → {"source": "mock", "normalized": 0.6234, ...}
```

### Selaimessa (tietokoneelta tai Pi 5:ltä):

**Web UI:**
```
http://<pi5_ip>:8080/ui/
```

**Swagger API:**
```
http://<pi5_ip>:8080/docs
```

---

## Ongelmanratkaisu

### "Connection refused" (Pi 5 → Pi 2)

1. Tarkista Pi 2 pyörii: `ps aux | grep trustcore`
2. Tarkista verkko: `ping 192.168.1.50`
3. Tarkista firewall: `sudo ufw status`

### "Attestation: FAIL"

1. Odota 10-30 sekuntia (attestation-intervalli)
2. Tarkista Pi 2 lokit: `tail -f ~/pi2_trust_server/trustcore_server.log`
3. Force retry: `curl http://localhost:8080/attestation`

### "Sensors not initialized"

→ Restart: `./start.sh`

### Mock-data näkyy vaikka sensori on kiinni

→ Asenna kirjastot:
```bash
# MQ-9 (Explorer HAT):
pip install explorerhat

# AetherCam (kamera):
# Ei tarvitse mitään, pelkkä IP riittää
```

---

## Seuraavat askeleet

**Kun molemmat Pi:t pyörivät:**

1. **Avaa dashboard:** `http://<pi5_ip>:8080/ui/`
2. **Lue täysi dokumentaatio:** `README.md`
3. **Konfiguroi verkko:** `NETWORK_SETUP.md` (staattinen IP, mDNS)
4. **Lisää oikeat sensorit:**
   - MQ-9: Explorer HAT tai ADS1115
   - S21: IP Webcam -sovellus

---

## Tarvitsetko apua?

- 📄 **README.md** — Täysi tekninen dokumentaatio
- 📄 **NETWORK_SETUP.md** — WiFi + IP -konfiguraatio
- 📄 **pi2_trust_server/README.md** — Pi 2 -spesifit ohjeet
- 📄 **pi5_edge_node/README.md** — Pi 5 -spesifit ohjeet

---

Tila ja rajaukset: `README.md`.
