# OpenSSL 3.0 Provider — RVV-skeleton

Korvaa `AetherOne_Platform_v1_0_FullInstaller`-paketin 4-rivisen
`oqs_rvv_provider/provider.c`-stubin. Uusi, itsenäinen, ei peri
edellisen ristiriitoja.

## Mitä tämä TODISTAA

`provider.c` on spesifikaation mukainen OpenSSL 3.0 provider-runko
(`OSSL_provider_init`, `provider_get_params`, `provider_gettable_params`,
`provider_query_operation`, `provider_teardown`). Todennettu kahdesti:

1. **x86, oikea OpenSSL 3.0.13 CLI:** `openssl list -provider-path .
   -provider oqs_rvv -providers` lataa ja tunnistaa providerin oikein.
2. **RISC-V+V, QEMU:** `harness_provider.c` kutsuu `OSSL_provider_init`:iä
   suoraan, linkattuna oikeaa ristikäännettyä OpenSSL 3.2 `libcrypto.a`:ta
   vasten (`no-shared no-apps no-tests no-docs no-legacy no-async`).
   PASS. Negatiivikontrolli (rikottu versiomerkkijono) -> FAIL.

## Mitä tämä EI todista (tietoinen rajaus)

- **Ei yhtään algoritmia.** `provider_query_operation` palauttaa `NULL`
  kaikelle. Ei Kyber/Dilithium/ML-DSA, ei RVV-kutsua ollenkaan viela.
  `hardware/pqc-rtl/rvv/mont_rvv.c` (todennettu erikseen) ei ole vielä
  kytketty tähän.
- **Ei ASIC/FPGA-rauta.** QEMU-emulaatio.
- **`.so`-lataustestiä ei ole tehty RISC-V:lla.** RISC-V-testi kutsuu
  `OSSL_provider_init`:ia suoraan linkattuna binaarina, ei dynaamisen
  latauksen (`dlopen`/`OSSL_PROVIDER_load`) kautta, koska `openssl`-CLI:ta
  ei ristikaannetty (`no-apps`). x86-testi sen sijaan KAYTTI oikeaa
  dynaamista latausta oikealla CLI:lla.

## Seuraava askel jos jatketaan

Kytke `mont_rvv.c`:n Montgomery-reduktio yhteen `provider_query_operation`:in
palauttamaan operaatioon (esim. `OSSL_OP_KEM` tai custom-KDF), niin että
`provider_query` palauttaa ensimmäisen oikean, RVV-kiihdytetyn algoritmin
NULL:n sijaan. Tama on isompi askel - vaatii OpenSSL:n oman
algoritmirekisteroinnin (`OSSL_ALGORITHM`-taulukot) ja parametrien
kasittelyn, ei vain runkoa.

## Toolchain

```
# Kerran (hidas, ~5-10 min):
git clone --depth 1 --branch openssl-3.2 https://github.com/openssl/openssl.git
cd openssl && ./Configure linux64-riscv64 no-shared no-tests no-apps no-docs \
  no-legacy no-async --cross-compile-prefix=riscv64-linux-gnu-
make -j$(nproc) build_generated && make -j$(nproc) libcrypto.a

# Testi:
bash run_provider_test.sh
```
