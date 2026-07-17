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

## Phase B1 VALMIS: A-matriisi + PRF/CBD-kohina (2026-07-19, jatko 2)

**Kayttajan oma B1-B4-jako K-PKE.Encrypt:lle otettu kayttoon** riskien
hallitsemiseksi Phase B:n laajuuden vuoksi.

**Toteutus:** `pqc_mlkem_decaps_b1_core.sv` - ByteDecode(12) ek:sta,
SampleNTT(rho,i,j) KxK A-matriisille, PRF+CBD(ETA1) y_vec:lle,
PRF+CBD(ETA2) e1_vec:lle ja e2_poly:lle. EI VIELA matriisikertolaskuja
- vain syotteen muodostus todennetaan tassa vaiheessa (kayttajan oma,
tarkoituksellinen rajaus).

**Uudelleenkaytetty suoraan M4-MLKEM-ORCH-001:sta (KeyGen):**
SampleNTT+CBD-silmukkarakenne - sama, jo todistettu kaava, eri
syote (rho/r' KeyGenin sigma/d_seed:n sijaan).

**Loydetty ja korjattu kaksi virhetta ENNEN testausta (ei jaljelle
jaanytta bugia):**
1. `ek`:n oikea leveys on 800 tavua (K*384+32=768+32=800), EI 768
   kuten alun perin oletin kommentissa - korjattu porttimaarittely.
2. **Kriittinen, aiemmin dokumentoitu Icarus-rajoitus** (ks.
   `pqc_byteencode_d1.sv`:n oma kommentti): unpacked-taulukko EI
   toimi oikein porttina. Korjattu litistamalla `A_out`/`y_vec_out`/
   `e1_vec_out` yhdeksi paketoiduksi vektoriksi kutakin (sisaiset,
   ei-porttina-kaytettavat unpacked-taulukot pysyvat FSM:n omana
   tyotilana, litistys tapahtuu VASTA ulostuloportissa `assign`-
   lauseilla).

**Testitulos:**
```
OK: A[0][0] tasmaa taydellisesti
OK: y_vec[0] tasmaa taydellisesti
OK: e1_vec[0] tasmaa taydellisesti
OK: e2_poly tasmaa taydellisesti
PASS: Decaps Phase B1 (A-matriisi + PRF/CBD-kohina) tasmaa golden-malliin
```

**PASS TAYDELLISESTI kaikille nelja tarkistetulle arvolle - ei
jaljella olevaa bugia taman kirjoitushetkella.**

## M4-DECAPS-ORCH-001:n paivitetty tila

| Vaihe | Tila |
|---|---|
| Phase A: K-PKE.Decrypt -> m' | ✅ |
| Phase G: G(m'\|\|h) -> K',r' | ✅ |
| Phase B1: A-matriisi + PRF/CBD-kohina | ✅ |
| Phase B2: NTT + matriisikertolasku | ❌ Seuraava |
| Phase B3: Compress + ByteEncode -> c' | ❌ |
| Phase B4: FO-valinta | ❌ |
| Wishbone-integraatio | ❌ |
| Synteesi + P&R | ❌ |

## Phase B2a VALMIS: NTT-forward y_vec:lle (2026-07-19, jatko 3)

**Kayttajan oma B2a/B2b-jako otettu kayttoon.** Taydentava havainto:
testipenkista tarkistettuna VAIN `y_vec` muunnetaan NTT-muotoon -
`e1_vec` ja `e2_poly` pysyvat normaalialueella, lisataan vasta
inverse-muunnoksen JALKEEN.

**Toteutus:** laajennettu `pqc_mlkem_decaps_b1_core.sv` sisaltamaan
NTT-forward-silmukka `y_vec[0]`, `y_vec[1]` -> `y_hat[0]`, `y_hat[1]`
- sama, jo kolmesti todistettu bring-up-metodologia (KeyGen, Decaps
Phase A).

**Testitulos:**
```
OK: y_hat[0] (B2a, NTT-forward) tasmaa taydellisesti
PASS: Decaps Phase B1 (A-matriisi + PRF/CBD-kohina) tasmaa golden-malliin
```

**PASS TAYDELLISESTI - ei loydettya bugia tassa vaiheessa** (kolmas
peraikkainen kerta kun taman metodologian uudelleenkaytto onnistuu
suoraan).

## M4-DECAPS-ORCH-001:n paivitetty tila

| Vaihe | Tila |
|---|---|
| Phase A: K-PKE.Decrypt -> m' | ✅ |
| Phase G: G(m'\|\|h) -> K',r' | ✅ |
| Phase B1: A-matriisi + PRF/CBD-kohina | ✅ |
| Phase B2a: NTT-forward y_vec:lle | ✅ |
| Phase B2b: Matriisikertolasku (A·y, t_hat·y) | ❌ Seuraava |
| Phase B3: Compress + ByteEncode -> c' | ❌ |
| Phase B4: FO-valinta | ❌ |

## Phase B2b-1 VALMIS: NTT-alueen lineaarialgebra (2026-07-19, jatko 4)

**Kayttajan oma B2b-1/B2b-2-jako otettu kayttoon.** B2b-1 =
pisteittainen kertolasku + akkumulointi NTT-alueella, EI VIELA
inverse-NTT:ta.

**Loydetty ja korjattu bugi: A-matriisi oli TRANSPONOITU.**

Testaus paljasti: RTL:n `A[1][0]` vastasi Python-referenssin
`sample_ntt(rho,0,1)`:ta, EI `sample_ntt(rho,1,0)`:ta. Syy:
`pqc_samplentt`:n omat `byte_i`/`byte_j`-portit vastaavat Python-
referenssin `sample_ntt(rho,i,j)`:n parametreja VAIHDETTUINA
(ristiin) - tama pysyi HUOMAAMATTA KeyGenissa, koska KeyGenin oma
matriisikertolaskukaava (`t_hat[i]=sum_j(A[i][j]*s_hat[j])`) ja
alkuperainen (transponoitu) tallennuskonventio sattuivat olemaan
KESKENAAN yhteensopivia - vasta Decapsin ERI kaava
(`u[col]=sum_j(A[j][col]*y_hat[j])`, A^T-tyyppinen kaytto) paljasti
epasymmetrisen bugin.

**Korjaus:** vaihdettu `samplentt_i`/`samplentt_j`-syote generointi-
vaiheessa (`samplentt_i<=j_ctr; samplentt_j<=i_ctr;`) niin etta
tallennettu `A[i][j]` vastaa SUORAAN Python-referenssin
`sample_ntt(rho,i,j)`:ta - poistaa implisiittisen transpoosion
kaikista MYOHEMMISTA kaavoista (tama korjaus koskee VAIN Decaps-
moduulia, EI vaikuta KeyGeniin, joka on erillinen, jo todistettu
tiedostonsa).

**Testitulos:**
```
OK: u_acc[0] (B2b-1, NTT-alueen akkumulointi) tasmaa taydellisesti
OK: v_acc (B2b-1) tasmaa taydellisesti
PASS: Decaps Phase B1 (A-matriisi + PRF/CBD-kohina) tasmaa golden-malliin
```

**PASS TAYDELLISESTI - molemmat NTT-alueen akkumulaattorit (u_acc,
v_acc) tasmaavat golden-malliin.**

**Lisaksi korjattu sama, jo tuttu bugiluokka** (rekisteroity syote +
kombinatorinen tulos samalla syklilla) matriisikertolaskun omassa
akkumuloinnissa - kaksivaiheinen setup/capture-tilapari
(S_MATMUL_U/S_MATMUL_U_CAPTURE, S_MATMUL_V/S_MATMUL_V_CAPTURE).

## M4-DECAPS-ORCH-001:n paivitetty tila

| Vaihe | Tila |
|---|---|
| Phase A: K-PKE.Decrypt -> m' | ✅ |
| Phase G: G(m'\|\|h) -> K',r' | ✅ |
| Phase B1: A-matriisi + PRF/CBD-kohina | ✅ |
| Phase B2a: NTT-forward y_vec:lle | ✅ |
| Phase B2b-1: NTT-alueen lineaarialgebra (A*y, t_hat*y) | ✅ |
| Phase B2b-2: inverse-NTT + skaalaus + normaalialue | ❌ Seuraava |
| Phase B3: Compress + ByteEncode -> c' | ❌ |
| Phase B4: FO-valinta | ❌ |
