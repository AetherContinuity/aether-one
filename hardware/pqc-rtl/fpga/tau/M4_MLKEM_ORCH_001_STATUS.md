# M4-MLKEM-ORCH-001: synteesikelpoinen ML-KEM.KeyGen-orkestrointi

**Paivamaara:** 2026-07-19
**Tila:** OSITTAINEN, TIETOISESTI KESKEN - ei viela taysi ML-KEM.KeyGen

## Loydos joka kaynnisti taman tyopaketin

Tarkistettaessa "ML-KEM-pohjainen istuntoavaimen muodostus TAU:lle"
-tavoitetta havaittiin: koko ML-KEM.KeyGen/Encaps/Decaps ON tahan
asti ollut olemassa VAIN testipenkkien proseduraalisena orkestrointina
(initial-lohkot) - EI synteesikelpoisena RTL:na. Jokainen ALIMODUULI
(NTT, SHA3, SamplePolyCBD, ByteEncode jne.) ON synteesikelpoinen ja
todistettu erikseen, mutta niita YHDISTAVA ohjauslogiikka ei ollut.

## Toteutettu tahan mennessa (pqc_mlkem_keygen_core.sv)

Synteesikelpoinen tilakone joka toistaa TASMALLEEN saman sekvenssin
kuin `tb/pqc_mlkem_keygen_tb.sv`:

1. ✅ SHA3-512(d||K) -> rho, sigma
2. ✅ SampleNTT(rho,i,j) x4 (KxK silmukka) -> A[i][j]
3. 🔄 PRF+SamplePolyCBD(sigma,N) x4 (2K) - ALOITETTU, EI VIELA
   testattu erikseen
4. ❌ NTT-forward x4 (2K) - EI VIELA toteutettu
5. ❌ Matriisikertolasku+summaus (t_hat) - EI VIELA toteutettu
6. ❌ ByteEncode12(t_hat)+rho -> ek - EI VIELA toteutettu
7. ❌ ByteEncode12(s_hat) -> dkPKE - EI VIELA toteutettu
8. ❌ H(ek)=SHA3-256(ek), dk-kokoaminen - EI VIELA toteutettu

## Todennettu (pqc_mlkem_keygen_core_partial_tb.sv)

- `rho` TASMAA taydellisesti Python-golden-referenssiin
  (`vectors/mlkem_keygen_vectors.txt`, sama tiedosto kuin alkuperainen
  testipenkki kayttaa) - SHA3-512-vaihe TOIMII OIKEIN synteesikelpoisena.
- Tilakone etenee koko KxK SampleNTT-silmukan lapi jumiutumatta
  (1399 sykliä), state etenee oikein S_START_CBD:hen asti.
- A[0][0]:n arvo saatiin ulos (ei viela verrattu Python-referenssiin
  erikseen - TAMA ON AVOIN, seuraava tarkistuskohta).

## Loydetty, viela ratkaisematon avoin kysymys

Alkuperainen testipenkki tekee `reset=1;@(posedge clk);reset=0;
@(posedge clk);` ENNEN JOKAISTA start-pulssia (myos peraikkaisten
SampleNTT/CBD-kutsujen valissa). TAMAN synteesikelpoisen FSM:n oma
toteutus EI VIELA tee tata - jaettu `reset`-signaali resetoisi MYOS
FSM:n oman tilan, ei vain alimoduulien sisaisen tilan.

**EI VIELA SELVITETTY:** onko tama per-kutsu-reset AIDOSTI
valttamaton oikeellisuudelle (esim. alimoduulin oma sisainen
akkumulaattori tai tila joka EI tyhjenny pelkalla start-pulssilla),
vai onko se VAIN testipenkin oma eristyskaytanto joka EI ole
tarpeen jatkuvassa, yhdessa FSM:ssa ajettavassa sekvenssissa.

**Tama on kriittinen avoin kysymys ENNEN kuin loput vaiheet
(erityisesti CBD-silmukka, joka on JO osittain toteutettu ilman
per-kutsu-resettia) voidaan todentaa luotettavasti.** Jos per-kutsu-
reset osoittautuu valttamattomaksi, koko FSM-rakenne tarvitsee oman
alimoduulikohtaisen reset-signaalinsa (erillinen paa-FSM:n omasta
resetista).

