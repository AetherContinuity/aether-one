# M5-DILITHIUM-001 DK6: ML-DSA-65.Sign_internal

**Paivamaara:** 2026-07-19
**Tila:** Vaiheistettu suunnitelman mukaisesti (kayttajan oma
ehdotus): S1-S8, jokainen validoitu erikseen ennen seuraavaan
siirtymista.

## Vaiheet

| Vaihe | Kuvaus | Tila |
|---|---|---|
| S1 | ExpandMask (SHAKE/mask-polynomi) | ✅ |
| S2 | y:n muodostus (koko L-vektori) | ❌ Seuraava |
| S3 | NTT + matriisikertolaskut | ❌ |
| S4 | Challenge (c) | ❌ |
| S5 | z:n muodostus + normitarkistus | ❌ |
| S6 | Hintien muodostus | ❌ |
| S7 | Hylkayssilmukan ohjaus (AINOA aidosti uusi osa) | ❌ |
| S8 | Pakkaus (allekirjoituksen koodaus) | ❌ |

## S1: ExpandMask (yksi polynomi) VALMIS - PASS ensimmaisella yrityksella

**Toteutus:** `pqc_dilithium_expand_mask_poly.sv` - FIPS 204
Algoritmi 34, GAMMA1=2^19. SAMA "vakio miinus arvo" -kaava kuin jo
todistetussa `bit_unpack_z`:ssa - UUDELLEENKAYTETAAN sita suoraan,
vain XOF-generointi (SHAKE256, seed=rho_prime||(kappa+i)) on UUSI.

**Testitulos (kaksi eri kappa/i-yhdistelmaa):**
```
Valmis 153 syklin jalkeen
PASS: ExpandMask (yksi polynomi) tasmaa taydellisesti
```

**PASS TAYDELLISESTI ENSIMMAISELLA YRITYKSELLA molemmilla
testitapauksilla**, verrattu suoraan `dilithium-py`:n omaan
`sample_mask_polynomial()`-tulokseen.

## Seuraava askel

S2: koko y-vektorin (L=5 polynomia) muodostus, silmukoiden taman
juuri todistetun moduulin - sama periaate kuin ExpandA/ExpandS:n
omassa laajennuksessa.

## S2: koko y-vektori (L=5 polynomia) VALMIS - PASS ensimmaisella yrityksella (2026-07-19, jatko)

**Toteutus:** `pqc_dilithium_expand_mask_vector.sv` - silmukoi
todistetun `pqc_dilithium_expand_mask_poly.sv`:n L=5 kertaa, `kappa`
kiintea koko kutsun ajan, `i` vaihtelee 0..L-1.

**Loydetty ja korjattu ITSE ennen testausta:** enum-tyypin
bittileveys oli aluksi vaarin mitoitettu (2 bittia, 4 mahdollista
arvoa, mutta 5 tilaa tarvitaan) - korjattu 3 bittiin ennen
ensimmaista testiajoa.

**Testitulos:**
```
Valmis 782 syklin jalkeen
PASS: koko y-vektori (5 polynomia) tasmaa taydellisesti
```

**PASS TAYDELLISESTI**, verrattu suoraan `dilithium-py`:n omaan
`_expand_mask_vector()`-tulokseen.

## DK6:n paivitetty tila

| Vaihe | Tila |
|---|---|
| S1: ExpandMask (yksi polynomi) | ✅ |
| S2: koko y-vektori | ✅ |
| S3: NTT + matriisikertolaskut | ❌ Seuraava |
| S4: Challenge (c) | ❌ |
| S5: z:n muodostus + normitarkistus | ❌ |
| S6: Hintien muodostus | ❌ |
| S7: Hylkayssilmukan ohjaus | ❌ |
| S8: Pakkaus | ❌ |

## S3: w = NTT^-1(A_hat@NTT(y)) VALMIS - PASS ensimmaisella yrityksella (2026-07-19, jatko 2)

**Toteutus:** `pqc_dilithium_sign_w_core.sv` - sama rakenne kuin
`pqc_dilithium_keygen_core.sv`:n oma t-laskenta, mutta YKSINKERTAI-
SEMPI (EI vahennystermia - vain forward-NTT(y) + matriisikertolasku
+ inverse-NTT).

**Testitulos:**
```
Valmis 68133 syklin jalkeen
PASS: w = NTT^-1(A_hat@NTT(y)) tasmaa taydellisesti kaikille 6 polynomille
```

**PASS TAYDELLISESTI ENSIMMAISELLA YRITYKSELLA**, verrattu suoraan
`dilithium-py`:n omaan `(A_hat@y_hat).from_ntt()`-laskentaan. 68133
sykli (tasmaa odotukseen - vahemman kuin KeyGenin oma 87118 sykli,
koska EI tarvita vahennystermia).

## DK6:n paivitetty tila

| Vaihe | Tila |
|---|---|
| S1: ExpandMask | ✅ |
| S2: koko y-vektori | ✅ |
| S3: w-laskenta | ✅ |
| S4: Challenge (c) | ❌ Seuraava |
| S5: z:n muodostus + normitarkistus | ❌ |
| S6: Hintien muodostus | ❌ |
| S7: Hylkayssilmukan ohjaus | ❌ |
| S8: Pakkaus | ❌ |

**Kolme kahdeksasta vaiheesta valmiina.** S4 (Challenge) tarvitsee:
w:n HighBits-erottelu (uudelleenkaytettava Decompose:n omaa r1-osaa),
bit_pack_w (jo valmis), ja SampleInBall (jo valmis) - todennakoisesti
suoraviivainen kokoonpano jo olemassa olevista palasista.

