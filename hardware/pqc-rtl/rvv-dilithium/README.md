# ML-DSA/Dilithium — täysi NTT RVV:llä

Korjaa aiemman `rvv/mont_rvv.c`:n virheellisen olettamuksen: se käytti
Kyberin (ML-KEM) 16-bittistä Montgomerya, ei ML-DSA:n 32-bittistä.
Dual-Pi-protolle (ML-DSA-65-allekirjoitus) tarvitaan tämä hakemisto, ei
`rvv/`-hakemisto.

## Mitä tämä TODISTAA

**`rej_eta`** (`rej_eta_rvv.c`, ETA=4 ML-DSA-65:lle — vahvistettu
`ref/params.h`:sta, ei 2): eri hylkäysrakenne kuin `rej_uniform` — nibble-
pohjainen (2 ehdokasta/tavu), ei 3-tavu-tripletti. Arvo on suora `4-t`
(ei `rej_uniform`:in bittimaskaus). Strategia: laske molempien nibblejen
(t0,t1) arvot ja hyväksymisliput erikseen, **striidaa ne lomitettuun
välipuskuriin** alkuperäisen `t0-ennen-t1`-järjestyksen säilyttämiseksi,
sitten yksi `vcompress` koko lomitetulle datalle. Golden-data: oikea
SHAKE256-puskuri (huom: ei SHAKE128, `ExpandS` käyttää eri XOF:ia kuin
`ExpandA`) + referenssin `rej_eta`-logiikka luettu suoraan `ref/poly.c`:sta.
PASS 256/256 kahdella riippumattomalla seed/nonce-parilla, molemmilla
VLEN-arvoilla. Negatiivikontrolli läpi.

**`ExpandA`** (`expand_a_rvv.c`): koko matriisi ML-DSA-65:lle (K=6, L=5,
`ref/params.h`:sta vahvistettu — ei oletettu), 30 `poly_uniform_rvv`-
kutsua nonce-arvoilla `(i<<8)+j` (referenssin `polyvec_matrix_expand`).
PASS 7680/7680 kerrointa (30×256), molemmilla VLEN-arvoilla,
negatiivikontrolli läpi. Kaikki 30 nonce-arvoa täyttyivät yhdellä
SHAKE128-erällä (ei tarvinnut uudelleentäyttöpolkua — se on testattu
erikseen `poly_uniform`-tasolla synteettisellä datalla).

**`poly_uniform`** (`poly_uniform_rvv.c`): SHAKE128 + `rej_uniform_rvv`
yhdistettynä, mukaan lukien referenssin `while(ctr<N)`-uudelleentäyttö.
Todellinen SHAKE128 ei käytännössä koskaan laukaise uudelleentäyttöä
näillä parametreilla (~99,9 % hyväksymisaste, 280 ehdokasta/256:ta
kohti) — haettu 200 000 satunnaisella seed/nonce-parilla, ei löytynyt
yhtään joka pakottaisi sen. Uudelleentäyttöhaara testattu siis
**keinotekoisella, kontrolloidulla tavuvirralla** (`poly_uniform_test_driver.c`),
joka pakottaa osittaisen täytön (ctr=224/256 ensimmäisen erän jälkeen)
ja tarkistaa että toinen kierros täyttää loput. Tämä testaa kontrollivuon
oikeellisuuden (puskurin offset/carry-käsittely blokkien välillä), ei
kryptografista satunnaisuutta. PASS 256/256, molemmilla VLEN-arvoilla,
negatiivikontrolli läpi.

**`rej_uniform`** (`rej_uniform_rvv.c`): hylkäysnäytteistys RVV:llä —
strided-lataus (`vlse8`, offset 0/1/2, stride 3) korvaa `vlseg3e8`:n joka
ei ole tuettu tässä GCC-versiossa, laajennus 8→32-bittiseksi (`vzext_vf4`),
vertailu (`vmsltu`), pakkaus (`vcompress`), määrälaskuri (`vcpop`). Eri
vektorointimalli kuin NTT:n kiinteä perhonen — data-riippuvainen
kompaktointi, ei kiinteä kaava.

Golden-data: oikea SHAKE128-puskuri (OpenSSL) + referenssin `rej_uniform`-
logiikka (`rej_driver.c`, sama algoritmi kuin `ref/poly.c`, tarkistettu
suoraan lähteestä). PASS 256/256 kahdella riippumattomalla seed/nonce-
parilla, molemmilla VLEN-arvoilla (128/256). Negatiivikontrolli läpi.

**SHAKE128** (`shake128_test.c`): OpenSSL:n `EVP_DigestFinalXOF`-rajapinta
oikeaa ristikäännettyä `libcrypto.a`:ta vasten. Kolme testivektoria
(tyhjä syöte, yksi tavu 0xCC, Dilithium-tyylinen seed+nonce), kaikki
laskettu itsenäisesti Python `hashlib`:lla — ei muistinvaraisia
"tunnettuja testivektoreita" (yksi käsin kirjoitettu arvo osoittautui
vääräksi ennen tätä tarkistusta, katso alla). PASS x86:lla ja RISC-V:llä
bittitarkasti.

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
- **Ei koko ML-DSA:ta.** NTT + `ExpandA` + `rej_eta`-ydin todennettu.
  Puuttuu: `poly_uniform_eta` (SHAKE256+`rej_eta` yhdistettynä, sama
  uudelleentäyttökuvio kuin `poly_uniform`:ssa — ei vielä tehty),
  `SampleInBall` (kolmas eri näytteistyslogiikka), avaingenerointi
  (`t=As+e`, `Power2Round`), hylkäysnäytteistys allekirjoituksessa,
  koodaus/pakkaus.
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

`poly_uniform_eta`: yhdistä SHAKE256 + `rej_eta_rvv` samalla
uudelleentäyttökuviolla kuin `poly_uniform_rvv`. Sen jälkeen `s1` (L
polynomia) ja `s2` (K polynomia) näytteistetään tällä. `SampleInBall`
on eri, kolmas näytteistyslogiikka (τ epänollaa ±1-kerrointa) — ei tehty.

## Toolchain

```
bash run_ntt_test.sh
```
