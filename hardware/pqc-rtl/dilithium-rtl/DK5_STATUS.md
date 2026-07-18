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