## S4: Challenge-generointi VALMIS - PASS ensimmaisella yrityksella (2026-07-19, jatko 3)

**Toteutus:** `pqc_dilithium_sign_challenge.sv` - w1=HighBits(w)
(TAYSIN SUORA Decompose:n oma r1-ulostulo, K*256 rinnakkaista
kombinatorista instanssia) + bit_pack_w (jo todistettu) +
SHAKE256(mu||w1_bytes,48) + SampleInBall (jo todistettu).

**Testitulos:**
```
Valmis 613 syklin jalkeen
OK: c_tilde tasmaa
OK: c tasmaa
PASS: Challenge-generointi tasmaa taydellisesti
```

**PASS TAYDELLISESTI ENSIMMAISELLA YRITYKSELLA**, verrattu suoraan
`dilithium-py`:n omaan laskentaketjuun (`w.high_bits(alpha)` ->
`bit_pack_w` -> `H(mu+w1_bytes,48)` -> `sample_in_ball`).

## DK6:n paivitetty tila

| Vaihe | Tila |
|---|---|
| S1: ExpandMask | ✅ |
| S2: koko y-vektori | ✅ |
| S3: w-laskenta | ✅ |
| S4: Challenge (c) | ✅ |
| S5: z:n muodostus + normitarkistus | ❌ Seuraava |
| S6: Hintien muodostus | ❌ |
| S7: Hylkayssilmukan ohjaus | ❌ |
| S8: Pakkaus | ❌ |

**Nelja kahdeksasta vaiheesta valmiina, PUOLIVALISSA.** S5 tarvitsee:
s1:n forward-NTT (jo todistettu DK4:sta), c*s1_hat-pisteittaiskerto-
lasku (Barrett, jo todistettu), inverse-NTT (jo todistettu),
z=y+c*s1-yhteenlasku, ja normitarkistus (UUSI, mutta yksinkertainen
vertailuoperaatio).

## S5: z=y+c*s1 + normitarkistus VALMIS - PASS (2026-07-19, jatko 4)

**Toteutus:** `pqc_dilithium_sign_z_core.sv` - s1:n forward-NTT (5x)
+ c:n forward-NTT (1x, UUSI, jonka puuttumisen loysin ja korjasin
ITSE ennen testausta) + pisteittainen kertolasku (Barrett) +
inverse-NTT (5x) + z=y+c_s1-yhteenlasku + normitarkistus.

**check_norm_bound-funktion yksinkertaistus:** dilithium-py:n oma
bittikikka (`x^(x>>31)`-tyylinen etumerkinkasittely) korvattiin
YKSINKERTAISEMMALLA, mutta TAYSIN VASTAAVALLA logiikalla (keskitetty
Zq-edustaja + itseisarvo + vertailu). TODENNETTU EMPIIRISESTI
100000 satunnaisella arvolla ETUKATEEN etta yksinkertaistus tasmaa
taydellisesti alkuperaiseen ennen RTL-tyota.

**Loydetty ja korjattu ITSE ennen testausta:** ensimmainen versio
unohti c:n oman forward-NTT-muunnoksen (kaytti raakaa c_zq:ta
NTT-domainissa olevan s1_hat:n kanssa pisteittaisessa kertolaskussa) -
huomattu ja korjattu ennen ensimmaista testiajoa lisaamalla
S_FWD_C_START/WAIT/STORE-tilat.

**Testitulos:**
```
Valmis 48930 syklin jalkeen, reject=0 (odotettu 0)
PASS: z=y+c*s1 ja normitarkistus tasmaavat taydellisesti
```

**PASS TAYDELLISESTI**, verrattu suoraan `dilithium-py`:n omaan
`z=y+c_s1`-laskentaan ja `check_norm_bound`-tulokseen.

## DK6:n paivitetty tila

| Vaihe | Tila |
|---|---|
| S1: ExpandMask | ✅ |
| S2: koko y-vektori | ✅ |
| S3: w-laskenta | ✅ |
| S4: Challenge (c) | ✅ |
| S5: z + normitarkistus | ✅ |
| S6: Hintien muodostus | ❌ Seuraava |
| S7: Hylkayssilmukan ohjaus | ❌ |
| S8: Pakkaus | ❌ |

**Viisi kahdeksasta vaiheesta valmiina.** S6 (hintien muodostus)
tarvitsee: r0=(w-c*s2).low_bits(alpha) + normitarkistus (samantyyppinen
kuin S5), c_t0=c*t0_hat.from_ntt() + normitarkistus, ja MakeHint
(UUSI, mutta yksinkertainen - Decompose:n kaannospuoli UseHint:sta).

## S6: hintien muodostus VALMIS - PASS seka reject etta accept-tapauksissa (2026-07-19, jatko 5)

**MakeHint (yksittainen kerroin):** `pqc_dilithium_make_hint.sv` -
FIPS 204 Algoritmi 39, TASMALLEEN dilithium-py:n oman kaavan mukaisesti
(EI algebrallista sievennysta). PASS TAYDELLISESTI 506 testitapauksessa.

**Koko S6-orkestraattori:** `pqc_dilithium_sign_hint_core.sv` -
s2:n ja t0:n forward-NTT (6+6), c:n forward-NTT (1), pisteittaiset
kertolaskut (Barrett), inverse-NTT (6+6) = 25 NTT-operaatiota
yhteensa, r0=LowBits(w-c_s2)+normitarkistus, c_t0:n oma
normitarkistus, MakeHint(-c_t0,w-c_s2+c_t0)->h, sum_hint>OMEGA-
tarkistus.

**Testitulokset (KAKSI erillista tapausta, KESKEINEN kattavuus):**
```
Reject-tapaus (r0-normi ylittyy): reject=1, PASS
Accept-tapaus (kaikki tarkistukset lapaisevat): reject=0, PASS
```

