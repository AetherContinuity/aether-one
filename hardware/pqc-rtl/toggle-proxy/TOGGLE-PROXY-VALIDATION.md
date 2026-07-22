# Toggle-count-proxy: mittarin validointi tunnetulla vuodolla

**Tila (paivitetty 2026-07-22, jatko):** EI VIELA VALIDOITU. Alkuperainen
tapahtumapohjainen mittari osoittautui metodologisesti puutteelliseksi
(mittasi vaaraa suuretta leveille signaaleille). Korjattu, bittitasoinen
versio EI VIELA lapaise validointia - se paljastaa itse selittamattoman
vaihtelun jopa tunnetussa leikkitoteutuksessa. Decapsiin EI OLE
sovellettu mitaan luotettavaa tulosta. Ks. "Paivitys 2026-07-22" alla.

## Menetelma

Kaksi leikkitoteutusta, SAMAT syotteet, RINNAKKAIN samassa
simulaatiossa:
- `toy_leaky_compare.sv`: 32-tavuinen vertailu VARHAISELLA
  keskeytyksella (tunnetusti vuotava, positiivikontrolli).
- `toy_constant_compare.sv`: sama vertailu YHTENA leveana
  `===`-lausekkeena (sama rakenne kuin ML-KEM:n oma, jo todettu
  syklitasolla vakioaikainen vertailu - negatiivikontrolli).

Neljä tapausta: eroaa tavussa 0 (aikaisin), tavussa 15 (keskella),
tavussa 31 (myohaisin), tai ei eroa lainkaan (taysi skannaus).

`count_toggles.py`: minimaalinen VCD-jasennin joka laskee arvon-
vaihtumien maaran per moduulihierarkia (`dut_leaky` / `dut_const`).

**HUOM tulkinnassa:** `clk`/`reset`/`start`/`a_in`/`b_in` jakavat
saman VCD-tunnisteen molempien moduulien kesken (Icarus ei
dupliloi pass-through-signaaleja) - naita EI kayteta vertailussa,
koska ne heijastavat testipenkin OMAA kokonaiskestoa (rajoittuu
hitaamman moduulin mukaan), EI moduulikohtaista aktiivisuutta.
Tulkinta rajattu SISAISIIN/ulostulosignaaleihin (`state`, `idx`,
`cmp_stage_out`, `done`, `match_out`).

## Tulokset

### Positiivikontrolli (`toy_leaky_compare`, `idx`-laskurin kytkennat)

| mismatch_pos | idx-kytkennat |
|---|---|
| 0 (aikaisin) | 2 |
| 15 (keskella) | 17 |
| 31 (myohaisin) | 33 |
| ei eroa (taysi skannaus) | 33 |

Tasan monotoninen suhde vuotoaseman ja kytkentamaaran valilla -
MITTARI NAKEE TUNNETUN VUODON.

### Negatiivikontrolli (`toy_constant_compare`, `state`/`done`-kytkennat)

| mismatch_pos | state-kytkennat | done-kytkennat |
|---|---|---|
| 0 | 5 | 4 |
| 15 | 5 | 4 |
| 31 | 5 | 4 |
| ei eroa | 5 | 4 |

TASAN SAMAT kaikissa neljassa tapauksessa - MITTARI EI NAYTA VUOTOA
JOSSA SITA EI OLE.

## PAIVITYS 2026-07-22: alkuperainen validointi oli metodologisesti puutteellinen, korjaus paljasti UUDEN avoimen kysymyksen