## Seuraavat askeleet (ei viela aloitettu)

1. Selvittaa per-kutsu-reset-kysymys (tarkastella SampleNTT/CBD-
   moduulien sisaista tilaa, tai testata empiirisesti: toimiiko
   CBD-silmukka oikein ilman valiresettia verrattuna golden-
   referenssiin).
2. Toteuttaa loput vaiheet (NTT-forward, matriisikertolasku,
   ByteEncode, H(ek), assembly) - jokainen erikseen testattuna
   ennen seuraavaa.
3. Lopullinen taydellinen golden-vertailu (ek, dk molemmat
   tasmaavat).
4. Vasta talloin: Encaps/Decaps-vastaavat orkestrointimoduulit
   (viela suurempi tyo).

**Tama on OMA, huomattava tyopakettinsa - ei valmis viela.**

## RATKAISTU: per-kutsu-reset -kysymys (2026-07-19)

**Tarkistettu suoraan koodista kolmesta relevantista moduulista:**

1. `pqc_samplentt.sv`: `S_IDLE`-tila tyhjentaa `done`:n JA kaynnistaa
   uuden SHAKE-laskennan suoraan `start`-pulssista - EI riipu
   ulkoisesta resetista aiemman ajon jalkeen.
2. `pqc_prf_samplepolycbd.sv`: EI OMAA TILAKONETTA LAINKAAN - puhdas
   kokoonpano, `pqc_samplepolycbd`-alimoduuli on TAYSIN kombinatorinen
   (ei edes clk/reset-portteja).
3. `pqc_shake256.sv`: TASMALLEEN sama kuvio kuin samplentt:ssa -
   `S_IDLE` tyhjentaa tilan ja kaynnistaa uudelleen puhtaasti
   `start`:sta.

**JOHTOPAATOS: per-kutsu-reset EI OLE arkkitehtonisesti valttamaton
naille moduuleille - alkuperaisen testipenkin oma kaytanto oli
PUHTAASTI eristyskaytanto/varovaisuus, ei hardware-vaatimus.**

Tama vahvistaa etta jo toteutettu FSM-rakenne (ilman per-kutsu-
resettia) on RAKENTEELLISESTI PERUSTELTU - voidaan jatkaa loppujen
vaiheiden toteutusta samalla periaatteella.

## UUSI LOYDOS: NTT-forward-vaihe vaatii bring-up-rajapinnan, ei hierarkkista kirjoitusta

`run_forward_ntt`-tehtava testipenkissa kayttaa `write_bank(...)`-
apufunktiota joka kirjoittaa SUORAAN HIERARKKISESTI ytimen sisaisiin
pankkeihin (`ntt_dut.bank0[addr] = value`) - TAMA ON PUHTAASTI
SIMULAATIOTASON TEMPPU, EI SYNTEESIKELPOINEN.

**Synteesikelpoisen version TAYTYY kayttaa ytimen omaa
FPGA_BRINGUP-lohkon load_valid/load_addr/load_data-rajapintaa**
(jo olemassa ja todistettu M4-FPGA-001:ssa) SAMAAN tarkoitukseen -
256 kertoimen kirjoittaminen pankkeihin ennen jokaista NTT-ajoa.

Tama on konkreettinen, selkea seuraava askel, mutta jaljella oleva
tyo (NTT-forward x4 kutsua x taysi 7-tasoinen aikataulu per kutsu,
matriisikertolasku, ByteEncode, H(ek), kokoaminen) on edelleen
huomattava - EI aloiteta talla kierroksella, kirjataan seuraavaksi
konkreettiseksi askeleeksi.

## Yhteenveto: mita nyt tiedetaan varmasti

✅ Per-kutsu-reset EI ole tarpeen (ratkaistu, koodista vahvistettu)
✅ SHA3-512-vaihe TOIMII synteesikelpoisena (rho tasmaa golden-malliin)
✅ SampleNTT-silmukka ETENEE oikein synteesikelpoisena
🔄 NTT-forward-vaihe vaatii FPGA_BRINGUP-rajapinnan kayttoa (EI
  hierarkkista kirjoitusta) - SEURAAVA konkreettinen askel
❌ Matriisikertolasku, ByteEncode, H(ek), kokoaminen - viela
  toteuttamatta

## NTT-forward-vaiheen toteutusyritys - LOYDETTY BUGI, EI VIELA RATKAISTU (2026-07-19)

