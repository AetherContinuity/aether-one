# M4-FPGA-003: Memory inference archaeology - white-box tulokset

**Menetelma:** Yosysin oma `debug memory_bram`/`memory_dff`-diagnostiikka,
ei enaa musta laatikko - katsottu TARKALLEEN miksi kukin lukuportti
hylataan.

## Loydos 1: alkuperainen rakenne

`memory_dff`-vaihe raportoi JOKAISELLE pankille (bank0-3) ja JOKAISELLE
niiden 5 "portille" jompikumpi:
- "no output FF found" (bank0,1,2)
- "FF found, but with a mux select that doesn't seem to correspond
  to transparency logic" (bank3)

**Juurisyy loytyi:** alkuperainen koodi kirjoittaa YHTEEN JAETTUUN
rekisteriin (esim. `rdata_a0`) `case`-valinnalla NELJASTA eri
pankista. Yosysin `memory_dff` ei tunnista tata minkaan YKSITTAISEN
pankin omaksi, puhtaaksi lukuportin rekisteriksi, koska rekisterin
arvo riippuu KAIKISTA neljasta pankista valitsimen kautta - ei
puhtaasti YHDEN muistin omasta luvusta.

## Loydos 2: mux-vasta-rekisteroinnin-jalkeen -korjaus

Rakennettu vaihtoehtoinen koodaustapa (`003_mux_after_register.sv`):
JOKAINEN pankki saa OMAN dedikoidun rekisterinsa jokaiselle osoitteelle
(paivittyy JOKA sykli riippumatta valitsimesta), ja lopullinen data
valitaan NAISTA JO REKISTEROIDYISTA arvoista vasta MYOHEMMIN
kombinatorisesti.

**Tulos: 16/19 lukuporttitarkistusta onnistui** ("merging output FF
to cell"), vain 3 jaljella (bank0[0], bank1[0], bank2[0] - bank3
onnistuu jo TAYSIN). Loput 6 "epaonnistumista" koskevat `bank_rom`:ia,
joka on TARKOITUKSELLA pieni (512 bittia) kombinatorinen osoite-
kartoitus - EI ole tarkoitus olla BRAM, tama on odotettu eika
ongelma.

## Jaljella oleva, kavennettu kysymys

Miksi `bank0[0]`, `bank1[0]`, `bank2[0]` (mutta EI `bank3[0]`) yha
epaonnistuvat "no output FF found"? Todennakoinen ehdokas: kirjoitus-
portin oma read-before-write-lapinakyvyystarkistus (DP16KD:n oma
rdwr-semantiikka, ks. /usr/share/yosys/ecp5/brams.txt: "rdwr
no_change/new/old") - koska bank3:n oma kirjoitus (`default:` case-
haara) saattaa saada eri kohtelun Yosysin analyysissa kuin eksplisiit-
tiset `2'd0/1/2`-haarat.

## Ei viela ratkaisua, mutta merkittava kavennus

Tama on ERITTAIN merkittava kavennus: alkuperaisesta "0/20 onnistui"
-tilanteesta paastiin "16/19 onnistuu, 3 jaljella (kaikki liittyvat
kirjoitusportin transparenssiin, ei enaa lukuporttien omaan
rekisterointiin)". Seuraava askel: tutkia TASMALLEEN mika
kirjoitusportin rakenteellinen ero bank3:n ja bank0-2:n valilla
selittaa taman viimeisen eron.

## Lisatutkimus 2026-07-18: RTLIL-vertailu bank0 vs bank3

**Kayttajan oma ehdotus:** vertaile RTLIL-tasolla miksi bank3 onnistuu
mutta bank0-2 eivat.

`write_rtlil`-dumpista loytyi rakenteellinen ero: bank0:n oma
`$memrd`-solmu esiintyy YHDISTETYSSA `connect \B { bank0, bank1,
bank2 }` -rakenteessa, kun taas bank3:n oma on YKSINAINEN, itsenainen
`connect \A`. Tama viittasi siihen etta `case`-lauseen `default:`-
haara (bank3) kasitellaan rakenteellisesti eri tavalla kuin
eksplisiittiset `2'd0/1/2`-haarat.

**Testattu hypoteesi:** korvattu `default:` eksplisiittisella
`2'd3:`:lla (`003b_explicit_case.sv`). **Tulos: EI muutosta** - sama
kolmen epaonnistumisen kuvio (bank0/1/2:n "portti[0]") sailyi
ENNALLAAN. Bank3:n oma "portti[0]" EI enaa edes esiintynyt listassa
(luultavasti optimoitui pois trivialisti eri tavalla).

