# Synteesiraportti: M5-DILITHIUM-001 (ML-DSA-65)

**Paivamaara:** 2026-07-20
**Tyokalu:** Yosys 0.33, geneerinen synteesi (`synth`, teknologia-
riippumaton LUT-primitiivikartoitus - EI viela FPGA-kohdekohtaista
`synth_ecp5`/`synth_ice40`-mappausta, ks. "Rajaukset" alla).

## Tarkoitus ja rajaukset

Tama raportti taydentaa toiminnallisen oikeellisuuden (todistettu
`dilithium-py`:ta ja NIST ACVP -vektoreita vastaan, ks. DK6_STATUS.md)
tiedolla siita **mita toteutus maksaa laitteistossa**.

**TARKEA RAJAUS todettu tassa kierroksessa:** taman ymparistön
kaytettavissa oleva muisti (3.9GB) ja aikabudjetti EIVAT RIITTANEET
KeyGen/Sign/Verify-**paatason** moduulien taydelliseen, tekniikka-
kartoitettuun synteesiin yhdessa ajossa - synteesi joko aikakatkaistiin
(exit 124) tai OOM-tapettiin (exit 137). Tama on SAMA luokan resurssi-
rajoite joka havaittiin jo simulointi-/verifiointityossa (ks.
DK6_STATUS.md, jatko 17: "koko RTL-ketjun yhdistaminen ei ole kestava
lahestymistapa").

**Sen sijaan:** raportoidaan TAYDELLINEN, tekniikkakartoitettu
(LUT-primitiivitason) synteesitulos jokaiselle YKSITTAISELLE
rakennuspalikalle erikseen (nama ONNISTUIVAT kaikki taydellisesti),
ja ANNETAAN EKSTRAPOLOITU ARVIO paatason moduuleille tunnettujen
instanssimaarien perusteella. Taydellinen paatason synteesi jaa
avoimeksi jatkotyoksi ymparistossa jossa on enemman muistia/aikaa
kaytettavissa (ks. "Suositus jatkotyolle").

## Rakennuspalikkojen taydelliset synteesitulokset

Kaikki alla olevat luvut ovat TAYDELLISESTI tekniikkakartoitettuja
(LUT-primitiivitason `$_AND_`/`$_MUX_`/`$_DFFE_PP_` jne. -soluja,
EI RTL-tason `$add`/`$mul`-operaattoreita) - Yosysin oma geneerinen
`synth`-makro, joka sisaltaa `techmap`+`abc`-vastaavan LUT-mappauksen.

| Moduuli | Solut yhteensa | Flip-flopit (DFF/DFFE/SDFF) | Kayttokohde |
|---|---|---|---|
| `pqc_dilithium_barrett_mulmod` | 6 517 | 0 (puhtaasti kombinatorinen) | Q=8380417-modulokertolasku, kaytetaan SATOJA kertoja NTT:n sisalla |
| `pqc_dilithium_ntt_core` (forward NTT + Barrett + butterfly) | 39 317 | 5 979 | Yksi 256-kertoiminen forward-NTT-muunnos |
| `pqc_dilithium_ntt_inverse_core` (inverse NTT + Barrett + GS-butterfly) | 51 809 | 6 002 | Yksi 256-kertoiminen inverse-NTT-muunnos |
| `pqc_dilithium_decompose` | 2 984 | 0 (kombinatorinen) | HighBits/LowBits (FIPS 204 Alg. 36) |
| `pqc_dilithium_make_hint` (sisaltaa 2x decompose) | 6 283 | 0 (kombinatorinen) | MakeHint (FIPS 204 Alg. 39) |
| `pqc_dilithium_pack_z` | 12 544 | 0 (kombinatorinen) | z:n tiukka 20-bit/kerroin -pakkaus |
| `pqc_dilithium_pack_h` | 2 377 | 492 | Hintien harva pakkaus (sekventiaalinen skannaus) |

**Huomio NTT-ytimien FF-maarasta (~6000 kpl kumpikin):** tama vastaa
odotusta - 256 kerrointa x 23 bittia (CW) = 5888 bittia PELKALLE
tyoskentelymuistille (`mem[]`-taulukko), plus ohjauslogiikan omat
rekisterit. Muistitaulukko EI naytettynyt omana `$mem`-objektinaan
lopullisessa raportissa, koska geneerinen `synth` muuntaa taman
kokoluokan (256x23) muistin suoraan flip-floppeihin (`memory_dff`-
vaihe) sen sijaan etta yrittaisi kartoittaa sen BRAM-lohkoon - tama
ON ODOTETTU, OIKEA kaytos generiselle (ei-arkkitehtuurikohtaiselle)
synteesille.

## Rinnakkaisrakenteen (1536 instanssia) skaalauskoe - MITATTU, EI ekstrapoloitu

**Paivitys 2026-07-20 (kayttajan oma ehdotus):** sen sijaan etta
luotettaisiin naiiviin lineaariseen ekstrapolointiin, rakennettiin
parametrisoitu rinnakkaiskaare (`pqc_dilithium_decompose_parallel_
wrapper.sv`, `pqc_dilithium_make_hint_parallel_wrapper.sv`) ja
synteesoitiin TODELLISILLA N-arvoilla: N=1, 16, 256, 1536.

| N | Decompose (solua) | Solua/instanssi | Make_hint (solua) | Solua/instanssi |
|---|---|---|---|---|
| 1 | 2 983 | 2983.0 | 6 283 (aiempi erillinen mittaus) | 6283 |
| 16 | 47 728 | 2983.0 | - | - |
| 256 | 763 904 | 2984.0 | - | - |
| **1536** | **4 583 424** | **2984.0** | **9 659 904** | **6289.0** |

**TARKEA, YLLATTAVA LOYDOS: skaalaus on TAYDELLISESTI LINEAARINEN,
EI OSOITA MERKITTAVAA VAHENNYSTA Yosysin omasta `share`-optimoinnista.**
Aiemmin taman raportin ensimmaisessa versiossa esitetty varovaisuus
("todellinen luku voisi olla 30-50% pienempi jako-optimoinnin ansiosta")
**OSOITTAUTUI VIRHEELLISEKSI TAMAN SPESIFISEN RAKENTEEN OSALTA** -
mitattu N=1536-tulos (4 583 424 / 9 659 904 solua) TASMAA (jopa
hieman YLITTAA) naiivin lineaarisen ekstrapoloinnin, EI ALITA sita.

**Selitys:** `Decompose`/`MakeHint` ovat KOMBINATORISIA moduuleja
JOIDEN JOKAINEN INSTANSSI SAA ERI, AJONAIKAISEN SYOTTEEN (eri
kertoimen arvo). Yosysin `share`-optimointipassi loytaa yhdistettavaa
logiikkaa VAIN kun useampi rakenne jakaa SAMAN syotteen tai
VAKIOARVON - given jokainen 1536:sta instanssista prosessoi OMAA,
toisistaan riippumatonta dataa, EI OLE mitaan jaettavaa logiikkaa.
TAMA ON YLEINEN, ODOTETTAVISSA OLEVA TULOS datankasittelyputkille
(data-parallel-rakenteille), jotka EIVAT sisalla toistuvia VAKIOITA.

**Tama VAHVISTAA (EI vain ekstrapoloi) etta taydellinen verify_core/
sign_hint_core -synteesi vaatisi VAHINTAAN ~4.6M+~9.7M=~14.3M solua
PELKASTAAN Decompose/MakeHint-osilta (plus NTT-ytimet, SHAKE,
ohjauslogiikka paalle) - TAMA YLITTAA MONINKERTAISESTI tyypillisen
keskisuuren FPGA:n (esim. ECP5-85K, ~84k LUT) kapasiteetin, VAIKKA
"solu" != "LUT" suoraan (yksi 4-tulon LUT voi toteuttaa useamman
yksinkertaisen portin) - jarkeva LUT-arvio olisi silti todennakoisesti
useita satoja tuhansia LUT:eja, edelleen MONINKERTAISESTI ECP5-85K:n
kapasiteetin ylitse.

**Muistinkaytto pysyi KOHTUULLISENA (~330MB) KAIKILLA testatuilla
N-arvoilla mukaan lukien N=1536** - tama YLLATTAEN OSOITTAA etta
PELKASTAAN Decompose/MakeHint-rakenteen OMA synteesi EI ITSESSAAN ollut
paatason (KeyGen/Sign/Verify) synteesin OOM-ongelman syy - ongelma
syntyy vasta kun tama YHDISTETAAN kaiken MUUN logiikan (NTT-ytimet,
SHAKE-instanssit, ohjaus-FSM:t) kanssa YHDEKSI, valtavaksi
suunnitteluksi.

## Kellotaajuus (Fmax) ja kriittinen polku

**EI VIELA MAARITETTY.** Fmax-arvio vaatii joko (a) FPGA-kohde-
kohtaisen `synth_ecp5`/`synth_ice40` + `nextpnr`-ajon (paikka/reititys
+ ajoitusanalyysi), tai (b) STA (Static Timing Analysis) -tyokalun
(esim. OpenSTA) kayton geneerisen synteesin tulokselle liitetylla
standardisolukirjastolla. KUMPAAKAAN EI OLE VIELA TEHTY tassa
projektissa Dilithium-moduuleille - tama on avoin jatkotyo (ks. alla).

Aiempi ML-KEM-tyo (SYNTHESIS_NOTE.md, 2026-07-11) kohtasi MYOS
avoimen, ratkaisemattoman kysymyksen ECP5-teknologiakartoituksessa
(muistiobjektit katosivat odottamattomasti `synth_ecp5`-vaiheessa) -
tama SAMA avoin kysymys koskee todennakoisesti myos Dilithium-
moduuleja, EIKA sita ole ratkaistu tassa kierroksessa.

## Yhteenveto ja rehellinen tila

| Kysymys | Vastaus |
|---|---|
| Yksittaisten rakennuspalikkojen LUT/FF-maara | ✅ Mitattu taydellisesti (taulukko ylla) |
| Rinnakkaisrakenteen (1536x) skaalauskayra | ✅ MITATTU (N=1,16,256,1536) - taydellisesti lineaarinen, EI jako-optimoinnin tuomaa vahennysta |
| Paatason moduulien (KeyGen/Sign/Verify) LUT/FF-maara | ❌ EI mitattu - resurssirajoite tassa ymparistossa (mutta 1536x-osan oma osuus NYT tunnetaan tarkasti) |
| ECP5/muu FPGA-kohteen resurssikaytto | ❌ EI tehty - sama avoin kysymys kuin ML-KEM:lla |
| Fmax / kriittinen polku | ❌ EI maaritetty |
| Suorituskykymittarit (syklimaara -> aika) | Katso DK6_STATUS.md: KeyGen ~87K sykli, Sign yhden-kierroksen ~242K sykli (vaihtelee hylkaysten mukaan), Verify ~115K sykli |

## Suositus jatkotyolle

1. **Paatason synteesi tarvitsee enemman resursseja** kuin tama
   sandbox-ymparisto tarjoaa (>3.9GB muistia, pidempi aikabudjetti
   kuin muutama minuutti per ajo). Suositellaan ajamista dedikoidulla
   koneella/CI-ajurilla jolla EI ole tata rajoitetta.
2. **PAIVITETTY kayttajan oman ehdotuksen ja mitatun datan
   perusteella:** koska N=1536-skaalaus ON VAHVISTETTU TAYDELLISESTI
   LINEAARISEKSI (ei jako-optimoinnin tuomaa vahennysta), K-arvon
   pienentaminen (esim. K=64 tai K=128 rinnakkaista instanssia 1536:n
   sijaan, silmukoiden loput sekventiaalisesti) VOIDAAN NYT ARVIOIDA
   LUOTETTAVASTI SUORAAN mitatusta per-instanssi-hinnasta (2984/6289
   solua per Decompose/MakeHint-instanssi), ILMAN tarvetta arvailla
   jako-optimoinnin vaikutusta - koska sita EI OLE tassa rakenteessa.
   Esim. K=128: 128*2984≈382K solua (Decompose) + 128*6289≈805K solua
   (MakeHint) - viela huomattava, mutta jo lahempana ECP5-luokan
   FPGA:iden kapasiteettia kuin taydet 1536.
3. Fmax/kriittinen polku vaatii joko FPGA-kohdekohtaisen `nextpnr`-
   ajon (ratkaisten ensin ML-KEM:n oman, viela avoimen ECP5-BRAM-
   kartoituskysymyksen) tai STA-tyokalun kaytonoton.
4. **Konkreettinen jatkokoe (kayttajan oma ehdotus):** synteesoi
   YKSI paatason moduuli (esim. `sign_hint_core.sv`) PARAMETRISOIDULLA
   rinnakkaisuusasteella (esim. uusi `PARALLEL_K`-parametri joka
   ohjaa MONTAKO 256-kertoimen K-riviä kasitellaan RINNAKKAIN vs.
   SEKVENTIAALISESTI) - tama antaisi TODELLISEN, MITATUN datapisteen
   taydelle moduulille eika vain sen Decompose/MakeHint-alirakenteelle,
   MUTTA vaatisi ensin FSM-tason muutoksen (silmukointi K-ulottuvuuden
   yli), joka on suurempi RTL-muutos kuin tama kierros kattoi.
