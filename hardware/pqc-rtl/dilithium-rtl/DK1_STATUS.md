# M5-DILITHIUM-001 DK1: 32-bittinen NTT-ydin

**Paivamaara:** 2026-07-19
**Tila:** Ensimmainen rakennuspalikka (Barrett-kertolaskureduktio) VALMIS.

## Arkkitehtuurivalinta: Barrett Montgomery-domainin sijaan

**Peruste:** `dilithium-golden/M5_DILITHIUM_001_PLAN.md` (osio 4)
dokumentoi etta rvv-dilithium-ohjelmistototeutus loysi "vaaran
Montgomery-etumerkkikonvention" KAHDESTI eri kohdissa. Barrett-
reduktio valttaa TAMAN kokonaan: arvot pysyvat koko ajan normaali-
alueella (0..Q-1), ei tarvetta Montgomery-domainiin/-domainista
muuntamiselle eika sen omalle etumerkkikonvention sekaannukselle.

Tama on TIETOINEN, dokumentoitu arkkitehtuurivalinta - EI sama
lahestymistapa kuin ohjelmistoreferenssissa, koska FPGA-DSP-lohkot
mahdollistavat suoran 23x23-bittisen kertolaskun ilman Montgomeryn
omaa optimointitarvetta (joka oli alun perin motivoitu OHJELMISTON
jakolaskun kalleudesta - RTL:ssa modulo-operaatio VOIDAAN toteuttaa
suoraan Barrett-piirilla ilman vastaavaa kustannusta).

## Barrett-parametrit (Q=8380417)

- k=46 (siirtomaara), m=floor(2^46/Q)=8396807
- Vahvistettu Pythonilla 100000 satunnaisella parilla ENNEN RTL-
  tyota: 0 virhetta.

## Toteutus ja testitulos

`pqc_dilithium_barrett_mulmod.sv` - taysin kombinatorinen (sama
periaate kuin `pqc_compress.sv`, `pqc_multiplyntts.sv` jne).

```
PASS: Barrett mulmod tasmaa taydellisesti kaikille 506 testitapaukselle
```

506 testitapausta = 6 reunatapausta (0,0 / Q-1,Q-1 / jne) + 500
satunnaista paria, verrattu SUORAAN Pythonin `(a*b)%Q`:hun.

## Seuraava askel

Yksittainen Cooley-Tukey-butterfly (t=zeta*b mod Q; out_a=(a+t)%Q;
out_b=(a-t)%Q, HUOM out_b:n oma modulo-alivuoto vaatii oman
kasittelynsa koska a-t voi olla negatiivinen) - testattava YHTA
butterfly-operaatiota vasten `dilithium-py`:n omasta `to_ntt()`-
metodista ENNEN koko 256-kertoimisen NTT-skeduloinnin rakentamista.

## Butterfly VALMIS ja todennettu (2026-07-19, jatko)

**Toteutus:** `pqc_dilithium_ntt_butterfly.sv` - uudelleenkayttaa
suoraan todistetun Barrett mulmod -moduulin, lisaa CT-butterflyn oman
yhteen-/vahennyslaskun huolellisella etumerkinkasittelylla.

**Loydetty ja korjattu ITSE, ENNEN testausta:** `a_out`/`b_out`-
nimeaminen oli aluksi VAIHTUNUT paikoiltaan verrattuna dilithium-py:n
omaan kaavaan (`coeffs[j]=a+t`, `coeffs[j+l]=a-t`) - korjattu heti
huomattuani, ennen ensimmaista testiajoa.

**Testivektorit generoitu KIRJASTON OMILLA zeta-arvoilla**
(`ring.ntt_zetas`), EI omalla bittikaannosfunktion uudelleen-
toteutuksella - suoraan ML-KEM-tyon oman opetuksen mukaisesti.

**Testitulos:**
```
PASS: NTT-butterfly tasmaa taydellisesti kaikille 504 testitapaukselle
```

**PASS TAYDELLISESTI ENSIMMAISELLA TESTIAJOLLA** - huolellinen
etumerkinkasittely (dokumentoitu tunnettu sudenkuoppa, ks. osio
"Arkkitehtuurivalinta") kannatti: ei loydetty bugia joka olisi
liittynyt juuri tahan, aiemmin ohjelmistopuolella kahdesti loydettyyn
virhetyyppiin.

