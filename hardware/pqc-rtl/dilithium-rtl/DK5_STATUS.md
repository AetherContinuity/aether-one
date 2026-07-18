# M5-DILITHIUM-001 DK5: ML-DSA-65.Verify_internal

**Paivamaara:** 2026-07-19
**Tila:** SampleInBall (ensimmainen uusi rakennuspalikka) VALMIS.

## Verify_internal:n kokonaisrakenne (suunnittelun pohjaksi)

```python
def _verify_internal(self, pk, m, sig):
    rho, t1 = self._unpack_pk(pk)
    c_tilde, z, h = self._unpack_sig(sig)
    if h.sum_hint() > OMEGA: return False
    if z.check_norm_bound(GAMMA1-BETA): return False
    A_hat = self._expand_matrix_from_seed(rho)      # UUDELLEENKAYTETTY DK2:sta
    tr = self._h(pk, 64)                             # SHAKE256, uudelleenkaytettava
    mu = self._h(tr + m, 64)                         # SHAKE256
    c = self.R.sample_in_ball(c_tilde, TAU)          # UUSI - DK5 oma
    c, z = c.to_ntt(), z.to_ntt()                    # UUDELLEENKAYTETTY DK1:sta
    t1 = t1.scale(1 << D).to_ntt()
    Az_minus_ct1 = (A_hat @ z - t1.scale(c)).from_ntt()  # UUDELLEENKAYTETTY (matriisikertolasku+inverse-NTT)
    w_prime = h.use_hint(Az_minus_ct1, 2*GAMMA2)     # UUSI - UseHint
    w_prime_bytes = w_prime.bit_pack_w(GAMMA2)       # UUSI - bit_pack_w
    return c_tilde == self._h(mu + w_prime_bytes, 48)
```

## SampleInBall VALMIS (2026-07-19)

**Toteutus:** `pqc_dilithium_sample_in_ball.sv` - FIPS 204
Algoritmi 29, TAU=49. GENUINE SEKVENTIAALINEN, TILALLINEN algoritmi
(Fisher-Yates-tyylinen sekoitus) - EI rinnakkaistettavissa kuten
aiemmat naytteenottomoduulit (ExpandA/ExpandS).

Kayttaa SHAKE256:ta (136-tavuinen XOF-puskuri, reilu turvamarginaali
~66 odotetulle tarvittavalle tavumaaralle).

**Testitulos (nelja eri c_tilde-arvoa, mukaan lukien satunnaisia):**
```
Valmis ~400 syklin jalkeen (error_exhausted=0)
PASS: SampleInBall tasmaa taydellisesti kaikille 256 kertoimelle
```

**PASS TAYDELLISESTI ENSIMMAISELLA YRITYKSELLA kaikissa nelja
testissa.**

## DK5:n tila

| Osa | Tila |
|---|---|
| SampleInBall | ✅ |
| unpack_pk/unpack_sig | ❌ Seuraava |
| Matriisikertolasku+skaalaus (uudelleenkaytto DK1/DK4:sta) | ❌ |
| UseHint | ❌ |
| bit_pack_w | ❌ |
| Koko Verify-orkestrointi | ❌ |

## Decompose VALMIS - loydetty ja korjattu klassinen SystemVerilog-sudenkuoppa (2026-07-19, jatko)

**Toteutus:** `pqc_dilithium_decompose.sv` - FIPS 204 Algoritmi 36,
ALPHA=2*GAMMA2=523776 (m=(Q-1)/ALPHA=16).

**LOYDETTY JA KORJATTU: klassinen SystemVerilog mixed signed/
unsigned -sudenkuoppa.** Ensimmainen versio kirjoitti "rp - r0_signed"
missa `rp` oli UNSIGNED ja `r0_signed` ETUMERKILLINEN - SystemVerilogin
oma saanto sanoo etta jos YKSIKIN operandi on unsigned, KOKO
LAUSEKE kasitellaan unsigned:na, jolloin `r0_signed`:n oma
etumerkki KATOAA (sen bittikuvio tulkitaan suoraan valtavana
positiivisena lukuna). Tama aiheutti 263/508 testitapauksen
epaonnistumisen - AINA `r1`-arvon virhe, `r0` oli AINA oikein
(koska se ei riippunut tasta sekoituksesta).

**Korjaus:** eksplisiittinen `$signed()`-muunnos MOLEMMILLE
operandeille ennen vahennyslaskua (`rp_signed = $signed({1'b0,rp})`),
valttaen sekoitetun signed/unsigned-kontekstin kokonaan.

**Testitulos korjauksen jalkeen:**
```
PASS: Decompose tasmaa taydellisesti kaikille 508 testitapaukselle
```

