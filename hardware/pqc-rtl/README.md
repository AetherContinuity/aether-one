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
| M2 Vaihe 3d | Suorituskykymittaus (syklit, pankkien käyttöaste) | ✅ TODENNETTU 2026-07-11, ks. rajaus alla |
| **M3 · Issue #1** | BaseCaseMultiply RTL:ssä | ✅ TODENNETTU 2026-07-12, ks. rajaus alla |
| **M3 · Issue #6** | Compress_d / Decompress_d RTL:ssä | ✅ TODENNETTU 2026-07-12, ks. rajaus alla |
| **M3 · Issue #7** | ByteEncode_d / ByteDecode_d RTL:ssä | ✅ TODENNETTU 2026-07-12 kaikille d=1,4,5,10,11,12 - ks. rajaus alla |
| **M3 · Issue #8** | K-PKE.Decrypt kokonaisuudessaan (k=2, du=10, dv=4) | ✅ TODENNETTU 2026-07-12 - ks. rajaus alla |
| **M3 · Issue #10** | Keccak-p[1600,24] permutaatioydin RTL:ssä | ✅ TODENNETTU 2026-07-12 - ks. rajaus alla |
| **M3 · Issue #11** | Sponge-kehys (pad10*1, absorbointi, puristus) | ✅ TODENNETTU 2026-07-12 - ks. rajaus alla |
| **M3 · Issue #12** | SHA3-256 kokonaisuudessaan + NIST-ankkurointi | ✅ TODENNETTU 2026-07-12 - ks. rajaus alla |
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

## Arkkitehtuuri (M1 + M2 Vaihe 1/2a/2b/2c-i/2c-ii/3a/3b/3c/3d/M3#1 -skoopissa toteutettu)

**M3 Issue #1:n todennus (2026-07-12) — BaseCaseMultiply RTL:ssä:**
`rtl/pqc_basecasemul.sv`. Uusi, erillinen kombinatorinen moduuli - ei
kosketa lane_fsm:aa eika NTT-putkea. Kayttaa SUORAA modulaarilaskentaa
(SystemVerilogin oma `%`), EI Montgomery-reduktiota - sama konventio
kuin golden-mallin oma `base_case_multiply` (plain-domain, gamma ei ole
esiskaalattu, toisin kuin NTT:n zeta-arvot). Kolmiosainen todennus:

1. 20 testitapausta suoraan golden-mallista (`m2-golden/kyber_ntt_golden.py`,
   jo todistettu 2a:ssa konvoluutiolauseella), kaikki bittitarkkoja,
   2 eri satunnaissiementa (2026, 13579)
2. Sisainen negatiivikontrolli: gamma muutettu ajon aikana (100->101),
   tulos todistetusti muuttuu - moduuli reagoi gammaan
3. Ulkoinen negatiivikontrolli: c0/c1-kaavat vaihdettu tahallaan ristiin
   -> 40 virhetta (2x20), testi kaatuu oikein

Mita talla EI todisteta: ei synteesikelpoisuutta (`%`-operaattori ei
synteesoidu suoraan taksi jaollisena piirina - synteesikelpoinen
Barrett/Montgomery-reduktio on erillinen, myohempi tyo). Ei viela
kytketty NTT-putken paahaan (encapsulation/decapsulation).

**M3 Issue #6:n todennus (2026-07-12) — Compress_d/Decompress_d RTL:ssä:**
`rtl/pqc_compress.sv`. Pyoristys FIPS 203:n lopullisen tekstin
(ei .ipd-luonnoksen, jossa oli dokumentoitu epaselvyys reunatapauksissa
- ks. M3_DESIGN_NOTE.md) mukainen round-half-up-maaritelma, vahvistettu
FIPS 203:n oman dokumentoidun ominaisuuden (Compress_d(Decompress_d(y))==y)
kautta TAYDELLISESTI (ei otanta) kaikilla d=1,4,5,10,11 ja kaikilla
mahdollisilla y-arvoilla ennen RTL:n kirjoittamista.

Todennus: 1000 Compress- ja 3122 Decompress-testitapausta (Decompress:
TAYDELLINEN kattavuus jokaiselle d:lle, ei satunnaisotos), kaikki
bittitarkkoja. Negatiivikontrolli: Compress/Decompress-kaavat vaihdettu
tahallaan ristiin -> 4120/4122 virhetta, testi kaatuu oikein.

**M3 Issue #7:n todennus (2026-07-12) — ByteEncode1/ByteDecode1 RTL:ssä,
d=1 (d=4,5,10,11,12 avoinna):** `rtl/pqc_byteencode_d1.sv`.

