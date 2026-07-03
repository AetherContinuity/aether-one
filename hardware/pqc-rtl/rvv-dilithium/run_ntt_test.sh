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

echo "[6/6] SHAKE128 (ExpandA:n pohja) - kaannetaan libcrypto.a jos ei jo olemassa..."
OPENSSL_SRC=../../../.openssl-src-riscv
if [ ! -f "$OPENSSL_SRC/libcrypto.a" ]; then
  git clone --depth 1 --branch openssl-3.2 https://github.com/openssl/openssl.git "$OPENSSL_SRC"
  cd "$OPENSSL_SRC"
  ./Configure linux64-riscv64 no-shared no-tests no-apps no-docs no-legacy no-async \
    --cross-compile-prefix=riscv64-linux-gnu-
  make -j"$(nproc)" build_generated
  make -j"$(nproc)" libcrypto.a
  cd - > /dev/null
fi
riscv64-linux-gnu-gcc -O2 -I "$OPENSSL_SRC/include" shake128_test.c -o shake128_test \
  -L "$OPENSSL_SRC" -lcrypto -lpthread -ldl
qemu-riscv64-static -L /usr/riscv64-linux-gnu ./shake128_test

echo "[7/7] rej_uniform (RVV: strided-lataus + vcompress) - oikeaa SHAKE128-pohjaista golden-dataa vasten..."
gcc -O2 rej_driver.c -o rej_driver -lcrypto
./rej_driver
riscv64-linux-gnu-gcc -march=rv64gcv -O2 rej_uniform_rvv.c test_rej_uniform.c -o test_rej_uniform
echo "-- VLEN=256 --"
qemu-riscv64-static -cpu rv64,v=true,vlen=256,elen=64 -L /usr/riscv64-linux-gnu ./test_rej_uniform
echo "-- VLEN=128 --"
qemu-riscv64-static -L /usr/riscv64-linux-gnu ./test_rej_uniform

echo "[8/8] poly_uniform (SHAKE128+rej_uniform yhdistettyna, mukaan lukien uudelleentaytto)..."
gcc -O2 poly_uniform_test_driver.c -o poly_uniform_test_driver
./poly_uniform_test_driver
riscv64-linux-gnu-gcc -march=rv64gcv -O2 rej_uniform_rvv.c poly_uniform_rvv.c test_poly_uniform.c -o test_poly_uniform
echo "-- VLEN=256 (pakotettu uudelleentaytto) --"
qemu-riscv64-static -cpu rv64,v=true,vlen=256,elen=64 -L /usr/riscv64-linux-gnu ./test_poly_uniform
echo "-- VLEN=128 --"
qemu-riscv64-static -L /usr/riscv64-linux-gnu ./test_poly_uniform

echo "[9/9] ExpandA taydelle matriisille (ML-DSA-65: K=6, L=5)..."
gcc -O2 expand_a_driver.c -o expand_a_driver -lcrypto
./expand_a_driver
riscv64-linux-gnu-gcc -march=rv64gcv -O2 -I "$OPENSSL_SRC/include" \
  rej_uniform_rvv.c poly_uniform_rvv.c expand_a_rvv.c test_expand_a.c \
  -o test_expand_a -L "$OPENSSL_SRC" -lcrypto -lpthread -ldl
echo "-- VLEN=256 --"
qemu-riscv64-static -cpu rv64,v=true,vlen=256,elen=64 -L /usr/riscv64-linux-gnu ./test_expand_a
echo "-- VLEN=128 --"
qemu-riscv64-static -L /usr/riscv64-linux-gnu ./test_expand_a

echo "[10/10] rej_eta (ExpandS:n ydin, ETA=4, RVV nibble-interleave)..."
gcc -O2 eta_driver.c -o eta_driver -lcrypto
./eta_driver
riscv64-linux-gnu-gcc -march=rv64gcv -O2 rej_eta_rvv.c test_rej_eta.c -o test_rej_eta
echo "-- VLEN=256 --"
qemu-riscv64-static -cpu rv64,v=true,vlen=256,elen=64 -L /usr/riscv64-linux-gnu ./test_rej_eta
echo "-- VLEN=128 --"
qemu-riscv64-static -L /usr/riscv64-linux-gnu ./test_rej_eta

echo "[11/11] poly_uniform_eta (SHAKE256+rej_eta yhdistettyna, oikea uudelleentaytto)..."
echo "HUOM: kayttaa referenssin fips202.c:ta, EI OpenSSL:n EVP_DigestFinalXOF:ia -"
echo "toistuva EVP_DigestFinalXOF-kutsu havaittiin EI-jatkuvaksi (katso README)."
cp "$REF_DIR/ref/fips202.c" "$REF_DIR/ref/fips202.h" .
gcc -O2 poly_eta_driver.c fips202.c -o poly_eta_driver
./poly_eta_driver
riscv64-linux-gnu-gcc -march=rv64gcv -O2 rej_eta_rvv.c poly_uniform_eta_rvv.c test_poly_uniform_eta.c fips202.c \
  -o test_poly_uniform_eta