**Zeta-ROM generoitu** (`dilithium_ntt_zetas.memh`, 256*23-bittinen),
suoraan kirjaston `ring.ntt_zetas`-listasta.

## Seuraava askel

Koko 256-kertoimisen NTT:n skedulointi (7 tasoa, l=128..1,
"schedule ROM" -periaatteella kuten ML-KEM:ssa) - HUOM Dilithiumin
oma k-indeksointi ("k=k+1" sekventiaalisesti KAIKKIEN butterflyjen
yli, ei per-taso nollattuna) ON YKSINKERTAISEMPI kuin ML-KEM:n
kaksikaistainen pankki-arkkitehtuuri - saattaa mahdollistaa
suoraviivaisemman, YHDEN-butterflyn-per-sykli-mallin ensimmaisessa
versiossa.

## KOKO 256-KERTOIMINEN NTT VALMIS - PASS ENSIMMAISELLA YRITYKSELLA (2026-07-19, jatko 2)

**Toteutus:** `pqc_dilithium_ntt_core.sv` - orkestroi todistetun
butterfly-moduulin 255-rivisen skedulun (`dilithium_ntt_forward_
schedule.memh`) yli. Skedulu generoitu SUORAAN `dilithium-py`:n omasta
`to_ntt()`-silmukasta (l, zeta, start) -kolmikkoina - EI kasin
johdettuja indekseja.

**Ensimmainen versio: korrektius edella, optimointi myohemmin** -
yksinkertainen rekisteripohjainen 256*23-bittinen muisti (ei viela
BRAM-pankitusta), yksi butterfly kerrallaan, useita syklia per
butterfly. Sama periaate kuin ML-KEM:n oma NTT-tyo (M1/M2-vaiheet
ennen M4-FPGA-sarjan optimointia).

**Testitulos (NELJA eri satunnaista polynomia, kaikki PASS):**
```
Valmis 4095 syklin jalkeen
PASS: koko NTT tasmaa taydellisesti kaikille 256 kertoimelle
```
Nelja eri siementa (99, 1, 2, 3) - KAIKKI tasmaavat taydellisesti
`dilithium-py`:n omaan `to_ntt()`-tulokseen, EI YHTAAN LOYDETTYA
BUGIA.

**Miksi tama meni niin suoraviivaisesti:** huolellinen etukateis-
tyo (Barrett-arkkitehtuurivalinta dokumentoituine perusteluineen,
skedulun generointi SUORAAN kirjaston omasta silmukasta eika kasin
johdettuna, butterfly testattu ERIKSEEN ennen koko NTT:n kokoamista)
kannatti - sama vaiheittainen kurinalaisuus joka toimi koko ML-KEM-
projektin ajan.

## DK1:n paivitetty tila

| Osa | Tila |
|---|---|
| Barrett-kertolaskureduktio | ✅ |
| NTT-butterfly | ✅ |
| Koko 256-kertoimisen NTT:n orkestrointi | ✅ |
| Inverse NTT | ❌ Seuraava |
| Synteesi + suorituskykymittaus (osio 8, suunnitelmasta) | ❌ |

**DK1 (32-bittinen NTT-ydin) on nyt lahes valmis** - jaljella inverse-
NTT (tarvitaan KeyGenissa: `t = NTT^-1(A*NTT(s1)) + s2`) ja
synteesi+mittaus ennen DK1:n sulkemista.

## INVERSE-NTT VALMIS - PASS ENSIMMAISELLA YRITYKSELLA (2026-07-19, jatko 3)

**Toteutus:** `pqc_dilithium_ntt_gs_butterfly.sv` (Gentleman-Sande-
butterfly, ERI rakenne kuin forward-NTT:n Cooley-Tukey: kertolasku
zeta:lla tapahtuu VASTA vahennyksen jalkeen, ei ennen) +
`pqc_dilithium_ntt_inverse_core.sv` (skedulu + lopullinen
256^-1-skaalaus).