**TARKEA, TAYDELLISESTI TODISTETTU LOYDOS:** Icarus Verilog EI valita
unpacked-taulukkoa ("logic x [0:N]") oikein moduulin PORTIN lapi -
vastaanottava puoli saa AINA 'x':n riippumatta sisaisesta logiikasta
tai elementin leveydesta. Todistettu taydellisesti eristetylla
minimiesimerkilla (8 alkion kopiointi, assign/generate/always_comb,
1-bittinen ja 16-bittinen elementti - kaikki epaonnistuivat samoin).
SAMASSA scopessa tai hierarkkisen pistoksen kautta (kuten M2:n
testipenkit tekevat) unpacked-taulukko toimii taydellisesti - ongelma
on spesifisesti porttiyhteydessa. Tama selittaa TAYDELLISESTI kaikki
taman session ByteEncode/Decode-epaonnistumiset. Ks.
M3_BYTEENCODE_DESIGN_NOTE.md §7 taydelliselle analyysille.

**Korjaus:** portit PAKATTUINA vektoreina ("logic [N-1:0]"), ei
unpacked-taulukkoina. **Yleinen periaate kaikelle tulevalle RTL:lle**:
kun portin pitaa kuljettaa useamman elementin taulukko, kayta pakattua
vektoria, ei unpacked-taulukkoa, tassa iverilog-versiossa.

Todennus: 10 testitapausta golden-mallista, bittitarkkoja.
Negatiivikontrolli (kaksiosainen): (1) porttiyhteyden oma toimivuus
todistettu erillisella minimiesimerkilla ennen korjausta, (2)
itse logiikka rikottu tahallaan (invertoitu ByteEncode1:n tulos)
-> 10/10 virhetta, testi kaatuu oikein.

**M3 Issue #7:n loppuunsaattaminen (2026-07-12) — d=4,5,10,11,12:**
`rtl/pqc_byteencode_dparam.sv`, D kaannosaikaisena parametrina.

**Matemaattinen oivallus** (vahvistettu golden-mallissa ennen RTL:aa):
ByteEncode/ByteDecode on pelkkaa SAMAN LINEAARISEN BITTIJONON
uudelleenryhmittelyä - digit-splittaus (d bittia/arvo) ja tavupakkaus
(8 bittia/tavu) ovat kaksi tapaa ryhmitella sama 256*d-bittinen jono,
ei mitaan permutaatiota. Tasta seuraa: suora bittikopiointi (`assign`)
on TAYSIN OIKEA operaatio seka Encodelle etta Decodelle KAIKILLA
d<12:lla - ei tarvita mitaan laskentaa. d=12 tarvitsee YHDEN
lisavaiheen ByteDecode12:ssa: kunkin 12-bittisen segmentin oma
mod Q -reduktio (FIPS 203:n oma dokumentoitu erikoistapaus - segmentti
voi olla 0..4095, mutta Z_q on 0..3328).

Todennus: 5 testitapausta per d (d=4,5,10,11), PASS kaikilla
ensimmaisella yrityksella (pakattu vektori -korjauksen ansiosta).
d=12 lisaksi oma reunatapaustesti (10 testitapausta, kaikki 12-
bittiset segmentit valilla [Q,4095] - EI satu olemaan jo < Q, joten
testi aidosti todistaa etta mod Q -reduktio aktivoituu, ei vain
sattumalta oikein). Negatiivikontrolli: mod Q poistettu tahallaan
d=12:n ByteDecodesta -> 11 virhetta, testi kaatuu oikein.

**Issue #7 kokonaisuudessaan valmis: kaikki 6 tarvittavaa d-arvoa
(1,4,5,10,11,12) todennettu.**

