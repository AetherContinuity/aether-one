#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

OPENSSL_SRC=../../../.openssl-src-riscv

if [ ! -f "$OPENSSL_SRC/libcrypto.a" ]; then
  echo "[1/3] Haetaan ja kaannetaan libcrypto.a RISC-V:lle (vain kerran)..."
  git clone --depth 1 --branch openssl-3.2 https://github.com/openssl/openssl.git "$OPENSSL_SRC"
  cd "$OPENSSL_SRC"
  ./Configure linux64-riscv64 no-shared no-tests no-apps no-docs no-legacy no-async \
    --cross-compile-prefix=riscv64-linux-gnu-
  make -j"$(nproc)" build_generated
  make -j"$(nproc)" libcrypto.a
  cd - > /dev/null
else
  echo "[1/3] libcrypto.a loytyi jo, ohitetaan kaannos."
fi

echo "[2/3] Kaannetaan provider + harness, linkataan libcryptoa vasten..."
riscv64-linux-gnu-gcc -O2 -I "$OPENSSL_SRC/include" -c provider.c -o provider.o
riscv64-linux-gnu-gcc -O2 -I "$OPENSSL_SRC/include" -c harness_provider.c -o harness_provider.o
riscv64-linux-gnu-gcc provider.o harness_provider.o -o harness_provider_riscv \
  -L "$OPENSSL_SRC" -lcrypto -lpthread -ldl

echo "[3/3] Ajetaan QEMU:ssa..."
qemu-riscv64-static -L /usr/riscv64-linux-gnu ./harness_provider_riscv

echo "[4/4] KEYMGMT-kytkentä: dispatch-taulukon läpi generoitu avain, oikea sign+verify..."
RVV_DIR=../rvv-dilithium
cp "$RVV_DIR"/rej_uniform_rvv.c "$RVV_DIR"/poly_uniform_rvv.c "$RVV_DIR"/expand_a_rvv.c \
   "$RVV_DIR"/rej_eta_rvv.c "$RVV_DIR"/poly_uniform_eta_rvv.c "$RVV_DIR"/expand_s_rvv.c \
   "$RVV_DIR"/ntt_rvv.c "$RVV_DIR"/invntt_rvv.c "$RVV_DIR"/poly_ops_rvv.c "$RVV_DIR"/compute_t_rvv.c \
   "$RVV_DIR"/polyt1_pack_rvv.c "$RVV_DIR"/pack_pk_rvv.c "$RVV_DIR"/polyeta_pack_rvv.c \
   "$RVV_DIR"/polyt0_pack_rvv.c "$RVV_DIR"/pack_sk_rvv.c "$RVV_DIR"/crypto_sign_keypair_rvv.c \
   "$RVV_DIR"/polyz_unpack_rvv.c "$RVV_DIR"/poly_uniform_gamma1_rvv.c \
   "$RVV_DIR"/sample_in_ball_rvv.c "$RVV_DIR"/decompose_rvv.c "$RVV_DIR"/chknorm_rvv.c \
   "$RVV_DIR"/pw_poly_rvv.c "$RVV_DIR"/polyw1_pack_rvv.c "$RVV_DIR"/vec_wrappers_rvv.c \
   "$RVV_DIR"/sign_core_rvv.c "$RVV_DIR"/use_hint_rvv.c "$RVV_DIR"/verify_core_rvv.c \
   "$RVV_DIR"/polyz_pack_rvv.c "$RVV_DIR"/pack_hint_rvv.c "$RVV_DIR"/pack_sig_rvv.c \
   "$RVV_DIR"/crypto_sign_signature_rvv.c "$RVV_DIR"/crypto_sign_verify_rvv.c .

DILITHIUM_REF=../../../.dilithium-ref
if [ ! -d "$DILITHIUM_REF" ]; then
  git clone --depth 1 https://github.com/pq-crystals/dilithium.git "$DILITHIUM_REF"
fi
python3 - << 'PYEOF'
import re
src = open("../../../.dilithium-ref/ref/ntt.c").read()
m = re.search(r'zetas\[N\] = \{([^}]*)\}', src, re.S)
nums = [int(x) for x in m.group(1).replace("\n", " ").split(",") if x.strip()]
assert len(nums) == 256
with open("zetas.h", "w") as f:
    f.write("static const int32_t ZETAS[256] = {" + ",".join(map(str, nums)) + "};\n")
PYEOF
cp "$DILITHIUM_REF/ref/fips202.c" "$DILITHIUM_REF/ref/fips202.h" .

