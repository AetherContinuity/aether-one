# TAU baseline v1.0

**Päiväys:** 2026-11-16. **Kattaa:** main-haaran tilan PR #31:n (B4) yhdistämisen jälkeen.
Sisältö-commit: `72b61bd` (haara `b4-budjetti`), jonka päälle tämä tiedosto lisättiin.

Tämä on jäädytetty tilannekuva, ei elävä dokumentti. Elävät dokumentit ovat
`README.md` ja `KORJAUSLISTA.md`; tätä tiedostoa ei päivitetä, vaan seuraava
baseline on uusi tiedosto.

Jokainen väite alla viittaa todisteeseen (CI-job tai tiedosto). Jos väite ja
todiste ovat ristiriidassa, todiste on oikeassa.

## A. Algoritminen oikeellisuus

| Väite | Todiste |
|---|---|
| ML-KEM-512 ja ML-KEM-768 (oletus K=3): synteesikelpoiset KeyGen-, Encaps- ja Decaps-ytimet täsmäävät kaikkiin NIST ACVP -tapauksiin (25 + 25 + 10 per sarja) | CI `test-pqc-rtl-acvp-mlkem-full` (512, 768); `run_acvp_mlkem_full.sh` generoi vektorit uudelleen NIST:n commitista 975de31 ja vaatii tavutason yhtäsuuruuden; negatiivikontrollit: turmeltu ja vajaa tiedosto |
| Golden-malli (`m2-golden/mlkem_golden.py`) täsmää samoihin 120 tapaukseen | `m2-golden/gen_mlkem_acvp_vectors.py` keskeytyy, jos ei |
| TAU-kehys (Wishbone, audit-loki, watchdog) ajaa KeyGen → Encaps → Decaps -ketjun | CI `run_m4_tau_*` (8 testiä, K=3 ja K=2) |
| ML-DSA-65 RTL: KeyGen, `Sign_internal`, `Verify_internal` | CI `test-pqc-rtl-acvp-dilithium`; **yksi** NIST-vektori per operaatio (KORJAUSLISTA C1) |
| ML-KEM-1024 (K=4) | Kääntyy, **ei todennettu** |

## B. RTL:n ajallinen käyttäytyminen

| Väite | Todiste |
|---|---|
| Decaps on syklitasolla vakioaikainen s:n, z:n ja c:n sisällön suhteen (RTL-simulaatio, 20 NIST-avainta, K=2 ja K=3) | `hardware/pqc-rtl/sivukanava/B8-ENNAKKO.md` (ennen mittausta), `B8-TULOS.md`; CI `test-pqc-rtl-b8-sivukanava` |
| Mittari havaitsee kolme tarkoituksella lisättyä vuotoa | `sivukanava/b8_negkontrollit.sh`, sama CI-job |
| Valintamekanismi ei lisää bittikytkentää valitun ehdokkaan päälle (yksi rekisteri) | B8 H4 |
| Avainten välinen syklivaihtelu on julkisesta datasta | **Tulkinta, ei testattu** (B8 H3) |

## C. Laitteistototeutuksen kelpoisuus

| Väite | Todiste |
|---|---|
| NTT-ydin: ECP5-synteesi ja P&R, Fmax 30,40 MHz (LFE5U-25F) | `hardware/pqc-rtl/fpga/timing_reports/` |
| ML-KEM-orkestrointi **ei mahdu** ECP5:lle nykyisellä arkkitehtuurilla: `decaps_a_core` 82 330 FF-bittiä (Yosys), koko kehys arviolta ≈ 685 000; 25F 24 288, 85F 83 640 FF | `hardware/pqc-rtl/b4/B4-ENNAKKO.md`, `B4-TULOS.md` |
| ML-DSA:n ylätason synteesi | **Ei tehty** (C3, C4) |
| Fyysinen FPGA-ajo | **Ei tehty** (B6) |

## D. Luottamusankkurin kokonaisuus

| Väite | Todiste |
|---|---|
| Pi-prototyyppi: Trust Server allekirjoittaa ML-DSA-65:llä ohjelmistona (liboqs), TPM+PQC-päästä-päähän ohjelmisto-TPM:llä | `README.md`, CI |
| RTL-ytimiä ei ole kytketty Pi-pinoon | KORJAUSLISTA D3 |
| TRNG | **Puuttuu** (B2) |
| Teho-/EM-sivukanavat | **Ei mitattu** (B7) |
| ML-DSA TAU-kehyksessä | **Ei** (C5); viestipuskuri 136 tavua (C2) |

## Testauksen luotettavuus

- Testipenkkien väärät PASSit (X === X, vajaa vektoritiedosto) löydettiin ja korjattiin 2026-11-16.
- 138 testipenkkiä avaa tiedostoja tarkistamatta kahvaa (A13). CI ajaa `vvp`:n kääreen kautta, joka epäonnistuu tiedostovirheestä; ilman käärettä ajettaessa testit ovat yhä alttiita.

## Arvioijalle

Älä nojaa tähän tiedostoon. Tarkista väitteet todisteista: koodi, testipenkit,
CI-lokit (`.github/workflows/verify.yml`, Actions-historia) ja ennakkorekisteröintien
commit-järjestys (`git log -- hardware/pqc-rtl/sivukanava hardware/pqc-rtl/b4`).
Erityisen arvokasta: väitteet, joita mikään testi ei pystyisi kumoamaan, ja vuoto-
tai virheluokat, joita B8:n mittari ei havaitsisi.
