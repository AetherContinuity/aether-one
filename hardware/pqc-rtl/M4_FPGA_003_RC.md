# M4_FPGA_003_RC.md — M4-FPGA-003: tutkimusvaiheen paatospiste

**Paivamaara:** 2026-07-19
**Tila:** Tutkimusvaihe PAATTYNYT. Tuotantointegraatio on OMA,
seuraava tyopaketti (M4-FPGA-004).

## Kolme erillista vaitetta, tiukasti erotettuina (kayttajan oma vaatimus)

| Vaite | Tila |
|---|---|
| Arkkitehtuuri inferoituu DP16KD:ksi | ✅ TODISTETTU |
| Arkkitehtuuri on algoritmisesti ekvivalentti vertailumalliin | ✅ TODISTETTU (golden trace, koko 7-vaiheinen ajo, kaikki 64 aikataulun askelta) |
| Tuotantoydin voidaan korvata tallä rakenteella ilman sivuvaikutuksia | ⏳ EI VIELA TODISTETTU - oma tyopakettinsa (M4-FPGA-004) |

**Vain kaksi ensimmaista on tassa dokumentissa vahvistettu. Kolmatta
EI OLE viela edes yritetty - se vaatii oman, huolellisen
integraatiotyonsa tuotantoytimeen (`rtl/pqc_ntt_stage_banked.sv`).**

## Hyvaksymiskriteerit (kaikki vahvistettu uudelleen 2026-07-19)

| Kriteeri | Tulos |
|---|---|
| DP16KD-lohkojen maara | ✅ 4 (yksi per pankki), 3270 solua |
| Golden trace (v10 vs. tuotantoydin, koko 7-vaiheinen ajo) | ✅ 64/64 aikataulun askelta, 0 eroa |
| Koko K-PKE-regressio (tuotantoydin, koskematon) | ✅ PASS (roundtrip, Decaps FO-hylkays, 10x multiseed KeyGen, M2 NTT) |
| CI | ✅ PASS (aiemmin vahvistettu, ei muutoksia tuotantoytimeen tehty tassa vaiheessa) |

## Lopullinen arkkitehtuuri (v10, `fpga/003_archaeology/repro_v10_size128.sv`)

Tama tiedosto on JAADYTETTY tasta eteenpain - ei enaa muutoksia
tutkimusvaiheessa.

### Muistiorganisaatio
- Nelja pankkia (bank0-3), kukin **128 alkiota** x 16 bittia
  (kasvatettu 64:sta - ainoastaan local-indeksit 0-63 ovat koskaan
  kaytossa, loput ovat BRAM-yhteensopivuutta varten pelkkaa
  ylimitoitusta).
- Osoitekartoitus: suljettu XOR-kaava (`bank = addr[1:0]^addr[3:2]^
  addr[5:4]^addr[7:6]`, `local = addr[7:2]`) - todistettu bijektiiviseksi
  ja tayttavan saman konfliktittomuusehdon kuin alkuperainen SAT-
  ratkaistu ROM (BANK_MAPPING_PROOF.md).

### Kirjoitusarbitrointi
- VIISI mahdollista kirjoituslahdetta per pankki (lane0.a, lane0.b,
  lane1.a, lane1.b, bring-up) arbitroitu YHDEKSI fyysiseksi kirjoitus-
  portiksi per pankki, prioriteettijarjestyksella
  (bring-up > lane0.a > lane0.b > lane1.a > lane1.b).
- Konfliktittomuustodistus takaa etta KORKEINTAAN yksi FSM-lahteista
  (a0,b0,a1,b1) osuu mihin tahansa yksittaiseen pankkiin per sykli -
  arbitrointi on siis MATEMAATTISESTI PERUSTELTU muunnos, ei
  optimointikikka.

### Lukuarbitrointi
- VASTAAVASTI viisi mahdollista lukulahdetta arbitroitu YHDEKSI
  fyysiseksi lukuportiksi per pankki.
- **Bring-up-portin aikajako:** bring-up:n oma read_en jakaa SAMAN
  fyysisen lukuportin FSM:n oman arbitroidun lukupolun kanssa -
  OLETUS: bring-up-luku ei koskaan ole aktiivinen SAMALLA syklilla
  kuin operatiivinen NTT-laskenta (paljon heikompi vaatimus kuin
  ajoitusmuutos koko datapolkuun).