**Tarkennettu tulkinta "portti[0]":sta:** todennakoisesti tama VIITTAA
kirjoitusportin omaan read-before-write-lapinakyvyystarkistukseen
(DP16KD:n oma rdwr-semantiikka), EI erilliseen lukukanavaan - koska
lukukanavia on vain 4 (a0,b0,a1,b1) mutta "portteja" tarkistetaan 5.
Bank3:n kirjoituspolku nayttaa saavan jostain (viela tunnistamattomasta)
syysta erilaisen, Yosysille helpommin ratkeavan rakenteen kuin
bank0-2:n omat.

**Ei viela lopullista vastausta.** `default` vs. eksplisiittinen
case EI ollut selittava tekija - juurisyy on jotain hienovaraisempaa
kirjoitusportin transparenssilogiikassa, tarkentumatta viela taman
kierroksen aikana.

## M4-FPGA-003A: minimaalinen transparenssitoistin - EI VIELA onnistunut

**Tavoite (kayttajan oma ehdotus):** rakentaa 20-30 rivin toistin
joka tuottaa TASMALLEEN saman "no output FF found" (bank0-2) vs.
"merging output FF" (bank3) -diagnostiikan, ilman koko NTT-ydinta.

**Testattu ensin:** `memory_dff -no-rw-check` -lippu (liittyy read/
write-collision-kasittelyyn). EI MUUTOSTA - sama kuvio sailyi.
Hypoteesi kumottu.

**Rakennettu minimaalinen toistin** (`repro.sv`, ~50 riviä): nelja
pankkia, kirjoitus neljasta lahteesta (case-valinnalla + default),
NELJA lukuosoitetta per pankki (vastaa oikeaa tarvetta: mika tahansa
neljasta lukupolusta voi osua tahan pankkiin) - VAPAILLA
testipenkkittomilla porttisignaaleilla (we0-3, wsel0-3 jne. suoraan
moduulin omina tuloportteina, ei oikeista tilakoneista johdettuina).

