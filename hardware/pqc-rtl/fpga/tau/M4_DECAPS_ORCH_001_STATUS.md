# M4-DECAPS-ORCH-001: ML-KEM.Decaps_internal synteesikelpoinen orkestrointi

**Paivamaara:** 2026-07-19
**Tila:** Phase A (K-PKE.Decrypt) VALMIS JA TODENNETTU. Phase G ja
Phase B (K-PKE.Encrypt + FO-valinta) viela toteuttamatta.

## Kokonaisalgoritmin rakenne (FIPS 203 Algoritmi 21)

ML-KEM.Decaps_internal koostuu kolmesta vaiheesta:
1. **Phase A**: K-PKE.Decrypt(dkPKE, c) -> m'
2. **Phase G**: G(m'||h) -> (K', r')
3. **Phase B**: K-PKE.Encrypt(ekPKE, m', r') -> c', vertailu c==c',
   FO-valinta (K' tai J(z||c) = SHAKE256(z||c))

Testipenkkien (`tb/pqc_mlkem_decaps_a_tb.sv`, `tb/pqc_mlkem_decaps_b_tb.sv`)
oma jako A/B seurattiin tallä samalla jaolla synteesikelpoisessa
orkestroinnissa - Phase B on huomattavasti laajempi (K-PKE.Encrypt
on lahes yhta laaja kuin koko KeyGen).

## Phase A: K-PKE.Decrypt(dkPKE, c) -> m' - VALMIS

**Toteutus:** `pqc_mlkem_decaps_a_core.sv`

**Sekvenssi:**
1. Pura c -> c1[0], c1[1] (DU=10-bittinen), c2 (DV=4-bittinen)
2. ByteDecode(DU) + Decompress(DU) c1[i]:sta -> u'[i]
3. ByteDecode(DV) + Decompress(DV) c2:sta -> v'
4. ByteDecode(12) dkPKE:sta -> s_hat[i]
5. NTT-forward u'[i]:lle -> u_hat[i] (uudelleenkaytetty M4-MLKEM-
   ORCH-001:n todistettu metodologia)
6. Matriisikertolasku+summaus: acc = sum_i(s_hat[i]*u_hat[i])
7. **NTT-inverse** acc:lle -> inner_raw -> scale -> inner (UUSI:
   ensimmainen kerta taman projektin synteesikelpoisessa
   orkestroinnissa - oma aikataulu-ROM, taso 6 VIIMEISENA
   toisin kuin forward-NTT:ssa)
8. w = v' - inner
9. Compress(D=1) + ByteEncode(D=1) w:sta -> m'

## Loydetyt ja korjatut bugit

**Bugi 1 (KORJATTU):** `pqc_bytedecode_dparam`:n oma `f_out`-leveys on
`256*D` bittia (TIIVIISTI pakattu D-bittinen ARVO), EI `256*COEFF_W`
kuten oletin - ByteDecode palauttaa RAA'AN D-bittisen arvon, VASTA
Decompress muuntaa taman Zq-kertoimeksi. Korjattu kaikkien kolmen
ByteDecode-instanssin (DU, DV, D=12) leveydet ja s_hat-purun
indeksointi vastaamaan tata.

**Bugi 2 (KORJATTU):** `pqc_compress`:n oma porttinimisto (`d`, `x_in`,
`compress_out`, `y_in`, `decompress_out`) EI vastannut oletustani
(`d_sel`, `y_out`) - korjattu oikeilla porttinimilla ja leveyksilla
(COEFF_W=16, ei 256).

**Bugi 3 (KORJATTU, sama luokka kuin aiemmin loydetty NTT-lukuvirhe):**
`c1_x_in` on rekisteroity, `c1_compress_out` on kombinatorinen SEN
POHJALTA - alkuperainen koodi luki `compress_out`:n SAMALLA syklilla
kuin asetti `x_in`:in, aiheuttaen YHDEN POSITION SIIRTYMAN KAIKISSA
256 bitissa (nakyi RTL=golden*2 -tyyppisena kuviona). Korjattu
kaksivaiheisella tilalla (S_ENCODE_M_SETUP asettaa x_in, S_ENCODE_M
kaappaa compress_out YHDEN syklin viiveella).

## Testitulos

```
OK valid: m' tasmaa taydellisesti golden-malliin (7626 syklia)
OK byte_corrupted: m' tasmaa taydellisesti golden-malliin (7626 syklia)
OK bit_corrupted: m' tasmaa taydellisesti golden-malliin (7626 syklia)
PASS: Decaps Phase A (K-PKE.Decrypt) - m' tasmaa kaikille 3 tapaukselle
```

**KAIKKI KOLME JAADYTETTYA TESTITAPAUSTA (valid, byte_corrupted,
bit_corrupted) LAPAISEVAT.**

## Jaljella (ei viela aloitettu)

- **Phase G**: G(m'||h) -> (K', r') - PIENI, suoraviivainen (SHA3-512,
  sama kuin KeyGenissa jo todistettu kaava)
- **Phase B**: K-PKE.Encrypt(ekPKE, m', r') -> c', vertailu, FO-valinta -
  LAAJA (lahes yhta suuri kuin koko KeyGen-orkestrointi: SampleNTT,
  PRF+CBD x2 (ETA1, ETA2), matriisikertolasku x2, NTT-forward x2,
  Compress+ByteEncode x2 (DU, DV))
- Wishbone-integraatio TAU-kehykseen (sama malli kuin KeyGenissa)
- Synteesi + P&R -vahvistus

## Phase G lisatty ja todennettu (2026-07-19, jatko)

Laajennettu `pqc_mlkem_decaps_a_core.sv` sisaltamaan myos G-vaiheen:
G(m'||h) -> (K', r') via SHA3-512 - sama, jo todistettu kaava kuin
M4-MLKEM-ORCH-001:ssa (KeyGenin oma SHA3-512-kaynnistys).

**Testitulos (kaikki kolme jaadytettya tapausta):**
```
OK valid: m' tasmaa taydellisesti golden-malliin
OK valid: K' tasmaa taydellisesti golden-malliin
OK valid: r' tasmaa taydellisesti golden-malliin
OK byte_corrupted: m'/K'/r' tasmaavat
OK bit_corrupted: m'/K'/r' tasmaavat
```

**PASS TAYDELLISESTI kaikille kolmelle tapaukselle, kaikille kolmelle
arvolle (m', K', r').**

## M4-DECAPS-ORCH-001:n paivitetty tila

| Vaihe | Tila |
|---|---|
| Phase A: K-PKE.Decrypt(dkPKE,c) -> m' | ✅ TODENNETTU |
| Phase G: G(m'\|\|h) -> (K',r') | ✅ TODENNETTU |
| Phase B: K-PKE.Encrypt(ekPKE,m',r') -> c', vertailu, FO-valinta | ❌ Ei viela aloitettu - LAAJA |
| Wishbone-integraatio | ❌ Ei viela aloitettu |
| Synteesi + P&R | ❌ Ei viela aloitettu |

Seuraava askel: Phase B, joka on lahes yhta laaja kuin koko
KeyGen-orkestrointi (SampleNTT, PRF+CBD x2, matriisikertolasku x2,
NTT-forward x2, Compress+ByteEncode x2).