### Ajoitus
- **READ_LATENCY=1**: `lane_fsm`:aan lisatty uusi tila (`S_WAIT_READ`)
  joka odottaa yhden ylimaaraisen syklin ennen `a_reg`/`b_reg`-
  nayttestysta - valttamaton koska rekisteroity (BRAM-yhteensopiva)
  muisti ei anna tulosta samalla syklilla kuin osoite asetetaan
  (toisin kuin alkuperainen kombinatorinen luku).
- `READ_LATENCY=0` (oletus, tuotantoytimen nykyinen kaytto) sailyy
  TAYSIN koskemattomana - tama parametri lisattiin nimenomaan
  taaksepainyhteensopivana (M4-FPGA-002D).

### Dedikoidut lukurekisterit
- Jokainen pankki saa OMAN dedikoidun rekisterinsa jokaiselle
  mahdolliselle lukijalle (EI jaettua rekisteria johon MONTA pankkia
  kirjoittaisi case-valinnalla) - tama oli M4-FPGA-003:n oma
  avainloydos (`memory_dff`-diagnostiikka: "no output FF found"
  jaetulle rekisterille, "merging output FF to cell" dedikoidulle).

## Miksi tama toimi: usean riippumattoman loydoksen yhdistelma

Kayttajan oma huomio, kirjattu talteen: **yksikaan yksittainen muutos
EI riittanyt yksinaan.** Lopullinen ratkaisu vaati KAIKKIEN
seuraavien yhdistelmaa:

1. READ_LATENCY=1 (rekisteroity luku, M4-FPGA-002D)
2. Dedikoidut lukurekisterit per pankki (mux VASTA rekisteroinnin
   jalkeen, ei ennen) - M4-FPGA-003A:n oma loydos
3. Kirjoitusarbitrointi (5->1 lahdetta/pankki) - v7a
4. Lukuarbitrointi (5->1 lahdetta/pankki) - v9
5. Bring-up-portin aikajako operatiivisen lukuportin kanssa - v9
6. Pankkien koon kasvatus 128:aan - v10 (yhdistettyna kaikkeen
   ylla olevaan - koko YKSINAAN ei riittanyt, koe M4-FPGA-002E)
7. Oikea verifiointimenetelma (golden trace, kayttajan oma
   ehdotus) - paljasti etta arkkitehtuuri OLI koko ajan oikein,
   ja etta aiempi "255/256 vaarin" -loydos oli oma testivirhe

## Tutkimuksen metodologinen arvo (kayttajan oma huomio)

Tama tutkimuspaketti (M4-FPGA-001 - 003A) kaytti johdonmukaisesti
kolmea tayttavaa menetelmaa:
1. **Black-box**: muuta RTL:aa, katso synteesitulosta.
2. **White-box**: lue Yosysin oma sisainen paatoksenteko
   (`memory_dff`, `$mem_v2`-parametrit).
3. **Delta debugging**: rakenna toimivasta minimista askel
   askeleelta, loyda tarkka murtumakohta.

Useampi hypoteesi testattiin JA KUMOTTIIN ennen lopullista ratkaisua
(case-valinta, ROM vs. kaava, WR_EN-rakenne, default-vs-eksplisiittinen
case) - jokainen kumottu hypoteesi kaventuu seuraavaa tutkimusta,
eika johtopaatoksia tehty ennen kuin niita oli kokeellisesti
vahvistettu tai kumottu.

## Seuraava vaihe: M4-FPGA-004 (tuotantointegraatio, EI VIELA aloitettu)

Vasta nyt, kun kaikki tutkimusvaiheen hyvaksymiskriteerit on
todistettu, on perusteltua aloittaa hallittu integraatio
tuotantoytimeen. Tama on OMA tyopakettinsa, jossa JOKAINEN muutos
tuotantoytimeen (`rtl/pqc_ntt_stage_banked.sv`) validoidaan
UUDELLEEN taydella M3-regressiolla ja CI:lla ENNEN seuraavaa askelta -
sama kurinalaisuus kuin koko tahan asti.