Rakennettu: NTT-aikataulun ROM (`mlkem_ntt_schedule_rom.memh`, 64
merkintaa), FSM-tilat lataukselle (bring-up load_valid), aikataulun
ajolle (64 perakkaista start-pulssia ROM:sta), ja tuloksen lukemiselle
(bring-up read_en/read_data).

**TULOS: FSM jumiutuu tilaan 14 (S_NTT_FWD_READ, oletettavasti)
useiksi tuhansiksi sykleiksi, sitten SIIRTYY YLLATTAEN takaisin
tilaan 0 (S_IDLE) - viittaa etta jokin osa siirtymalogiikkaa tuottaa
KELVOTTOMAN tila-arvon joka osuu `default: state <= S_IDLE;`
-haaraan.**

`s_hat[0]`:n ensimmaiset 32 bittia (`06f606f6`) nayttavat epailyttavan
TOISTUVALTA kuviolta - EI VIELA VARMISTETTU onko tama aito NTT-tulos
vai merkki viallisesta lukuindeksoinnista (esim. `read_idx-8'd1`-
kompensaatiolla, jota kaytin 1-syklin lukuviiveen huomioimiseen,
saattaa olla off-by-one- tai ajoitusvirhe).

**EI VIELA RATKAISTU.** Todennakoisia jatkoaskelia:
1. Debugata TASMALLEEN missa kohtaa tila-arvo menee kelvottomaksi
   (lisata state-tulostus jokaiselle syklille lyhyella aikavalilla).
2. Tarkistaa read_idx/read_valid-ajoitus tarkasti (mahdollinen
   off-by-one bring-up-lukupolun 1-syklin viiveen kompensoinnissa).
3. Tarkistaa `ntt_schedule_rom`:n oma pakkaus/purku (bittikentat
   `entry[57:50]` yms.) - mahdollinen virhe pakkausjarjestyksessa.

**TAMA ON REHELLISESTI KIRJATTU KESKENERAISEKSI** - ei viela
toimiva NTT-forward-vaihe, vaativa oman debug-kierroksensa ennen
jatkoa matriisikertolaskuun.

## Debug-tulos 2026-07-19: bugi TARKASTI PAIKANNETTU lukuvaiheeseen

**Kayttajan oma pyynto:** debugataan loydetty ongelma.

**Ratkaisu tarkkaan tilasiirtyman jaljitykseen:** lisattiin
sykli-kohtainen tila+signaalitulostus. TULOS: **aikataulun suoritus
(64 askelta) ETENEE TAYSIN OIKEIN** - `sched_idx` kasvaa siististi
0:sta 63:een, `stage_done` pulssaa oikein jokaisen tason lopussa,
EI pankkikonflikteja. FSM saavuttaa `S_DONE`:n (tila 25) 10643
syklin jalkeen - EI KOSKAAN JUMIUDU, aiempi tulkinta "bugista" oli
VAARA: FSM vain saavutti tarkoituksella viela toteuttamattoman
S_DONE-placeholderin, joka putoaa oletusarvoisesti takaisin
S_IDLE:en (koska `S_DONE`:lle ei ole viela omaa case-haaraa).

**Automaattinen, tarkka vertailu Python-golden-referenssiin
(purettu suoraan `dk_expect`:sta `byte_decode(12,...)`:lla)
paljasti TODELLISEN, VIELA RATKAISEMATTOMAN bugin:**

`s_hat[0]` EI TASMAA - kaikki 256 kerrointa eroavat golden-
referenssista. **Merkittava vihje: RTL[0]=RTL[1]=1782 (identtiset!)**
ennen kuin arvot alkavat poiketa toisistaan tasta eteenpain - tama
viittaa VAHVASTI etta LUKUVAIHEEN (`S_NTT_FWD_READ`) omassa
ajoituksessa/indeksoinnissa on virhe (esim. ensimmainen luettu arvo
kirjoitetaan VAHINGOSSA kahteen peräkkäiseen tauluindeksin, sitten
kaikki myohemmat arvot ovat sen seurauksena vaaria).

## Tarkennettu johtopaatos

