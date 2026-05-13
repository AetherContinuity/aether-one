# Aether One™ — Kahden Pi:n verkkoasetusten ohje

Tämä ohje neuvoo yksityiskohtaisesti miten Pi 2 (Trust Server) ja Pi 5 (Edge Node) konfiguroidaan samaan WiFi-verkkoon ja kommunikoimaan keskenään.

---

## Vaihe 1: WiFi-verkon valinta

**Suositus:** Käytä samaa WiFi-verkkoa johon tietokoneesi on yhteydessä.

**Tarkista tietokoneen verkko:**
```bash
# Linuxilla / macOS:
ip route | grep default
# Windowsilla:
ipconfig
```

Esimerkki: `192.168.1.0/24` verkko, gateway `192.168.1.1`

---

## Vaihe 2: Pi 2 (Trust Server) — Staattinen IP

**Miksi staattinen IP?**
- Pi 5 tarvitsee vakaan osoitteen attestaatioon
- Helpompi debugata ja ylläpitää

### A) Kirjaudu Pi 2:lle

```bash
# Jos näyttö + näppäimistö:
# → Kirjaudu normaalisti

# Jos headless (SSH):
ssh pi@raspberrypi.local
# TAI etsi IP: nmap -sn 192.168.1.0/24
```

### B) Aseta staattinen IP

**Ethernet (suositus):**
```bash
sudo nmcli con mod "Wired connection 1" ipv4.addresses 192.168.1.50/24
sudo nmcli con mod "Wired connection 1" ipv4.gateway 192.168.1.1
sudo nmcli con mod "Wired connection 1" ipv4.dns "8.8.8.8 8.8.4.4"
sudo nmcli con mod "Wired connection 1" ipv4.method manual
sudo nmcli con up "Wired connection 1"
```

**WiFi:**
```bash
# Tarkista WiFi-yhteyden nimi:
nmcli con show

# Aseta IP (korvaa "WIFI_NAME" oikealla nimellä):
sudo nmcli con mod "WIFI_NAME" ipv4.addresses 192.168.1.50/24
sudo nmcli con mod "WIFI_NAME" ipv4.gateway 192.168.1.1
sudo nmcli con mod "WIFI_NAME" ipv4.dns "8.8.8.8 8.8.4.4"
sudo nmcli con mod "WIFI_NAME" ipv4.method manual
sudo nmcli con up "WIFI_NAME"
```

### C) Tarkista

```bash
hostname -I
# → Pitäisi näyttää: 192.168.1.50

ping google.com
# → Internet toimii
```

### D) (Valinnainen) Hostname

```bash
sudo hostnamectl set-hostname aether-trust
# Uudelleenkäynnistys:
sudo reboot
```

Nyt Pi 2 on saatavilla:
- `ssh pi@192.168.1.50`
- `ssh pi@aether-trust.local`

---

## Vaihe 3: Pi 5 (Edge Node) — DHCP tai staattinen

### A) DHCP (helpompi, suositus)

Pi 5 voi käyttää dynaamista IP:tä — **ei haittaa**, koska se on client (ei server).

Tarkista Pi 5:n IP:
```bash
hostname -I
# → esim. 192.168.1.123
```

### B) Staattinen IP (jos haluat)

Sama prosessi kuin Pi 2:lla, mutta eri IP:
```bash
sudo nmcli con mod "Wired connection 1" ipv4.addresses 192.168.1.51/24
sudo nmcli con mod "Wired connection 1" ipv4.gateway 192.168.1.1
sudo nmcli con mod "Wired connection 1" ipv4.dns "8.8.8.8"
sudo nmcli con mod "Wired connection 1" ipv4.method manual
sudo nmcli con up "Wired connection 1"

# Hostname (valinnainen):
sudo hostnamectl set-hostname aether-edge
sudo reboot
```

---

## Vaihe 4: Testaa yhteys Pi:iden välillä

### Pi 5:ltä → Pi 2:lle

```bash
# Pi 5:llä
ping 192.168.1.50
# → Pitäisi vastata

curl http://192.168.1.50:5000/nonce
# → {"nonce": "abc123..."}
```

### Pi 2:ltä → Pi 5:lle

```bash
# Pi 2:lla
ping <pi5_ip>
# → Pitäisi vastata
```

---

## Vaihe 5: Firewall-tarkistus

Jos `ping` toimii mutta `curl` ei:

### Pi 2 (Trust Server):

```bash
sudo ufw status
# Jos aktiivinen:
sudo ufw allow 5000/tcp
sudo ufw reload
```

### Pi 5 (Edge Node):

```bash
sudo ufw status
# Jos aktiivinen:
sudo ufw allow 8080/tcp
sudo ufw reload
```

---

## Vaihe 6: Konfiguroi Pi 5 → Pi 2 attestation