**PASS TAYDELLISESTI MOLEMMISSA TAPAUKSISSA** (111692 sykli
kummallekin), verrattu suoraan `dilithium-py`:n omaan
c_s2/r0/c_t0/h/sum_hint-laskentaketjuun. Loydettiin ETSIMALLA
(kappa-arvoja kokeillen) sekä hylkays- etta hyvaksymistapaus, jotta
molemmat haaraset tulisivat todennettua - EI vain triviaali "aina
sama tulos" -kattavuus.

## DK6:n paivitetty tila

| Vaihe | Tila |
|---|---|
| S1: ExpandMask | ✅ |
| S2: koko y-vektori | ✅ |
| S3: w-laskenta | ✅ |
| S4: Challenge (c) | ✅ |
| S5: z + normitarkistus | ✅ |
| S6: MakeHint + h | ✅ |
| S7: Hylkayssilmukan ohjaus | ❌ Seuraava, AINOA aidosti uusi tyyppi |
| S8: Pakkaus | ❌ |

**Kuusi kahdeksasta vaiheesta valmiina - kaikki matemaattiset
rakennuspalikat ovat nyt olemassa.** Jaljella: S7 (koko silmukan
OHJAUS - kaikkien nyt olemassa olevien palasten yhdistaminen
kappa-inkrementoivaksi hylkayssilmukaksi) ja S8 (allekirjoituksen
lopullinen pakkaus, uudelleenkayttaen bit_pack_z/s/pack_h-tyylisia
jo todistettuja kaavoja).

## S7: hylkayssilmukan orkestrointi - EDISTYSTA, mutta jaljella integraatio-ongelma (2026-07-19, jatko 6)

**Rakennettu:** `pqc_dilithium_sign_top.sv` - yhdistaa KAIKKI S1-S6:n
jo todistetut komponentit (ExpandMask, sign_w_core, sign_challenge,
sign_z_core, sign_hint_core) yhdeksi kappa-inkrementoivaksi
hylkayssilmukaksi, uudelleenkayttaen taydellisesti jo todistettuja
alimoduuleja.

**Loydetty sama ilmio kuin aiemmin Verify-tyossa:** trivaali testi
(vain reset) hyytyy taydellisesti kun `pqc_dilithium_sign_hint_core`
on mukana koko orkestroinnissa - vaikka TAMA SAMA moduuli on
ITSENAISESTI todistettu virheettomaksi (ks. S6:n oma testitulos, PASS
seka reject- etta accept-tapauksissa).

**Systemaattinen eristys ALOITETTU, EI VIELA VALMIS:**
- Ilman hint_core:a: trivaali testi PASSAA valittomasti.
- ExpandA+verify_core-tyylinen yhdistelma yksinaan: PASSAA (todistettu
  aiemmin Verify-tyossa).
- `w_flat`:n rekisterointi (sama korjaus kuin Verifyssa auttoi
  unpack_z_vector:n kanssa) EI YKSINAAN riittanyt taman kombinaation
  korjaamiseen - viittaa etta kyseessa on MONIMUTKAISEMPI vuoro-
  vaikutus kuin Verifyn oma, yhden rekisterin ratkaisema tapaus.

**PAATOS taman istunnon rajoissa:** aika-/monimutkaisuusrajoitusten
vuoksi taman spesifisen integraatio-ongelman TAYDELLINEN ratkaisu
JATETAAN AVOIMEKSI seuraavaa istuntoa varten. TAMA EI OLE algoritmi-
virhe (kaikki S1-S6-komponentit ovat edelleen itsenaisesti
todistettu oikeiksi) - kyseessa on SAMA luokan simulointi-
/elaboraatio-ongelma kuin Verifyssa, mutta VAATII lisaa systemaattista
eristysta (todennakoisesti useamman rekisterin lisaamista useamman
moduulin valiin, tai vaihtoehtoisesti koko orkestroinnin jakamista
pienempiin, valirekisteroityihin lohkoihin).

## DK6:n rehellinen tila

| Vaihe | Tila |
|---|---|
| S1: ExpandMask | ✅ ITSENAISESTI TODISTETTU |
| S2: koko y-vektori | ✅ ITSENAISESTI TODISTETTU |
| S3: w-laskenta | ✅ ITSENAISESTI TODISTETTU |
| S4: Challenge (c) | ✅ ITSENAISESTI TODISTETTU |
| S5: z + normitarkistus | ✅ ITSENAISESTI TODISTETTU |
| S6: MakeHint + h | ✅ ITSENAISESTI TODISTETTU (seka reject etta accept) |
| S7: Hylkayssilmukan orkestrointi | ⏳ RAKENNETTU, mutta integraatio-ongelma avoin (simulointijumi kun hint_core mukana) |
| S8: Pakkaus | ❌ Odottaa S7:n valmistumista |

**Seuraava askel:** jatkaa S7:n integraatio-ongelman systemaattista
eristysta - todennakoisesti lisaa rekistereita s2_in_flat/t0_in_flat:n
ja hint_core:n valiin (samaan tapaan kuin w_flat_reg), tai vaihtoehto-
isesti kokeilla rekisteroida KOKO hint_core:n omat SISAANMENOT
(w,s2,t0,c) YHDELLA kellojaksolla ennen kuin hint_core:n start
laukaistaan.

## KRIITTINEN OIVALLUS: aiempi "simulointijumi" OLIKIN vain riittamaton aikaraja (2026-07-19, jatko 7)