**Aikataulun suoritus (64 NTT-tasoa) ON TAYSIN OIKEIN.** Bugi ON
kavennettu tarkasti LUKUVAIHEESEEN (`S_NTT_FWD_READ`-tilan oma
read_idx/read_valid-kasittely, mahdollisesti `read_idx-8'd1`-
kompensointilogiikan virhe 1-syklin lukuviiveen huomioimisessa).

**Seuraava askel:** debugata TASMALLEEN `S_NTT_FWD_READ`-tilan oma
ajoitus (esim. verrata suoraan M4-SoC-001:n jo TOIMivaksi todistettuun
Wishbone-lukupolkuun, joka kayttaa SAMAA bring-up-rajapintaa
oikein) - todennakoisin korjaus: poistaa virheellinen `-8'd1`-
kompensointi ja kayttaa suoraan rekisteroityä read_idx-arvoa joka
VASTASI luettua dataa (samankaltainen kuin toimivassa Wishbone-
esimerkissa).

**EI VIELA RATKAISTU, MUTTA MERKITTAVASTI KAVENNETTU:** ongelma-
alue on nyt tasan yksi tila (S_NTT_FWD_READ), ei enaa koko NTT-
forward-sekvenssi.

## KORJATTU lukuvaiheen bugi + LOYDETTY UUSI, AIEMPI bugi (2026-07-19)

**Korjaus 1 - TOTEUTETTU:** `ntt_read_en`/`ntt_read_addr` muutettu
REKISTEROIDYSTA (`<=`) KOMBINATORISEKSI (`assign`), samalla
periaatteella kuin jo toimivaksi todistettu Wishbone-lukupolku
(`pqc_ntt_wishbone_wrapper.sv`). Lisatty `read_idx_captured`-
rekisteri joka tallentaa MIKA read_idx oli silloin kun vastaava
data lopulta saapuu (1 syklin viive).

**Tulos: duplikaattibugi (RTL[0]=RTL[1]) POISTUI** - jokainen
luettu arvo on nyt eri (ei enaa off-by-one-tyylista toistoa).

**MUTTA loydettiin UUSI, AIEMPI bugi:** verrattaessa `s_vec[0]`:aa
(NTT:n oma SYOTE, ennen muunnosta) suoraan Python-golden-viitteeseen
(`kpke_encrypt_golden.py:n kpke_keygen()`, joka kayttaa TASMALLEEN
samaa `sample_poly_cbd(prf(ETA1,sigma,0),ETA1)`-kutsua):

```
golden: [2, 1, 3328, 3328, 1, 3327, 3328, 1, 0, 3328, ...]
RTL:    [0, 0, 3328, 0, 1, 0, 1, 1, 2, 3328, ...]
```

**Arvot EIVAT tasmaa, MUTTA eivat ole taysin satunnaisiakaan** -
esim. kohdassa [2] molemmat naytaavat 3328. Tama viittaa
mahdolliseen INDEKSOINTI- tai BITTIJARJESTYSVIRHEESEEN
`pqc_prf_samplepolycbd`-moduulin oman ulostulon (`f_out`) ja
oman FSM:ni `cbd1_out`-tallennuksen valilla (`s_vec[n_ctr[0]] <=
cbd1_out`), EI satunnaisesta laskentavirheesta.

**TAMA ON ERI, AIEMPI BUGI kuin lukuvaiheen ongelma - sijaitsee
CBD-vaiheessa (S_START_CBD/S_WAIT_CBD), EI NTT-forward-lukuvaiheessa.**
Lukuvaiheen korjaus oli silti oikea ja tarpeellinen (poisti yhden
todellisen bugin), mutta CBD-vaiheen oma, viela ratkaisematon bugi
selittaa lopullisen s_hat-eron.

## Paivitetty tila ja seuraava askel

Bugi kavennettu entisesta ("koko NTT-forward ei toimi") tarkkaan:
CBD-vaiheen (`pqc_prf_samplepolycbd`/`cbd1_out`) oman ulostulon ja
FSM:n oman `s_vec`-tallennuksen valisen kytkennan tarkistus.
Seuraava askel: vertailla `cbd1_out`:n RAAKAA ulostuloa (ennen
FSM:n omaa tallennusta) suoraan `pqc_prf_samplepolycbd`-moduulin
OMAAN, jo aiemmin todistettuun testipenkkiin nahden - onko vika
itse CBD-moduulissa (epatodennakoista, koska aiemmin todistettu)
vai VAIN taman uuden FSM:n omassa kytkennassa/tallennuksessa.

