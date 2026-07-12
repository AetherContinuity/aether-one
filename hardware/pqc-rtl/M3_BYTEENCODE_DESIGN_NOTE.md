# M3 Issue #7 — ByteEncode/ByteDecode: arkkitehtuurivaihtoehtojen vertailu

**Päivämäärä:** 2026-07-12
**Tila:** Suunnitteludokumentti ennen toteutusta. Yritys 1 (yksi valtava
`always_comb`-lohko, ajonaikaiset silmukat) hylätty - ks. Issue #7:n
kommentti. Tämä dokumentti vertailee kaksi vaihtoehtoista arkkitehtuuria
ennen seuraavaa toteutusyritystä.

## 1. Miksi yritys 1 epäonnistui - hypoteesi, ei todistettu

Yksi `always_comb`-lohko jossa silmukka purkautuu ajonaikaisesti jopa
3072 iteraatioon (d=12: 256×12 bittiä) käyttäytyi epäluotettavasti
iverilogissa - jokainen korjausyritys (muuttujien leventäminen,
siirto silmukan sisältä moduulin tasolle) teki tuloksen huonommaksi.
Tarkkaa juurisyytä ei jäljitetty loppuun asti (aika/laajuus-syista),
mutta havainto on riittävä hylkäämään TÄMÄN NIMENOMAISEN toteutustavan
- ei riitä päättelemään että KAIKKI kombinatorinen toteutus olisi
mahdotonta (ks. Compress/Decompress, M3 #6, joka ONNISTUI - 256
iteraatiota, EI sisäkkäisiä 3072:een asti purkautuvia silmukoita).

## 2. Tärkeä, tarkistettu arkkitehtoninen fakta

FIPS 203:n koko spesifikaatio (K-PKE.KeyGen, K-PKE.Encrypt,
K-PKE.Decrypt - tarkistettu kaikki kutsupaikat lopullisesta tekstistä)
kayttaa ByteEncode/ByteDecodea AINA kiintealla, kaannosaikaisella
d-arvolla:

| Kutsupaikka | d |
|---|---|
| ekPKE ← ByteEncode12(t_hat) | 12 |
| dkPKE ← ByteEncode12(s_hat) | 12 |
| t_hat ← ByteDecode12(ekPKE[...]) | 12 |
| mu ← Decompress1(ByteDecode1(m)) | 1 |
| c1 ← ByteEncode_du(Compress_du(u)) | du (10 tai 11, parametrisarjan mukaan kiintea) |
| c2 ← ByteEncode_dv(Compress_dv(v)) | dv (4 tai 5, parametrisarjan mukaan kiintea) |
| u' ← Decompress_du(ByteDecode_du(c1)) | du |
| v' ← Decompress_dv(ByteDecode_dv(c2)) | dv |
| s_hat ← ByteDecode12(dkPKE) | 12 |
| m ← ByteEncode1(Compress1(w)) | 1 |

**d EI TARVITSE olla ajonaikainen portti.** Alkuperainen suunnitteluni
(d ajonaikaisena 4-bittisena porttina, sama moduuli kaikille d-arvoille)
oli tarpeettoman joustava - todellinen kayttotarve on aina yksi kiintea
d-arvo per kutsupaikka.

## 3. Vaihtoehto A — Modulaarinen kombinatorinen, d kaannosaikaisena parametrina

d muutetaan SystemVerilogin `parameter`-arvoksi (ei runtime-porttia).
Tama mahdollistaa `generate`/`genvar`-pohjaisen rakenteellisen
silmukan, joka puretaan KAANNOSAIKANA (elaboration time), ei
ajonaikaisesti simuloituna prosessina - eri mekanismi kuin yritys 1:n
`for (int i...)`-silmukka `always_comb`:n sisalla.

**Edut:**
- Valttaa juuri sen mekanismin (ajonaikaisesti purkautuva silmukka
  isossa always_comb-lohkossa) joka epaonnistui yrityksessa 1.
- Vastaa todellista kayttotarvetta tarkasti (d on aina kiintea
  kaannosaikana oikeassa algoritmissa, ks. §2).
- Jokainen tarvittava d-arvo (1, 4, 5, 10, 11, 12) voidaan instansioida
  erikseen ja testata erikseen, pienempina paloina.
- Genvar-pohjainen generate on lahempana oikeaa synteesikelpoista
  rakennetta kuin ajonaikainen silmukka - hyodyttaa myos M4:aa
  (synteesikelpoisuus) myohemmin.

**Haitat:**
- Vaatii kuusi erillista moduuli-instanssia (tai parametrisoitua
  instansiointia) eri d-arvoille sen sijaan etta yksi moduuli
  kasittelisi kaikki - hieman enemman koodia, mutta jokainen pala
  on pienempi ja yksinkertaisempi.
- Ei viela todistettu toimivaksi - tama on hypoteesi joka pitaa
  testata.

## 4. Vaihtoehto B — Sekventiaalinen FSM

Yksi kellotettu tilakone, joka kasittelee yhden Z_m-arvon (d bittia)
per sykli, laskuri 0..255, samaan tyyliin kuin `lane_fsm`
(pqc_rvv_cluster_2lane.sv) joka on jo todistettu luotettavaksi
iverilogissa suurillakin (256×7-tason) iteraatiomaarilla.

