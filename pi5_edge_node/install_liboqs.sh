#!/bin/bash
# liboqs (C-kirjasto) + liboqs-python — ML-DSA-65:n allekirjoitus.
#
# MIKSI ERILLINEN SKRIPTI
# core/trustcore/crypto.py tekee `import oqs`. Jos tuonti epaonnistuu,
# oqs = None ja palvelin kaynnistyy ILMAN PQC-allekirjoitusta.
# requirements.txt ei voi asentaa C-kirjastoa, joten se rakennetaan tassa.
# Sama minimikaannos kuin CI:ssa (.github/workflows/verify.yml): vain
# ML-DSA-65, OpenSSL kaytossa.
#
# liboqs:n versio valitaan asennetun liboqs-python-paketin mukaan, jotta
# kirjasto ja kaare tasmaavat. Jos vastaavaa tagia ei ole, kaytetaan
# liboqs:n paahaaraa ja tulostetaan varoitus.
#
# Kaytto:  ./install_liboqs.sh        (ajetaan venv aktivoituna; install.sh
#                                      kutsuu tata automaattisesti)
# Ymparistomuuttujat:
#   LIBOQS_PREFIX   asennuspolku (oletus /usr/local)
#   LIBOQS_JOBS     rinnakkaisten kaannosten maara (oletus 2 — Pi 2:n
#                   1 Gt muisti ei riita `nproc`-maaraan)
set -euo pipefail

PREFIX="${LIBOQS_PREFIX:-/usr/local}"
JOBS="${LIBOQS_JOBS:-2}"
SUDO=""
if [ "$(id -u)" -ne 0 ] && [ ! -w "$PREFIX" ]; then SUDO="sudo"; fi

selftest() {
python3 - <<'PY'
import sys
try:
    import oqs
    with oqs.Signature("ML-DSA-65") as s:
        pk = s.generate_keypair()
        sig = s.sign(b"aether-one selftest")
    with oqs.Signature("ML-DSA-65") as v:
        ok = v.verify(b"aether-one selftest", sig, pk)
    sys.exit(0 if ok else 1)
except Exception as exc:
    print(f"  ({type(exc).__name__}: {exc})", file=sys.stderr)
    sys.exit(1)
PY
}

if selftest 2>/dev/null; then
    echo "liboqs: ML-DSA-65 toimii jo — ei tehda mitaan."
    exit 0
fi

for tool in git cmake ninja cc; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Puuttuu: $tool"
        echo "Asenna: sudo apt install -y git cmake ninja-build build-essential libssl-dev"
        exit 1
    fi
done

echo "liboqs: asennetaan liboqs-python..."
pip install --quiet liboqs-python

VER="$(pip show liboqs-python 2>/dev/null | awk '/^Version:/{print $2}')"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "liboqs: haetaan lahdekoodi (liboqs-python $VER)..."
# liboqs-python 0.16.0.1 -> liboqs-tagi 0.16.0 (kaareen oma neljas numero pois)
TAG="$(echo "$VER" | cut -d. -f1-3)"
if git clone --quiet --depth 1 --branch "$TAG" https://github.com/open-quantum-safe/liboqs.git "$WORK/liboqs" 2>/dev/null; then
    echo "liboqs: tagi $TAG"
else
    echo "liboqs: tagia $TAG ei loytynyt — kaytetaan paahaaraa (versiot voivat poiketa)."
    git clone --quiet --depth 1 https://github.com/open-quantum-safe/liboqs.git "$WORK/liboqs"
fi

echo "liboqs: kaannetaan (vain ML-DSA-65, $JOBS rinnakkaista; Pi 2:lla useita minuutteja)..."
cmake -S "$WORK/liboqs" -B "$WORK/build" -GNinja \
    -DOQS_MINIMAL_BUILD="SIG_ml_dsa_65" -DOQS_USE_OPENSSL=ON \
    -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=Release \
    -DOQS_BUILD_ONLY_LIB=ON -DCMAKE_INSTALL_PREFIX="$PREFIX" >/dev/null
ninja -C "$WORK/build" -j"$JOBS" >/dev/null
$SUDO ninja -C "$WORK/build" install >/dev/null
if command -v ldconfig >/dev/null 2>&1; then $SUDO ldconfig || true; fi

if selftest; then
    echo "liboqs: ML-DSA-65 allekirjoitus ja verifiointi toimivat."
else
    echo "VIRHE: liboqs asennettiin, mutta ML-DSA-65-itsetesti epaonnistui."
    echo "Tarkista, etta $PREFIX/lib on kirjastopolulla (ldconfig / LD_LIBRARY_PATH)."
    exit 1
fi
