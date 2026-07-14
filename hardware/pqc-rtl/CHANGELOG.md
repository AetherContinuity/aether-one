# CHANGELOG — hardware/pqc-rtl (M3: ML-KEM-512, FIPS 203)

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
