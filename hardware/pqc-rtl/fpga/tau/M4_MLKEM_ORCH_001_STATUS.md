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
