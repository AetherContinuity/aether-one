# PQC RTL — NTT256 Kiihdytin (TrustCore NX -polku)

SystemVerilog RTL-prototyyppi NTT256-kiihdyttimelle.
Pi 5 toimii simulointiympäristönä ennen FPGA-siirtymää.

## Tila

| Milestone | Kuvaus | Tila |
|-----------|--------|------|
| M1 (skoopattu) | 1 NTT-taso, 16 butterflya/lane, pankkikonflikti | ✅ TODENNETTU 2026-07-02, ks. rajaus alla. **HUOM: kaytti korjattua Montgomery-aritmetiikkaa 2026-07-10 lahtien, ks. [MONTGOMERY_FIX_NOTE.md](MONTGOMERY_FIX_NOTE.md)** |
| M2 Vaihe 1 | Per-butterfly zeta-indeksointi | ✅ TODENNETTU 2026-07-10, ks. rajaus alla. Sama Montgomery-korjaus koskee tata |
| M2 Vaihe 2a | Python-golden-malli: 7-tason Kyber-NTT + BaseCaseMultiply | ✅ TODENNETTU 2026-07-10, ks. `m2-golden/README.md` |
| M2 Vaihe 2b | Yksi taso (level 6, 128 butterflya) RTL:ssa | ✅ TODENNETTU 2026-07-10, ks. rajaus alla |
| M2 Vaihe 2c-i | Kaksi peräkkäistä tasoa (6→5), sama muisti, tasojen ketjutus | ✅ TODENNETTU 2026-07-10, ks. rajaus alla |
| M2 Vaihe 2c-ii | Kaikki 7 tasoa, koko Kyber-NTT | ✅ TODENNETTU 2026-07-10, ks. rajaus alla |
| M2 Vaihe 3a | Muodollinen SAT-todistus 4-pankkiselle kuvaukselle | ✅ TODENNETTU 2026-07-10, ks. [BANK_MAPPING_PROOF.md](BANK_MAPPING_PROOF.md) |
| M2 Vaihe 3b | Yksi taso (6), oikea 4-pankkinen muisti RTL:ssä | ✅ TODENNETTU 2026-07-11, ks. rajaus alla |
| M2 Vaihe 3c | Kaikki 7 tasoa 4-pankkisella muistilla | ✅ TODENNETTU 2026-07-11, ks. rajaus alla |
| M2 Vaihe 3d | Suorituskykymittaus (syklit, pankkien käyttöaste) | ⛔ EI ALOITETTU |
| M3 | FPGA-prototyyppi (Pynq-Z2 / Basys 3) | Q2 2026 |
| M4 | TrustCore NX integraatio (7nm) | Q3 2026 |

**M1:n todennettu skoopin rajaus (2026-07-02):**
`rtl/pqc_rvv_cluster_2lane.sv` + `tb/pqc_cluster_m1_tb.sv` ajettu Icarus
Verilogilla, PASS kahdella eri satunnaissiemenellä, sekä negatiivikontrolli
(tahallaan rikottu golden-arvo -> testi epäonnistuu oikein, exit code 1).
Aja itse: `bash hardware/pqc-rtl/run_m1_test.sh`.

Mitä tämä TODISTAA:
- Montgomery-perhonen (`t=mont_reduce(b*zeta); a'=a+t; b'=a-t mod Q`) on
  bittitarkka Python-golden-mallia vastaan.
- Round-robin-arbitteri alternoi oikein kun kaksi lanea pyytää samaa
  pankkia (bank0) samana syklina - konflikti on aito, todennettu
  laskemalla alternointien määrä ajon aikana (≥2, tyypillisesti ~30).