### Pi 5:llä, muokkaa `core/config.py`:

```python
# Ennen:
AETHER_ATTESTATION_SERVER_URL = "http://localhost:5000"

# Jälkeen:
AETHER_ATTESTATION_SERVER_URL = "http://192.168.1.50:5000"

# Varmista myös:
AETHER_ATTESTATION_ENABLED = True
AETHER_ATTESTATION_INTERVAL = 10  # sekuntia
```

**TAI** käytä environment variablea:
```bash
export AETHER_ATTESTATION_SERVER_URL="http://192.168.1.50:5000"
./start.sh
```

---

## Vaihe 7: Käynnistä molemmat

### Terminaali 1 (Pi 2):
```bash
ssh pi@192.168.1.50
cd ~/pi2_trust_server
./start.sh
```

Näet:
```
🔐 Aether One — TrustCore Trust Server
======================================
📡 Server IP: 192.168.1.50
🔌 Server URL: http://192.168.1.50:5000
```

### Terminaali 2 (Pi 5):
```bash
ssh pi@<pi5_ip>
cd ~/pi5_edge_node
./start.sh
```

Odota ~10 sekuntia → näet Pi 5:n logeissa:
```
🔐 Attestation: PASS
```

---

## Vaihe 8: Tarkista dashboardista

### Web UI (Pi 5):
```
http://<pi5_ip>:8080/ui/
```

→ Attestation status pitäisi näyttää `PASS` (vihreä)

### API (Pi 5):
```bash
curl http://<pi5_ip>:8080/attestation
```

Vastaus:
```json
{
  "status": "PASS",
  "device_id": "abc123...",
  "tpm_available": false,
  "decision_hash": "def456..."
}
```

---

## Vianetsintä

### "Connection refused" (Pi 5 → Pi 2)

**Tarkista:**
1. Pi 2 server pyörii: `ps aux | grep trustcore`
2. Firewall sallii: `sudo ufw status`
3. Verkko toimii: `ping 192.168.1.50`

**Debug Pi 2:lla:**
```bash
# Tarkista mikä kuuntelee portissa 5000:
sudo lsof -i :5000
```

### "Attestation: FAIL"

**Yleisimmät syyt:**
1. Pi 2 server ei vastaa → tarkista yhteys
2. Device ei ole enrollattu → Pi 2 server auto-enrollaa ensimmäisellä kerralla
3. PQC-avaimet väärin → poista `trustcore_keys/` ja käynnistä uudelleen

**Debug:**
```bash
# Pi 2:lla, tarkista lokit:
tail -f trustcore_server.log

# Pi 5:llä, tarkista lokit:
# (näkyy start.sh terminaalissa)
```

### "Attestation: UNKNOWN"

→ Pi 5 ei ole vielä yrittänyt attestaatiota.
Odota 10-30 sekuntia (määräytyy `AETHER_ATTESTATION_INTERVAL` mukaan).

**Pakota heti:**
```bash
# Pi 5:llä
curl http://localhost:8080/attestation
# → Triggeröi attestation loop
```

---

## Staattinen IP -yhteenveto

| Laite | IP | Portti | URL |
|-------|----|----|-----|
| Pi 2 (Trust) | 192.168.1.50 | 5000 | http://192.168.1.50:5000 |
| Pi 5 (Edge) | 192.168.1.51 (tai DHCP) | 8080 | http://192.168.1.51:8080 |

---

## Edistyneet asetukset

### A) mDNS (helpompi kuin IP-osoitteet)

Asenna Avahi (yleensä jo mukana):
```bash
sudo apt install avahi-daemon
sudo systemctl enable avahi-daemon
sudo systemctl start avahi-daemon
```

Nyt laitteet löytyvät:
- `aether-trust.local` (Pi 2)
- `aether-edge.local` (Pi 5)

**Konfiguroi Pi 5:**
```python
AETHER_ATTESTATION_SERVER_URL = "http://aether-trust.local:5000"
```

### B) Port forwarding (jos haluat käyttää internetistä)

**Tämä on turvallisuusriski — ei suositella tuotannossa.**

1. Router admin-paneeli (yleensä http://192.168.1.1)
2. Port Forwarding / Virtual Server
3. Lisää:
   - Pi 2: External 5000 → Internal 192.168.1.50:5000
   - Pi 5: External 8080 → Internal 192.168.1.51:8080

Nyt käytettävissä internetistä:
- `http://<router_public_ip>:5000` → Pi 2
- `http://<router_public_ip>:8080` → Pi 5

**Parempi tapa:** VPN (Tailscale, WireGuard)

---

**Verkkoasetukset valmiit! Kahden Pi:n Aether One -järjestelmä on nyt täysin toimiva.** 📡