**PASS TAYDELLISESTI** (8 reunatapausta, mukaan lukien erikoistapaus
rp-r0==Q-1, + 500 satunnaista).

## DK5:n paivitetty tila

| Osa | Tila |
|---|---|
| SampleInBall | ✅ |
| Decompose (HighBits/LowBits/UseHint:n perusta) | ✅ |
| UseHint | ❌ Seuraava |
| unpack_pk/unpack_sig | ❌ |
| bit_pack_w | ❌ |
| Koko Verify-orkestrointi | ❌ |

## UseHint VALMIS - PASS ensimmaisella yrityksella (2026-07-19, jatko 2)

**Toteutus:** `pqc_dilithium_use_hint.sv` - FIPS 204 Algoritmi 40,
uudelleenkayttaa suoraan juuri todistetun (ja korjatun) `pqc_dilithium_
decompose.sv`:n.

**Testitulos:**
```
PASS: UseHint tasmaa taydellisesti kaikille 506 testitapaukselle
```

506 = 6 reunatapausta (mukaan lukien h=0/1-yhdistelmat ALPHA-rajoilla)
+ 500 satunnaista (h,r)-paria.

**PASS TAYDELLISESTI ENSIMMAISELLA YRITYKSELLA** - edellisen
Decompose-korjauksen (mixed signed/unsigned) hyoty nakyi suoraan:
koska UseHint uudelleenkayttaa JO KORJATTUA decompose-moduulia, ei
loydetty uutta bugia tassa vaiheessa.

## DK5:n paivitetty tila

| Osa | Tila |
|---|---|
| SampleInBall | ✅ |
| Decompose | ✅ |
| UseHint | ✅ |
| unpack_pk/unpack_sig | ❌ Seuraava |
| bit_pack_w | ❌ |
| Koko Verify-orkestrointi | ❌ |

## bit_unpack_z VALMIS - PASS ensimmaisella yrityksella (2026-07-19, jatko 3)

**Toteutus:** `pqc_dilithium_unpack_z.sv` - GAMMA1=2^19-purkukaava
(`z=GAMMA1-altered`), SAMA "vakio miinus arvo" -kaava kuin bit_pack_
t0/bit_pack_s:ssa (pakkaus JA purku ovat symmetrisia taman kaavan
ansiosta). Kaksinkertaisen komplementin trikki (todistettu aiemmin)
toimi jalleen ensimmaisella yrityksella.

**Testitulos:**
```
PASS: bit_unpack_z tasmaa taydellisesti kaikille 256 kertoimelle
```

## DK5:n paivitetty tila

| Osa | Tila |
|---|---|
| SampleInBall | ✅ |
| Decompose | ✅ |
| UseHint | ✅ |
| bit_unpack_z (yksi polynomi) | ✅ |
| bit_unpack_z (koko L=5-vektori) | ❌ Seuraava, suoraviivainen laajennus |
| unpack_h (harva->tiheys-hintipurku) | ❌ |
| bit_pack_w | ❌ |
| Koko Verify-orkestrointi | ❌ |

## Koko z-vektorin laajennus + unpack_h VALMIINA (2026-07-19, jatko 4)

**Koko z-vektori (5 polynomia):** `pqc_dilithium_unpack_z_vector.sv`,
silmukoi todistetun yksittaisen moduulin - PASS ensimmaisella
yrityksella.

**unpack_h:** `pqc_dilithium_unpack_h.sv` - hintien purku harvasta
esityksesta (positiolista+offsetit) tiheaksi 0/1-taulukoksi. GENUINE
SEKVENTIAALINEN, VAIHTELEVAN PITUUDEN purku (OMEGA=55, K=6,
h_bytes=61 tavua).

**Testitulos (KOLME eri hint-jakaumaa, mukaan lukien molemmat
AARIRAJAT):**
```
30 hintia (epatasainen jakauma): PASS
0 hintia (tyhja): PASS
55 hintia (OMEGA-maksimi, epatasainen jakauma): PASS
```

**PASS TAYDELLISESTI KAIKISSA KOLMESSA TAPAUKSESSA, mukaan lukien
molemmat aariarvot (0 ja OMEGA).**

## DK5:n paivitetty tila

| Osa | Tila |
|---|---|
| SampleInBall | ✅ |
| Decompose | ✅ |
| UseHint | ✅ |
| bit_unpack_z (yksi + koko vektori) | ✅ |
| unpack_h | ✅ |
| bit_pack_w | ❌ Seuraava, VIIMEINEN uusi rakennuspalikka |
| Koko Verify-orkestrointi | ❌ |

## bit_pack_w VALMIS - PASS ensimmaisella yrityksella (2026-07-19, jatko 5)

