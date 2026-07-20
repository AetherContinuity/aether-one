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

## Ekstrapoloidut arviot paatason moduuleille

`pqc_dilithium_verify_core.sv` ja `pqc_dilithium_sign_hint_core.sv`
instantioivat `Decompose`/`MakeHint`/`UseHint`-tyyppisia moduuleja
**K*256 = 1536 kertaa RINNAKKAIN** (ei kertaalleen sekventiaalisesti).
Naiveilla (ei jaetun logiikan optimoinnilla) skaalauksella:

| Rinnakkainen rakenne | Yksi instanssi | x1536 (naiivi skaalaus) |
|---|---|---|
| Decompose (UseHint:n oma sisainen kaytto) | 2 984 solua | **~4 583 000 solua** |
| MakeHint (sign_hint_core:n oma kaytto) | 6 283 solua | **~9 651 000 solua** |

**TARKEA VAROITUS:** tama on NAIIVI, YLAMITTAINEN arvio - todellinen
synteesi todennakoisesti jakaisi paljon logiikkaa uudelleenkayttoon
Yosysin oman `opt`/`share`-passin kautta (esim. Decompose:n oma
`ALPHA`-jakolasku on identtinen jokaiselle 1536 instanssille, jolloin
osa logiikasta VOISI periaatteessa jakaa resursseja, vaikka rakenne
on rinnakkainen eika ajallisesti jaettu). TAMA ON JUURI SE SYY MIKSI
taydellinen paatason synteesi on tarpeen TARKAN luvun saamiseksi -
ekstrapolointi antaa vain KARKEAN SUURUUSLUOKKA-arvion (miljoonia
soluja), EI tarkkaa resurssivaatimusta.

**Tama ekstrapoloitu suuruusluokka (miljoonia soluja rinnakkaiselle
hint-kasittelylle) selittaa MYOS SUORAAN, miksi taman istunnon
simulaatiot (erityisesti `sign_hint_core`:n oma testaus) osoittautuivat
niin aikaa/muistia vievaksi Icarus Verilogissa - sama rakenteellinen
skaalatekija (1536 rinnakkaista instanssia) vaikuttaa seka
simulointiin etta synteesiin.**

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
| Paatason moduulien (KeyGen/Sign/Verify) LUT/FF-maara | ❌ EI mitattu - resurssirajoite tassa ymparistossa. Karkea ekstrapolointi annettu, EI tarkka luku. |
| ECP5/muu FPGA-kohteen resurssikaytto | ❌ EI tehty - sama avoin kysymys kuin ML-KEM:lla |
| Fmax / kriittinen polku | ❌ EI maaritetty |
| Suorituskykymittarit (syklimaara -> aika) | Katso DK6_STATUS.md: KeyGen ~87K sykli, Sign yhden-kierroksen ~242K sykli (vaihtelee hylkaysten mukaan), Verify ~115K sykli |

## Suositus jatkotyolle

1. **Paatason synteesi tarvitsee enemman resursseja** kuin tama
   sandbox-ymparisto tarjoaa (>3.9GB muistia, pidempi aikabudjetti
   kuin muutama minuutti per ajo). Suositellaan ajamista dedikoidulla
   koneella/CI-ajurilla jolla EI ole tata rajoitetta.
2. Kun paatason synteesi onnistuu, vertaa TODELLISTA solumaaraa
   TAMAN raportin ekstrapoloituun arvioon (~4.6M/~9.7M soluja
   rinnakkaisille hint-rakenteille) - merkittava ero (esim. 10x
   pienempi) olisi VAHVA merkki siita etta Yosysin oma logiikanjako-
   optimointi toimii tehokkaasti rinnakkaisten, identtisten alira-
   kenteiden kanssa.
3. Fmax/kriittinen polku vaatii joko FPGA-kohdekohtaisen `nextpnr`-
   ajon (ratkaisten ensin ML-KEM:n oman, viela avoimen ECP5-BRAM-
   kartoituskysymyksen) tai STA-tyokalun kaytonoton.
4. Harkitse `sign_hint_core`:n ja `verify_core`:n OMAA UUDELLEEN-
   ARKKITEHTUURIA sekventiaalisemmaksi (esim. K rinnakkaista
   instanssia 1536:n sijaan, silmukoiden 256 kerrointa sekventiaali-
   sesti kunkin K:n sisalla) JOS resurssikaytto osoittautuu
   liialliseksi - tama olisi klassinen aika/pinta-ala-kompromissi,
   joka pienentaisi seka simulointiaikaa etta synteesiresursseja
   merkittavasti kustannuksella lisatyista kelloskykleista per
   Verify/Sign-kutsu.
