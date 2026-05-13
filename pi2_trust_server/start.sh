#!/bin/bash
set -e

echo "🔐 Aether One — TrustCore Trust Server"
echo "======================================"
echo ""

# Aktivoi venv
if [ ! -d ".venv" ]; then
    echo "❌ Virtuaaliympäristö puuttuu. Aja ensin: ./install.sh"
    exit 1
fi

source .venv/bin/activate

# Näytä verkko-osoite
IP=$(hostname -I | awk '{print $1}')
echo "📡 Server IP: $IP"
echo "🔌 Server URL: http://$IP:5000"
echo ""
echo "Endpointit:"
echo "  GET  /nonce         - Hae nonce attestaatiota varten"
echo "  POST /verify        - Varmentaa allekirjoituksen"
echo "  GET  /enrolled      - Näytä rekisteröidyt laitteet"
echo ""
echo "Pysäytä: CTRL+C"
echo "Lokit: trustcore_server.log"
echo ""
echo "▶ Käynnistetään..."

# Käynnistä server
python -m core.trustcore.server