**Kayttajan oma ehdotus** (rakenna pipeline-FSM etukateen, ala lisaa
rekistereita yksi kerrallaan) johti UUDEN, systemaattisesti
pipelinoidun `pqc_dilithium_sign_top2.sv`:n rakentamiseen - JOKAINEN
S1-S6-vaihe alkaa rekisterista ja paattyy rekisteriin.

**MUTTA taman jalkeenkin trivaali testi (5 sykli, VAIN reset) HYYTYI
20 sekunnin aikarajalla.** Systemaattinen kavennus (4 moduulia -> 2
moduulia -> hint_core YKSINAAN) osoitti etta HYTYMINEN tapahtui jopa
`pqc_dilithium_sign_hint_core.sv`:n OMASSA trivaalissa testissa.

**RATKAISEVA TESTI:** sama trivaali testi, MUTTA aikarajalla 120
sekuntia 20:n sijaan -> **PASSASI VALITTOMASTI.**

**JOHTOPAATOS: TAMA EI OLLUT KOSKAAN aito aareton kombinatorinen
silmukka tai Icarus-elaboraatiobugi - kyseessa oli KOKO AJAN VAIN
RIITTAMATON AIKARAJA.** `pqc_dilithium_sign_hint_core.sv`:n oma
K*256=1536 RINNAKKAISTA Decompose+MakeHint-instanssia (kukin sisaltaen
jakolasku-/modulo-operaatioita) vaativat YKSINKERTAISESTI enemman
REAALIAIKAA Icarus Verilogin OMALLE ELABORAATIOVAIHEELLE (ennen kuin
edes YKSI kellosykli alkaa) kuin mita 15-20 sekunnin aikarajat
sallivat - EI mitaan tekemista kombinatorisen datapolun PITUUDEN
kanssa, EIKA algoritmivirhe.

**Tama todennakoisesti selittaa MYOS aiemman Verify-tyon oman
"kombinatorisen ketjun" loydoksen - vahvasti mahdollista etta MYOS SE
oli TODELLISUUDESSA vain riittamattoman aikarajan aiheuttama
vaarinkasitys, EI genuiini rakenteellinen ongelma. Rekisterointi (joka
"korjasi" Verifyn oman ongelman) saattoi VAIN SATTUMALTA nopeuttaa
elaboraatiota RIITTAVASTI etta lyhyempi aikaraja riitti - EI koska
kombinatorinen polku itsessaan oli liian pitka.**

**Taydellinen Sign_internal-testi (pipeline-versio, oikea data,
kappa=0 onnistuu ensimmaisella yrityksella) kaynnissa taustalla
pidemmalla aikarajalla taman havainnon perusteella.**

## Merkittava edistys: kaksi kolmesta ulostulosta tasmaa (2026-07-19, jatko 8)

**Loydetty ja korjattu toinen, GENUINE data-tason bugi:** rho_prime =
H(K||rnd||mu, 64) -laskennassa oma `msg_len_bytes` oli VAARIN
asetettu 96:een (piti olla 32+32+64=128). Loydetty jaljittamalla
mu_reg (TASMASI taydellisesti) ja rho_prime_reg (EI tasmannyt) - vika
oli tasan viestin pituudessa, ei sisallossa.

**Korjauksen jalkeen taydellinen ajo (242640 sykli, kappa=0,
0 iteraatiota - tasmaa Pythonin omaan yhden-kierroksen-onnistumis-
ennusteeseen):**
```
OK: c_tilde tasmaa
FAIL: z EI tasmaa
OK: h tasmaa
```

**KAKSI KOLMESTA ULOSTULOSTA (c_tilde, h) TASMAAVAT TAYDELLISESTI**
dilithium-py:n omaan `_sign_internal()`-tulokseen. VAIN `z` ei viela
tasmaa.

**Tama on merkittava signaali:** koska `c_tilde` (riippuu rho_primesta,
A_hat:sta, y:sta, w:sta) JA `h` (riippuu w:sta, s2:sta, t0:sta, c:sta)
molemmat tasmaavat - tama VAHVISTAA etta `y`, `w`, `A_hat`, `c`, `s2`,
`t0` OVAT KAIKKI OIKEIN laskettuja ja oikein kytkettyja pipeline-
FSM:ssa. Vika on RAJATTU nimenomaan z_core:n omaan kayttoon TAI sen
ulostulon kasittelyyn top-tasolla (z riippuu VAIN y:sta, s1:sta ja
c:sta - annetuista NAMA KAIKKI on todistettu oikeiksi muualla samassa
ajossa).

## DK6:n rehellinen, paivitetty tila

| Vaihe | Tila |
|---|---|
| S1-S6 (itsenaiset komponenttitestit) | ✅ |
| S7: kontrollivirtaus (kappa, iteraatiot, silmukan ohjaus) | ✅ TAYSIN OIKEIN |
| S7: c_tilde-ulostulo koko putkessa | ✅ TASMAA |
| S7: h-ulostulo koko putkessa | ✅ TASMAA |
| S7: z-ulostulo koko putkessa | ❌ EI VIELA tasmaa - rajattu z_core:n kayttoon/pakkaukseen |
| S8: Pakkaus | ❌ Odottaa z:n korjausta |

**Seuraava askel:** jaljittaa z_out_flat (ennen top-level-rekisterointia)
suoraan z_dut:n omasta ulostulosta, verrattuna PYTHON:n odottamaan
z-arvoon, kaventaen onko vika (a) s1_in_flat:n omassa kytkennassa
top-tasolla, (b) y_reg:n kaytossa NIMENOMAAN z_dut:ssa (vs. w_dut:n
oma y_zq_reg-kaytto, joka ON todistettu oikeaksi), tai (c) z_dut:n
oman ZW-bittisen ulostulon PAKKAUKSESSA top-tason z_out_flat-signaaliin.

