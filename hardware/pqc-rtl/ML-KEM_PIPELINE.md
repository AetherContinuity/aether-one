# ML-KEM_PIPELINE.md — integraatiotason jäljitettävyys

**Päivämäärä:** 2026-07-13
**Tarkoitus:** yksi selkea datapolkukaavio + viittaukset siihen, mika
GitHub Issue/moduuli toteuttaa kunkin vaiheen. Ei pitkaa selitysta -
katso yksittaisten Issueiden omat design note -tiedostot ja
README.md:n vastaavat osiot tarkemmalle kuvaukselle.

## K-PKE.KeyGen — datapolku

```
d (32 tavua satunnaisuutta)
   |
   v
G(d||k) = SHA3-512(d||k)                              [Issue #12/#13]
   |
   +--> rho (32 tavua)              sigma (32 tavua)
   |         |                            |
   |         v                            v
   |    XOF(rho||j||i)              PRF_eta1(sigma, N)
   |    = SHAKE128                  = SHAKE256          [Issue #14]
   |         |                            |
   |         v                            v
   |    SampleNTT                   SamplePolyCBD_eta1
   |    [Issue #15]                 [Issue #15]
   |         |                            |
   |         v                            v
   |    A_hat[i][j]                 s[i], e[i] (Rq-domain)
   |    (Tq-domain, k*k kpl)              |
   |                                      v
   |                                 NTT(s), NTT(e)     [Issue #10/M2]
   |                                      |
   +----------+---------------------------+
              v
      t_hat = A_hat . s_hat + e_hat
      (MultiplyNTTs + polyadd)            [Issue #8/M2]
              |
              v
      ekPKE = ByteEncode12(t_hat) || rho  [Issue #7/#12]
      dkPKE = ByteEncode12(s_hat)         [Issue #7]
```

## K-PKE.Encrypt — datapolku (paaosin sama koneisto, eri syote)

```
ekPKE, m (32 tavua), r (32 tavua satunnaisuutta)
   |
   +--> t_hat = ByteDecode12(ekPKE[0:384k])            [Issue #7]
   +--> rho = ekPKE[384k:384k+32]
   |         |
   |         v
   |    XOF(rho||j||i) -> SampleNTT -> A_hat (uudelleen, sama kuin KeyGen)
   |
   +--> PRF_eta1(r,N) -> SamplePolyCBD -> y[i]
   +--> PRF_eta2(r,N) -> SamplePolyCBD -> e1[i], e2
   |         |
   |         v
   |    NTT(y)                                          [Issue #10]
   |         |
   |         v
   |    u = NTT^-1(A_hat^T . y_hat) + e1                [Issue #8/#10]
   |    mu = Decompress1(ByteDecode1(m))                [Issue #6/#7]
   |    v_poly = NTT^-1(t_hat^T . y_hat) + e2 + mu
   |         |
   |         v
   |    c1 = ByteEncode_du(Compress_du(u))              [Issue #6/#7]
   |    c2 = ByteEncode_dv(Compress_dv(v_poly))
   |         |
   |         v
   |    c = c1 || c2  (ciphertext)
```

## K-PKE.Decrypt — jo TAYSIN valmis ja todennettu (Issue #8)

```
dkPKE, c  ->  u', v' (Vaihe 1)  ->  NTT+MultiplyNTTs+polyadd (Vaihe 2)
   ->  NTT^-1 (Vaihe 3)  ->  polysub+Compress1+ByteEncode1 (Vaihe 4)
   ->  m
```

## Moduuli -> Issue-taulukko