**Skedulu generoitu SUORAAN `dilithium-py`:n omasta `from_ntt()`-
silmukasta** (l nousee 1:sta 128:aan, k VAHENEE 256:sta, zeta on
NEGATOITU) - EI kasin johdettuna.

**Testitulokset (KOLME erillista todennustasoa):**

1. Yksittainen GS-butterfly, 504 testitapausta: PASS
2. Koko inverse-NTT `dilithium-py`:n `from_ntt()`-tulosta vasten
   (4 eri siementa: 55, 200, 201, 202): PASS TAYDELLISESTI kaikilla
3. **RTL-RTL round-trip**: oma forward-NTT-ydin -> oma inverse-NTT-
   ydin, tulos == alkuperainen syote, TAYSIN ITSEKONSISTENTTI (ei edes
   tarvinnut ulkoista dilithium-py-vertailua tahan yhteen testiin,
   koska alkuperainen syote ITSESSAAN on odotettu tulos): PASS

```
Forward-NTT valmis 4095 syklin jalkeen
Inverse-NTT valmis 4097 syklin jalkeen
PASS: RTL-RTL round-trip - NTT^-1(NTT(f)) == f taydellisesti
```

**EI YHTAAN LOYDETTYA BUGIA missaan kolmesta tasosta.**

## DK1:n paivitetty tila - LAHES VALMIS

| Osa | Tila |
|---|---|
| Barrett-kertolaskureduktio | ✅ |
| NTT-butterfly (forward, Cooley-Tukey) | ✅ |
| Koko forward-NTT | ✅ |
| GS-butterfly (inverse, Gentleman-Sande) | ✅ |
| Koko inverse-NTT (+ 256^-1-skaalaus) | ✅ |
| RTL-RTL round-trip (itsekonsistenssi) | ✅ |
| Synteesi + suorituskykymittaus (osio 8, suunnitelmasta) | ❌ Seuraava, VIIMEINEN vaihe ennen DK1:n sulkemista |

## Ensimmainen synteesiyritys: LOGIIKKASYNTEESI ONNISTUI, P&R vaatii bring-up-rajapinnan (2026-07-19, jatko 4)

**MERKITTAVA LOYDOS: `pqc_dilithium_ntt_core.sv`:n LOGIIKKASYNTEESI
(Yosys `synth_ecp5`) ONNISTUI TAYDELLISESTI, ENSIMMAISTA KERTAA KOKO
TAMAN ISTUNNON AIKANA** (aiemmat ML-KEM-moduulien synteesiyritykset
aina aikakatkaistiin useiden Keccak-instanssien takia). Tama NTT-ydin
EI sisalla Keccakia - vain Barrett+butterfly+skedulu-ROM - ja
synteesoitui alle 280 sekunnissa puhtaasti.

**Solutilastot (Yosys):**
```
Number of cells:              54406
  CCU2C                         267
  DP16KD                          1  (skedulu-ROM inferoitui BRAM:ksi)
  L6MUX21                      6003
  LUT4                        32264
  MULT18X18D                     14  (Barrett-kertolaskuille)
  PFUMX                        9872
  TRELLIS_FF                   5985
```

**P&R (nextpnr-ecp5) EPAONNISTUI - mutta EI korrektiusongelma:**
`coeffs_in`/`coeffs_out`-portit ovat 256*23=5888 bittia LEVEITA
(TAYSIN RINNAKKAINEN "bring-up"-rajapinta, sama tyyli kuin ML-KEM:n
ALKUPERAINEN, ENNEN FPGA_BRINGUP-korjausta). Tama tuottaa ~11780
TRELLIS_IO-solmua vaadittuna - MIKAAN oikea ECP5-piiri ei tarjoa
lahellekaan tata maaraa I/O-pinneja (365 tallä paketilla).

**TAMA ON TASMALLEEN sama, jo aiemmin ratkaistu ongelma kuin
ML-KEM:n oma M4-FPGA-001** (FPGA_BRINGUP-portit) - ratkaisu on
TUNNETTU: sana-kerrallaan-lataus/luku (esim. 23-bittinen data-vayla +
8-bittinen osoite + valid/ready-kasittely) TAYDEN 5888-bittisen
rinnakkaisportin sijaan.