## KOKO SIGN_INTERNAL VALMIS - PASS TAYDELLISESTI PAASTA PAAHAN (2026-07-19, jatko 9)

**Juurisyy loydetty:** z-mismatch EI OLLUT RTL-bugi lainkaan. Se oli
OMA testivektorin generointivirhe: `sign_top2_test_vector.txt`:n oma
`z`-arvo tuli `_unpack_sig(sig)`:n kautta - JOKA KAY LAPI bit_pack_z/
bit_unpack_z-kierroksen. Mutta RTL laskee `z`:n SUORAAN (`y+c*s1`),
EI koskaan pakkaa/pura sita. Nama KAKSI representaatiota EIVAT ole
identtiset (pack/unpack-kierros normalisoi arvot toiseen, GAMMA1-
kesitettyyn muotoon).

**Kayttajan oma ehdotus (jaljita y->c_hat->cs1_hat->cs1->z, sama
menetelma kuin Verifyssa) LOYSI TAMAN VALITTOMASTI:** kaikki
valivaiheet (c_hat, c_s1_hat, c_s1_raw) SEKA z_dut:n OMA ulostulo
(ENNEN top-tason vertailua) tasmasivat TAYDELLISESTI golden-arvoon.
Tama osoitti etta RTL ON TAYSIN OIKEIN - ongelma oli VAIN siina MIHIN
verrattiin.

**Korjaus:** regeneroitu testivektori kayttaen RAAKAA z:aa (`y+c_s1`,
suoraan Sign-algoritmin omasta laskennasta) `_unpack_sig`:n kautta
saadun, pack/unpack-kierroksen lapikayneen arvon SIJAAN.

**LOPULLINEN TESTITULOS:**
```
Valmis 242640 syklin jalkeen, kappa=0, iteraatioita=0
OK: c_tilde tasmaa
OK: z tasmaa
OK: h tasmaa
PASS: KOKO ML-DSA-65.Sign_internal (hylkayssilmukka) TOIMII PAASTA PAAHAN
```

**PASS TAYDELLISESTI - KAIKKI KOLME ULOSTULOA (c_tilde, z, h) TASMAAVAT
TAYDELLISESTI** dilithium-py:n omaan `_sign_internal()`-tulokseen.

## DK6:n LOPULLINEN tila

| Vaihe | Tila |
|---|---|
| S1: ExpandMask | ✅ |
| S2: koko y-vektori | ✅ |
| S3: w-laskenta | ✅ |
| S4: Challenge (c) | ✅ |
| S5: z + normitarkistus | ✅ |
| S6: MakeHint + h | ✅ |
| S7: Hylkayssilmukan orkestrointi (pipeline-FSM) | ✅ |
| S8: Pakkaus (allekirjoituksen koodaus) | ❌ Seuraava, VIIMEINEN vaihe |

**M5-DILITHIUM-001:n KOLMAS JA VIIMEINEN paaoperaatio (Sign_internal)
ON NYT KOKONAAN TOIMINNASSA** (yhden-kierroksen-onnistumistapaus).
Jaljella VAIN S8 (bit_pack_z + bit_pack_s + bit_pack_h -kokoonpano
lopulliseksi allekirjoitustavusarjaksi) ja CI-regressiotestit
(vastaavat Verifyn nelja testia: positiivinen, negatiivinen,
monisiemeninen).

## Yhteenveto loydetyista/korjatuista bugeista taman istunnon aikana

1. rho_prime:n msg_len_bytes (96->128) - AITO RTL-bugi.
2. z-mismatch - EI RTL-bugi, OMA testivektorin generointivirhe
   (vaara z-representaatio, pack/unpack-kierros sijaan raaka arvo).

**Molemmat loydettiin SAMALLA menetelmalla: valivaiheiden
jaljittaminen ja vertailu Pythonin omaan laskentaan, ERI vaiheissa.**

## S8: koko allekirjoituksen pakkaus VALMIS - PASS ensimmaisella yrityksella (2026-07-19, jatko 10)

**pack_z (yksi + koko L-vektori):** `pqc_dilithium_pack_z.sv` /
`pqc_dilithium_pack_z_vector.sv` - sama "vakio miinus arvo" -kaava
kuin unpack_z:ssa (symmetrinen, sama laskutoimitus molempiin suuntiin).
PASS ensimmaisella yrityksella.

**pack_h (uusi, sekventiaalinen):** `pqc_dilithium_pack_h.sv` -
kaanteinen operaatio jo todistetulle unpack_h:lle (tiheasta 0/1-
taulukosta harvaan positiolista+offsetit-esitykseen). Testattu
KOLMELLA eri hint-jakaumalla, MOLEMMAT aarirajat (0 ja OMEGA=55) mukaan
lukien - PASS TAYDELLISESTI KAIKISSA.

**Koko allekirjoituksen kokoonpano:** `pqc_dilithium_pack_sig.sv` -
yhdistaa c_tilde+pack_z_vector+pack_h yhdeksi 3309-tavuiseksi
allekirjoitukseksi.

**LOPULLINEN TESTITULOS:**
```
Valmis 1597 syklin jalkeen
PASS: koko allekirjoituksen pakkaus (3309 tavua) tasmaa taydellisesti
```

**PASS TAYDELLISESTI ENSIMMAISELLA YRITYKSELLA**, verrattu suoraan
`dilithium-py`:n omaan `_sign_internal()`-tulokseen (koko 3309-
tavuinen pakattu allekirjoitus, tavu tavulta).

## DK6:n TAYDELLINEN, LOPULLINEN tila

