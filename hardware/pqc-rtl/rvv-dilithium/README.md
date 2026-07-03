# ML-DSA/Dilithium — täysi NTT RVV:llä

Korjaa aiemman `rvv/mont_rvv.c`:n virheellisen olettamuksen: se käytti
Kyberin (ML-KEM) 16-bittistä Montgomerya, ei ML-DSA:n 32-bittistä.
Dual-Pi-protolle (ML-DSA-65-allekirjoitus) tarvitaan tämä hakemisto, ei
`rvv/`-hakemisto.

## Mitä tämä TODISTAA

**Täysi keypair-ketju** (`test_keypair_chain.c`): `ExpandA` + `ExpandS` +
`t=As+e`+`Power2Round` ajettu **peräkkäin, oikealla `rho`/`rhoprime`-
seedillä**, ei enää erillisinä synteettisin testein. PASS 3072/3072
oikeaa referenssin `crypto_sign_keypair`-alkuosaa vastaan (sama seed
molemmissa). Tämä on ensimmäinen kerta koko projektissa jossa useampi
RVV-rakennuspalikka on todistetusti yhteensopiva päästä päähän, ei vain
kukin erikseen.

**`SampleInBall`** (`sample_in_ball_rvv.c`, TAU=49, CTILDEBYTES=48
ML-DSA-65:lle — vahvistettu `ref/params.h`:sta): **tahallaan skalaarinen,
ei RVV-vektoroitu.** Tämä on Fisher-Yates-tyyppinen osittainen sekoitus
rejektionäytteistyksellä — jokainen askel `i` lukee ja kirjoittaa
`c[b]`:tä, jossa `b`:n hyväksymisehto (`b≤i`) ja luettava muisti riippuvat
edellisen askeleen lopputuloksesta. Kahta peräkkäistä askelta ei voi
laskea rinnakkain ilman algoritmin vaihtamista. Vektorointiyritys tähän
olisi näennäistä — sama virhe jota koko tämä hakemisto on välttänyt.
PASS 256/256 kahdella riippumattomalla siemenellä (49/256 epänollaa
kerrointa molemmissa, täsmää TAU:hun), negatiivikontrolli läpi.

**`t=As+e` + `Power2Round`** (`compute_t_rvv.c`): avaingeneroinnin
ydinlasku, koostettu kuudesta uudesta, erikseen todennetusta palikasta:

- **`invntt_rvv.c`**: käänteis-NTT (Gentleman-Sande-perhonen, eri
  operaatiojärjestys kuin eteenpäin-NTT — add/sub ENNEN kertolaskua, ei
  jälkeen). Lopuksi skaalaus Montgomery-kertoimella (f=41978). PASS
  256/256 oikeaa referenssiä vastaan.
- **`poly_ops_rvv.c`**: `poly_pointwise_montgomery` (NTT-domain-kertolasku),
  `poly_add`, `reduce32`, `caddq`, `power2round` — kaikki yksinkertaisia
  per-kerroin-operaatioita, vektoroitu suoraan ilman compress-tarvetta.
  6/6 PASS.
- **`compute_t_rvv.c`**: kokoaa nämä + jo olemassa olevan `ntt_rvv`:n
  referenssin `crypto_sign_keypair`:n järjestykseen: `NTT(s1)` →
  matriisi-vektori-pistetulo+summa (L termiä K:lle polynomille) →
  `reduce32` → `invntt_tomont` → `+s2` → `caddq` → `power2round`.

**Löydetty oma virhe ennen testausta:** golden-generaattorin ensimmäinen
versio lisäsi ylimääräisen `reduce32`-kutsun juuri ennen `caddq`:ta, jota
referenssissä ei ole (`ref/sign.c`: `invntt_tomont → add s2 → caddq`,
ei toista `reduce32`:ta välissä). Korjattu ennen RVV-testausta lukemalla
`sign.c` uudestaan rivi riviltä — sattumalta tulos ei muuttunut tälle
testidatalle, mutta virhe olisi voinut piillä muulla datalla.

PASS 3072/3072 (2×6×256: `t1`+`t0`, K=6 polynomia), molemmilla VLEN-
arvoilla, negatiivikontrolli läpi. Testidata synteettistä (ei oikeasta
ExpandA/ExpandS-ulostulosta) — testaa laskuketjun oikeellisuuden, ei
kytkeytymistä aiempiin vaiheisiin (se on oma, tekemätön askel).