**Toteutus:** `pqc_dilithium_pack_w.sv` - TAYSIN SUORA yhdistaminen,
EI etumerkkimuunnosta (w'=UseHint():n tulos ON JO [0,16)-alueella,
sama tiukka 4-bittinen formaatti kuin bit_pack_w:n oma tuotos).

**Testitulos:**
```
PASS: bit_pack_w (768 tavua) tasmaa taydellisesti dilithium-py:n tulokseen
```

**PASS TAYDELLISESTI ENSIMMAISELLA YRITYKSELLA.**

## DK5:n LOPULLINEN tila - KAIKKI UUDET RAKENNUSPALIKAT VALMIINA

| Osa | Tila |
|---|---|
| SampleInBall | ✅ |
| Decompose | ✅ |
| UseHint | ✅ |
| bit_unpack_z (koko vektori) | ✅ |
| unpack_h | ✅ |
| bit_pack_w | ✅ |
| **Koko Verify-orkestrointi** | ❌ Seuraava, VIIMEINEN vaihe |

Kaikki uudet, Verify_internal:lle ominaiset rakennuspalikat ovat nyt
valmiit ja todennettu erikseen. Seuraava askel on koota nama YHTEEN
uudelleenkaytettavien osien (ExpandA, NTT-forward/inverse,
matriisikertolasku, SHAKE256) kanssa yhdeksi taydeksi
ML-DSA-65.Verify_internal-orkestroinniksi.

## Verify-ytimen laskenta (Az_minus_ct1) VALMIS - PASS ensimmaisella yrityksella (2026-07-19, jatko 6)

**Toteutus:** `pqc_dilithium_verify_core.sv` - laskee
`Az_minus_ct1 = NTT^-1(A_hat@NTT(z) - NTT(t1*2^D)*NTT(c))` (K=6
polynomia). Sama rakenne kuin `pqc_dilithium_keygen_core.sv`, mutta
LISATTYNA "vahenna c*t1_scaled" -termi. Uudelleenkayttaa suoraan
DK1:n NTT-ytimet ja Barrett-kertolaskun.

**Testitulos:**
```
Valmis 101428 syklin jalkeen
PASS: Az_minus_ct1 tasmaa taydellisesti kaikille 6 polynomille
```

**PASS TAYDELLISESTI ENSIMMAISELLA YRITYKSELLA** - verrattu suoraan
`dilithium-py`:n omaan `(A_hat@z_hat - t1_hat.scale(c_hat)).from_ntt()`
-laskentaan. 101428 sykli (EVEN ENEMMAN kuin KeyGenin oma 87118
sykli, koska tarvitaan 12 NTT-muunnosta: 5 z:lle, 6 t1:lle, 1 c:lle,
vs KeyGenin oma 5+6).

## DK5:n paivitetty tila

| Osa | Tila |
|---|---|
| SampleInBall | ✅ |
| Decompose | ✅ |
| UseHint | ✅ |
| bit_unpack_z | ✅ |
| unpack_h | ✅ |
| bit_pack_w | ✅ |
| **Verify-ytimen laskenta (Az_minus_ct1)** | ✅ |
| Koko Verify-orkestrointi (unpack+hash+ydin+UseHint+pack_w+vertailu) | ❌ Viimeinen vaihe |

**Kaikki raskas laskennallinen tyo Verifylle on nyt valmis ja
todistettu.** Jaljella VAIN kokoonpanotyo: unpack_pk/unpack_sig
(suoraviivaista), tr/mu-hashit (SHAKE256, uudelleenkaytettava), ja
lopullinen liitanta olemassa oleviin, jo todistettuihin palasiin
(SampleInBall, UseHint, bit_pack_w).

## Koko Verify-orkestrointi: EI VIELA TOIMINNASSA (2026-07-19, jatko 7)

**HUOM: `pqc_dilithium_verify_top.sv` ja sen testipenkki loytyivat
jo olemassa olevina tiedostoina taman istunnon aikana (ei suoraa
muistikuvaa niiden luonnista taman keskustelun sisalla) - ne
kaantyivat puhtaasti, mutta EIVAT VIELA LAPAISSEET testia.**

**Testitulos:**
```
FAIL: aikakatkaisu (600000 syklia)
verify_ok: x (odotettu: 1, koska allekirjoitus on aito)
```