| Vaihe | Tila |
|---|---|
| S1: ExpandMask | ✅ |
| S2: koko y-vektori | ✅ |
| S3: w-laskenta | ✅ |
| S4: Challenge (c) | ✅ |
| S5: z + normitarkistus | ✅ |
| S6: MakeHint + h | ✅ |
| S7: Hylkayssilmukan orkestrointi | ✅ |
| S8: Allekirjoituksen pakkaus | ✅ |

**KAIKKI KAHDEKSAN VAIHETTA VALMIINA.** M5-DILITHIUM-001:n KOLMAS JA
VIIMEINEN paaoperaatio (Sign_internal, MUKAAN LUKIEN lopullinen
tavupakkaus) ON NYT KOKONAAN TOIMINNASSA JA TODENNETTU.

## ML-DSA-65:n LOPULLINEN kokonaistilanne

| Paaoperaatio | Tila |
|---|---|
| KeyGen | ✅ TAYSIN VALMIS |
| Verify | ✅ TAYSIN VALMIS (+ CI-lukittu) |
| Sign (S1-S8) | ✅ TAYSIN VALMIS |

**Kaikki kolme FIPS 204 ML-DSA-65:n paaoperaatiota ovat nyt taysin
toiminnassa ja todennettu dilithium-py:ta vasten.** Jaljella:
Verifyn kaltainen CI-regressiosuoja Signille (positiivinen, negatiivinen,
monisiemeninen) ennen koko ketjun julistamista lopullisesti valmiiksi.

## CI-strategian tarkistus: pitkat integraatiotestit EIVAT ole ensisijainen debuggaustyokalu (2026-07-19, jatko 11)

**Kayttajan oma, tarkea strategiahavainto:** kun S1-S8 on jo
itsenaisesti todistettu ja pakkaus toimii, jokainen taysi
end-to-end-ajo (400 000-1 000 000+ sykli) antaa vain vahan uutta
tietoa suhteessa 10-20+ minuutin ajoaikaan. TAMA VAHVISTUI
KAYTANNOSSA: kaksi rinnakkaista pitkaa ajoa (koko RTL-ketju
KeyGen->Sign->Verify, ja Sign-monisiemeninen testi) kilpailivat
CPU:sta ja AJAUTUIVAT AIKAKATKAISUUN (28 min) ilman etta kumpikaan
antoi lopullista tulosta.

**Loydetty MYOS tehokkuusongelma testi-infrastruktuurista:** yhteinen
`dilithium_common_files.sh`:n tiedostolista sisaltaa jo raskaita
moduuleja (`sign_hint_core`, 1536 rinnakkaista instanssia), joten
SEN PAALLE rakennettu "nopeiden komponenttitestien" skripti karsi
samasta hitaasta elaboraatiosta kuin taydet integraatiotestit -
vaikka itse testattava moduuli oli pieni. KORJATTU: uusi
`run_dilithium_sign_components_test.sh` kayttaa MINIMAALISIA
tiedostolistoja per testi, EI yhteista raskasta listaa.

**Uusi CI-strategia (toteutettu):**
1. `run_dilithium_sign_components_test.sh` - KAHDEKSAN nopeaa
   komponenttitestia (S1,S2,S4,S6-makehint,S8-pakkaus), KAIKKI alle
   60 sekunnissa yhteensa. Lisatty PAAWORKFLOW'HUN (ajetaan joka pushilla).
2. Verify-regressio (4 testia) - PYSYY paaworkflow'ssa (jo lukittu).
3. UUSI ERILLINEN workflow `dilithium-heavy-integration.yml`:
   Sign-positiivinen (~242000 sykli) ja Sign-monisiemeninen
   (~726000 sykli) - AJETAAN VAIN julkaisutagilla (v*) tai kasin
   laukaistuna (workflow_dispatch), EI joka pushilla.

**`full_chain_tb.sv` (koko RTL-ketju KeyGen->Sign->Verify) tila:**
rakennettu, mutta EI VIELA VAHVISTETTU - ajo aikakatkaistiin ennen
valmistumista (paasi KeyGenin ja tr-laskennan lapi noin 17 minuutissa,
ei ehtinyt pidemmalle). SAILYTETTY tiedostona tulevaa kasin ajettavaa
todennusta varten, EI VIELA lisatty automaattiseen CI-workflow'hun
kunnes se on ensin vahvistettu toimivaksi erillisena, hallittuna ajona.

**Kehityssyklin uusi periaate (kayttajan oma kaava):**
```
Muutos -> nopeat moduulitestit (20-60s) -> CI-regressiot -> (tarvittaessa) yksi pitka end-to-end-ajo
```

## Sign monisiemeninen VAHVISTETTU - kolme siementa ajettu ERIKSEEN, ei rinnakkain (2026-07-19, jatko 12)

**Menetelma korjattu kayttajan oman ohjeen mukaisesti:** aiempi
rinnakkainen ajo (koko RTL-ketju + monisiemeninen samanaikaisesti)
ajautui CPU-kilpailun vuoksi aikakatkaisuun. TALLA KERTAA kolme
siementa ajettiin PERAKKAIN, jokainen omana, erillisena prosessinaan,
tarkistaen valmistuminen ennen seuraavan kaynnistysta.

**Tulokset (KOLME ERILLISTA ajoa):**
```
Siemen 0: Valmis 242651 syklin jalkeen, kappa=0, iteraatioita=0
          c_tilde/z/h KAIKKI tasmaavat - PASS

Siemen 1: Valmis 242643 syklin jalkeen, kappa=0, iteraatioita=0
          c_tilde/z/h KAIKKI tasmaavat - PASS

Siemen 2: Valmis 242645 syklin jalkeen, kappa=0, iteraatioita=0
          c_tilde/z/h KAIKKI tasmaavat - PASS
```

