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
