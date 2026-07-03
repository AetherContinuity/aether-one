# ML-DSA/Dilithium — täysi NTT RVV:llä

Korjaa aiemman `rvv/mont_rvv.c`:n virheellisen olettamuksen: se käytti
Kyberin (ML-KEM) 16-bittistä Montgomerya, ei ML-DSA:n 32-bittistä.
Dual-Pi-protolle (ML-DSA-65-allekirjoitus) tarvitaan tämä hakemisto, ei
`rvv/`-hakemisto.

## Mitä tämä TODISTAA

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

## Seuraava askel jos jatketaan

Avaingenerointi (`OSSL_OP_KEYMGMT`) NTT:n päälle — vaatii `ExpandA`/
`ExpandS` (SHAKE-pohjainen näytteistys), ei vain aritmetiikkaa.

## Toolchain

```
bash run_ntt_test.sh
```