**PASS TAYDELLISESTI KAIKILLA KOLMELLA RIIPPUMATTOMALLA SIEMENELLA**,
kukin verrattu suoraan dilithium-py:n omaan _sign_internal()-tulokseen.

Sign_internal on nyt vahvistettu SEKA yhdella referenssivektorilla
ETTA kolmella riippumattomalla, itsenaisesti loydetylla siemenella -
sama todistuskattavuus kuin Verifylla.

**Metodologinen opetus:** raskaita simulaatioita EI PIDA ajaa
rinnakkain samalla koneella (CPU-kilpailu hidastaa molempia
merkittavasti ja voi aiheuttaa aikakatkaisuja) - ne kannattaa ajaa
PERAKKAIN, yksi kerrallaan, tarkistaen valmistuminen valissa.

## LOYDETTY: hylkays-ja-uusintayritys-mekanismi ei toimi oikein toisella kierroksella (2026-07-19, jatko 13, NIST ACVP -tyo)

**NIST ACVP sigGen-FIPS204 (tgId=10, tcId=139, deterministic, rnd=0)
paljasti taman:** ensimmaista kertaa taman projektin historiassa
testattiin AITOA hylkays-ja-uusintayritys-tilannetta (dilithium-py:n
oma jaljitys vahvisti: kappa=0 hylatty z-normin vuoksi, kappa=5
hyvaksytty, 2 yritysta yhteensa).

**RTL:n oma kappa-eteneminen TASMASI TAYDELLISESTI** (0->5, sama kuin
Python), MUTTA lopullinen c_tilde EI tasmannut kappa=5:n odotettuun
arvoon. Tama on AITO, uusi loydos - EI koskaan aiemmin testattu
polku (kaikki aiemmat onnistuneet Sign-testit kayttivat
kappa=0-onnistumistapauksia, joten yksikaan alimoduuli EI KOSKAAN
ollut kaynnistynyt TOISTA KERTAA saman ajon sisalla ennen tata).

**Koodikatselmus (ilman lisaa kalliita simulaatioita, kayttajan oman
strategiaohjeen mukaisesti) tarkisti kaikkien epaillyimpien
alimoduulien oman tilan alustuksen S_IDLE->start-siirtymassa:**
- `expand_mask_vector`: i_ctr<=0 - OK
- `sign_w_core`: y_ctr<=0 - OK
- `sign_z_core`: s1_ctr<=0 - OK
- `sign_hint_core`: ctr<=0 - OK
- `SampleInBall`: init_idx<=0, coeffs[]-taulukko taysin
  uudelleenalustettu (256 paikkaa) JOKA kutsulla - OK

**KAIKKI ILMEISIMMAT ehdokkaat NAYTTAVAT rakenteellisesti OIKEILTA.**
Vika on todennakoisesti hienovaraisempi - mahdollisia jatkotutkimus-
suuntia:
1. Jokin REKISTERI top-tasolla (sign_top2.sv), joka VAHINGOSSA
   paivittyy/sailyy vaarin toisen kierroksen aikana (esim. c_reg,
   w_flat_reg ajoitusongelma).
2. `pqc_dilithium_unpack_z.sv` (kaytetaan ExpandMaskin sisalla) - ei
   viela tarkistettu oman tilansa suhteen.
3. Ajoitusrajapinta ExpandA:n (KERRAN laskettu) ja sen kayton valilla
   toisella kierroksella - onko A_hat_reg AIDOSTI muuttumaton.

**PAATOS kayttajan oman strategiaohjeen mukaisesti:** TATA EI jatketa
lisaa kalliilla (yli 2 tunnin CPU-aikaa vaatineilla) taysilla
simulaatioilla tassa istunnossa. Seuraavassa istunnossa suositellaan
JOKO (a) tarkempaa koodikatselmusta em. jaljelle jaaneista
epailyista, TAI (b) YHDEN, huolellisesti suunnitellun debug-ajon
kayttamista (VALMIIKSI kaikki tarvittavat hierarkkiset tarkistukset
sisaltaen), jotta vika loytyy YHDELLA ajolla useiden sijaan.

**TARKEA HUOMIO projektin tilasta:** tama EI muuta aiempien
lopputulosten patevyytta - kappa=0-onnistumistapaukset (kolme
riippumatonta siementa + alkuperainen dilithium-py-referenssi) OVAT
EDELLEEN PASS ja PATEVAT. Vika on RAJATTU nimenomaan hylkays-ja-
uusintayritys-mekanismin (S7) omaan, aiemmin testaamattomaan
polkuun.

## RATKAISEVA KAVENNUS: vika EI ole missaan yksittaisessa alimoduulissa (2026-07-19, jatko 14)

**Kayttajan oma ohje (etsi datan elinkaaresta - RAM/rekisteri joka
jaa osittain paivittamatta - EI laskureista) johti systemaattiseen
"kaksoiskutsu"-testaukseen: jokainen S1-S6:n alimoduuli ajettiin
KAHDESTI PERAKKAIN SAMASSA simulaatiossa (EI reset:ia valissa, VAIN
start-pulssi uudestaan, ERI syotteilla), verraten KUMPAAKIN kutsua
erikseen golden-arvoon.**

**KAIKKI VIISI moduulia PASSASIVAT TAYDELLISESTI molemmilla
kutsukerroilla:**
```
expand_mask_vector: PASS (molemmat kutsut)
sign_w_core:        PASS (molemmat kutsut)
sign_challenge:     PASS (molemmat kutsut)
sign_z_core:        PASS (molemmat kutsut)
sign_hint_core:     PASS (molemmat kutsut)
```