**Alkuperainen `count_toggles.py` (yllaoleva validointi) laski
ARVONVAIHTOTAPAHTUMIA (yksi VCD-rivi = yksi "kytkenta"), EI
BITTITASON Hamming-etaisyytta.** Tama on metodologisesti TYHJA
leveille signaaleille (esim. 256-bittinen `K_final_out`): "arvo
vaihtui" -tapahtumien maara on SAMA riippumatta siita ovatko kaksi
eri arvoa lahella toisiaan vai taysin erilaisia. TODELLINEN
tehonkulutukseen korreloiva suure ON bittien maara jotka vaihtavat
tilaa, EI arvonvaihtotapahtumien lukumaara. TAMA LOYTYI ennen kuin
tyokalua sovellettiin Decapsiin - Decaps-tulos ("kokonaiskytkennat
tasan samat molemmilla poluilla") oli SAATU alkuperaisella,
PUUTTEELLISELLA versiolla ja ON SITEN HYLATTAVA, EI raportoitava
tuloksena.

**Korjattu versio** (laskee XOR-pohjaisen Hamming-etaisyyden
perakkaisten arvojen valilla monibittisille signaaleille) **PALJASTI
UUDEN, VIELA RATKAISEMATTOMAN kysymyksen:** uudelleenajettuna toy-
esimerkeille, SEKA `dut_leaky` ETTA `dut_const` naytttavat NYT
kasvavaa bittikytkentamaaraa mismatch_pos:in mukaan (leaky:
195/279/368/375; const: 195/223/252/257 jarjestyksessa pos=0/15/31/
ei-eroa) - EI ENAA selkeaa positiivi/negatiivi-erottelua.

**Tarkistettu ja HYLATTY hypoteesi:** syotteen oma korruptio (XOR
0xFF) tuottaa SAMAN Hamming-painon (popcount=7) kaikissa kolmessa
testatussa positiossa (a_in:n tavut noilla positioilla ovat kaikki
popcount=1: 0x01, 0x10, 0x20) - tama EI siis selita havaittua
vaihtelua.

**Todellinen syy ON VIELA TUNNISTAMATTA.** Tama ON aito, avoin
metodologinen kysymys - EI ratkaistu tassa istunnossa aikarajoitteen
vuoksi.

## Rehellinen tila 2026-07-22 (paivitetty)

- **Alkuperainen validointi (tapahtumapohjainen) EI OLE ENAA voimassa**
  - se mittasi vaaraa suuretta.
- **Korjattu, bittitasoinen tyokalu ON OLEMASSA, MUTTA EI VIELA
  VALIDOITU** - se ITSE paljastaa selittamattoman vaihtelun jopa
  tunnetussa leikkitoteutuksessa, ENNEN kuin mitaan voidaan sanoa
  Decapsista.
- **Decapsiin EI OLE sovellettu mitaan luotettavaa toggle-analyysia
  tassa istunnossa.** Aiemmin saatu "tasan sama kokonaiskytkenta-
  maara" -tulos Decapsille perustui VIRHEELLISEEN tyokaluun ja ON
  HYLATTY - EI raportoida `M3_MLKEM_ACVP_STATUS.md`:hen konformanssi-
  tai ajoitusvaitteena.

## Suositus jatkotyolle (seuraava istunto)

1. Selvita miksi bittitason kytkentamaara vaihtelee `mismatch_pos`:n
   mukaan MOLEMMISSA (leaky JA const) toy-moduuleissa, vaikka
   syotteen oma korruption Hamming-paino on vakio. Epaillyt syyt
   (EI viela tarkistettu): (a) `a_in`/`b_in`-signaalien OMA
   toggle-osuus kokonaislaskennassa (naiden pitaisi ehka olla
   POISSULJETTU, samalla tavalla kuin `clk`/`reset`/`start` jo
   suljettiin pois - NAMA OVAT MYOS pass-through-syotteita, ei
   moduulin OMAA laskentaa); (b) jokin muu, viela tunnistamaton
   VCD-jasennyksen oma virhe.
2. VASTA kun bittitasoinen tyokalu naytttaa SELKEAN, SELITETYN
   positiivi/negatiivi-erottelun (sama vaatimus kuin alkuperainen
   validointi, MUTTA nyt oikealla mittarilla) - VASTA SITTEN sovelleta
   sita Decapsiin uudelleen.
3. Tama ON tarkka esimerkki siita miksi mittarin validointi ENNEN
   kohteen mittaamista on valttamatonta - kaksi eri metodologista
   virhetta (tapahtuma- vs. bittipohjainen laskenta, JA nyt tama
   toinen, viela selittamaton vaihtelu) loytyivat SEKVENSSISSA,
   kumpikin ENNEN kuin virheellista tulosta olisi voitu raportoida
   Decapsista.
