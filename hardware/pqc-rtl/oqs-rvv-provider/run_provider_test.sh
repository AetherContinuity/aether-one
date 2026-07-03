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
