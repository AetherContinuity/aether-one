# M5-DILITHIUM-001 DK4: KeyGenin ydinlaskenta

**Paivamaara:** 2026-07-19
**Tila:** t = NTT^-1(A*NTT(s1)) + s2 VALMIS ja todennettu.

## Toteutus

`pqc_dilithium_keygen_core.sv` - yhdistaa KOLME jo erikseen
todistettua rakennuspalikkaa (DK1 NTT-ytimet, DK2 A-matriisi, DK3
s1/s2):

1. Forward-NTT jokaiselle s1[i]:lle (5 kertaa, jaettu NTT-ydin)
2. Matriisikertolasku NTT-domainissa: t_hat[row] = sum_j(A[row][j]*
   s1_hat[j]) (Barrett-kertolasku + modulaarinen yhteenlasku)
3. Inverse-NTT jokaiselle t_hat[row]:lle (6 kertaa, jaettu NTT-ydin)
4. t = t_raw + s2 (taysin kombinatorinen, kaikki 6*256 kerrointa
   rinnakkain)

**s1/s2:n muunnos raa'asta etumerkillisesta (-4..4) Zq-edustajaksi**
([0,Q)) tehdaan taman moduulin OMASSA sisaankaynnissa (jos negatiivinen,
lisataan Q) - ExpandS:n oma ulostulo pysyy sellaisenaan (raakana),
Zq-muunnos VASTA taalla, kayttopaikassa.

## Loydetty "bugi" joka EI OLLUTKAAN bugi

Ensimmainen testiajo aikakatkaistiin (50000 sykli). Jaljitys
paljasti etta tilakone EI ollut jumissa - se etenee TAYSIN oikein,
mutta koko laskenta (5 forward-NTT:ta + 6*5*256 pisteen matriisi-
kertolasku + 6 inverse-NTT:ta) tarvitsee YHTEENSA ~68000 sykli, mika
YLITTI alkuperaisen, liian varovaisen 50000 syklin aikarajan.
Kasvatettu 150000:een - PASS valittomasti.

**Tama on TARKEA opetus:** ennen kuin oletetaan RTL-bugi, tarkista
AINA ensin onko kyseessa VAIN riittamaton aikaraja - erityisesti
laajoja, useita ala-vaiheita yhdistavia orkestraattoreita testattaessa,
joissa syklimaarat kertautuvat nopeasti.

## Testitulos

```
Valmis 68134 syklin jalkeen
PASS: t = NTT^-1(A*NTT(s1))+s2 tasmaa taydellisesti kaikille 6 polynomille
```

**PASS TAYDELLISESTI kaikille 6 polynomille**, verrattu suoraan
`dilithium-py`:n omaan `(A_hat @ s1_hat).from_ntt() + s2` -laskentaan
(kaytten `ML_DSA_65`:n omia sisaisia metodeja suoraan, EI omaa
rinnakkaista Python-uudelleentoteutusta).

## Mitattu suorituskyky (osio 8, suunnitelman mukaisesti)

68134 sykli koko KeyGenin ydinlaskennalle (5 forward-NTT + matriisi-
kertolasku + 6 inverse-NTT + yhteenlasku), EI VIELA sisalla
ExpandA/ExpandS:n omaa nayttestysaikaa (nama on jo mitattu erikseen:
~12399 sykli ExpandA:lle, ~6208 sykli ExpandS:lle).

**KOKO KeyGen-orkestroinnin arvioitu kokonaissyklimaara** (ExpandA +
ExpandS + tama ydinlaskenta + Power2Round + pakkaus): karkeasti
12399+6208+68134+jokin pieni lisa Power2Round/pakkaukselle ≈ 87000-
90000 sykli, tarkka luku mitataan kun koko orkestrointi on koottu.

## Seuraava askel

Power2Round(t) -> (t1, t0) - suhteellisen pieni, suoraviivainen
lisays (per-kerroin modulo-2^13-jako + etumerkkikasittely) - ja
lopuksi pakkaus ek/dk-muotoon.