**M3 Issue #8:n esityo (2026-07-12) — MultiplyNTTs:** `rtl/pqc_multiplyntts.sv`.
Uudelleenkayttaa jo todennetun `pqc_basecasemul`-moduulin (Issue #1)
suoraan, 128 genvar-generoitua instanssia, gamma-arvot ROM:ista
(m2-golden/multiplyntts_gamma_rom.memh, generoitu golden-mallista -
gamma_i = zeta^(2*BitRev7(i)+1) mod q, FIPS 203 Appendix A toinen
taulukko). Portit PAKATTUINA vektoreina (Issue #7:n oma korjattu
periaate).

Todennus: 5 testitapausta golden-mallista (kayttaa suoraan jo
konvoluutiolauseella todennettua `multiply_ntts`-funktiota, M2 Vaihe
2a:sta), bittitarkkoja. Negatiivikontrolli (kaksiosainen): (1) yksi
f_hat-alkio muutettu, h_hat muuttuu todistetusti, (2) yksi gamma-arvo
ROM:ssa rikottu tahallaan -> 6 virhetta, testi kaatuu oikein.

Tama on valmis rakennuspalikka K-PKE.Decryptin kokoonpanolle (Issue #8
paaosa) - kaikki tarvittavat palikat (NTT, BaseCaseMultiply/MultiplyNTTs,
Compress/Decompress, ByteEncode/Decode) ovat nyt olemassa ja todennettu.

**M3 Issue #8:n loppuunsaattaminen (2026-07-12) — koko K-PKE.Decrypt
paasta paahan:** `tb/pqc_kpke_decrypt_full_tb.sv`. Yhdistaa kaikki
neljä vaihetta (kayttajan ehdottama vaiheistus):
- Vaihe 1: ByteDecode+Decompress -> u', v'
- Vaihe 2: NTT(u') + MultiplyNTTs + polyadd -> sum_hat
- Vaihe 3: NTT^-1 + final_scale -> inner (ks. NTT_INVERSE_DESIGN_NOTE.md)
- Vaihe 4: polysub (w=v'-inner), Compress1, ByteEncode1 -> m

Kaksi uutta pientä rakennuspalikkaa: `pqc_polysub.sv` (mod-q-vahennys,
sama rakenne kuin polyadd) ja `pqc_batch_compress.sv` (256 rinnakkaista
pqc_compress-instanssia Compress-suuntaan, taydentaa Vaihe 1:n
pqc_batch_decompress.sv:n).

Testattu k=2, du=10, dv=4 (ML-KEM-512) kiintealla testiavaimella (ei
KeyGen/Encrypt - vaativat Keccakia, Issue #9). PASS ENSIMMAISELLA
YRITYKSELLA jokaiselle valivaiheelle (w, w_compressed, lopullinen m).
Negatiivikontrolli: yksi s_hat-arvo rikottu -> kaikki kolme tarkistusta
(w, w_compressed, m) kaatuvat oikein. Taysi regressio: kaikki 9 aiempaa
testia (M1, 2b, 2c-i, 2c-ii, 3b, 3c, Vaihe 2, NTT^-1 round-trip,
NTT^-1 stage-debug) PASS muuttumattomana.

**Issue #8 kokonaisuudessaan valmis.**

**M3 Issue #10:n todennus (2026-07-12) — Keccak-p[1600,24]
permutaatioydin RTL:ssa:** `rtl/pqc_keccak_f1600.sv`. Iteratiivinen
(1 kierros/sykli, laskuri 0..23) - ks. KECCAK_DESIGN_NOTE.md 3.4
arkkitehtuuripaatokselle. RHO_OFFSETS ja RC-vakiot ROM:eista, generoitu
SUORAAN golden-mallista (keccak_golden.py) - ei kasin transkriboitu.

Todennus kahdella tasolla (kayttajan oma ehdotus): (1) toiminnallinen -
lopputila (24 kierroksen jalkeen) oikea, (2) RAKENTEELLINEN - kaikki
24 valitilaa tasmaavat jaadytettyyn referenssiin (vectors/
keccak_round_snapshots.json) jokaiselle kolmelle testitapaukselle
(all_zero, sha3_256_abc_block, all_ff). PASS kaikilla molemmilla
tasoilla, kaikilla kolmella testitapauksella.

Matkalla loytyi ja korjattiin testipenkin oma ajoituskilpa-ajo (NBA-
region race: hierarkkinen tilan luku heti `@(posedge clk)`:n jalkeen
nappasi rekisterin VANHAN arvon, koska testipenkin oma luku ja DUT:n
always_ff-paivitys kilpailivat samasta delta-syklista) - EI RTL-bugi,
sama oppitunti kuin NTT^-1:n omassa juurisyyanalyysissa: tarkista
testipenkki ensin. Korjaus: `#1`-viive `@(posedge clk)`:n jalkeen
ennen tilan lukua.

Negatiivikontrolli: chi-vaiheen operandien jarjestys vaihdettu
tahallaan ristiin -> virhe havaitaan tasolla 23 (viimeinen kierros,
kun epalineaarinen virhe on ehtinyt levita koko tilaan) seka
lopputuloksessa, testi kaatuu oikein.

**M3 Issue #11:n todennus (2026-07-12) — sponge-kehys (pad10*1,
absorbointi, puristus):** kolme erillista vaihetta (kayttajan oma
ehdotus), kukin testattu itsenaisesti ennen seuraavaa.

- **Vaihe A** (`rtl/pqc_keccak_pad.sv`): pad10*1 + domain-suffiksi,
  testattu TAYSIN IRRALLAAN permutaatiosta. Kolme kriittista
  reunatapausta: tyhja viesti, rate-1 tavua (domain-suffiksi ja
  0x80-paatosbitti YHDESSA tavussa, 0x86), tasan rate tavua
  (domain-suffiksi ja 0x80 ERI lohkoissa). PASS kaikilla kolmella.
- **Vaihe B** (`rtl/pqc_keccak_absorb.sv`): ajaa pqc_keccak_f1600:aa
  lohko kerrallaan, XORaten kunkin RATE_BYTES-lohkon tilaan ennen
  permutaatiota. Testattu 'abc' (1 lohko) ja 'A'*136 (2 lohkoa),
  LOHKOKOHTAISESTI (ei vain lopputulosta) - PASS ensimmaisella
  yrityksella, Issue #10:n oma NBA-region-race-oppitunti (#1-viive)
  sovellettu suoraan alusta asti.
- **Vaihe C** (`rtl/pqc_keccak_squeeze.sv`): puristus, seka yhden
  lohkon (32 tavua, ei lisapermutaatiota) etta useamman lohkon (200
  tavua, 1 lisapermutaatio - SHAKE:n oma tarve) tapaus testattu
  erikseen. PASS molemmilla ensimmaisella yrityksella.

Kaikki kolme vaihetta: negatiivikontrollit (0x80-XOR poistettu,
XOR-kytkenta poistettu, take-rajoitus poistettu) havaitsevat
virheet oikein, testit kaatuvat oikein.

**Issue #11 kokonaisuudessaan valmis.**

**M3 Issue #12:n todennus (2026-07-12) — SHA3-256 kokonaisuudessaan:**
`rtl/pqc_sha3_256.sv`. Puhdas kokoonpano (pqc_keccak_pad + pqc_keccak_absorb
+ pqc_keccak_squeeze), EI uutta aritmetiikkaa - vain FSM joka jarjestaa
vaiheet peräkkäin.

**Kaksinkertainen ulkoinen ankkurointi golden-mallille ennen tata
Issueta:** (1) Pythonin hashlib (riippumaton OpenSSL-pohjainen
toteutus, jo aiemmin Issue #9:ssa), (2) NIST:n oma julkaistu
"SHA3-256_Msg0" esimerkki (csrc.nist.gov:n toolkit-esimerkit, tyhja
viesti) - haettu GitHub-peilista (coruus/nist-testvectors) ja
tarkistettu tasmalleen taydelliseksi (mukaan lukien alkutilan
XOR'd-tavut ja kaikkien 24 kierroksen valiarvot).

Nelja testitapausta: tyhja viesti (NIST-ankkuroitu), "abc" (klassinen
julkaistu vektori), 200 tavua (monilohko-absorbointi), ja **32 tavun
kiintea syote joka vastaa TASMALLEEN miten ML-KEM:n H(s)-funktio
kutsuu SHA3-256:ta myohemmin (Issue #15)** - kayttajan oma ehdotus,
toimii jo nyt API-tason regressiotestina tulevaa integraatiota varten.

PASS KAIKILLA NELJALLA ENSIMMAISELLA YRITYKSELLA - puhtaan kokoonpanon
etu: kaikki rakennuspalikat olivat jo erikseen todennettu (Issue
#10/#11), yhdistaminen ei tuonut uusia virhelahteita. Negatiivikontrolli:
squeeze-vaiheen ulostulopituus muutettu tahallaan (32->31 tavua) ->
kaikki neljä testitapausta kaatuvat oikein.

**Issue #12 kokonaisuudessaan valmis.**

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

**M2 Vaihe 3d:n mittaustulokset (2026-07-11):** `tb/pqc_ntt_full_banked_perf_tb.sv`,
puhtaasti testipenkin puoleista instrumentointia (ei muuta RTL:ää).

- **Jokainen 7 tasosta vie täsmälleen 192 sykliä** ydinlaskentaan
  (64 butterflya/lane × 3 sykliä/butterfly), riippumatta montako
  erillistä ryhmää se tasolla jaetaan useammaksi peräkkäiseksi
  askeleeksi - teoreettinen ennuste piti paikkansa jokaisella tasolla.
- Ylikustannus per taso kasvaa lineaarisesti askelmäärän mukaan
  (2 sykliä/käynnistys: level6/5 1×2, level4 2×4, level3 4×8,
  level2 8×16, level1 16×32, level0 32×64).
- **Pankkien käyttöaste täydellisesti tasan**: 896/896/896/896 luku+
  kirjoitusta koko 7-tason ajon yli - vahvistaa 3a:n todistaman
  64/64/64/64-tasapainon käytännössä koko NTT:n laajuudelta, ei vain
  osoitejakauman rakenteena.
- Kokonaissykliä: 1540 (2 eri satunnaissiementä, identtiset - sykliajat
  eivät riipu datasta, vain ohjausrakenteesta, kuten odotettu).
- **Rehellisesti dokumentoitu jäännös**: yksittäisten tasojen
  ylikustannusten summa (2+2+4+8+16+32+64=128) EI täsmää mitattuun
  kokonaisylikustannukseen (196) - 68 syklin ero jää selittämättä
  (todennäköisesti resetointijakso ja/tai tasosiirtymien välinen aika,
  joita ei seurattu erikseen). Ei korjattu eikä piiloteltu - raportoitu
  sellaisenaan.

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