rm -f fips202.c fips202.h
echo "-- VLEN=256 --"
qemu-riscv64-static -cpu rv64,v=true,vlen=256,elen=64 -L /usr/riscv64-linux-gnu ./test_poly_uniform_eta
echo "-- VLEN=128 --"
qemu-riscv64-static -L /usr/riscv64-linux-gnu ./test_poly_uniform_eta

echo "[12/12] ExpandS taydelle (s1: L=5, s2: K=6, ML-DSA-65)..."
cp "$REF_DIR/ref/fips202.c" "$REF_DIR/ref/fips202.h" .
gcc -O2 expand_s_driver.c fips202.c -o expand_s_driver
./expand_s_driver
riscv64-linux-gnu-gcc -march=rv64gcv -O2 rej_eta_rvv.c poly_uniform_eta_rvv.c expand_s_rvv.c test_expand_s.c fips202.c \
  -o test_expand_s
rm -f fips202.c fips202.h
echo "-- VLEN=256 --"
qemu-riscv64-static -cpu rv64,v=true,vlen=256,elen=64 -L /usr/riscv64-linux-gnu ./test_expand_s
echo "-- VLEN=128 --"
qemu-riscv64-static -L /usr/riscv64-linux-gnu ./test_expand_s

echo "[13/13] t=As+e + Power2Round (avaingeneroinnin ydinlasku, ML-DSA-65)..."
cp "$REF_DIR/ref/reduce.c" "$REF_DIR/ref/reduce.h" "$REF_DIR/ref/ntt.c" "$REF_DIR/ref/ntt.h" \
   "$REF_DIR/ref/params.h" "$REF_DIR/ref/config.h" .

gcc -O2 invntt_driver.c -o invntt_driver
./invntt_driver
riscv64-linux-gnu-gcc -march=rv64gcv -O2 invntt_rvv.c test_invntt.c -o test_invntt
qemu-riscv64-static -cpu rv64,v=true,vlen=256,elen=64 -L /usr/riscv64-linux-gnu ./test_invntt

gcc -O2 ops_driver.c -o ops_driver
./ops_driver
riscv64-linux-gnu-gcc -march=rv64gcv -O2 poly_ops_rvv.c test_poly_ops.c -o test_poly_ops
qemu-riscv64-static -cpu rv64,v=true,vlen=256,elen=64 -L /usr/riscv64-linux-gnu ./test_poly_ops

gcc -O2 compute_t_driver.c -o compute_t_driver
./compute_t_driver
rm -f reduce.c reduce.h ntt.c ntt.h params.h config.h
riscv64-linux-gnu-gcc -march=rv64gcv -O2 ntt_rvv.c invntt_rvv.c poly_ops_rvv.c compute_t_rvv.c test_compute_t.c -o test_compute_t
echo "-- VLEN=256 --"
qemu-riscv64-static -cpu rv64,v=true,vlen=256,elen=64 -L /usr/riscv64-linux-gnu ./test_compute_t
echo "-- VLEN=128 --"
qemu-riscv64-static -L /usr/riscv64-linux-gnu ./test_compute_t

echo "[14/14] Taysi keypair-ketju: ExpandA+ExpandS+t=As+e oikealla rho/rhoprime:lla..."
cp "$REF_DIR/ref/reduce.c" "$REF_DIR/ref/reduce.h" "$REF_DIR/ref/ntt.c" "$REF_DIR/ref/ntt.h" \
   "$REF_DIR/ref/params.h" "$REF_DIR/ref/config.h" "$REF_DIR/ref/fips202.c" "$REF_DIR/ref/fips202.h" .
gcc -O2 keypair_driver.c -o keypair_driver
./keypair_driver
riscv64-linux-gnu-gcc -march=rv64gcv -O2 -I "$OPENSSL_SRC/include" \
  rej_uniform_rvv.c poly_uniform_rvv.c expand_a_rvv.c \
  rej_eta_rvv.c poly_uniform_eta_rvv.c expand_s_rvv.c \
  ntt_rvv.c invntt_rvv.c poly_ops_rvv.c compute_t_rvv.c \
  test_keypair_chain.c fips202.c \
  -o test_keypair_chain -L "$OPENSSL_SRC" -lcrypto -lpthread -ldl
echo "-- VLEN=256 --"
qemu-riscv64-static -cpu rv64,v=true,vlen=256,elen=64 -L /usr/riscv64-linux-gnu ./test_keypair_chain
echo "-- VLEN=128 --"
qemu-riscv64-static -L /usr/riscv64-linux-gnu ./test_keypair_chain

echo "[15/15] SampleInBall (tahallaan skalaarinen - Fisher-Yates ei vektoroidu)..."
gcc -O2 sib_driver.c fips202.c -o sib_driver
./sib_driver
riscv64-linux-gnu-gcc -march=rv64gcv -O2 sample_in_ball_rvv.c test_sample_in_ball.c fips202.c -o test_sample_in_ball
qemu-riscv64-static -cpu rv64,v=true,vlen=256,elen=64 -L /usr/riscv64-linux-gnu ./test_sample_in_ball
rm -f reduce.c reduce.h ntt.c ntt.h params.h config.h fips202.c fips202.h
