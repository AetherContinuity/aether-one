# ML-DSA/Dilithium — täysi NTT RVV:llä

Korjaa aiemman `rvv/mont_rvv.c`:n virheellisen olettamuksen: se käytti
Kyberin (ML-KEM) 16-bittistä Montgomerya, ei ML-DSA:n 32-bittistä.
Dual-Pi-protolle (ML-DSA-65-allekirjoitus) tarvitaan tämä hakemisto, ei
`rvv/`-hakemisto.

## Mitä tämä TODISTAA

**SHAKE128** (`shake128_test.c`): OpenSSL:n `EVP_DigestFinalXOF`-rajapinta
oikeaa ristikäännettyä `libcrypto.a`:ta vasten. Kolme testivektoria
(tyhjä syöte, yksi tavu 0xCC, Dilithium-tyylinen seed+nonce), kaikki
laskettu itsenäisesti Python `hashlib`:lla — ei muistinvaraisia
"tunnettuja testivektoreita" (yksi käsin kirjoitettu arvo osoittautui
vääräksi ennen tätä tarkistusta, katso alla). PASS x86:lla ja RISC-V:llä
bittitarkasti. Tämä on `ExpandA`:n pohja (SHAKE128-pohjainen
näytteistys), ei vielä hylkäysnäytteistystä.

**32-bittinen Montgomery-reduktio** (`mont_dilithium_rvv.c`), pq-crystals/
dilithium `ref/reduce.c`:n algoritmi (`t32=(int32_t)a*QINV; t=(a-t32*Q)>>32`).
`QINV=58728449` — huom: tämä EI ole yleisesti muistettu "4236238847", joka
on väärä etumerkkikonventio. Vahvistettu suoraan kloonatusta
pq-crystals/dilithium-lähteestä, ei muistinvaraisesti.

**Täysi 256-pisteen NTT** (`ntt_rvv.c`), sama 8-tasoinen Cooley-Tukey-
rakenne kuin `ref/ntt.c`:ssa, zeta-taulukko (256 arvoa) poimittu
ohjelmallisesti referenssistä (`run_ntt_test.sh`:n Python-pätkä, ei käsin
kopioitu — käsin kopiointi 256 luvusta olisi virhealtista).

Molemmat todennettu:
- Golden-vektorit **oikeasta käännetystä ja ajetusta pq-crystals-
  referenssikoodista** (`driver.c` linkittää `reduce.c`+`ntt.c`:n suoraan),
  ei omasta approksimaatiosta.
- PASS VLEN=256:lla JA VLEN=128:lla.
- Negatiivikontrolli: rikottu golden-arvo -> FAIL.
- NTT testattu kahdella riippumattomalla satunnaisella syötteellä.

Aja itse: `bash run_ntt_test.sh` (kloonaa pq-crystals/dilithium ensimmäisellä
ajolla, `.dilithium-ref/`, ei committoitu).

## Mitä tämä EI todista (tietoinen rajaus)

- **Ei ole ASIC/FPGA-rauta.** QEMU-emulaatio.
- **Ei koko ML-DSA:ta.** Vain NTT (polynomien kertolaskun ydin). Puuttuu:
  avaingenerointi, näytteistys (`SampleInBall`, `ExpandA`, `ExpandS`),
  hylkäysnäytteistys allekirjoituksessa, koodaus/pakkaus.
- **Ei kytketty `oqs-rvv-provider/`:hen.** Se on yhä NULL-runko kaikelle
  algoritmille.
- **`rvv/mont_rvv.c` (Kyber-versio) on erillinen, ei tämän korvaama.**
  Molemmat pysyvät repossa, eri parametrijoukoille.

## Löydetty oma virhe (dokumentoitu, jotta ei toistu)

SHAKE128-testin ensimmäinen versio sisälsi käsin kirjoitetun "tunnetun"
testivektorin yhden tavun (0xCC) syötteelle joka oli yksinkertaisesti
väärä (ei mistään lähteestä, muistinvarainen). OpenSSL:n oikea tuloste
erosi tästä väärästä odotusarvosta - testi näytti aluksi epäonnistumiselta
vaikka koodi oli oikein. Korjattu laskemalla oikea arvo itsenäisesti
Python `hashlib`:lla ennen testin hyväksymistä, ei luottamalla muistiin.

## Seuraava askel jos jatketaan

Avaingenerointi (`OSSL_OP_KEYMGMT`) NTT:n päälle — vaatii `ExpandA`/
`ExpandS` (SHAKE-pohjainen näytteistys), ei vain aritmetiikkaa.

## Toolchain

```
bash run_ntt_test.sh
```