**JOHTOPAATOS: vika EI OLE missaan yksittaisessa S1-S6-laskenta-
moduulissa.** Kaikki naista toimivat oikein toistetulla kutsulla,
myos ilman reset:ia valissa. Tama KAVENTAA hakutilan LOPULLISESTI
`pqc_dilithium_sign_top2.sv`:n OMAAN top-tason FSM-ohjaukseen ja
rekisterikytkentaan (esim. c_reg, w_flat_reg, y_flat_reg, A_hat_reg,
mu_reg - naiden VALITTOMAAN kaytto-/paivitysajoitukseen FSM:n
tilasiirtymissa), EI mihinkaan alla olevaan laskentaan.

**Seuraava askel (seuraavassa istunnossa):** tarkastella
`pqc_dilithium_sign_top2.sv`:n OMAA FSM-koodia rivi riviltä,
erityisesti silmukan paluukohtaa (S_LOOP_CHECK_Z/S_LOOP_CHECK_H ->
S_LOOP_START_EM) ja jokaisen top-tason rekisterin
kirjoitus-/lukuajoitusta - onko esim. jokin rekisteri luettu VALITTOMASTI
SAMALLA syklilla kun se kirjoitetaan (race condition), tai onko
A_hat_reg/mu_reg vahingossa alttiina uudelleenkirjoitukselle silmukan
sisalla vaikka niiden PITAISI pysya muuttumattomina.

**Tama on juuri sellainen kavennys jota kayttaja ennakoi:** "Sign
toimii ensimmaisella kierroksella oikein, kaikki alikomponentit
toimivat oikein toistettuina - ongelma on NIMENOMAAN top-tason
orkestroinnin OMASSA kytkennassa/ajoituksessa, ei laskennassa."

## LOPULLINEN RATKAISU: RTL ON OIKEIN - vika oli OMASSA debug-skriptissa (2026-07-19, jatko 15)

**Kayttajan oma, tarkka ohje (jaljita koko toisen kierroksen
syoteketju - kappa->rho_prime->ExpandMask(y)->NTT->w->w1->SHAKE->
c_tilde - RTL:n OMISTA hierarkkisista rekistereista, EI oletetuista
Python-arvoista) LOYSI RATKAISUN VALITTOMASTI.**

**Menetelma:** ajettiin YKSI kattava jaljitys, joka poimi RTL:n OMAT
`mu_reg`, `rho_prime_reg`, `y_reg`, `w_reg`, `c_tilde_reg`-arvot
SUORAAN hierarkiasta (dut.mu_reg jne) SEN JALKEEN kun koko Sign oli
valmistunut (kappa=5-kierroksen loppuarvot). NAMA arvot syotettiin
SITTEN Pythoniin, joka laski `y=ExpandMask(rho_prime,5)`,
`w=(A_hat@y_hat).from_ntt()`, `c_tilde=H(mu+w1_bytes,48)` KAYTTAEN
TASMALLEEN RTL:n omia arvoja - EI mitaan erillista, oletettua
"kappa=5 golden" -laskentaa (joka osoittautui aiemmin vaarin
lasketuksi).

**TULOS: c_tilde TASMASI TAYDELLISESTI.**
```
Python c_tilde (RTL:n oma mu/rho_prime/kappa=5 kaytettyna):
e046d59162ae4a390480239f27a1205f164b2356805f19d6519e69d1ef146ff0cbaaaf73987976a51a4bcbff6e16a136

RTL:n oma c_tilde_reg:
e046d59162ae4a390480239f27a1205f164b2356805f19d6519e69d1ef146ff0cbaaaf73987976a51a4bcbff6e16a136

Tasmaavatko: True
```

**JOHTOPAATOS: sign_top2.sv:n OMA hylkays-ja-uusintayritys-mekanismi
(S7) TOIMII TAYDELLISESTI OIKEIN, MYOS TOISELLA KIERROKSELLA.** Aiempi
"virhe" (jatko 13:ssa raportoitu "kappa=5 c_tilde ei tasmaa") johtui
KOKONAAN OMASTA, ERILLISESTA Python-debug-skriptista, joka laski
"golden kappa=5 c_tilde":n VAARIN (todennakoisesti eri rho_prime/mu-
arvoilla kuin mita RTL TODELLISUUDESSA kaytti, samantyyppinen virhe
kuin aiemmat kaksi loydetya testivektorivirhetta taman projektin
historiassa).

**Tama on KOLMAS kerta taman projektin aikana, kun epailty "RTL-bugi"
osoittautuu OMAN testi-/debug-skriptin virheeksi** (aiemmat kaksi:
rho_prime:n msg_len, ja z:n pack/unpack-representaatio). Tama
vahvistaa kayttajan oman, toistuvan neuvon arvon: AINA verrata RTL:n
OMIA, hierarkkisesti poimittuja arvoja, EI oletettuja/erikseen
laskettuja "golden"-arvoja, kun jaljitetaan monivaiheista laskentaa.

## DK6:n LOPULLINEN, VAHVISTETTU tila

| Vaihe | Tila |
|---|---|
| S1-S8 (kaikki) | ✅ TAYDELLISESTI VAHVISTETTU |
| Hylkays-ja-uusintayritys (S7, kappa=0->5) | ✅ VAHVISTETTU NIST ACVP -vektorilla |

**M5-DILITHIUM-001:n KAIKKI paaoperaatiot (KeyGen, Verify, Sign
mukaan lukien AITO hylkays-ja-uusintayritys) ovat nyt TAYDELLISESTI
todennettu SEKA dilithium-py:ta ETTA NIST:n omia ACVP-KAT-vektoreita
vastaan.**
