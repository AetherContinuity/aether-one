# CHANGELOG — hardware/pqc-rtl (ML-KEM, FIPS 203; TAU-kehys; ML-DSA-65)

Merkinnät uusin ensin. Jokainen kohta viittaa lähdedokumenttiin; tila- ja
rajaustiedot ovat niissä ja juuren `KORJAUSLISTA.md`:ssä.

## 2026-11-16: oletus K=3

- `pqc_tau_integrated_wrapper` ja ML-KEM-ytimet: `parameter int K = 3`.
- TAU-testipenkit (`pqc_tau_*_tb.sv`) K-parametrisia; `run_m4_tau_*.sh` ajaa
  jokaisen K=3:lla (oletus) ja K=2:lla. K=3-vektorit poimitaan NIST ACVP
  -tiedostoista (`m2-golden/gen_tau_k3_vectors.py`).
- Testipenkkikorjaus: Icarus täydentää `?:`-lausekkeen lyhyemmän
  merkkijonon NUL-tavuilla, jolloin `$fopen` epäonnistuu ja odotusarvot
  jäävät X:iksi; X === X läpäisi ek-vertailun. Tiedostonimi nyt if/else,
  `fh == 0` ja X-arvot ovat virheitä. `mlkem_acvp_tb.sv`: `$fscanf`-paluuarvot
  tarkistetaan (vajaa tiedosto toisti edellisen tapauksen ja läpäisi).
- Lähde: juuren `KORJAUSLISTA.md` (B1, D1, A12).

## 2026-11-15: ML-KEM-768 (K=3)

- Orkestrointiytimet (`pqc_mlkem_keygen_core`, `pqc_mlkem_decaps_a_core`,
  `pqc_mlkem_decaps_b1_core`, `pqc_mlkem_encaps_top`, `pqc_mlkem_decaps_top`)
  ja `pqc_tau_integrated_wrapper` parametrisoitu K:n mukaan. Oletus K=2.
- NIST ACVP: kaikki KeyGen- (25), Encaps- (25) ja Decaps-tapaukset (10),
  ML-KEM-512 ja ML-KEM-768, synteesikelpoisia ytimiä vasten
  (`run_acvp_mlkem_full.sh`, `fpga/tau/mlkem_acvp_tb.sv`). CI:ssä.
- Koko protokollaketju Wishbonen kautta K=3:lla
  (`pqc_tau_full_protocol_tb.sv`, `-P ...K=3`).
- Verilator-lint orkestrointiytimille (aiemmin kaksi `BLKLOOPINIT`-virhettä).
- Lähde: `M3_MLKEM_ACVP_STATUS.md`, juuren `KORJAUSLISTA.md` (B1, B3, D1).

## 2026-10-02: ACVP CI:hin

- `run_acvp_mlkem.sh` (KeyGen 1, Encaps 3, Decaps 5, negatiivikontrollit)
  ja `run_acvp_dilithium.sh` jokaisella pushilla. Lähde: `M3_MLKEM_ACVP_STATUS.md`.

## 2026-07-21..22: ML-KEM NIST ACVP ja Decaps-mittaukset

- ACVP KeyGen 1, Encaps 3, Decaps 5 vektoria. Decaps-syklimittaus saman
  avaimen vertailulla, toggle-mittaus (`toggle-proxy/`).
  Lähde: `M3_MLKEM_ACVP_STATUS.md`.

## 2026-07-19: M4-TAU-001, orkestrointi, ML-DSA-65 RTL

- TAU-kehys: Wishbone, audit-loki, watchdog (`M4_TAU_001_MILESTONE.md`,
  `fpga/tau/M4_TAU_001_STATUS.md`).
- Synteesikelpoinen KeyGen/Encaps/Decaps-orkestrointi
  (`fpga/tau/M4_MLKEM_ORCH_001_STATUS.md`, `M4_ENCAPS_ORCH_001_STATUS.md`,
  `M4_DECAPS_ORCH_001_STATUS.md`, `M4_TAU_FULL_PROTOCOL_MILESTONE.md`).
- ML-DSA-65 RTL: KeyGen, `Sign_internal`, `Verify_internal`
  (`dilithium-rtl/M5_DILITHIUM_KEYGEN_COMPLETE.md`, `dilithium-rtl/NIST_ACVP_STATUS.md`).

## 2026-07 (M4-FPGA-001..008)

- BRAM-inferointi (DP16KD = 4), ECP5-synteesi ja P&R NTT-ytimelle,
  Fmax 30,40 MHz (ECP5-25k). Lähde: `M4_FPGA_003_RC.md`,
  `fpga/timing_reports/M4_FPGA_006_ANALYSIS.md`.

## M3 Release Candidate 1 (2026-07-14)

Taydellinen ML-KEM-512 (FIPS 203, k=2, eta1=3, eta2=2, du=10, dv=4)
toiminnallisesti verifioituna RTL:ssa, iterative Verilog -toteutuksena.