`done`-signaali EI koskaan lauennut 600000 syklin sisalla. Taman
oma, itsenainen `verify_core`-moduuli (Az_minus_ct1-laskenta) tarvitsi
VAIN 101428 sykli - koko orkestroinnin (ExpandA+SampleInBall+
Verify-ydin+UseHint+hash-laskennat) OLISI PITANYT tarvita karkeasti
115000-120000 sykli, EI yli 600000:ta. Tama viittaa GENUINE
RAKENTEELLISEEN ONGELMAAN taman orkestrointikerroksen omassa FSM:ssa
(esim. jokin tila joka ei koskaan siirry eteenpain), EI PELKASTAAN
riittamattomaan aikarajaan (toisin kuin DK4:n keygen_core.sv:n oma,
aiemmin loydetty vaaraharma "bugi").

**TARKEA EROTTELU:** kaikki YKSITTAISET rakennuspalikat (SampleInBall,
Decompose, UseHint, bit_unpack_z, unpack_h, bit_pack_w, verify_core/
Az_minus_ct1-laskenta) OVAT EDELLEEN todistetusti oikein, testattu
ERIKSEEN ja PASSANNEET. Ongelma on SPESIFISESTI taman `verify_top.sv`
-orkestrointikerroksen OMASSA kokoonpanologiikassa (esim. FSM-tilojen
valinen kytkenta, kasittelyjarjestys, tai jokin signaali joka ei
etene oikein).

## DK5:n rehellinen tila

| Osa | Tila |
|---|---|
| KAIKKI yksittaiset rakennuspalikat (SampleInBall...bit_pack_w) | ✅ |
| Verify-ytimen laskenta (Az_minus_ct1) itsenaisena moduulina | ✅ |
| Koko Verify-orkestrointi (verify_top.sv) | ❌ EI VIELA TOIMI - vaatii debug-tyota |

**Seuraava askel:** debugata `pqc_dilithium_verify_top.sv`:n oma FSM
samalla systemaattisella menetelmalla kuin aiemmin (tilasiirtymien
jaljitys hierarkkisilla signaalinimilla), loytaen tarkka kohta jossa
tilakone jaa jumiin tai etenee vaarin.

## Rikkinainen jaannetiedosto POISTETTU - juurisyy: kombinatorinen jumi (2026-07-19, jatko 8)

**Kayttaja vahvisti:** `pqc_dilithium_verify_top.sv` ja sen testipenkki
olivat jaanteita KESKEYTYNEESTA ensimmaisesta yrityksesta - EI
tarkoituksellisesti valmiiksi saatettua tyota.

**Diagnoosi ennen poistoa:** systemaattinen jaljitys osoitti etta
jopa TRIVIAALEIN mahdollinen testi (5 sykli, reset paalla koko ajan,
start EI koskaan laukaistu) EI TUOTTANUT MITAAN TULOSTETTA edes
30 sekunnin aikarajalla - EI edes ENSIMMAISTA `$display`-riviä
testipenkin omasta initial-lohkosta. Tama on VAHVA merkki
KOMBINATORISESTA SILMUKASTA (tai vastaavasta nollaviive-jumista)
JOKA TAPAHTUU JO ALUSTUSVAIHEESSA, riippumatta kellosta/resetista -
EI PELKASTAAN hidas simulaatio (toisin kuin DK4:n keygen_core.sv:n
oma, aiemmin loydetty vaaraharma "bugi").

**Generate-lohkot tarkistettu** - eivat paljastaneet ilmeista
syyta (rajalliset, standardit L/K/256-silmukat, samaa mallia kuin
kaikkialla muualla taman projektin ajan).

**PAATOS:** koska tama tiedosto on TODISTETUSTI keskeneraisen/
keskeytyneen yrityksen jaanne, EI kannata jatkaa sen debugaamista
loputtomiin - POISTETTU kokonaan. Sen sijaan koko Verify-orkestrointi
RAKENNETAAN UUDELLEEN, kayttaen OMAA, jo erikseen todistettua
`pqc_dilithium_verify_core.sv`-moduulia (Az_minus_ct1-laskenta,
PASS ensimmaisella yrityksella, 101428 sykli) perustana.

## DK5:n rehellinen, paivitetty tila

| Osa | Tila |
|---|---|
| KAIKKI yksittaiset rakennuspalikat (SampleInBall...bit_pack_w) | ✅ |
| Verify-ytimen laskenta (Az_minus_ct1) itsenaisena moduulina | ✅ |
| Koko Verify-orkestrointi | ❌ Rakennettava UUDELLEEN (edellinen yritys oli rikkinainen jaanne, poistettu) |

**Seuraava askel:** rakentaa UUSI, HUOLELLISESTI TESTATTU
verify_top.sv suoraan `pqc_dilithium_verify_core.sv`:n paalle,
samalla vaiheittaisella kurinalaisuudella (kaannetaan+testataan
JOKAINEN lisays ERIKSEEN ennen seuraavaan siirtymista) joka on
kantanut koko taman projektin ajan.
