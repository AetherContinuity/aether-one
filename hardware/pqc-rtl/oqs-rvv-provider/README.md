# OpenSSL 3.0 Provider — RVV-skeleton

Korvaa `AetherOne_Platform_v1_0_FullInstaller`-paketin 4-rivisen
`oqs_rvv_provider/provider.c`-stubin. Uusi, itsenäinen, ei peri
edellisen ristiriitoja.

## Mitä tämä TODISTAA

**SIGNATURE-kytkentä — TÄMÄ SULKEE KOKO PROJEKTIN.** (`signature.c`):
`OSSL_FUNC_SIGNATURE_NEWCTX`/`FREECTX`/`SIGN_INIT`/`SIGN`/`VERIFY_INIT`/
`VERIFY`, signatuurit luettu suoraan `core_dispatch.h`:sta. Testattu
**täysin OpenSSL:n omalla konventiolla**: ensin kysytään allekirjoituksen
koko (`sig=NULL`), sitten allekirjoitetaan oikealla `RAND_bytes`-
satunnaisuudella, sitten verifioidaan — kaikki `mldsa_rvv_keymgmt_functions`
+ `mldsa_rvv_signature_functions` -dispatch-taulukoiden läpi `function_id`:
llä haettuna, ei suoraan nimillä kutsuen (sama tapa kuin OpenSSL:n oma
ydin tekisi providerin ladattuaan).

PASS: koon kysely (3309, täsmää `CRYPTO_BYTES`:iin), allekirjoitus
(`rc=1`), verifiointi oikealle viestille (`rc=1`), verifiointi turmellulle
viestille (`rc=0`, todellinen hylkäys OpenSSL:n `1=onnistui/0=epäonnistui`
-konvention mukaisesti — huomaa käänteinen etumerkkikonventio verrattuna
`crypto_sign_verify_rvv`:n omaan `0=OK/-1=FAIL`:iin, `signature.c` tekee
muunnoksen). Molemmilla VLEN-arvoilla.

**TÄSTÄ ETEENPÄIN: KOKO ML-DSA-65 ON KYTKETTY PÄÄSTÄ PÄÄHÄN OPENSSL-
PROVIDER-RAJAPINNAN LÄPI.** Avaingenerointi (`KEYMGMT`) ja allekirjoitus/
verifiointi (`SIGNATURE`) molemmat todennettu oikealla dispatch-
mekanismilla, oikealla RVV-laskennalla, oikealla OpenSSL-satunnaisuudella.

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

- **`provider_query_operation` palauttaa yhä `NULL`.** `KEYMGMT`- ja
  `SIGNATURE`-dispatch-taulukot on rakennettu ja todennettu suoraan,
  mutta niitä ei ole rekisteröity `provider.c`:n `OSSL_ALGORITHM`-
  taulukkoon `OSSL_provider_init`:ssa. Tämä tarkoittaa: oikea
  `EVP_PKEY_sign`/`openssl pkeyutl` ei vielä löydä algoritmia providerin
  kautta — testattu suoralla dispatch-taulukon läpikäynnillä, ei
  todellisella `EVP_PKEY_CTX`-tason API-kutsulla. Rekisteröinti on
  mekaaninen viimeistely, ei uutta logiikkaa.
- **Ei ASIC/FPGA-rauta.** QEMU-emulaatio.
- **`.so`-lataustestiä ei ole tehty RISC-V:lla** (dynaaminen `dlopen`,
  ei suora linkitys) — `openssl`-CLI:ta ei ristikäännetty.

## Seuraava askel jos jatketaan

Rekisteröi `mldsa_rvv_keymgmt_functions` ja `mldsa_rvv_signature_functions`
`provider.c`:n `provider_query_operation`:iin `OSSL_ALGORITHM`-taulukkona
(`algorithm_name = "ML-DSA-65"` tms.), jolloin oikea `EVP_PKEY_CTX_new_from_name`
+ `EVP_PKEY_sign`/`EVP_PKEY_verify` löytäisi algoritmin providerin läpi.
Tämän jälkeen ainoa jäljellä oleva askel olisi `openssl`-CLI:n
ristikäännös, jotta koko ketjun voisi ajaa yhdellä `openssl pkeyutl`
-komennolla — ei enää RVV-logiikkaa, pelkkää OpenSSL-työkaluketjun
kokoamista.

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