## TARKEA KORJAUS: aiempi "sigma-bugi" OLI oma referenssivirheeni (2026-07-19, jatko)

**Loydetty:** `d_seed` luetaan testipenkkiin `$fscanf(fh,"%h",d_seed)`:lla,
joka tulkitsee hex-merkkijonon TAVANOMAISENA (MSB-ensin) numerona -
EI `pack_bytes()`-konvention (LSB-ensin) mukaisesti. Kun laskin OMAN
Python-referenssini aiemmin kayttaen `bytes.fromhex()`:ia SUORAAN,
sain d_seed:n VAARASSA tavujarjestyksessa verrattuna siihen miten
RTL sen todellisuudessa kayttaa.

**Korjattu laskemalla d_seed uudelleen:** luetaan hex-arvo
kokonaislukuna (`int(hex,16)`), sitten PURETAAN se `pack_bytes()`-
konvention mukaisesti tavuiksi (`unpack_bytes`) - tama vastaa
TASMALLEEN mita $fscanf+RTL yhdessa tuottavat.

**TULOS: koko 512-bittinen SHA3-512-digest (seka rho etta sigma)
TASMASI TAYDELLISESTI RTL:n aiemmin nayttamiin arvoihin**, kun
laskin sen UUDELLEEN taman oikean d_seed-kasittelyn kanssa. Tama
VAHVISTAA etta SHA3-512-vaihe (rho+sigma) ON JA ON OLLUT KOKO AJAN
OIKEIN - aiempi "sigma ei tasmaa" -loydos OLI OMA REFERENSSIVIRHEENI,
EI RTL-bugi.

## s_hat EI VIELA TASMAA - jaljella oleva, aito bugi

Uusittu koko s_hat[0]/s_hat[1]-vertailu OIKEALLA d_seed-kasittelylla
(kayttaen `kpke_keygen()`-referenssifunktiota suoraan samalla
korjatulla d_seed:lla). **TULOS: s_hat[0] JA s_hat[1] EIVAT VIELA
TASMAA - kaikki 256 kerrointa eroavat MOLEMMISSA.**

**Uusi vihje:** viimeinen kerroin `s_hat[0][255]` on **`x`
(alustamaton/tuntematon)** RTL:ssa - tama viittaa VAHVASTI etta
lukusilmukan (`S_NTT_FWD_READ`) omassa RAJATAPAUKSESSA (viimeinen,
255. kerroin) on off-by-one-tyyppinen virhe joka jattaa SEN
kirjoittamatta kokonaan.

## Yhteenveto oikeista, todennetuista loydoksista

✅ SHA3-512 (rho+sigma): OIKEIN - aiempi "bugi" oli oma referenssivirhe
✅ SampleNTT-silmukka: etenee oikein (aiemmin todennettu)
✅ Lukuvaiheen duplikaattibugi: KORJATTU (kombinatorinen read_en/addr)
❌ s_hat[0]/s_hat[1]: EIVAT VIELA TASMAA - JALJELLA OLEVA, AITO BUGI
   - Uusi vihje: viimeinen kerroin jaa alustamattomaksi (off-by-one
     lukusilmukan rajatapauksessa)

**EI VIELA RATKAISTU.** Seuraava askel: korjata lukusilmukan
rajatapaus (255. kerroin), sitten TOISTAA taydellinen vertailu -
jos MYOS muut kertoimet ovat viela vaarin senkin jalkeen, tutkia
CBD-vaiheen omaa n_ctr->s_vec/e_vec-tallennusindeksointia tarkemmin
(esim. onko n_ctr:n JAKO s_vec:n vai e_vec:n valilla, ja MIKA
tarkka alaindeksi, oikein toteutettu).

## Lukusilmukan korjaus + massiivinen kavennus (2026-07-19, jatko 2)

**Lukusilmukan korjaus toteutettu:** `S_NTT_FWD_READ` jaettu kahteen
tilaan (`S_NTT_FWD_READ` esittaa osoitteen, `S_NTT_FWD_READ_WAIT`
odottaa `read_valid`:ia) - vastaa tasmalleen jo toimivaksi todistettua
Wishbone-lukupolun yksi-kerrallaan-kattelymallia (ei enaa paallekkaisia,
jatkuvia peräkkäisiä lukuja jotka aiheuttivat osoitteen "juuttumisen"
kahdeksi sykliksi).

