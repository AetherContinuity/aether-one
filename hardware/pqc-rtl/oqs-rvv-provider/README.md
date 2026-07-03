# OpenSSL 3.0 Provider — RVV-skeleton

Korvaa `AetherOne_Platform_v1_0_FullInstaller`-paketin 4-rivisen
`oqs_rvv_provider/provider.c`-stubin. Uusi, itsenäinen, ei peri
edellisen ristiriitoja.

## Mitä tämä TODISTAA

**KEYMGMT-kytkentä ML-DSA-65-RVV-toteutukseen** (`keymgmt.c`):
`OSSL_FUNC_KEYMGMT_NEW`/`GEN_INIT`/`GEN`/`GEN_CLEANUP`/`HAS`/`GET_PARAMS`/
`GETTABLE_PARAMS` toteutettu oikeilla, `core_dispatch.h`:sta luetuilla
funktiosignaturoilla (ei arvattu). `keymgmt_gen` kutsuu
`rvv-dilithium/crypto_sign_keypair_rvv.c`:tä oikealla `RAND_bytes`-
satunnaisuudella (ei kiinnitetty siemen — tämä on ensimmäinen kohta koko
repossa jossa RVV-koodi ajetaan oikealla satunnaisuudella, ei
determinismin vuoksi kiinnitetyllä testiarvolla).

Testattu **kutsumalla dispatch-taulukkoa täsmälleen niin kuin OpenSSL:n
oma ydin tekisi** (etsitään funktiot `function_id`:n perusteella
taulukosta, ei suoraan nimellä) — ei vain "kääntyy", vaan todellinen
rajapintapolku. Tuotettu avain testattu **toiminnallisesti**: samalla
avaimella oikea `crypto_sign_signature_rvv`+`crypto_sign_verify_rvv`
-kierto onnistuu, ja turmeltu viesti hylätään. Koska siemen on oikeaa
satunnaisuutta, ei bittitarkkaa golden-vertailua — toiminnallinen PASS on
oikea mittari tässä. PASS molemmilla VLEN-arvoilla, eri avain joka
ajolla, silti aina toimiva.

**`provider.c` on spesifikaation mukainen OpenSSL 3.0 provider-runko**
(`OSSL_provider_init`, `provider_get_params`, `provider_gettable_params`,
`provider_query_operation`, `provider_teardown`). Todennettu kahdesti:

1. **x86, oikea OpenSSL 3.0.13 CLI:** `openssl list -provider-path .
   -provider oqs_rvv -providers` lataa ja tunnistaa providerin oikein.
2. **RISC-V+V, QEMU:** `harness_provider.c` kutsuu `OSSL_provider_init`:iä
   suoraan, linkattuna oikeaa ristikäännettyä OpenSSL 3.2 `libcrypto.a`:ta
   vasten (`no-shared no-apps no-tests no-docs no-legacy no-async`).
   PASS. Negatiivikontrolli (rikottu versiomerkkijono) -> FAIL.

## Mitä tämä EI todista (tietoinen rajaus)

- **Ei allekirjoitusoperaatiota (`OSSL_FUNC_SIGNATURE_*`).** `KEYMGMT`
  tuottaa avaimen, mutta `provider_query_operation` palauttaa yhä `NULL`
  `OSSL_OP_SIGNATURE`:lle — avainta ei voi vielä käyttää oikean
  `EVP_PKEY_sign`/`EVP_PKEY_verify`-rajapinnan kautta, vain suoralla
  testiajurilla joka kutsuu `crypto_sign_signature_rvv`/`verify_rvv`:tä
  itse.
- **Ei ASIC/FPGA-rauta.** QEMU-emulaatio.
- **`.so`-lataustestiä ei ole tehty RISC-V:lla.** Testi kutsuu dispatch-
  taulukkoa suoraan linkattuna binaarina, ei dynaamisen latauksen kautta.

## Seuraava askel jos jatketaan

`OSSL_FUNC_SIGNATURE_*`: `newctx`/`sign_init`/`sign`/`verify_init`/
`verify`/`freectx` -toteutus joka kutsuu `crypto_sign_signature_rvv`/
`crypto_sign_verify_rvv`:tä `KEYMGMT`:n tuottaman avainolion kanssa.
Tämä on viimeinen palanen ennen kuin providerin läpi voi tehdä oikean
`openssl pkeyutl -sign`/`-verify` -komennon (vaatisi myös `openssl`-CLI:n
ristikäännöksen, joka jätettiin pois `no-apps`-lipulla — oma päätöksensä
jos halutaan mennä niin pitkälle).

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
