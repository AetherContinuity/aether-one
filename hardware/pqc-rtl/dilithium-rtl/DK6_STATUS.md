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