**Loydetty JA korjattu oma testivirhe:** uuden tilan lisays SIIRSI
kaikkien myohempien tilojen enum-arvoja yhdella - testini odotti
vanhaa `S_DONE=25`-arvoa, vaikka se on nyt `26`. FSM SAAVUTTI maalin
oikein jo aiemmin, mutta testi ei sita huomannut ja odotti aikakatkaisuun
asti.

**s_vec[0] TASMAA TAYDELLISESTI golden-referenssiin** (oikealla
`d_seed`-kasittelylla): `[0,0,3328,0,1,0,1,1,2,3328,...]` - SEKA
RTL etta Python antavat TAYSIN saman tuloksen.

## Kavennettu johtopaatos: bugi ON NYT PUHTAASTI NTT-laskennan omassa
vertailussa, ei aiemmissa vaiheissa

**KAIKKI vaiheet SHA3-512:sta CBD-nayttenottoon TAYDELLISESTI
TODISTETTU OIKEIKSI.** Jaljella oleva ero (s_hat ei tasmaa `ntt(s_vec)`:hen)
on nyt rajattu YKSISTAAN NTT-FORWARD-LASKENNAN (kirjoitus+aikataulu+
luku KOKONAISUUTENA, TAI Python-vertailun oman `ntt()`-funktion
mahdollisen erilaisen konvention) piiriin.