**Tulos: KAIKKI NELJA pankkia onnistuivat** ("merging output FF to
cell") - toistin EI viela reprodusoi todellista virhetta.

**Johtopaatos:** jokin oikean jarjestelman yksityiskohta puuttuu
viela toistimesta. Todennakoisin ehdokas: `grant0/grant1/is_write0/
is_write1` -signaalit oikeassa jarjestelmassa TULEVAT `lane_fsm`:n
omista tilakoneista (monimutkaisempi, tilariippuvainen logiikka),
eivat vapaista tuloporteista - tama voi vaikuttaa siihen miten
Yosysin optimointi (`opt`) kasittelee kirjoitusehtoja ENNEN
`memory_dff`:aa. Seuraava askel: lisata TAKAISIN yksinkertaistettu
mutta AIDOSTI TILARIIPPUVAINEN ohjaussignaali (esim. pieni oma FSM
tai ainakin rekisteroity enable-signaali suorien tuloporttien
sijaan) toistimeen.

## LAPIMURTO 2026-07-18: Delta debugging loysi tarkan juurisyyn

**Menetelma (kayttajan oma ehdotus):** rakenna toimivasta minimaali-
sesta toistimesta askel askeleelta lisaten yksi oikean jarjestelman
piirre kerrallaan, ajaen memory_dff jokaisen lisayksen jalkeen.

| Versio | Lisatty piirre | memory_dff-tulos |
|---|---|---|
| v1 (baseline) | - | ✅ Kaikki 4 pankkia onnistuvat |
| v2 | Laskettu XOR-osoite (ei vapaita valintasignaaleja) | ✅ Onnistuu |
| v3 | YKSI aito lane_fsm-instanssi | ✅ Onnistuu |
| v4 | KAKSI aitoa lane_fsm-instanssia | ✅ Onnistuu (kaikki 16 porttia) |
| v5 | + konfliktintunnistus (bank_conflict_detected) | ✅ Onnistuu (kaikki 16 porttia) |
| **v6** | **+ bring-up-lukuportti (FPGA_BRINGUP-tyylinen read_data)** | **❌ bank0/1/2[0] epaonnistuvat - TASMALLEEN sama kuvio kuin oikeassa jarjestelmassa!** |

**JUURISYY LOYDETTY: bring-up-lukuportin lisays (VIIDES lukulahde
neljan pankin case-valintarakenteeseen) on tasmalleen se piirre joka
rikkoo memory_dff:n kyvyn tunnistaa bank0/1/2:n FSM-lukurekistereita
puhtaiksi DFF-yhdistyksiksi. bank3 sailyy toimivana (todennakoisesti
koska sen oma `default`-haara kasittelee seka FSM:n etta bring-up:n
lukupolut jotenkin yhteensopivasti, kun taas eksplisiittiset
2'd0/1/2-haarat eivat).**

Tama VAHVISTAA ja TARKENTAA aiempaa "default vs explicit case"
-hypoteesia (joka aiemmin naytti kumoutuvan kun testattiin PELKASTAAN
bank3:n oman kirjoitus-caseen muutosta) - todellinen mekanismi
liittyy nimenomaan SIIHEN, etta BRING-UP:N lukupolku LISAA VIIDENNEN
kilpailevan lukulahteen, ja Yosysin optimointi kasittelee tata
viidetta lahdetta eri tavalla `default`-haaran (bank3) ja
eksplisiittisten haarojen (bank0-2) kanssa.

## Vaikutus jatkotyohon

Tama on nyt riittavan tarkka ja pieni loytto (~6 rivia koodia lisaa
minimaalisesta v5:sta v6:hon) etta sen pohjalta VOISI:
1. Kokeilla poistaa bring-up:n lukupolku PYSYVASTI oikeasta
   ytimesta (kayttaa esim. VAIN hierarkkista debugia simulaatiota
   varten, ei synteesikelpoisia lukuportteja lainkaan) - jos M4:n
   varsinainen tavoite ei vaadi FPGA:lta ulkoista lukumahdollisuutta
   kesken laskennan.
2. TAI muuttaa bring-up:n lukupolun rakennetta (esim. erillinen,
   EI samaa case-rakennetta uudelleenkayttava, MUX-rakenne) - jatko-
   tutkimuksen aihe.
3. TAI hyvaksya etta bring-up JA BRAM-inferointi eivat toistaiseksi
   ole yhteensopivia SAMASSA moduulissa, ja rakentaa BRAM-inferoitava
   ydin ILMAN bring-up-portteja, kayttaen ERI mekanismia (esim.
   Verilator-simulaatio tai testipenkin oma hierarkkinen pikasy)
   toiminnallista todentamista varten silloin kun BRAM halutaan.

Tama loytto muuttaa M4-FPGA-002/003:n koko suunnan: este EI ollut
koskaan itse NTT-ydin, muistin koko tai case-rakenne sinansa - se oli
NIMENOMAAN bring-up-ominaisuuden (M4-FPGA-001:n oma lisays) OMA
sivuvaikutus BRAM-inferointiin.

## KORJAUS 2026-07-18: memory_dff ei riittanyt - kirjoitusporttien maara on erillinen este

**Kayttajan oma ehdotus testattu:** v7 - SAMA bring-up-rajapinta,
VAIN lukutoteutus muutettu mux-vasta-rekisteroinnin-jalkeen-tyyliksi
(sama kuin FSM-lukuporteissa).

**Tulos `memory_dff`:ssa: TAYDELLINEN ONNISTUMINEN** - kaikki 20
porttia (5 per pankki x 4 pankkia) lapaisevat "merging output FF to
cell".

**MUTTA taysi `synth_ecp5`-synteesi EI SILTI tuottanut DP16KD:ta**
(159830 solua, hajautettu). Tama paljasti etta `memory_dff`:n
lapaisy EI TAKAA `memory_bram`:n onnistumista - kyseessa on KAKSI
ERI porttia peräkkäin, molemmat pitaa lapaista.

**`debug memory_bram`:n oma diagnostiikka paljasti todellisen
jaljella olevan esteen:** bank0 (ja luultavasti bank1-3) saavat
kirjoituksia **USEASTA ERILLISESTA LAHTEESTA** (havaittu vahintaan
3 eri koodirivilta: 119, 125, 129 - vastaten FSM:n a0/b0/a1/b1-
kirjoituspolkuja, JA todennakoisesti myos bring-up:n oma load_valid-
kirjoitus). **ECP5:n DP16KD tukee VAIN 2 porttia YHTEENSA** (koe 4:n
jo aiemmin todistama rajoitus) - mutta jokainen pankki tarvitsee
TAYDESSA jarjestelmassa jopa 5 mahdollista kirjoituslahdetta (2 lanea
x 2 osoitetta + bring-up).

## TARKENNETTU JOHTOPAATOS

Este EI OLE (vain) lukupuolen mux-jarjestys (jonka `memory_dff`
tarkistaa) - se on MYOS (ja lopulta ratkaisevammin) kirjoitusPORTTIEN
MAARA, joka ylittaa DP16KD:n 2-porttirajan riippumatta lukupuolen
korjauksesta. `memory_dff`:n onnistuminen oli VALTTAMATON mutta EI
RIITTAVA ehto - `memory_bram` vaatii LISAKSI etta portteja on
enintaan 2 per muisti-instanssi.

## Vaikutus DCEIN/TN-002-ajatteluun (kayttajan oma nakokulma)

Kayttajan oma D3/D4-erottelu (Operational vs. Diagnostic datapath)
on edelleen OIKEA suunta, MUTTA pelkka bring-up:n LUKUPOLUN
uudelleenjarjestely EI YKSIN riita - myos bring-up:n KIRJOITUSPOLKU
(load_valid) lisaa YHDEN LISAPORTIN joka voi olla se, mika vie
kokonaisporttimaaran DP16KD:n 2-rajan yli. Tama tukee entista
vahvemmin ehdotettua M4-FPGA-003A-tyopakettia (bring-up datapath
isolation), mutta hyvaksymiskriteerien listaan kannattaa lisata
eksplisiittisesti:

✅ EI VAIN lukupolun rakenne, vaan MYOS kirjoituspolun porttimaara
   pysyy <=2 per pankki-instanssi kun bring-up on mukana.

## M4-FPGA-003A jatkokoe: v7a (arbitroitu kirjoitus) vs v7b (suora)

**Kayttajan oma hypoteesi:** onko ongelma loogisten kirjoituslahteiden
maara vai fyysisten kirjoitusporttien maara? Testattu rakentamalla
v7a (yksi arbitroitu kirjoituslahde per pankki, prioriteettijarjes-
tyksella load>a0>b0>a1>b1) verrattuna v7b:hen (5 suoraa lahdetta,
sama kuin aiempi v6/v7).

**Tulokset:**

| Mittari | v7b (suora, 5 lahdetta) | v7a (arbitroitu, 1 lahde) |
|---|---|---|
| memory_dff | 20/20 onnistuu | 20/20 onnistuu |
| bank0:n kirjoitusporttien maara (RTLIL) | 3-5 | **1** (vahvistettu) |
| Solumaara (taysi synteesi) | 159830 | **5684** (96% vahennys) |
| DP16KD? | ❌ | ❌ (viela) |

**OSITTAINEN VAHVISTUS kayttajan hypoteesille:** kirjoituslahteiden
arbitrointi YHDEKSI fyysiseksi portiksi VAHENSI dramaattisesti
solumaaraa (96%) ja onnistui vahentamaan RTLIL-tason kirjoitusportit
yhteen - MUTTA EI VIELA riittanyt taydelliseen DP16KD-inferointiin.

**Tekninen este jatkotutkimukselle:** `debug memory_bram -rules
/usr/share/yosys/ecp5/brams.txt` (seka `debug`-etuliitteella etta
ilman) epaonnistuu toistuvasti "ERROR: Syntax error in rules file
line 1" - tama on TYOKALUN KAYTTOON liittyva este (oikea `synth_ecp5`
-skripti kutsuu memory_bram:ia sisaisesti onnistuneesti, mutta
manuaalinen suora kutsu samalla saantotiedostolla epaonnistuu
jostain viela tunnistamattomasta syysta - mahdollisesti puuttuva
esikasittelyvaihe tai ymparistoasetus jonka synth_ecp5 tekee
automaattisesti).

## Tilanne nyt

Merkittava, mitattava edistys (96% solumaaran vahennys, kirjoitus-
porttien maara 1:een asti), mutta DP16KD ei viela ilmesty. Este on
todennakoisesti viela toinen, tarkentumaton yksityiskohta (mahdollisesti
kirjoitusportin oma transparenssi-/rdwr-maarittely, joka `memory_bram`:n
saantotiedostossa vaatii viela jotain lisaa jota v7a ei viela tayta),
JA erikseen tarvitaan oikea tapa saada `memory_bram`:n oma paatoslogiikka
nakyviin (tekninen este, ei viela ratkaistu).

## RATKAISEVA LOYDOS 2026-07-19: $mem_v2-parametrivertailu paljasti todellisen esteen

**Kayttajan oma ehdotus:** vertaile RTLIL:n $mem_v2-solun parametreja
(ei enaa Verilogia) onnistuneen referenssimuistin (koe 1, 1x DP16KD)
ja v7a:n valilla, memory_dff:n jalkeen.

**Ensin tutkittu (ja KUMOTTU) hypoteesi:** WR_EN-yhteyden outo
rakenne (`bitti[15] toistettuna 16 kertaa`). Vertailu paljasti etta
TAMA SAMA rakenne loytyy MYOS onnistuneesta referenssista - taysin
normaali, standardi Yosys-esitystapa "yksi enable-bitti levitettyna
kaikkiin 16 databittiin". EI ero.

**OIKEA, RATKAISEVA ERO LOYTYI: `RD_PORTS`-parametri.**

| Parametri | Referenssi (1x DP16KD) | v7a bank0 |
|---|---|---|
| WR_PORTS | 1 | 1 (v7a:n arbitrointi korjasi taman!) |
| **RD_PORTS** | **1** | **5** |
| RD_CLK_ENABLE | 1'1 | 5'11111 (kaikki 5 rekisteroity, OK) |
| RD_COLLISION_X_MASK | 0 | 0 (sama) |
| RD_TRANSPARENCY_MASK | 0 | 0 (sama) |

**Yhteensa porttien maara (luku+kirjoitus):**
- Referenssi: 1+1 = **2** (tasan DP16KD:n oma raja)
- v7a: 1+5 = **6** (reilusti yli DP16KD:n 2-porttirajan)

## LOPULLINEN JOHTOPAATOS

v7a:n arbitrointi (kayttajan oma koe) KORJASI OIKEIN kirjoituspuolen
(5->1 kirjoituslahdetta) - tama SELITTAA taydellisesti aiemman 96%:n
solumaaran vahennyksen (kirjoituspuolen logiikka yksinkertaistui
merkittavasti). MUTTA lukupuoli EI VIELA ollut arbitroitu - jokainen
pankki tarvitsee edelleen VIISI erillista samanaikaista lukua (4
FSM-lukua: a0,b0,a1,b1 + 1 bring-up-luku) SAMASSA syklissa, ja
TAMA ylittaa DP16KD:n 2-porttirajan riippumatta kirjoituspuolen
korjauksesta.

**Talla hetkella tiedetaan tasmalleen mika este on jaljella:**
lukuporttien maara (5) ylittaa DP16KD:n kapasiteetin (2 porttia
yhteensa, jaettuna luvun ja kirjoituksen kesken). Tama EI ole enaa
arvailua - se on suoraan luettavissa $mem_v2-solun omasta RD_PORTS-
parametrista.

## Vaikutus arkkitehtuurille

Toisin kuin kirjoituspuoli (jossa yksi arbitroitu portti riitti,
koska VAIN YKSI kirjoitus tapahtuu kerrallaan per pankki todellisessa
kayttotilanteessa), lukupuoli tarvitsee AIDOSTI SAMANAIKAISIA lukuja
(butterfly-laskenta lukee seka a- etta b-arvon SAMALLA syklilla,
molemmilta laneilta). Tama TARKOITTAA etta lukupuolen "arbitrointi"
YHDEKSI portiksi VAATISI joko:
(a) ajoitusmuutoksen (lukea vain 1-2 arvoa per sykli, useampi sykli
    per butterfly-operaatio - vahentaa lapaisyakykyy), TAI
(b) useamman DP16KD-instanssin kayton per pankki (esim. 3x DP16KD
    per pankki jos kukin antaa 2 porttia, jolloin 5 lukua + 1
    kirjoitus = 6 porttia jakautuisi 3 instanssin kesken - MUTTA
    tama vaatisi DP16KD:iden VALISEN datan yhdistamisen, koska
    KAIKKI 3 instanssia sisaltaisivat SAMAN datan kolmena kopiona
    - resurssien haaskausta mutta saattaisi toimia).

Tama on nyt selkea, konkreettinen paatoskohta seuraavalle
tyopaketille: valita (a) vai (b), tai hyvaksya etta bring-up:n oma
lukuportti (5. lukija) poistetaan/rajoitetaan erikseen omaksi
kytkennakseen (esim. multiplekserilla joka jakaa YHDEN FSM-lukuportin
bring-upin kanssa, kun FSM ei ole aktiivinen).

## Teoreettinen minimi ja v8-koe: lukupuolen arbitrointi

**Kayttajan oma oivallus:** koska BANK_MAPPING_PROOF.md:n konfliktit-
tomuustodistus takaa etta KORKEINTAAN yksi neljasta osoitteesta
(a0,b0,a1,b1) osuu MIHIN TAHANSA yksittaiseen pankkiin per sykli,
lukupuoli VOIDAAN arbitroida samalla periaatteella kuin kirjoituspuoli
(v7a).

**Toteutettu (v8):** FSM:n oma lukupuoli (a0,b0,a1,b1) arbitroitu
per pankki YHDEKSI luvuksi (sama periaate kuin kirjoituspuolen v7a),
sailyttaen bring-up:n oman lukuportin erillisena.

**Tulos:**

| Mittari | v7a (vain kirjoitus arbitroitu) | v8 (+ luku arbitroitu) |
|---|---|---|
| RD_PORTS | 5 | **2** |
| WR_PORTS | 1 | 1 |
| Portteja yhteensa | 6 | **3** |
| Solumaara | 5684 | **4738** |
| DP16KD? | ❌ | ❌ (yha 1 portti yli) |

## Teoreettinen minimi (kayttajan oma pyynto)

Todellisen ytimen aidosti SAMANAIKAISET lukulahteet:
- lane0.a, lane0.b, lane1.a, lane1.b: NAISTA konfliktittomuustodistus
  takaa etta KORKEINTAAN YKSI osuu mihin tahansa pankkiin per sykli
  -> arbitroituna 1 fyysinen lukuportti RIITTAA (todistettu v8:ssa,
  RD_PORTS putosi 4:sta 1:een taman osalta).
- bring-up (diagnostiikka): 1 ERILLINEN lukuportti, koska sen oma
  luku EI ole ajoituksellisesti sidottu FSM:n lukusykliin (voi
  tapahtua milloin tahansa, myos silloin kun FSM ei ole aktiivinen).

**Teoreettinen minimi TASSA arkkitehtuurissa: 1 (arbitroitu FSM-luku)
+ 1 (bring-up-luku) = 2 lukuporttia, + 1 kirjoitusportti = 3
YHTEENSA.**

**TAMA YLITTAA DP16KD:n 2-porttirajan YHDELLA porttiyksikolla** -
EI viela sovi yhteen DP16KD:hen, MUTTA on hyvin lahella.

## Mahdollinen viimeinen askel

Jos bring-up:n oma lukuportti VOITAISIIN ajoituksellisesti jakaa
FSM:n oman lukuportin kanssa (esim. bring-up-luku sallittaisiin
VAIN kun FSM ei ole aktiivisesti lukemassa - mux joka valitsee
FSM:n arbitroidun osoitteen TAI bring-up:n osoitteen, ei molempia
samanaikaisesti), teoreettinen minimi putoaisi 2:een (1 luku + 1
kirjoitus) - TASMALLEEN DP16KD:n oma raja.

Tama vastaisi kayttajan oman DCEIN-nakokulman mukaista D3/D4-
erottelua: bring-up (diagnostiikka) EI VOISI toimia TAYSIN
riippumattomasti operatiivisesta datapolusta samanaikaisesti, vaan
jakaisi SAMAN fyysisen portin ajoituksellisesti - hyvaksyttava
kompromissi diagnostiikkaominaisuudelle.

## Vaihtoehto B (kayttajan oma ehdotus): muistin replikaatio

Jos edes tama viimeinen jakaminen ei onnistu/haluta, vaihtoehto on
hyvaksya ETTA nykyinen rinnakkaisuus vaatii USEAMMAN fyysisen
DP16KD-lohkon SAMALLE DATALLE (redundanssi) - tama on kayttajan oma,
teknisesti perusteltu nakemys: "ei epaonnistuminen optimoinnissa,
vaan tekninen ratkaisu kun looginen vaatimus ei ole pienennettavissa
ilman suorituskyvyn muutosta".

## LOPULLINEN LAPIMURTO 2026-07-19: DP16KD ILMESTYI (v10)

**Kayttajan oma viimeinen ehdotus:** aikajaa bring-up:n lukuportti
FSM:n oman arbitroidun lukuportin kanssa (ei kaksi erillista fyysista
porttia).

**v9: RD_PORTS=1, WR_PORTS=1** (tasan sama kuin onnistunut referenssi)
- MUTTA taysi synteesi EI VIELA tuottanut DP16KD:ta (4729 solua).
- $mem_v2-parametrivertailu paljasti VIIMEISEN eron: **SIZE=64
  (v9) vs SIZE=256 (referenssi)**. Kaikki muu tasmalleen identtista.

**v10: v9 + pankkien koko kasvatettu 64:sta 128:aan**
(kayttajan aiemmin todistama kokoraja, nyt yhdistettyna porttien
arbitrointiin):

**TULOS: DP16KD = 4 (yksi per pankki), VAIN 3271 SOLUA.**

Tama on ENSIMMAINEN kerta koko M4-FPGA-002/003-tutkimuksen aikana
etta OIKEAN arkkitehtuurin (aito lane_fsm, konfliktiton pankki-
kartoitus, bring-up-portit) johdannainen tuottaa BRAM-lohkoja.

## Yhteenveto: kolme tekijaa yhdessa, ei yksi

Taydellinen ratkaisu vaati KAIKKI kolme seuraavaa muutosta YHDESSA -
mikaan yksittainen ei riittanyt yksinaan:

1. **Kirjoituspuolen arbitrointi** (v7a): 5 kirjoituslahdetta -> 1
   per pankki, hyodyntaen konfliktittomuustodistusta.
2. **Lukupuolen arbitrointi + bring-up:n aikajako** (v9): 5 lukua ->
   1 per pankki, bring-up jakaa SAMAN portin FSM:n kanssa ajoituksel-
   lisesti (oletus: ei koskaan samanaikaista kayttoa).
3. **Pankkien koon kasvatus** 64 -> 128 (v10, kayttajan aiemmin
   todistama, erillinen kokoraja-havainto).

## Seuraava askel

Toiminnallinen oikeellisuus (simulaatio, golden-malli) tulee
todentaa v10:lle ENNEN kuin tata sovelletaan oikeaan tuotantoytimeen.

## TARKEA VAROITUS: DP16KD-synteesi vahvistettu, TOIMINNALLINEN VIRHE loytyi

v10:n synteesitulos (DP16KD=4, 3271 solua) on VAHVISTETTU Yosysin
rakennetasolla. MUTTA toiminnallinen testi (Icarus Verilog -simulaatio,
golden-malliin vertailu) paljasti VAKAVAN VIRHEEN: **255/256 osoitetta
vaaria** koko 7-tasoisessa NTT-laskennassa.

**TARKEA HAVAINTO:** alkuperainen funktiopohjainen arbitrointilogiikka
(v7a/v8/v9:ssa kaytetty `function automatic ... output` -tyyli) EI
KOSKAAN ollut toiminnallisesti testattu Icarus Verilogilla - vain
Yosysin OMA rakennetarkistus (memory_dff, synth_ecp5) suoritettiin.
Icarus ei edes HYVAKSYNYT alkuperaista funktiosyntaksia ("Function
arguments must be input ports"), joten se korvattiin `for`-silmukka-
pohjaisella logiikalla JUURI TATA toiminnallista testia varten - ja
TAMA UUSI, Icarus-yhteensopiva versio EI toimi oikein.

**JOHTOPAATOS: DP16KD-synteesin onnistuminen EI VIELA todista etta
itse ARBITROINTILOGIIKKA on toiminnallisesti oikein.** Kaksi
toisistaan riippumatonta asiaa: (1) synteesikelpoisuus/BRAM-inferointi
(VAHVISTETTU), (2) toiminnallinen oikeellisuus (VIELA VIRHEELLINEN,
vaatii oman debug-kierroksensa).

**EI VIELA valmista, vahvistettua ratkaisua.** Seuraava valttamaton
askel ennen minkaanlaista soveltamista tuotantoytimeen: debugata
arbitrointilogiikan toiminnallinen virhe (todennakoisin syy: `for`-
silmukan sisainen `case`-rakenne tai `tb[1:0]`-tyyppimuunnos ei
kayttaydy odotetusti Icarus Verilogissa, tai alkuperainen
funktiopohjainen logiikka itsessaan sisalsi jo virheen jota ei
aiemmin havaittu koska sita ei koskaan ajettu simulaationa).

## Kolmivaiheinen debug (kayttajan oma menetelma): ongelma kavennettu ajoitukseen

**Testi rakennettu TAYSIN ilman lane_fsm:aa** - vain bring-up-portin
kautta (load_valid/read_en), jotta kirjoitus- ja lukuarbitrointi
voidaan testata eristettyna FSM:n omasta ajoituksesta.

- **Vaihe 1** (kirjoita kaikki 256 osoitetta bring-up:n kautta): OK.
- **Vaihe 2** (lue kaikki 256 osoitetta HIERARKKISESTI, ohittaen
  lukuarbitroinnin): **0/256 virhetta.** Kirjoituspolku (muisti-
  organisaatio + kirjoitusarbitrointi) TAYSIN OIKEIN.
- **Vaihe 3** (lue samat 256 osoitetta ARBITROINNIN KAUTTA,
  bring-up:n read_en-polku): **0/256 virhetta.** Lukuarbitrointi-
  logiikka TAYSIN OIKEIN.

**JOHTOPAATOS (kayttajan oma kolmihaarainen paattely):** koska
MOLEMMAT vaiheet onnistuivat taydellisesti mutta koko 7-tasoinen
NTT-laskenta (lane_fsm:n kautta) epaonnistui 255/256 osoitteessa,
**ongelma EI OLE muistiorganisaatiossa EIKA arbitrointilogiikassa
itsessaan - ongelma on AJOITUKSESSA**, todennakoisesti lane_fsm:n
oman moniajovuoroiden (a0,b0,a1,b1-luku/kirjoitus useiden syklien
aikana) ja arbitrointilogiikan valisessa vuorovaikutuksessa.

Tama kaventaa ongelman TASMALLEEN kayttajan oman menetelman
mukaisesti: EI tarvitse enaa epailla muistiorganisaatiota tai
arbitrointia - jaljella on VAIN ajoitusvuorovaikutus lane_fsm:n
kanssa.

## Seuraava askel

Tutkia TASMALLEEN mika ajoitusero syntyy kun lane_fsm (todellinen
moniajovaiheinen S_REQ_READ->S_WAIT_READ->S_COMPUTE->S_REQ_WRITE-
sykli) on aktiivinen samanaikaisesti arbitrointilogiikan kanssa -
todennakoinen ehdokas: pb_a0/pb_b0/pb_a1/pb_b1 (osoitteet joita
arbitrointi kayttaa VALINTAAN) saattavat MUUTTUA lane_fsm:n oman
moniajovaiheisen kierroksen aikana ENNEN kuin arbitroitu luku ehtii
valmistua, aiheuttaen etta arbitrointi valitsee VAARAN pankin
(vanhentuneen osoitteen perusteella) tietylla syklilla.

## TARKEA KORJAUS: aaltomuotovertailun "ero" oli oma testivirhe, ei bugi

Kayttajan oma ehdotus toteutettu: v4 (vanha) vs v10 (arbitroitu)
rinnakkain, yksi lane + kaksi lanea.

**Yhden lanen vertailu (VAIN lane0 aktiivinen, oikealla alustuksella):
TAYSIN IDENTTINEN 25 syklin ajan, EI EROA.** Tama vahvistaa etta
YKSITTAISEN lanen operaatio on funktionaalisesti identtinen vanhan
ja uuden arkkitehtuurin valilla.

**Kahden lanen vertailu paljasti eron syklilla 3** - MUTTA analyysi
osoitti etta tama johtui OMASTA TESTIVIRHEESTANI: valitsin
`base_addr1=64` MIELIVALTAISESTI (ilman todentaa etta se vastaa
oikeaa, aikataulusta johdettua, konfliktittomaksi todistettua osoite-
paria). Tarkistus:

```
bank_of(addr_a0=0)  = 0
bank_of(addr_b0=4)  = 1
bank_of(addr_a1=64) = 1  <-- SAMA PANKKI kuin addr_b0!
bank_of(addr_b1=68) = 0  <-- SAMA PANKKI kuin addr_a0!
```

**Tama ON AITO KONFLIKTI - MUTTA se syntyy VAIN koska testin omat
osoitteet (base_addr1=64, pair_dist=4) EIVAT vastaa mitaan oikeaa
NTT-aikataulun konfliktittomaksi todistettua osoiteyhdistelmaa.**
BANK_MAPPING_PROOF.md:n konfliktittomuustodistus koskee VAIN
todellisia aikataulusta (`full_schedule.txt`) johdettuja nelikkoja -
EI mielivaltaisia testiosoitteita.

**JOHTOPAATOS: taman aaltomuotokokeen "loydetty ero" EI ollut aito
bugi lane_fsm:n ja arbitroinnin vuorovaikutuksessa - se oli oman
testini virheellinen osoitevalinta.** Tama EI viela vastaa alkuperaista
kysymysta (miksi taysi 7-tasoinen NTT-testi epaonnistui 255/256
osoitteessa, VAIKKA se kaytti OIKEITA, aikataulusta johdettuja
osoitteita).

## Seuraava, oikein rajattu askel

Toistaa aaltomuotovertailu kayttaen OIKEITA, `full_schedule.txt`:sta
luettuja base_addr-arvoja (ei mielivaltaisia), jotta konfliktittomuus-
takuu aidosti patee - vasta silloin mahdollinen loytyva ero olisi
todellinen ajoitusongelma eika oman testin oma virhe.
