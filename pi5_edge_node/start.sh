#!/bin/bash
set -e

echo "🔬 Aether One — Pi5 Edge Node"
echo "=============================="
echo ""

# Aktivoi venv
if [ ! -d ".venv" ]; then
    echo "❌ Virtuaaliympäristö puuttuu. Aja ensin: ./install.sh"
    exit 1
fi

source .venv/bin/activate

# Näytä verkko-osoite
IP=$(hostname -I | awk '{print $1}')
echo "📡 Edge Node IP: $IP"
echo "🔌 API URL: http://$IP:8080"
echo "🌐 Dashboard: http://$IP:8080/ui/"
echo "📊 Drift Monitor: file://$(pwd)/dashboards/global_drift_monitor.html"
echo ""
echo "API Endpointit:"
echo "  GET  /health                - Health check"
echo "  GET  /sensors               - Mock sensor state (legacy)"
echo "  GET  /sensor/mq9            - MQ-9 kaasusensori"
echo "  GET  /sensor/aethercam      - AetherCam IP-kamera"
echo "  GET  /node_status_realtime  - Live KRI + sensorit"
echo "  GET  /kri                   - TrustCore KRI status"
echo "  GET  /lr                    - LR päätöstila"
echo "  GET  /attestation           - Attestation status"
echo ""
echo "Pysäytä: CTRL+C"
echo ""
echo "▶ Käynnistetään..."

# Käynnistä relay
python -m core.aether_relay