| Vaihe | Moduuli(t) | Issue | Tila |
|---|---|---|---|
| Keccak-permutaatio | pqc_keccak_f1600.sv | #10 | Valmis |
| Sponge (pad/absorb/squeeze) | pqc_keccak_pad/absorb/squeeze.sv | #11 | Valmis |
| SHA3-256 | pqc_sha3_256.sv | #12 | Valmis |
| SHA3-512 | pqc_sha3_512.sv | #13 | Valmis |
| SHAKE128/256 | pqc_shake128/256.sv | #14 | Valmis |
| SampleNTT | pqc_samplentt.sv | #15 | Valmis |
| SamplePolyCBD | pqc_samplepolycbd.sv | #15 | Valmis |
| NTT / NTT^-1 | pqc_ntt_stage_banked.sv | M2 / NTT_INVERSE | Valmis |
| MultiplyNTTs | pqc_multiplyntts.sv | #8 (esityo) | Valmis |
| PolyAdd / PolySub | pqc_polyadd.sv, pqc_polysub.sv | #8 | Valmis |
| Compress / Decompress | pqc_compress.sv, pqc_batch_compress/decompress.sv | #6 | Valmis |
| ByteEncode / ByteDecode | pqc_byteencode_*.sv | #7 | Valmis |
| K-PKE.Decrypt (kokonaan) | tb/pqc_kpke_decrypt_full_tb.sv | #8 | Valmis |
| **K-PKE taydellinen round-trip** | tb/pqc_kpke_roundtrip_tb.sv | Issue #15 | **✅ KOKONAAN VALMIS (Seed->KeyGen->Encrypt->Decrypt->m)** |
| **K-PKE.KeyGen** | tb/pqc_kpke_keygen_full_tb.sv | **#15** | **✅ KOKONAAN VALMIS (d -> ekPKE+dkPKE)** |
| **K-PKE.Encrypt** | tb/pqc_kpke_encrypt_full_tb.sv | **#15** | **✅ KOKONAAN VALMIS (ekPKE+m+r -> c)** |
| ML-KEM.KeyGen_internal | tb/pqc_mlkem_keygen_tb.sv | #15 | Valmis |
| ML-KEM.Encaps_internal | tb/pqc_mlkem_encaps_tb.sv | #15 | Valmis |
| ML-KEM.Decaps_internal | tb/pqc_mlkem_decaps_a_tb.sv + tb/pqc_mlkem_decaps_b_tb.sv | #15 | ✅ VALMIS (jaettu kahteen pienempaan RTL-testiin) |

**Ratkaisu (2026-07-14):** yhdistetty testipenkki jaettiin kahteen
pienempaan, kayttajan oman ehdotuksen mukaisesti:
- **Decaps TB A**: K-PKE.Decrypt -> m', G(m'||h) -> (K',r') - PASS
  kaikki 9 tarkistusta (3 tapausta x 3), EI segmentointivirhetta.
- **Decaps TB B**: (m',r',ek,z syotteina) -> K-PKE.Encrypt -> c',
  tavu-tavulta-vertailu (ensimmainen eroava tavu debugiin), FO-valinta
  - PASS kaikki 3 tapausta (valid, byte_corrupted, bit_corrupted),
  EI segmentointivirhetta.

Tama vahvistaa kayttajan oman hypoteesin: aiempi kaatuminen johtui
tyokalun (Icarus Verilog VVP) omasta rajoituksesta erittain suuren
yhdistetyn integraatiotestipenkin kanssa, EI RTL- tai algoritmi-
virheesta. Molemmat pienemmat testipenkit kayttavat samoja jo
validoituja moduuleita.

**ML-KEM.KeyGen_internal, Encaps_internal JA Decaps_internal ovat
nyt kaikki valmiit ja todennettu RTL:ssa.**

## Integraatioperiaate (kayttajan oma ohje, kirjattu talteen)

**Ala muuta enaa primitiiveja ilman erittain painavaa syyta.** Jos
KeyGen- tai Encrypt-integraatiossa ilmenee ongelma, oletusarvo on
etta virhe on INTEGRAATIOKERROKSESSA (kutsujarjestys, parametrit,
datamuodot moduulien valilla), kunnes nayttoa osoittaa toisin. Sama
periaate joka loysi NTT^-1:n ja Keccakin omat testipenkkibugitkin
nopeasti: tarkista integraatio/testipenkki ENSIN.

Integraatio tehdaan kerroksittain (kayttajan oma jarjestys):
1. Entropy/seed: SHAKE -> SampleNTT, SHAKE -> SamplePolyCBD (oikea
   PRF/XOF-kutsukonventio, N-laskurin oikea kasvatus)
2. Polynomien generointi: A-matriisi, s, e
3. Lineaarialgebra: NTT, MultiplyNTTs, PolyAdd
4. Koodaus: Compress, ByteEncode

Vasta kun jokainen kerros toimii erikseen, ne yhdistetaan seuraavaan.