**Edut:**
- Todistetusti toimiva malli tassa projektissa (lane_fsm) - ei uusi,
  testaamaton lahestymistapa.
- Realistisempi oikealle laitteistolle (256 arvon sarjallistaminen
  kapealle vaylalle vaatii oikeasti useita sykleja joka tapauksessa).
- d voi silti olla ajonaikainen jos joskus tarvitaan (vaikka §2:n
  mukaan tata ei tarvita).

**Haitat:**
- Lisaa sekventiaalista ajoituskompleksisuutta puhtaasti
  algoritmiselle, tilattomalle muunnokselle (ByteEncode/Decode ei
  ole luonnostaan tilallinen operaatio - Compress/Decompress ja
  BaseCaseMultiply, jotka molemmat onnistuivat kombinatorisesti,
  ovat samantyyppisia "puhtaita funktioita").
- Enemman koodia/tilaa (start/done-kasittely) yksinkertaiselle
  bittipakkaukselle.

## 5. Suositus

**Vaihtoehto A (modulaarinen kombinatorinen, d kaannosaikaisena
parametrina) kokeillaan ensin.** Perustelu: §2:n tarkistettu fakta
(d on aina kaannosaikana kiintea oikeassa kaytossa) tekee tasta
paitsi todennakoisesti vakaamman ratkaisun iverilogille, myos
arkkitehtonisesti oikeamman - ei vain "valta FSM koska edellinen
kaatui" vaan aito tekninen peruste joka on riippumaton yritys 1:n
epaonnistumisesta.

Jos Vaihtoehto A EI toimi luotettavasti (esim. sama iverilog-
epavakaus toistuu myos genvar-pohjaisella rakenteella), siirrytaan
Vaihtoehto B:hen (FSM) - ei toistetta ilman uutta nayttoa etta A
epaonnistuu nimenomaan.

## 6. Seuraava askel

Toteuta Vaihtoehto A ensin YHDELLE d-arvolle (esim. d=1, pienin ja
yksinkertaisin) taydellisella todennuksella (golden-malli, negatiivi-
kontrolli) ennen muiden d-arvojen lisaamista - sama pienten askelten
periaate kuin M2/M3:ssa muutenkin.

## 7. LOPPUTULOS (2026-07-12) — todellinen juurisyy loydetty, ei arvailu

d=1 toteutettiin Vaihtoehto A:n mukaisesti (genvar/generate), mutta
EPAONNISTUI TAYSIN samalla tavalla kuin yritys 1 - KAIKKI ulostulot
'x':aa jopa yksinkertaisimmalla testitapauksella. Tama oli yllattavaa
(§5:n oletus oli etta genvar valttaisi ongelman) ja johti taydelliseen
eristykseen:

**Todistettu, EI enaa hypoteesi:** Icarus Verilog (tama versio) EI
valita unpacked-taulukkoa ("logic x [0:N]") oikein moduulin PORTIN lapi
- vastaanottava puoli saa AINA 'x':n, riippumatta sisaisesta logiikasta
(assign, generate, always_comb - kaikki testattu erikseen minimi-
esimerkilla) tai elementin leveydesta (testattu seka 1-bittisella
etta 16-bittisella elementilla). SAMASSA scopessa (ei porttia) TAI
hierarkkisen pistoksen kautta (`dut.signal[i] = ...`, kuten M2:n
testipenkit tekevat) unpacked-taulukko toimii TAYDELLISESTI.

Tama selittaa TAYDELLISESTI seka yritys 1:n etta d=1-genvar-yrityksen
epaonnistumisen - molemmat kayttivat unpacked-taulukkoa PORTTINA.
Selittaa myos miksi mikaan M2:n moduuli ei koskaan tormannyt tahan:
M2 kaytti joko yksittaisia leveita arvoja portteina (esim.
pqc_basecasemul.sv) TAI piti taulukot sisaisina signaaleina joihin
testipenkki pistaa hierarkkisesti (pqc_ntt_stage_banked.sv:n bank0
jne.) - ei koskaan unpacked-taulukkoa suoraan porttina.

**Korjaus, todistettu toimivaksi:** portit PAKATTUINA vektoreina
("logic [N-1:0]"), ei unpacked-taulukkoina. d=1:lle: `logic [255:0]
f_in` (256 bittia yhtena bussina), viipaloituna tarvittaessa
`[i +: 1]` tai `[i*8 +: 8]`. Toteutettu `pqc_byteencode_d1.sv`:ssa,
todennettu 10 testitapauksella + negatiivikontrollilla (seka
porttiyhteyden etta itse logiikan rikkomiskoe).

**Yleinen periaate jatkoa varten (kaikki tuleva RTL, ei vain
ByteEncode/Decode):** kun moduulin portti tarvitsee kuljettaa useamman
elementin taulukon, kayta PAKATTUA vektoria ("logic [N-1:0]") ja
viipaloi sisaisesti - ala kayta unpacked-taulukkoa ("logic x [0:N]")
porttina tassa iverilog-versiossa.
