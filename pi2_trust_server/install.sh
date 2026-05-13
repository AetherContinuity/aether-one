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
