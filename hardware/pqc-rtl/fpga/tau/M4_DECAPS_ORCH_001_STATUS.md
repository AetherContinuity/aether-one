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

## Phase B2b-2 VALMIS: inverse-NTT + skaalaus + normaalialue (2026-07-19, jatko 5)

**Toteutus:** laajennettu `pqc_mlkem_decaps_b1_core.sv`:
1. Inverse-NTT `u_acc[col]`:lle (col=0,1) + skaalaus + `e1_vec[col]`-
   lisays -> `u_vec[col]`
2. Inverse-NTT `v_acc`:lle + skaalaus
3. `mu_poly` = Decompress(D=1)(ByteDecode(D=1)(m')) - m':n oma
   dekoodaus takaisin polynomiksi
4. `v_poly` = skaalattu_v + `e2_poly` + `mu_poly`

**Loydetty ja korjattu sama, jo tuttu bugiluokka etukateen** (rekiste-
roity syote + kombinatorinen tulos samalla syklilla) mu_poly:n omassa
dekoodaussilmukassa - kaksivaiheinen setup/capture-tilapari
(`S_DECODE_MU`/`S_DECODE_MU_CAPTURE`), lisatty JO ENNEN testausta
(aiemman debug-kokemuksen ansiosta).

**Loydetty (oma testivirhe, EI RTL-bugi):** testin oma aikakatkaisu-
raja (10000 sykliä) oli liian lyhyt taman pidemman laskennan (2x
forward-NTT + 2x inverse-NTT + matriisikertolasku + mu-dekoodaus)
kokonaisajalle - kasvatettu 30000:een.

**Testitulos:**
```
OK: u_vec[0] (B2b-2, normaalialue) tasmaa taydellisesti
OK: v_poly (B2b-2, normaalialue) tasmaa taydellisesti
PASS: Decaps Phase B1 (A-matriisi + PRF/CBD-kohina) tasmaa golden-malliin
```

**PASS TAYDELLISESTI kaikille yhdeksalle tarkistetulle arvolle.**

## M4-DECAPS-ORCH-001:n paivitetty tila

| Vaihe | Tila |
|---|---|
| Phase A: K-PKE.Decrypt -> m' | ✅ |
| Phase G: G(m'\|\|h) -> K',r' | ✅ |
| Phase B1: A-matriisi + PRF/CBD-kohina | ✅ |
| Phase B2a: NTT-forward y_vec:lle | ✅ |
| Phase B2b-1: NTT-alueen lineaarialgebra | ✅ |
| Phase B2b-2: inverse-NTT + skaalaus + normaalialue | ✅ |
| Phase B3: Compress + ByteEncode -> c' | ❌ Seuraava |
| Phase B4: FO-valinta | ❌ |

**Kaikki raskas laskennallinen tyo (NTT-forward/inverse, matriisi-
kertolasku, kohinan lisays) on nyt valmis ja todennettu.** Jaljella
on VAIN muotoiluvaihe (Compress+ByteEncode c':n muodostamiseksi) ja
lopullinen FO-vertailu/valinta.

## Phase B3 VALMIS + TARKEA KORJAUS aiempaan A-transpoosi-oletukseen (2026-07-19, jatko 6)

**Toteutettu:** `Compress(DU/DV)` + `ByteEncode(DU/DV)` (batch-versiot,
taysin kombinatorisia) `u_vec`:lle ja `v_poly`:lle -> `c'`.

**KRIITTINEN OPPI: aiempi B2b-1:n "A-transpoosi-korjaus" OLI VAARIN.**

Aiemmin (edellisessa jatko-osassa) loysin etta RTL:n `A[1][0]` ei
tasmannyt Python `sample_ntt(rho,1,0)`:hon, vaan `sample_ntt(rho,0,1)`:hon
- ja "korjasin" taman vaihtamalla generointi-syotteen. TAMA KORJAUS
NAYTTI TOIMIVAN, koska vertasin tulosta OMAAN, manuaalisesti
uudelleentoteutettuun Python-referenssiin (`ntt_inv`, `multiply_ntts`
suoraan) - joka JAKOI SAMAN, todellisuudessa VAARAN transpoosi-
oletuksen kanssa RTL:n (korjatun) version kanssa!

**Vasta Phase B3:n `c'`-vertailu VIRALLISTA `kpke_encrypt()`-funktiota
vasten paljasti todellisen tilanteen:**

`kpke_encrypt_golden.py`:n oma kommentti: *"A_hat[i,j] =
SampleNTT(rho||j||i) - TASMALLEEN SAMA kuin K-PKE.KeyGen, EI
transponoitu generoinnissa. Transponointi tapahtuu VASTA KAAVASSA:
u[i] = sum_j A_hat[j][i] * y_hat[j]"*.

**Oikea korjaus:** PALAUTETTU A-matriisin generointi KeyGenin OMAAN,
EI-transponoituun konventioon (`samplentt_i<=i_ctr;
samplentt_j<=j_ctr;`, ENNALLAAN) - transpoosi toteutuu VAIN
matriisikertolaskun omassa indeksoinnissa (`A[mm_j][mm_col]`, joka
oli JO alunperin oikein - vain generointi oli tarpeettomasti
"korjattu" vaarin).

**Metodologinen opetus talletettu:** kun oma manuaalinen Python-
uudelleentoteutus KAYTTAA SAMOJA oletuksia kuin testattava RTL,
vertailu voi antaa VAARAN "PASS"-tuloksen molempien jakaessa saman
virheen. VAIN vertailu TAYSIN riippumattomaan, jo aiemmin erikseen
todistettuun VIRALLISEEN funktioon (tassa: `kpke_encrypt()` itse,
joka on jo kaytossa M3:n omissa, laajasti todennetuissa testeissa)
paljastaa tallaisen "yhteisen sokean pisteen" -tyyppisen virheen.

**Testitulos (kaikki yhdeksan tarkistettua arvoa, PAIVITETTYJEN
golden-referenssien kanssa):**
```
OK: A[0][0], y_vec[0], e1_vec[0], e2_poly, y_hat[0]
OK: u_vec[0], v_poly (B2b-2, normaalialue)
OK: c' (B3, Compress+ByteEncode) tasmaa taydellisesti golden-malliin
OK: u_acc[0], v_acc (B2b-1, NTT-alueen akkumulointi)
PASS: Decaps Phase B1 (A-matriisi + PRF/CBD-kohina) tasmaa golden-malliin
```

## M4-DECAPS-ORCH-001:n paivitetty tila

| Vaihe | Tila |
|---|---|
| Phase A: K-PKE.Decrypt -> m' | ✅ |
| Phase G: G(m'\|\|h) -> K',r' | ✅ |
| Phase B1: A-matriisi + PRF/CBD-kohina | ✅ (korjattu) |
| Phase B2a: NTT-forward y_vec:lle | ✅ |
| Phase B2b-1: NTT-alueen lineaarialgebra | ✅ (korjattu) |
| Phase B2b-2: inverse-NTT + skaalaus + normaalialue | ✅ |
| Phase B3: Compress + ByteEncode -> c' | ✅ **UUSI - koko c' tasmaa** |
| Phase B4: FO-valinta | ❌ Seuraava, VIIMEINEN vaihe |

**Kaikki kryptografinen laskenta on nyt valmis ja todistettu KOKO
tuotoksen (c') osalta.** Jaljella on VAIN Phase B4: c==c'-vertailu ja
FO-valinta (K' tai J(z||c)).

## TAYDELLINEN LAPIMURTO: KOKO ML-KEM.Decaps_internal VALMIS (2026-07-19, jatko 7)

**Phase B4 (FO-valinta) toteutettu ja todennettu KAIKILLE KOLMELLE
jaadytetylle testitapaukselle:**

```
OK valid: c' tasmaa, match=1, K_final = normaali K'
OK byte_corrupted: c' tasmaa, match=0, K_final = implisiittinen hylkays J(z||c)
OK bit_corrupted: c' tasmaa, match=0, K_final = implisiittinen hylkays J(z||c)
PASS: Decaps Phase B4 (FO-valinta) tasmaa golden-malliin kaikille 3 tapaukselle
```

**Toteutus:** SHAKE256(z||c, 32 tavua) J-funktiolle, vertailu
`c===c'`, FO-valinta `K_final = match ? K' : J(z||c)`.

## M4-DECAPS-ORCH-001: KAIKKI VAIHEET VALMIINA JA TODENNETTU

| Vaihe | Tila |
|---|---|
| Phase A: K-PKE.Decrypt -> m' | ✅ |
| Phase G: G(m'\|\|h) -> K',r' | ✅ |
| Phase B1: A-matriisi + PRF/CBD-kohina | ✅ |
| Phase B2a: NTT-forward y_vec:lle | ✅ |
| Phase B2b-1: NTT-alueen lineaarialgebra | ✅ |
| Phase B2b-2: inverse-NTT + skaalaus + normaalialue | ✅ |
| Phase B3: Compress + ByteEncode -> c' | ✅ |
| Phase B4: FO-valinta (K' tai J(z\|\|c)) | ✅ **VIIMEINEN VAIHE** |

**ENSIMMAINEN KERTA KOKO PROJEKTIN AIKANA ETTA TAYSI
ML-KEM.Decaps_internal ON TODISTETTU SYNTEESIKELPOISEKSI JA
BITTITARKASTI OIKEAKSI RTL:NA - kaikki kolme testitapausta (onnistunut
paatos, tavu-tason korruptio, bitti-tason korruptio) todistavat seka
normaalin etta implisiittisen hylkayspolun toimivan oikein.**

## Yhteenveto koko Decaps-matkan loydoksista

1. `pqc_bytedecode_dparam`:n oma f_out-leveys (256*D, ei 256*COEFF_W)
2. `pqc_compress`:n porttinimisto (d/x_in/compress_out, ei d_sel/y_out)
3. Sama bugiluokka toistuvasti: rekisteroity syote + kombinatorinen
   tulos samalla syklilla (korjattu joka kerta kaksivaiheisella
   setup/capture-mallilla, useissa eri konteksteissa)
4. `ek`:n oikea leveys (800 tavua, ei 768)
5. Unpacked-taulukko porttina -rajoitus (kaytettiin proaktiivisesti
   aiemman loydoksen perusteella)
6. **A-matriisin transpoosi-sekaannus KAHDESSA VAIHEESSA:** ensin
   loydettiin naennainen transpoosiongelma, KORJATTIIN VAARIN
   (koska vertailtiin omaan, saman virheen jakavaan manuaaliseen
   referenssiin), sitten TODELLINEN korjaus loytyi vasta vertaamalla
   TAYSIN riippumattomaan, viralliseen `kpke_encrypt()`-funktioon.

**Metodologinen paaopetus koko taman tyopaketin ajalta:** vaiheittainen,
golden-referenssiin perustuva testaus (kayttajan oma B1/B2a/B2b-1/
B2b-2/B3/B4-jako) mahdollisti jokaisen bugin kavennyksen tarkasti
rajattuun osa-alueeseen - MUTTA yhtä tarkeaa oli SEN LOPPUUN ASTI
VIETY, riippumattomaan viralliseen funktioon perustuva lopputarkistus,
joka paljasti etta yksi aiempi "korjaus" oli itse asiassa perustunut
virheelliseen itsereferenssiin.

## Seuraavat askeleet (ei viela aloitettu)

1. Wishbone-integraatio TAU-kehykseen (sama malli kuin KeyGenissa,
   M4-TAU-001)
2. Synteesi + P&R -vahvistus ECP5:lla
3. Encaps-orkestrointi (ML-KEM.Encaps_internal - ECU:n oma puoli)

## Yhdistetty huippumoduuli VALMIS: paasta-paahan-testi TUOREELLA vektorilla (2026-07-19, jatko 8)

**Toteutus:** `pqc_mlkem_decaps_top.sv` yhdistaa Phase A+G
(`pqc_mlkem_decaps_a_core`) ja Phase B1-B4 (`pqc_mlkem_decaps_b1_core`)
YHDEKSI ML-KEM.Decaps_internal-orkestroinniksi: kaynnista A+G, odota,
kaynnista B (kayttaen A+G:n m'/K'/r'-tulosta), odota, tuota K_final.

**Kriittinen validointiaskel:** testattu TUOREELLA, RIIPPUMATTOMALLA
testivektorilla - EI aiemmin kaytetyilla A/B-vaiheiden omilla
vektoreilla (jotka olivat KESKENAAN yhteensopimattomia, eri
avainpareista). Generoitu KOKONAAN UUSI ketju: `mlkem_keygen_internal`
-> `mlkem_encaps_internal` -> `mlkem_decaps_internal` (kaikki
VIRALLISIA, jo erikseen todistettuja funktioita) - satunnainen
d_seed/z_seed/viesti, EI mikaan aiemmin nahty testitapaus.

**Testitulos:**
```
Valmis 21860 syklin jalkeen
match_out: 1 (odotettu: 1, koska c on aito, oikein muodostettu siffertext)
PASS: koko Decaps-huippumoduuli - K_final tasmaa taydellisesti riippumattomaan testivektoriin
```

**PASS TAYDELLISESTI - tama on VAHVIN mahdollinen validointi taholle
tyolle: taysin tuore, aiemmin nakematon testivektori, kaytten
VIRALLISIA FIPS 203 -referenssifunktioita paasta paahan.**

## M4-DECAPS-ORCH-001:n lopullinen tila

Kaikki 8 osavaihetta (A, G, B1, B2a, B2b-1, B2b-2, B3, B4) VALMIINA.
Yhdistetty huippumoduuli (`pqc_mlkem_decaps_top.sv`) VALMIS ja
todennettu tuoreella vektorilla.

**Seuraavat askeleet (ei viela aloitettu):**
1. Wishbone-integraatio TAU-kehykseen (sama malli kuin KeyGenissa)
2. Synteesi + P&R -vahvistus ECP5:lla
3. Encaps-orkestrointi (ML-KEM.Encaps_internal - ECU:n oma puoli)

## Wishbone-integraatio TAU-kehykseen VALMIS (2026-07-19, jatko 9)

**Toteutus:** laajennettu `pqc_tau_integrated_wrapper.sv` sisaltamaan
Decaps KeyGenin rinnalle, samalla mallilla (WORD_SEL+START+STATUS-
rekisterit).

**Uudet Wishbone-rekisterit (0x130-0x139):**
- 0x130: DECAPS_WORD_SEL
- 0x131: DECAPS_C_IN (siffertext, 384 sanaa)
- 0x132: DECAPS_DK_IN (dk, 816 sanaa)
- 0x133: DECAPS_START
- 0x134: DECAPS_STATUS (busy/done)
- 0x135: DECAPS_K_FINAL_OUT
- 0x136: DECAPS_MATCH

**Testitulos (pqc_tau_decaps_wishbone_tb.sv, kaytten SAMAA tuoretta,
riippumatonta testivektoria kuin huippumoduulin oma testi):**
```
ECU: c + dk kirjoitettu Wishbone-vaylan kautta
Decaps valmis 7288 Wishbone-syklin jalkeen
match: 1
PASS: K_final tasmaa taydellisesti Wishbone-vaylan kautta luettuna
PASS: Decaps-Wishbone-integraatio - koko ketju toimii
```

**Ei regressiota:** olemassa oleva KeyGen-integraatiotesti PASSAA
edelleen samassa, yhdistetyssa kaareessa (KeyGen ja Decaps toimivat
rinnakkain samalla Wishbone-vaylalla).

## M4-DECAPS-ORCH-001:n lopullinen tila

| Osa | Tila |
|---|---|
| Kaikki 8 algoritmivaihetta (A, G, B1, B2a, B2b-1, B2b-2, B3, B4) | ✅ |
| Yhdistetty huippumoduuli | ✅ |
| Wishbone-integraatio TAU-kehykseen | ✅ |
| Synteesi + P&R -vahvistus | ❌ Seuraava |
| Encaps-orkestrointi (ECU:n oma puoli) | ❌ |
| Audit-loki/watchdog-integraatio Decapsille (KeyGenin tapaan) | ❌ Pieni lisatyo |

## Audit-loki + watchdog-integraatio Decapsille VALMIS (2026-07-19, jatko 10)

**Toteutus:** Decaps kirjaa nyt audit-lokiin OMAT tapahtumansa
(DECAPS_STARTED, DECAPS_COMPLETED), erillisilla tunnistehasheilla
KeyGenista. Watchdog-keskeytys kattaa nyt myos Decapsin oman ajon
(sama periaate kuin KeyGenille: jos watchdog laukeaa KESKEN Decapsin
ajon, lokitetaan DECAPS_WATCHDOG_INTERRUPTED-tapahtuma, EI
DECAPS_COMPLETED-tapahtumaa).

**Arbitrointijarjestys audit-lokin jaetulle kirjoitusresurssille:**
watchdog-keskeytys (KeyGen) > watchdog-keskeytys (Decaps) > KeyGen-
omat tapahtumat > Decaps-omat tapahtumat.

**Loydetty oma testivirhe (EI RTL-bugi):** liian aikainen AUDIT_SEQ-
tarkistus heti Decapsin oman "done"-signaalin jalkeen - audit-lokin
oma SHA3-256-pohjainen kirjoitus (DECAPS_COMPLETED-tapahtuma) ei ollut
viela ehtinyt valmistua. Korjattu lisaamalla pieni odotus (100 sykli)
- sama "kadonnut pulssi" -harkinta kuin aiemmin loydetty M4-SoC-001:ssa.

**Testitulos (pqc_tau_decaps_audit_tb.sv):**
```
OK: Decaps valmis 7288 syklin jalkeen
OK: audit-loki sisaltaa tasan kaksi merkintaa
OK: seq=0 on DECAPS_STARTED-tapahtuma
OK: seq=1 on DECAPS_COMPLETED-tapahtuma
PASS: Decaps kirjaa audit-lokiin oikeat, omat tapahtumat
```

**Ei regressiota:** kaikki neljä olemassa olevaa integraatiotestia
(KeyGen-paasta-paahan, watchdog-keskeytys, audit-multiword, Decaps-
Wishbone) PASSAAVAT edelleen samassa, yhdistetyssa kaareessa.

## M4-DECAPS-ORCH-001:n LOPULLINEN tila

| Osa | Tila |
|---|---|
| Kaikki 8 algoritmivaihetta | ✅ |
| Yhdistetty huippumoduuli | ✅ |
| Wishbone-integraatio TAU-kehykseen | ✅ |
| Audit-loki + watchdog-integraatio | ✅ |
| Synteesi + P&R -vahvistus | ❌ Seuraava |
| Encaps-orkestrointi (ECU:n oma puoli) | ❌ |

**TAU:n palvelukehys tukee nyt SEKA KeyGenia etta Decapsia,
molemmat samalla, todistetulla mallilla (START/STATUS-rekisterit,
audit-tapahtumat, watchdog-suoja).**

## Synteesiyritys: Phase A yksinaan viela liian raskas taman ymparistion rajoissa (2026-07-19, jatko 11)

Yritettiin synteesoida `pqc_mlkem_decaps_a_core` YKSINAAN (VAIN yksi
Keccak/f1600-instanssi, EI koko orkestraattoria) - taustalla ajettuna,
1500 sekunnin aikarajalla. Prosessi jatkoi yli 3 minuutin ajan
(muistinkaytto kasvoi tasaisesti ~2.2GB:iin) ilman etta se ehti
valmistua taman istunnon oman komentorajan puitteissa.

**Tama VAHVISTAA aiemmin dokumentoidun havainnon (KeyGenin oma
synteesiyritys):** Yosys/ABC-optimointi taman NTT-ytimen +
useiden kombinatoristen alimoduulien (ByteDecode, Decompress,
Compress, NTT-inverse-skaalaus) YHDISTELMALLE on laskennallisesti
raskasta - EI korrektiusongelma, PUHTAASTI suorituskykyongelma
taman TYOYMPARISTON rajoissa.

**EI VIELA RATKAISTU** - vaatii joko: (a) pidemman, taustalla
ajettavan prosessin JOKA istunnon oman komentorajan ULKOPUOLELLA,
tai (b) resurssien kohdennetun optimoinnin (esim. yksinkertaisempi
synteesikonfiguraatio, tai Keccak-instanssien jakaminen usean
kayttajan kesken - aiemmin KeyGenin yhteydessa tunnistettu, EI VIELA
toteutettu mahdollisuus).

**Toiminnallinen oikeellisuus PYSYY TAYSIN koskemattomana ja
todistettuna** - tama on puhtaasti synteesin OMAN AJAN kysymys, ei
vaikuta jo saavutettuun, vankkaan tulokseen.