### Valmiit kokonaisuudet

- **Keccak-p[1600,24] + sponge-kehys** (Issue #10-#11): permutaatioydin,
  pad10*1, absorbointi, puristus.
- **SHA3-256, SHA3-512, SHAKE128, SHAKE256** (Issue #12-#14): kaikki
  neljä FIPS 202 -funktiota, NIST-ankkuroitu golden-malli.
- **SampleNTT** (Issue #15): FIPS 203 Liite B huomioitu (280 iteraation
  minimiraja), C2SP/CCTV:n "unlucky"-testisiemenilla vahvistettu
  (taydellinen tasmays kolmella tunnetulla vaikealla tapauksella).
- **SamplePolyCBD** (Issue #15): taysin kombinatorinen, molemmat
  eta-arvot (2,3).
- **NTT / NTT^-1** (M2, NTT_INVERSE_DESIGN_NOTE.md): 7-tasoinen,
  4-pankkinen bankkitoteutus, jaettu datapolku molempiin suuntiin
  (mode-portti). NTT^-1:n aiempi "data-riippuvainen anomalia"
  yksiselitteisesti suljettu (testipenkin oma puuttuva skaalausvaihe,
  ei RTL-bugi, ks. commit-historia).
- **MultiplyNTTs, Compress/Decompress, ByteEncode/Decode** (Issue
  #6-#8): kaikki d-arvot (1,4,5,10,11,12).
- **K-PKE.KeyGen, K-PKE.Encrypt, K-PKE.Decrypt** (Issue #8, #15):
  kaikki kolme algoritmia itsenaisesti todennettu SEKA yhtena
  yhtenaisena Seed->KeyGen->Encrypt->Decrypt->m-round-trip-ketjuna,
  aidosti eri viestilla/satunnaisuudella kuin erillisissa testeissa.
- **ML-KEM.KeyGen_internal, Encaps_internal, Decaps_internal**
  (Issue #15): taydellinen ulompi kuori. Decaps_internal (Fujisaki-
  Okamoto-muunnos implisiittisella hylkayksella) jaettu kahteen
  RTL-testipenkkiin (TB A/B) Icarus Verilogin oman segmentointi-
  virheen valttamiseksi - kaikki kolme jaadytettya tapausta (valid,
  byte_corrupted, bit_corrupted) todennettu.

### Verifiointi (M3 RC1)

- Golden-mallin oma paastapaahan-regressio: **1000/1000** satunnaista
  (d,z,m)-syotetta, mukaan lukien yhden bitin korruptio + FO-hylkayksen
  varmistus jokaiselle.
- RTL-tason tilavuototesti: K-PKE.KeyGen ajettu **10 kertaa perakkain
  samassa simulaatiossa**, ei rekisterijaanteita/tilavuotoja.
- Verilator-lint (-Wall) kaikille rtl/*.sv-tiedostoille: **0 LATCH/
  UNDRIVEN/COMBDLY-varoitusta** koko RTL-hakemistossa.
- Yosys-synteesi (geneerinen): pqc_ntt_stage_banked ja pqc_keccak_f1600
  synteesoituvat puhtaasti, 0 virhetta.
- Taydellinen FIPS 203 -algoritmikattavuustaulukko (FIPS203_COVERAGE.md).

### Tunnetut rajaukset (dokumentoitu, ei puutteita)

- Aito TRNG-integraatio (laitteistotason satunnaislukugeneraattori
  ML-KEM.KeyGen/Encaps:n omalle satunnaisuudelle) EI viela toteutettu -
  testataan _internal-versioita, joissa satunnaisuus annetaan
  testivektorina. Oma tuleva tyokokonaisuutensa.
- ECP5-spesifinen BRAM-mappaus (aiemmin M2:ssa tunnistettu kysymys,
  ks. SYNTHESIS_NOTE.md) ei viela ratkaistu - geneerinen synteesi
  toimii, FPGA-kohdekohtainen resurssioptimointi on M4:n oma tyo.
- Vain ML-KEM-512 (k=2) parametrisarja testattu tayspitkasti - ML-KEM-
  768/1024 (k=3/4) pitaisi toimia samalla RTL:lla eri K-parametrilla,
  mutta ei viela erikseen todennettu.

## Aiemmat vaiheet

Ks. hardware/pqc-rtl/README.md ja yksittaiset design note -tiedostot
(M2_DESIGN_NOTE.md, M3_DESIGN_NOTE.md, KECCAK_DESIGN_NOTE.md,
NTT_INVERSE_DESIGN_NOTE.md, SAMPLENTT_DESIGN_NOTE.md,
M3_BYTEENCODE_DESIGN_NOTE.md, MONTGOMERY_FIX_NOTE.md) taydelliselle
historialle.
