#!/bin/bash
set -e

echo "🔬 Aether One — Pi5 Edge Node — Asennus"
echo "========================================"
echo ""

# Tarkista Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 ei löydy. Asenna: sudo apt install python3 python3-pip python3-venv"
    exit 1
fi

echo "✓ Python3 löytyi: $(python3 --version)"

# Luo virtuaaliympäristö
if [ ! -d ".venv" ]; then
    echo "📦 Luodaan virtuaaliympäristö..."
    python3 -m venv .venv
fi

# Aktivoi ja asenna
source .venv/bin/activate
echo "📥 Asennetaan riippuvuudet..."
pip install --upgrade pip
pip install -r requirements.txt

# Buildaa TrustCore native (jos C-lähdekoodit löytyy)
if [ -f "core/trustcore_native/build.sh" ]; then
    echo "🔨 Buildi TrustCore v1.0 C-core..."
    cd core/trustcore_native
    bash build.sh || echo "⚠️  C-core build epäonnistui (ei kriittinen, Python-fallback toimii)"
    cd ../..
fi

echo ""
echo "✅ Asennus valmis!"
echo ""
echo "Seuraavat vaiheet:"
echo "  1. (Valinnainen) Konfiguroi Pi 2 Trust Server IP:"
echo "     nano core/config.py"
echo "     → Vaihda AETHER_ATTESTATION_SERVER_URL"
echo ""
echo "  2. (Valinnainen) Konfiguroi AetherCam IP (S21):"
echo "     nano sensor_reader/aethercam_reader.py"
echo "     → Vaihda DEFAULT_STREAM_URL"
echo ""
echo "  3. Käynnistä:"
echo "     ./start.sh"
echo ""
