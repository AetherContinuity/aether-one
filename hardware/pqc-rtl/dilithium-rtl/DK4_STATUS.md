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

## Power2Round VALMIS (2026-07-19, jatko)

**Toteutus:** `pqc_dilithium_power2round.sv` - FIPS 204 Algoritmi 35
(D=13), taysin kombinatorinen, yksi kerroin kerrallaan.

**Loydetty ja korjattu ITSE, ennen testausta:** `r1_out`:n oma
bittipoiminta `diff`-signaalista oli aluksi vaarin mitoitettu
(diff[CW:D] antoi 11 bittia, mutta r1_out on 10-bittinen) - korjattu
diff[CW-1:D]:ksi ennen ensimmaista testiajoa.

**Testitulos:**
```
PASS: Power2Round tasmaa taydellisesti kaikille 508 testitapaukselle
```

508 testitapausta = 8 reunatapausta (0, Q-1, 2^13-rajat) + 500
satunnaista arvoa, verrattu suoraan `dilithium-py`:n omaan
`reduce_mod_pm`-apufunktioon perustuvaan `power_2_round`-laskentaan.

**PASS TAYDELLISESTI - EI YHTAAN JAANYTTA LOYDETTYA BUGIA testauksen
aikana** (bittileveysvirhe loydettiin ja korjattiin ITSE ennen
testiajoa, tarkistamalla arvoalueet huolellisesti).

## DK4:n paivitetty tila

| Osa | Tila |
|---|---|
| t-laskenta (matriisikertolasku+NTT) | ✅ |
| Power2Round (yksittainen kerroin) | ✅ |
| Power2Round koko t-vektorille (6*256 kerrointa) | ❌ Seuraava (suoraviivainen, taysin rinnakkainen laajennus) |
| Pakkaus ek/dk-muotoon | ❌ |

## Power2Round koko t-vektorille VALMIS - PASS ensimmaisella yrityksella (2026-07-19, jatko 2)

**Toteutus:** `pqc_dilithium_power2round_vector.sv` - silmukoi
todistetun yksittaisen `pqc_dilithium_power2round.sv`:n K*256=1536
kertaa generate-lohkolla, taysin rinnakkainen/kombinatorinen.

**Testitulos:**
```
OK: t1 (6*256 kerrointa) tasmaa taydellisesti
OK: t0 (6*256 kerrointa) tasmaa taydellisesti
PASS: Power2Round koko t-vektorille tasmaa taydellisesti
```

**PASS TAYDELLISESTI ENSIMMAISELLA YRITYKSELLA**, verrattu suoraan
`dilithium-py`:n omaan `t.power_2_round(D)`-metodiin (kayttaen
todellista, DK4:n omaa `t`-arvoa - EI erillista testivektoria).

## DK4:n LOPULLINEN tila

| Osa | Tila |
|---|---|
| t-laskenta (matriisikertolasku+NTT) | ✅ |
| Power2Round (yksittainen + koko vektori) | ✅ |
| Pakkaus ek/dk-muotoon | ❌ Viimeinen askel |

**DK4 on lahes kokonaan valmis** - jaljella VAIN lopullinen tavu-
pakkaus (`bit_pack_t1`, `bit_pack_s`, `bit_pack_t0`) ek/dk-formaattiin,
minka jalkeen koko KeyGen-orkestrointi voidaan koota yhteen kaikista
DK1-DK4:n jo todistetuista palasista.

## ek-pakkaus VALMIS - PASS ensimmaisella yrityksella (2026-07-19, jatko 3)

**Toteutus:** `pqc_dilithium_pack_ek.sv` - PELKKA `rho`:n ja `t1`:n
yhdistaminen. Huomio: `dilithium-py`:n oma `__bit_pack`-apufunktio
pakkaa kertoimet TIUKASTI (kerroin i bittiasemassa [i*n_bits:
(i+1)*n_bits)) - taman ANSIOSTA `t1_out_flat` (Power2Round-vektorin
oma ulostulo, jo 256*10-bittisena tiukasti pakattuna per polynomi)
VASTAA SUORAAN `bit_pack_t1`:n omaa formaattia ilman mitaan
uudelleenjarjestelya - ek-pakkaus on siis TAYSIN SUORAVIIVAINEN.

**Testitulos:**
```
PASS: ek-pakkaus (1952 tavua) tasmaa taydellisesti dilithium-py:n _pack_pk()-tulokseen
```

**PASS TAYDELLISESTI ENSIMMAISELLA YRITYKSELLA**, koko 1952-tavuinen
`ek` tasmaa taydellisesti `dilithium-py`:n omaan `_pack_pk()`-tulokseen.

## DK4:n LOPULLINEN tila

| Osa | Tila |
|---|---|
| t-laskenta | ✅ |
| Power2Round (yksittainen + koko vektori) | ✅ |
| ek-pakkaus | ✅ |
| dk-pakkaus (s1/s2/t0 etumerkkimuunnoksineen + tr=H(ek)) | ❌ Seuraava, viimeinen DK4-askel |

**ek-puoli on nyt TAYSIN VALMIS.** dk-puoli vaatii viela: (a) s1/s2:n
oma etumerkkimuunnos (`eta-c`) ennen 4-bittista pakkausta, (b) t0:n
oma etumerkkimuunnos (`4096-c`) ennen 13-bittista pakkausta, (c)
`tr=H(ek)` (SHA3-512, 64 tavua, uudelleenkaytettava suoraan jo
todistettu SHA3-512-ydin), (d) kaikkien osien yhdistaminen.