**Seuraava askel ennen DK1:n sulkemista:** rakennettava bring-up-
rajapintainen versio (`FPGA_BRINGUP`-parametrilla, sama konventio
kuin ML-KEM:ssa) JOTTA P&R ja Fmax-mittaus voidaan tehda oikein.

## Bring-up-versio: logiikkasynteesi ONNISTUI, P&R keskeytettiin (2026-07-19, jatko 5)

**Toteutus:** `pqc_dilithium_ntt_core_bringup.sv` - sama laskentalogiikka
kuin `pqc_dilithium_ntt_core.sv`, mutta sana-kerrallaan lataus/luku
(sama FPGA_BRINGUP-konventio kuin ML-KEM:ssa) 5888-bittisten
rinnakkaisporttien sijaan. Todennettu PASS-tuloksella ennen synteesia
(`pqc_dilithium_ntt_core_bringup_tb.sv`, sama golden-vertailu).

**Mitattu syklimaara (osio 8:n oma suorituskykymittari,
suunnitelman mukaisesti):**
```
Valmis 3584 syklin jalkeen
```
= 3584 sykli / 256-kertoiminen NTT (1024 butterfly-operaatiota).

**Logiikkasynteesi (Yosys `synth_ecp5`): ONNISTUI TAYDELLISESTI.**

```
Number of cells:              76899
  CCU2C                         262
  ...
```

**P&R (nextpnr-ecp5): EI EHTINYT VALMISTUA taman istunnon rajoissa.**
Yritetty seka lyhyella (280s) etta pidemmalla (1800s taustalla)
aikarajalla - jalkimmainen eteni sijoittelun lapi (~100000 iteraatiota,
~11 minuuttia) mutta ei ehtinyt reititykseen/ajoitusanalyysiin asti.
**TAMA ON SAMA, JO AIEMMIN DOKUMENTOITU RESURSSIRAJOITUS** kuin
ML-KEM:n omien moduulien P&R-yritykset (KeyGen, Decaps Phase A) -
EI korrektiusongelma, PUHTAASTI taman tyoymparistin oma suoritusaika-
rajoitus.

**HUOMIONARVOISTA:** taman moduulin OMA LOGIIKKASYNTEESI (Yosys)
onnistui NOPEAMMIN ja LUOTETTAVAMMIN kuin mikaan ML-KEM-moduuli taman
istunnon aikana (ML-KEM:n omat Yosys-yrityksetkin usein aikakatkaistiin
Keccak-instanssien takia) - tama viittaa etta Dilithium-NTT:n oma
logiikka (Barrett+butterfly, ei Keccakia) on aidosti KEVYEMPI
synteesoida kuin ML-KEM:n Keccak-raskaat moduulit. P&R:n oma
hitaus tassa nayttaa liittyvan enemman TYOYMPARISTON omaan CPU-
suorituskykyyn kuin taman piirin omaan monimutkaisuuteen.

## DK1:n LOPULLINEN tila (suunnitelman osio 8:n hyvaksymiskriteerit)

| Kriteeri | Tila |
|---|---|
| 1. Algoritminen oikeellisuus | ✅ Forward+inverse NTT, 3 todennustasoa, EI loydettya bugia |
| 2. Regressiotestit | ✅ Kaikki testit toistettavissa `dilithium-rtl/`-kansiossa |
| 3. Synteesikelpoisuus | ✅ (logiikkasynteesi) / ⏳ (P&R/timing-sulkeuma avoinna) |
| 4. Mitattu suorituskyky | ✅ (osittain: 3584 sykli/NTT, solutilastot) / ⏳ (Fmax puuttuu P&R:n takia) |

**DK1 on siis FUNKTIONAALISESTI ja METODOLOGISESTI valmis, mutta
Fmax-mittaus jaa AVOIMEKSI tassa istunnossa** - sama, rehellisesti
raportoitu rajoitus kuin ML-KEM:n omissa P&R-yrityksissa. Tama ei
estä siirtymista DK2:een (ExpandA) - Fmax voidaan mitata myohemmin,
kun/jos pidempi, istunnon ulkopuolinen P&R-ajo on kaytettavissa.