**`ExpandS`** (`expand_s_rvv.c`): `s1` (L=5) + `s2` (K=6) = 11 kutsua
`poly_uniform_eta_rvv`:hen, nonce-järjestys `ref/sign.c`:stä vahvistettu
(`s1` nonce 0..L-1, `s2` jatkuu nonce L..L+K-1 — ei molemmat nollasta).
Jokaiselle nonce-arvolle oma, pysyvä Keccak-tila (`shake256_absorb_once`
+ `shake256_squeezeblocks`) — **ei** yksinkertaistettua "alusta uudelleen
joka squeeze-kutsulla" -adapteria, joka olisi näyttänyt toimivalta tälle
siemenelle (kaikki 11 nonce-arvoa täyttyivät yhdellä erällä) mutta
rikkoutunut hiljaa jos jokin nonce olisi tarvinnut uudelleentäytön —
korjattu ennen testausta, ei sen jälkeen. PASS 2816/2816 kerrointa
(11×256), molemmilla VLEN-arvoilla, negatiivikontrolli läpi.

**`poly_uniform_eta`** (`poly_uniform_eta_rvv.c`): SHAKE256 + `rej_eta_rvv`
yhdistettynä, mukaan lukien referenssin uudelleentäyttö. **Todellinen
uudelleentäyttö löytyi luonnostaan** (seed=56410, nonce=0, ctr=253/256
ensimmäisen erän jälkeen) — ei tarvinnut keinotekoista dataa kuten
`poly_uniform`:in (SHAKE128) tapauksessa.

**Löydös OpenSSL:n EVP-XOF:sta (tärkeä, dokumentoitu jotta ei toistu):**
Ensimmäinen versio käytti `EVP_DigestFinalXOF`:ia toistuvasti samalle
kontekstille uudelleentäyttöä varten (sama malli kuin `shake128_test.c`:ssä,
mutta useilla peräkkäisillä kutsuilla). Tämä epäonnistui — testattiin
suoraan: `EVP_DigestFinalXOF(ctx, buf, 272)` seurattuna
`EVP_DigestFinalXOF(ctx, buf2, 136)` **ei** anna samaa tulosta kuin yksi
`EVP_DigestFinalXOF(ctx, full, 408)`-kutsu. Käytös on deterministinen
(sama kutsujono antaa aina saman tuloksen) mutta **ei ole todellinen
squeeze-jatkumo**. Referenssin `stream256_squeezeblocks` vaatii aidon
jatkumon. Korjaus: käytetään pq-crystalsin omaa `fips202.c`:tä
(`shake256_absorb_once`+`shake256_squeezeblocks`) OpenSSL:n EVP-rajapinnan
sijaan tälle testille. Aiemmat SHAKE128-testit eivät kärsineet tästä,
koska ne kutsuivat `EVP_DigestFinalXOF`:ia vain kerran per konteksti.

PASS 256/256, molemmilla VLEN-arvoilla, negatiivikontrolli läpi.

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
- **Ei koko ML-DSA:ta.** Koko avaingenerointiketju (`ExpandA`+`ExpandS`+
  `t=As+e`+`Power2Round`) todennettu päästä päähän, ja `SampleInBall`
  (allekirjoituksen näytteistys) todennettu erikseen. Puuttuu: `pack_pk`/
  `pack_sk` (koodaus), koko allekirjoitusalgoritmi (`y`-näytteistys,
  `w=Ay`, `z=y+cs1`, hylkäysnäytteistys — iso, ei kosketettu), verifiointi.
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

Koko avaingenerointi on nyt todennettu päästä päähän. Seuraava iso
kokonaisuus on allekirjoitusalgoritmi: `y` (`poly_uniform_gamma1`, neljäs
eri näytteistyslogiikka), `w=Ay`, `w1=HighBits(w)`, `c=H(mu,w1)` →
`SampleInBall`, `z=y+cs1` (hylätään jos `||z||∞≥GAMMA1-BETA`), `r0=
LowBits(w-cs2)` (hylätään jos liian suuri), `h=MakeHint`. Isompi kuin
mikään tähän mennessä tehty yksittäinen askel — sisältää useita
hylkäysehtoja jotka voivat pakottaa koko allekirjoitusyrityksen
uusimisen alusta.

## Toolchain

```
bash run_ntt_test.sh
```
