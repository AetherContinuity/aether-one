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
