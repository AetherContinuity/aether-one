#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

REF_DIR=../../../.dilithium-ref

if [ ! -d "$REF_DIR" ]; then
  echo "[1/5] Haetaan pq-crystals/dilithium-referenssi..."
  git clone --depth 1 https://github.com/pq-crystals/dilithium.git "$REF_DIR"
else
  echo "[1/5] Referenssi loytyi jo."
fi

echo "[2/5] Poimitaan zeta-taulukko ohjelmallisesti (ei kasin kopioitu)..."
python3 - << 'PYEOF'
import re
src = open("../../../.dilithium-ref/ref/ntt.c").read()
m = re.search(r'zetas\[N\] = \{([^}]*)\}', src, re.S)
nums = [int(x) for x in m.group(1).replace("\n", " ").split(",") if x.strip()]
assert len(nums) == 256, f"odotettiin 256 zetaa, saatiin {len(nums)}"
with open("zetas.h", "w") as f:
    f.write("static const int32_t ZETAS[256] = {" + ",".join(map(str, nums)) + "};\n")
print("zetas.h kirjoitettu,", len(nums), "arvoa")
PYEOF

echo "[3/5] Kaannetaan ja ajetaan oikea referenssi -> golden-vektorit..."
cp "$REF_DIR/ref/reduce.c" "$REF_DIR/ref/reduce.h" "$REF_DIR/ref/params.h" \
   "$REF_DIR/ref/config.h" "$REF_DIR/ref/ntt.c" "$REF_DIR/ref/ntt.h" .
gcc -O2 driver.c -o driver
./driver > /dev/null
rm -f reduce.c reduce.h params.h config.h ntt.c ntt.h  # ei tallenneta kopioita, vain golden-tuloste

echo "[4/5] Kaannetaan RVV-toteutus ja testataan Montgomery erikseen..."
riscv64-linux-gnu-gcc -march=rv64gcv -O2 mont_dilithium_rvv.c test_mont_dilithium.c -o test_mont_dilithium
echo "-- VLEN=256 --"
qemu-riscv64-static -cpu rv64,v=true,vlen=256,elen=64 -L /usr/riscv64-linux-gnu ./test_mont_dilithium
echo "-- VLEN=128 --"
qemu-riscv64-static -L /usr/riscv64-linux-gnu ./test_mont_dilithium

echo "[5/5] Kaannetaan taysi NTT ja testataan oikeaa golden-tulosta vasten..."
riscv64-linux-gnu-gcc -march=rv64gcv -O2 ntt_rvv.c test_ntt.c -o test_ntt
echo "-- VLEN=256 --"
qemu-riscv64-static -cpu rv64,v=true,vlen=256,elen=64 -L /usr/riscv64-linux-gnu ./test_ntt
echo "-- VLEN=128 --"
qemu-riscv64-static -L /usr/riscv64-linux-gnu ./test_ntt