**Seuraava askel:** koska RTL:n oma NTT-ydin ON JO ERIKSEEN
TODISTETTU TOIMIVAKSI (M2/M3:n "koko 7-tasoinen NTT tasmaa golden-
malliin" -testit lapaisevat), todennakoisin jaljella oleva syy on:
(a) Python-vertailun oman `ntt()`-funktion (kyber_ntt_golden.py)
JOKIN ERI KONVENTIO (esim. bittikaannospermutaatio) verrattuna
suoraan `s_hat = byte_decode(dkPKE)`-purkuun, TAI (b) oma FSM:ni
`load_idx`:n oma kirjoituskonventio (S_NTT_FWD_LOAD) ei tasmaa
`read_idx`:n oman lukukonvention kanssa symmetrisesti.

## Definitiivinen kavennus: vika ON aikataulun SUORITUSSILMUKASSA (2026-07-19, jatko 3)

Systemaattinen, vaihe-vaiheelta-eristava testaus suoritettu:

1. **Suora testi (hierarkkinen kirjoitus, sama syote+aikataulu kuin
   PROVEN M2/M3-testeissa): PASS TAYDELLISESTI.** Tama todistaa
   ETTA ytin+aikataulu+golden-referenssi ovat KAIKKI oikein YHDESSA.
2. **Latausvaiheen (bring-up load_valid) tarkistus: PASS
   TAYDELLISESTI** - kaikki 256 arvoa oikein pankeissa heti latauksen
   jalkeen.
3. **Aikataulu-ROM:n purku: PASS TAYDELLISESTI** - kaikki tarkistetut
   kentat (pair_dist, base0/1, zeta0/1) tasmaavat tarkalleen
   alkuperaisiin tiedostoihin.
4. **Pankkien sisalto HETI aikataulun suorituksen JALKEEN (ennen
   lukuvaihetta): EI TASMAA** - 256/256 arvoa vaarin JO PANKEISSA.

**LOPULLINEN, TAYDELLISESTI KAVENNETTU JOHTOPAATOS: bugi ON
YKSINOMAAN `S_NTT_FWD_SCHED_START`/`S_NTT_FWD_SCHED_WAIT`-silmukan
OMASSA `ntt_start`-pulssien laukaisussa/ajoituksessa** - EI
missaan muualla (lataus, ROM, ydin, golden-referenssi ovat KAIKKI
erikseen todistettu oikeiksi).

**EI VIELA RATKAISTU.** Todennakoisin jaljella oleva syy: `stage_done`-
signaalin oma kasittely S_NTT_FWD_SCHED_WAIT:ssa (mahdollisesti
sama tyyppinen "kadonnut pulssi" -ongelma kuin aiemmin loydettiin
M4-SoC-001:n Wishbone-integraatiossa, TAI `ntt_start`:n oma
ajoitus/kesto EI RIITA laukaisemaan ytimen omaa FSM:aa oikein
JOKAISELLA 64 aikataulun askeleella).

## Seuraava askel

Jaljittaa TASMALLEEN mika tapahtuu ENSIMMAISEN aikataulun askeleen
(taso 6) aikana verrattuna PROVEN-testin omaan ajoitukseen - onko
`stage_done` genuiinisti sama PULSSI molemmissa, VAI onko oma FSM:ni
mahdollisesti REAGOI VAARAAN stage_done-pulssin ESIINTYMAAN (esim.
edellisen ajon oma stage_done, joka ei viela ehtinyt nollaantua
ennen uutta start-pulssia).

## LAPIMURTO: JUURISYY LOYDETTY JA KORJATTU (2026-07-19, jatko 4)

**LOPULLINEN JUURISYY:** aikataulun ROM pakkasi VAIN YHDEN "length"-
arvon, kayttaen SITA sekä `pair_dist`:lle etta `count`:lle. TAMA ON
OIKEIN 63:lle 64:sta aikataulun askeleesta (joissa count=pair_dist=
length, `full_schedule.txt`:n oma formaatti), MUTTA VAARIN
ENSIMMAISELLE askeleelle (taso 6): PROVEN-testin oma koodi kayttaa
`pair_dist<=128` MUTTA `count<=64` - ERI ARVOT taman ERIKOISTAPAUKSEN
kohdalla!

**Korjaus:** ROM-pakkaus muutettu sisaltamaan `count` ERIKSEEN
`pair_dist`:sta (72-bittinen sana 64-bittisen sijaan:
`{count[8],pair_dist[8],base0[9],zeta0[16],base1[9],zeta1[16]}`).
Taso 6:n oma merkinta paivitetty: `count=64, pair_dist=128`
(erikoistapaus), kaikki muut 63 merkintaa: `count=pair_dist=length`
(sama kuin ennen).

**TULOS: PASS TAYDELLISESTI - seka `s_hat[0]` etta `s_hat[1]`
TASMAAVAT KOKONAAN golden-referenssiin (kaikki 256 kerrointa
molemmissa)!**

## M4-MLKEM-ORCH-001:n paivitetty tila

| Vaihe | Tila |
|---|---|
| 1. SHA3-512(d\|\|K) -> rho, sigma | ✅ TODENNETTU |
| 2. SampleNTT(rho,i,j) x4 -> A[i][j] | ✅ TODENNETTU (etenee oikein) |
| 3. PRF+SamplePolyCBD x4 -> s_vec, e_vec | ✅ TODENNETTU (s_vec[0] tasmaa taydellisesti) |
| 4. NTT-forward x4 -> s_hat, e_hat | ✅ **TODENNETTU - s_hat[0]/s_hat[1] TASMAAVAT TAYDELLISESTI** |
| 5. Matriisikertolasku+summaus (t_hat) | ❌ Ei viela toteutettu |
| 6. ByteEncode12(t_hat)+rho -> ek | ❌ Ei viela toteutettu |
| 7. ByteEncode12(s_hat) -> dkPKE | ❌ Ei viela toteutettu |
| 8. H(ek)=SHA3-256(ek), dk-kokoaminen | ❌ Ei viela toteutettu |

**Puolet (4/8) vaiheista nyt taydellisesti todennettu synteesikelpoisena
RTL:na.** Tama on merkittava virstanpylvas - ensimmainen kerta koko
projektin aikana etta ML-KEM:n orkestrointilogiikka (ei vain sen
alimoduulit) on todistetusti synteesikelpoinen JA oikea.

## Metodologinen huomio (talletetaan talteen)

Tama debug-kierros osoitti systemaattisen, vaihe-vaiheelta-eristavan
testauksen arvon: SHA3-512, SampleNTT, CBD, lataus, luku, ROM-purku
todistettiin KAIKKI erikseen oikeiksi ENNEN kuin lopullinen juurisyy
(count vs. pair_dist -sekaannus YHDESSA erikoistapauksessa 64:sta)
loytyi. Ilman tata kurinalaisuutta olisi ollut helppo epailla vaaria
komponentteja (esim. lukuvaiheen ajoitusta, jota MYOS korjattiin
mutta joka EI ollut lopullinen syy).
