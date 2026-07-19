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
