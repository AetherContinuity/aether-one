# OpenSSL 3.0 Provider — RVV-skeleton

Korvaa `AetherOne_Platform_v1_0_FullInstaller`-paketin 4-rivisen
`oqs_rvv_provider/provider.c`-stubin. Uusi, itsenäinen, ei peri
edellisen ristiriitoja.

## Mitä tämä TODISTAA

**`OSSL_ALGORITHM`-rekisteröinti — VIIMEINEN PALANEN, PROJEKTI VALMIS.**
(`provider.c`:n `provider_query`): `mldsa_rvv_keymgmt_functions` ja
`mldsa_rvv_signature_functions` rekisteröity nimellä `"ML-DSA-65-RVV"`
(`property_definition="provider=oqs_rvv"`) `OSSL_OP_KEYMGMT`- ja
`OSSL_OP_SIGNATURE`-operaatioille. Muille operaatioille (esim.
`OSSL_OP_KEYEXCH`) palautetaan yhä `NULL` — rehellisesti, ei teeskennellä
tukea jota ei ole.

Testattu **`OSSL_provider_init`:sta lähtien**, ei suoraan `mldsa_rvv_*`-
symboleista: haetaan `provider_query`-funktio dispatch-taulukosta,
kutsutaan sitä `OSSL_OP_KEYMGMT`/`OSSL_OP_SIGNATURE`:lle, poimitaan
funktiot palautetusta `OSSL_ALGORITHM`-taulukon `implementation`-
kentästä — tämä on täsmälleen se reitti jota OpenSSL:n oma ydin kulkisi
ladattuaan providerin ja etsiessään `EVP_PKEY_CTX_new_from_name`:n
kautta. `OSSL_OP_KEYEXCH` palauttaa `NULL` oikein (ei väärää positiivista).

Tämä väite oli aiemmin merkitty "mekaaniseksi, ei uutta logiikkaa" — se
osoittautui todeksi: PASS ensimmäisellä yrityksellä, molemmilla VLEN-
arvoilla, koko `keygen→sign→verify(oikea)→verify(turmeltu)`-kierto
`provider_query`-reitin läpi.

**TÄSTÄ ETEENPÄIN KOKO ML-DSA-65-RVV-PROVIDER-PROJEKTI ON VALMIS.**
Ei jäljellä olevia avoimia palasia tässä hakemistossa.

**SIGNATURE-kytkentä** (`signature.c`):
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

- **`.so`-dynaamista latausta (`dlopen`/`OSSL_PROVIDER_load`) ei ole
  testattu RISC-V:lla.** Kaikki testit tässä hakemistossa linkitsevät
  suoraan. x86-testi (`provider_get_params`-koe alussa) käytti oikeaa
  dynaamista latausta oikealla CLI:lla — RISC-V-puolella `openssl`-CLI:ta
  ei ristikäännetty.
- **Ei ASIC/FPGA-rauta.** QEMU-emulaatio.
- **`mu`/`rhoprime` on koko `rvv-dilithium`-hakemiston ajan testattu
  kiinteillä/johdetuilla arvoilla, ei koskaan mielivaltaisella
  viestipituudella tai erikoismerkeillä** (vain ASCII-testiviestejä).

## Tila

Ei jäljellä olevia tunnettuja avoimia palasia tässä hakemistossa. Jos
jatketaan, seuraava luonnollinen laajennus olisi `openssl`-CLI:n
ristikäännös jotta koko ketjun voisi ajaa yhdellä `openssl pkeyutl`
-komennolla — ei enää RVV-logiikkaa, pelkkää OpenSSL-työkaluketjun
kokoamista, eikä sitä ole pyydetty.

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
