#!/bin/bash
set -e

echo "🔐 Aether One — Pi 2 Trust Server — Asennus"
echo "============================================="
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

# PQC: liboqs (C-kirjasto) + liboqs-python. Ilman tata crypto.py:n
# `import oqs` epaonnistuu ja attestaatio toimii ILMAN ML-DSA-65-
# allekirjoitusta. Asennus keskeytyy, jos itsetesti ei mene lapi.
echo "🔑 Tarkistetaan PQC (liboqs, ML-DSA-65)..."
bash "$(dirname "$0")/install_liboqs.sh"

echo ""
echo "✅ Asennus valmis!"
echo ""
echo "Käynnistä palvelin:"
echo "  ./start.sh"
echo ""
echo "Tai manuaalisesti:"
echo "  source .venv/bin/activate"
echo "  python -m core.trustcore.server"
echo ""