**M2 Vaihe 1:n todennettu skoopin rajaus (2026-07-10):**
`idx` viety ulos `lane_fsm`:sta uutena output-porttina (`idx_out`),
kumpikin lane indeksoi jaettua `tw_window`-taulukkoa OMALLA idx-arvollaan
kiinteän `tw_window[0]`:n sijaan. Sama toolchain, sama
`run_m1_test.sh`. PASS kahdella eri satunnaissiemenella, plus KAKSI
negatiivikontrollia:
1. Tahallaan rikottu golden-arvo -> FAIL oikein (peritty M1:sta).
2. **Uusi:** tahallaan palautettu vanha `tw_window[0]`-kytkentä (M1:n
   rajaus) -> testi FAILaa oikein 61 virheella, ja testipenkin oma
   negatiivikontrolli tunnistaa tarkalleen syyn ("tulos tasmaa TAYSIN
   idx0-only-vaaraan ennusteeseen"). Todistaa etta per-butterfly-
   indeksointi OIKEASTI vaikuttaa tulokseen, ei vain etta koodi kaantyy.

Mitä M2 Vaihe 1 TODISTAA (M1:n lisaksi):
- Kumpikin lane käyttää OMAA per-butterfly-zetaansa (16 eri zeta-arvoa,
  ei enää yhtä yhteistä), bittitarkasti Python-golden-mallia vastaan.
- Vaarin-indeksoinnin negatiivikontrolli: jos RTL indeksoisi vain
  `tw_window[0]`:aa (M1:n vanha kayttays), 68/128 sanaa tasmaisi silti
  sattumalta vaaraan ennusteeseen mutta EI kaikki 128 - testi erottaa
  taman oikeasta kaytoksesta oikein molemmissa suunnissa.

Mitä tämä EI todista (tietoinen rajaus, ei piilotettu):
- Ei koko 256-pisteen NTT:tä, vain yksi taso, 16 butterflya per lane.
- Lane0 ja lane1 kayttavat SAMAA tw_window-taulukkoa SAMALLA idx-arvolla
  (molemmat butterfly-indeksit 0..15 per lane kayttavat tw_window[sama
  idx]) - tama ei viela mallinna oikean 256-pisteen NTT:n globaalia
  butterfly-asemointia, jossa eri lanet kasittelisivat eri butterfly-
  alueita eri zetoilla. Tama on M2 Vaihe 2:n laajuus.
- Malli on **käyttäytymismalli (behavioral), ei synteesikelpoinen RTL**.
  Ei todista piirin ajoitusta, pinta-alaa eikä FPGA/ASIC-synteesikelpoi-
  suutta. `always_comb`/`function automatic` -rakenteet ja hierarkkinen
  suora muistiosoitus eivät sellaisenaan synteesoidu.
- Edellisen session testipenkki (`pqc_cluster_verified_tb.sv`, ei tässä
  repossa) hylättiin: sen oma osoitelaskenta oli sisäisesti ristiriitainen
  (base_addr_lane1=16 vs. data sijoitettu osoitteisiin 32-63). Tämä on
  uusi, itsekonsistentti pari - DUT ja testipenkki kirjoitettu yhdessä.

**M2 Vaihe 2a:n todennus (2026-07-10):** Python-golden-malli, ei RTL:ää.
Ks. `m2-golden/README.md`. Kolmitasoinen todennus: (1) round-trip
NTT⁻¹(NTT(f))=f, (2) konvoluutiolause riippumattomasti (koulukirja-
negasyklinen konvoluutio, eri koodipolku), (3) negatiivikontrolli
(rikottu BaseCaseMultiply -> todistetusti väärä tulos).

**M2 Vaihe 2b:n todennus (2026-07-10):** Ensimmäinen taso (level 6,
128 butterflya, 2 lanea x 64) RTL:ssä, `rtl/pqc_ntt_level6_2lane.sv`.
Uusi ylätason moduuli, EI muuta `pqc_rvv_cluster_2lane.sv`:a - käyttää
samaa `lane_fsm`:ää uudella `PAIR_DIST`-parametrilla (128, oletus 1
säilyttää M1/Vaihe 1:n muuttumattomana). Kolmitasoinen todennus (ks.
[MONTGOMERY_FIX_NOTE.md](MONTGOMERY_FIX_NOTE.md) taustaksi):
1. **Sisäinen konsistenssi**: RTL täsmää 2a:n golden-malliin (Python
   `ntt_level6_only()`), kaikki 256 sanaa, 2 eri satunnaissiementä.
2. **Normatiivinen konsistenssi**: käytetty oikeaa FIPS 203 -zeta-arvoa
   (1729, level 6:n ainoa zeta), ei mielivaltaista testiarvoa kuten
   M1/Vaihe 1.
3. **Regressio**: M1 ja M2 Vaihe 1 ajettu uudelleen Montgomery-korjauksen
   jälkeen, molemmat PASS muuttumattomana.
Negatiivikontrolli: esiskaalaamaton (raaka) zeta syötettynä tuottaa
todistetusti väärän tuloksen (254/256 sanaa eroaa) - Montgomery-
esiskaalaus on todistetusti välttämätön, ei vain kosmeettinen.

Mitä 2b EI todista: ei toisen lanen omaa zeta-aluetta (molemmat
käyttävät samaa vakiozetaa, oikein tälle tasolle), ei muita 6 tasoa,
ei muistin banking-järjestelmää.

**M2 Vaihe 2c-i:n todennus (2026-07-10):** Kaksi peräkkäistä tasoa
(level 6 → level 5), sama muisti, `rtl/pqc_ntt_stage_2lane.sv` - UUSI,
YLEINEN moduuli (ei muuta `pqc_rvv_cluster_2lane.sv`:a eika
`pqc_ntt_level6_2lane.sv`:a). `pair_dist` muutettu `lane_fsm`:n
compile-time-parametrista AJONAIKAISEKSI PORTIKSI (oletus 8'd1,
sailyttaa kaikki aiemmat instanssit muuttumattomina ilman eksplisiittista
kytkentaa - iverilog ei tue parametririippuvaista porttien oletusarvoa,
siksi vakio-oletus).

**Matkalla loytyi toinen merkittava, aiemmin piilossa ollut bugi:**
`lane_fsm`:n `S_DONE`-tila oli pysyva lopputila - ei koskaan palannut
`S_IDLE`:hen, joten toinen `start`-pulssi ei koskaan kaynnistanyt uutta
ajoa samassa simulaatiossa. Ei huomattu aiemmin koska M1/Vaihe 1/2b
kayttivat moduulia vain KERRAN per simulaatio - 2c-i on ensimmainen
testi joka ajaa saman moduulin kahdesti peräkkäin. Korjattu:
`S_DONE` palaa nyt `S_IDLE`:hen yhden syklin jalkeen.

Todennus: (1) VALITILA tarkistettu erikseen heti tason 6 jalkeen ennen
tason 5 ajoa (ei vain lopputulosta - deterministinen ketju voisi
teoriassa nayttaa oikealta lopussa vaikka valivaihe olisi vaara), (2)
LOPPUTILA tason 5 jalkeen, molemmat bittitarkkoja 2a:n golden-malliin
nahden, 2 eri satunnaissiementa. Negatiivikontrolli: tason 5 kahden
ryhman zeta-arvot vaihdettu tahallaan ristiin lanejen valilla ->
256/256 sanaa vaarin - lane<->ryhma<->zeta-yhdistys on todistetusti
merkityksellinen.

Seuraava askel M2 Vaihe 2c-ii:hen: laajenna kaikkiin 7 tasoon (level 6..0),
kukin tasolla oma zeta-avaruus ja globaali butterfly-asemointi. Sama
testifilosofia. Vasta tämän jälkeen M2 Vaihe 3 (neljä pankkia, oikea
osoitus, konfliktinhallinta) - laskennan pitää olla todistetusti oikein
ennen muistiosajärjestelmän monimutkaistamista, jotta virheen lähde
(matematiikka vs. muistiohjaus) pysyy erotettavissa.

**M2 Vaihe 2c-ii:n todennus (2026-07-10):** Koko 7-tasoinen Kyber-NTT.
Arkkitehtoninen periaate: `m2-golden/gen_full_ntt_vectors.py` generoi
TARKAN AIKATAULUN (taso, ryhmäpari, osoitteet, zetat) suoraan samasta
silmukkarakenteesta jota jo riippumattomasti todennettu `ntt()`-funktio
kayttaa - ei erillista, käsin johdettua osoite/zeta-logiikkaa RTL-
testipenkin puolella, jotta kaksi kielta eivät voi laskea samaa asiaa
hienovaraisesti eri tavalla. Taso 6 (1 ryhmä, pariton) ajetaan olemassa
olevalla `pqc_ntt_level6_2lane`-moduulilla (ei muuteta). Tasot 5..0
(kaikki parilliset ryhmämäärät: 2/4/8/16/32/64) ajetaan
`pqc_ntt_stage_2lane`-moduulilla TOISTUVASTI, 63 ryhmäparia yhteensä,
lukien parametrit (`pair_dist`, `base_addr`, `zeta`) suoraan
aikataulutiedostosta.

Todennus: kaikki 256 sanaa täsmäävät `ntt()`-golden-malliin bittitarkasti,
2 eri satunnaissiementä. Negatiivikontrolli: taso 6 ohitettu tahallaan
(tasot 5..0 ajettu suoraan raa'alle syötteelle) -> 256/256 sanaa väärin -
taso 6 on todistetusti välttämätön osa ketjua, ei redundantti.

Mitä 2c-ii EI todista: ei muistin banking-järjestelmää (M2 Vaihe 3:n
laajuus - tässä käytetään yhtä isoa muistitaulukkoa, ei neljää pankkia),
ei ajonaikaista aikataulutinta LAITTEISTOSSA (aikataulu ajetaan
testipenkin/ohjelmiston toimesta, ei RTL:n omalla tilakoneella -
"hardware scheduler" olisi oma, myöhempi laajennus).

## Arkkitehtuuri (M1 + M2 Vaihe 1/2a/2b/2c-i/2c-ii/3a/3b/3c -skoopissa toteutettu)

**M2 Vaihe 3b:n todennus (2026-07-11):** Taso 6, oikea 4-pankkinen muisti
(`rtl/pqc_ntt_level6_banked.sv`), käyttäen 3a:n muodollisesti todistettua
ROM-kuvausta (`m2-golden/bank_rom_4banks.memh` + `bank_local_4banks.memh`).
Ei muuta `lane_fsm`:aa (`pqc_rvv_cluster_2lane.sv`) - käyttää sitä
muuttumattomana. Sama laskenta kuin 2b:ssä, uusi asia on itse
muistireititys.

**Todennus kolmiosaisena:**
1. Kaikki 256 sanaa täsmäävät 2b:n omaan golden-malliin (sama laskenta,
   eri muistireititys), 2 eri satunnaissiementä.
2. **Ajonaikainen konfliktintunnistus**: jokaisella syklillä tarkistetaan
   erikseen (ei vain oleteta 3a:n todistuksen perusteella) etteivät
   molemmat lanet koskaan osu samaan pankkiin. Nolla konfliktia koko
   ajon aikana - 3a:n offline (Z3) todistus vahvistuu myös oikeasti
   ajetussa RTL:ssä.
3. Negatiivikontrolli: ROM tahallaan rikottu (pakotettu osoite 64
   samaan pankkiin kuin osoite 0) -> ajonaikainen tarkistus havaitsee
   2 konfliktia, ja laskenta todistetusti hajoaa (5 väärää tulosta) -
   konfliktintunnistus ei ole vain koriste, se havaitsee aidon virheen.

**Matkalla löytyi ja korjattiin Icarus Verilog -spesifinen ongelma**
(ei looginen suunnitteluvirhe): alkuperäinen lukulogiikka käytti
jatkuvaa sijoitusta (`assign rdata_a0 = read_bank(...)`) automaattista
funktiota kutsuen. Tämä EI päivittynyt oikein kun VAIN pankkitaulukon
sisältö muuttui (esim. toisen lanen kirjoitus) - iverilog seurasi vain
funktion omien argumenttien (pankki-indeksi, paikallinen osoite)
muutoksia, ei niiden SISÄLLÄ luettuja taulukkoalkioita. Aiheutti sen
että ensimmäisen butterflyn (idx=0) lukema jäi `x`:ksi koko sen
käsittelyn ajan, tuottaen väärän (nolla) tuloksen juuri niille neljälle
osoitteelle. Korjattu `always_comb`-lohkolla, joka seuraa oikein kaikkea
sisällä luettua.

Mitä 3b EI todista: ei kaikkia 7 tasoa (M2 Vaihe 3c:n laajuus), ei
suorituskykyä/syklimääriä (M2 Vaihe 3d).

**M2 Vaihe 3c:n todennus (2026-07-11):** Kaikki 7 tasoa, oikea
4-pankkinen muisti kaikilla. `rtl/pqc_ntt_stage_banked.sv` - YKSI
yleinen moduuli (yhdistää 2c-ii:n ajonaikaisen parametroinnin ja 3b:n
4-pankkisen muistin + `always_comb`-korjauksen alusta asti). Käsittelee
myös tason 6 samalla yleisellä rajapinnalla (base0=0, base1=64,
pair_dist=128, molemmat lanet sama zeta) - ei enää erillistä
level6-erikoismoduulia. YKSI moduuli-instanssi koko 7-tason ajolle -
pankit säilyvät instanssin sisällä, ei tarvitse siirtää dataa kahden
DUT:in välillä (toisin kuin 2c-ii, joka käytti kahta erillistä
muistia). Sama aikataulutiedosto kuin 2c-ii:ssä.

Todennus: kaikki 256 sanaa täsmäävät golden-malliin, 2 eri
satunnaissiementä. Ajonaikainen konfliktintunnistus: 0 konfliktia
kaikkien 448 nelikön yli (7 tasoa). Negatiivikontrolli: ROM rikottu
-> 10 konfliktia havaittu, laskenta todistetusti hajoaa. PASS toistuu
korjauksen palautuksen jälkeen.

- Montgomery-reduktio (behavioral, ei pipelinoitu)
- Yksi jaettu pankki (bank0), round-robin-arbitroitu 2 lanen kesken
- Per-butterfly zeta-indeksointi jaetusta tw_window-taulukosta (M2 Vaihe 1)
- 2-lane FSM: IDLE → REQ_READ → COMPUTE → REQ_WRITE → (seuraava/DONE)

## Toolchain

- Icarus Verilog 12.0 (testattu tässä ympäristössä, ei vielä Pi5:llä)
- Python `gen_vectors.py` → `.memh` → SV-testipenkki

## Yhteys TrustCore NX:ään

NTT256 tässä käyttää Kyberin (ML-KEM) 16-bittistä Montgomery-reduktiota
(Q=3329). **Ei ML-DSA/Dilithium** — Dilithiumin Montgomery on 32-bittinen
(Q=8380417, R=2^32). Dual-Pi-protolle (ML-DSA-65-allekirjoitus) tämä M1/
M2 Vaihe 1 ei kelpaa sellaisenaan (sama Kyber-parametrisointi molemmissa);
tarvitaan erillinen 32-bittinen Dilithium-Montgomery
(ks. hardware/pqc-rtl/rvv/README.md).
Tämä RTL siirtyy suoraan TrustCore NX ASIC:iin — synteesikelpoisen
uudelleenkirjoituksen jälkeen (M3/M4).


