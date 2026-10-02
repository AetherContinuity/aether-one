# Aether One™ — Roadmap

**Päivitetty:** 2026-10-02. Tila osittain: `README.md`. Avoimet kohdat: `KORJAUSLISTA.md`.

Rasti tarkoittaa, että työ on tehty ja todennus on kirjattu repoon. Se ei tarkoita,
että osa olisi valmis käyttöön.

## Taso 1: Pi-prototyyppi

- [x] Pi 2 Trust Server: attestaatio, ML-DSA-65 (liboqs)
- [x] Pi 5 Edge Node: KRI/LR, web-käyttöliittymä, drift-näkymät, sensoriajurit
- [x] TPM-attestaatio ohjelmisto-TPM:llä (swtpm) CI:ssä
- [ ] `liboqs-python` asennusskripteihin (KORJAUSLISTA A1)
- [ ] C-ydin (`libtrustcore.so`) — ei repossa
- [ ] Mittaukset fyysisillä laitteilla (latenssi, kuorma)

## Taso 2: RTL ja FPGA

ML-KEM-512:

- [x] M1–M2: NTT256, 4-pankkinen muisti, SAT-todistus
- [x] M3: koko ML-KEM-512 (`_internal`) ja Keccak/SHA-3-perhe RTL:nä, 2026-07-14
- [x] M4-FPGA-001..008: NTT-ytimen ECP5-synteesi ja P&R, BRAM-inferointi, Fmax 30,40 MHz
- [x] M4-SoC-001: Wishbone-kääre NTT-ytimelle
- [x] M4-TAU-001: TAU-kehys (Wishbone, audit-loki, watchdog), 2026-07-19
- [x] M4-ORCH: KeyGen-, Encaps- ja Decaps-orkestrointi TAU-kehyksessä
- [x] NIST ACVP: KeyGen 1, Encaps 3, Decaps 5 vektoria, 2026-07-21
- [x] Decaps: syklitason ajoitusmittaus ja toggle-mittaus, 2026-07-22
- [ ] Koko ML-KEM-ytimen synteesi ja P&R (Keccak-instanssien jakaminen)
- [ ] ACVP-testit CI:hin
- [ ] TRNG
- [ ] ML-KEM-768/1024
- [ ] Ajo fyysisellä FPGA-laudalla

ML-DSA-65 (M5-DILITHIUM-001, issue #17):

- [x] KeyGen, `Sign_internal`, `Verify_internal` RTL:nä, `dilithium-py`-todennettu
- [x] NIST ACVP: yksi vektori per operaatio
- [x] Rakennuspalikoiden synteesi yksitellen
- [ ] `MAX_BLOCKS`: yli 136 tavun viestit
- [ ] Lisää ACVP-vektoreita (Signin yksikierroksinen tapaus, sigVer `testPassed=True`)
- [ ] Päätason synteesi, ECP5 P&R, Fmax
- [ ] TAU-kehysintegraatio

RISC-V-ohjelmisto:

- [x] `rvv-dilithium/`: ML-DSA-65 C + RVV, QEMU
- [x] `rvv/`: ML-KEM:n Montgomery-reduktio RVV:llä (yksi funktio)
- [x] `tvm-riscv/`, `oqs-rvv-provider/`: kokeilut, ajo QEMU:ssa
- [ ] ML-KEM:n muu RVV-optimointi

Ratkaistava ennen ML-DSA-työn laajentamista:

- [ ] Turvatasojen epäsuhta ML-KEM-512 / ML-DSA-65 (KORJAUSLISTA D1)

## Taso 3–4: konseptit, ei työn alla

Seuraavat ovat `concept/`-kansion tavoitetiloja. Niille ei ole työpakettia, aikataulua
eikä rahoitusta, eikä nykyinen suunta (`PROJECT_STATUS_AND_DIRECTION.md`: tutkimusprototyyppi)
tähtää niihin.

- TrustCore NX: oma RISC-V-SoC, suurempi FPGA-kohde (Versal / Agilex), gate-level, ASIC
- Patentti
- Fyysinen laite, valmistuskumppani