riscv64-linux-gnu-gcc -march=rv64gcv -O2 -I "$OPENSSL_SRC/include" \
  rej_uniform_rvv.c poly_uniform_rvv.c expand_a_rvv.c \
  rej_eta_rvv.c poly_uniform_eta_rvv.c expand_s_rvv.c \
  ntt_rvv.c invntt_rvv.c poly_ops_rvv.c compute_t_rvv.c \
  polyt1_pack_rvv.c pack_pk_rvv.c polyeta_pack_rvv.c polyt0_pack_rvv.c pack_sk_rvv.c \
  crypto_sign_keypair_rvv.c keymgmt.c \
  polyz_unpack_rvv.c poly_uniform_gamma1_rvv.c \
  sample_in_ball_rvv.c decompose_rvv.c chknorm_rvv.c pw_poly_rvv.c \
  polyw1_pack_rvv.c vec_wrappers_rvv.c sign_core_rvv.c use_hint_rvv.c verify_core_rvv.c \
  polyz_pack_rvv.c pack_hint_rvv.c pack_sig_rvv.c \
  crypto_sign_signature_rvv.c crypto_sign_verify_rvv.c \
  test_keymgmt_provider.c fips202.c \
  -o test_keymgmt_provider -L "$OPENSSL_SRC" -lcrypto -lpthread -ldl

echo "[5/5] SIGNATURE-kytkentä: sign+verify OpenSSL-konvention mukaisesti (koon kysely, sign, verify, hylkäys)..."
riscv64-linux-gnu-gcc -march=rv64gcv -O2 -I "$OPENSSL_SRC/include" \
  rej_uniform_rvv.c poly_uniform_rvv.c expand_a_rvv.c \
  rej_eta_rvv.c poly_uniform_eta_rvv.c expand_s_rvv.c \
  ntt_rvv.c invntt_rvv.c poly_ops_rvv.c compute_t_rvv.c \
  polyt1_pack_rvv.c pack_pk_rvv.c polyeta_pack_rvv.c polyt0_pack_rvv.c pack_sk_rvv.c \
  crypto_sign_keypair_rvv.c keymgmt.c \
  polyz_unpack_rvv.c poly_uniform_gamma1_rvv.c \
  sample_in_ball_rvv.c decompose_rvv.c chknorm_rvv.c pw_poly_rvv.c \
  polyw1_pack_rvv.c vec_wrappers_rvv.c sign_core_rvv.c use_hint_rvv.c verify_core_rvv.c \
  polyz_pack_rvv.c pack_hint_rvv.c pack_sig_rvv.c \
  crypto_sign_signature_rvv.c crypto_sign_verify_rvv.c signature.c \
  test_signature_provider.c fips202.c \
  -o test_signature_provider -L "$OPENSSL_SRC" -lcrypto -lpthread -ldl

rm -f rej_uniform_rvv.c poly_uniform_rvv.c expand_a_rvv.c rej_eta_rvv.c poly_uniform_eta_rvv.c \
      expand_s_rvv.c ntt_rvv.c invntt_rvv.c poly_ops_rvv.c compute_t_rvv.c polyt1_pack_rvv.c \
      pack_pk_rvv.c polyeta_pack_rvv.c polyt0_pack_rvv.c pack_sk_rvv.c crypto_sign_keypair_rvv.c \
      polyz_unpack_rvv.c poly_uniform_gamma1_rvv.c sample_in_ball_rvv.c decompose_rvv.c \
      chknorm_rvv.c pw_poly_rvv.c polyw1_pack_rvv.c vec_wrappers_rvv.c sign_core_rvv.c \
      use_hint_rvv.c verify_core_rvv.c polyz_pack_rvv.c pack_hint_rvv.c pack_sig_rvv.c \
      crypto_sign_signature_rvv.c crypto_sign_verify_rvv.c zetas.h fips202.c fips202.h

echo "-- VLEN=256 --"
qemu-riscv64-static -cpu rv64,v=true,vlen=256,elen=64 -L /usr/riscv64-linux-gnu ./test_keymgmt_provider
qemu-riscv64-static -cpu rv64,v=true,vlen=256,elen=64 -L /usr/riscv64-linux-gnu ./test_signature_provider
echo "-- VLEN=128 --"
qemu-riscv64-static -L /usr/riscv64-linux-gnu ./test_keymgmt_provider
qemu-riscv64-static -L /usr/riscv64-linux-gnu ./test_signature_provider
