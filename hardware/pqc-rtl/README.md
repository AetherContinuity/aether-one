# PQC RTL — NTT256 Kiihdytin (TrustCore NX -polku)

SystemVerilog RTL-prototyyppi NTT256-kiihdyttimelle.
Pi 5 toimii simulointiympäristönä ennen FPGA-siirtymää.

## Tila

| Milestone | Kuvaus | Tila |
|-----------|--------|------|
| M1 (skoopattu) | 1 NTT-taso, 16 butterflya/lane, pankkikonflikti | ✅ TODENNETTU 2026-07-02, ks. rajaus alla |
| M2 | Koko 256-pisteen NTT, monivaiheinen aikataulutin | ⛔ EI ALOITETTU |
| M3 | FPGA-prototyyppi (Pynq-Z2 / Basys 3) | Q2 2026 |
| M4 | TrustCore NX integraatio (7nm) | Q3 2026 |

**M1:n todennettu skoopin rajaus (2026-07-02):**
`rtl/pqc_rvv_cluster_2lane.sv` + `tb/pqc_cluster_m1_tb.sv` ajettu Icarus
Verilogilla, PASS kahdella eri satunnaissiemenellä, sekä negatiivikontrolli
(tahallaan rikottu golden-arvo -> testi epäonnistuu oikein, exit code 1).
Aja itse: `bash hardware/pqc-rtl/run_m1_test.sh`.

Mitä tämä TODISTAA:
- Montgomery-perhonen (`t=mont_reduce(b*zeta); a'=a+t; b'=a-t mod Q`) on
  bittitarkka Python-golden-mallia vastaan.
- Round-robin-arbitteri alternoi oikein kun kaksi lanea pyytää samaa
  pankkia (bank0) samana syklina - konflikti on aito, todennettu
  laskemalla alternointien määrä ajon aikana (≥2, tyypillisesti ~30).

Mitä tämä EI todista (tietoinen rajaus, ei piilotettu):
- Ei koko 256-pisteen NTT:tä, vain yksi taso, 16 butterflya per lane.
- Kaikki saman lanen butterflyt käyttävät SAMAA zeta-arvoa (ei per-
  butterfly-indeksointia kuten oikea 256-pisteen NTT vaatisi).
- Malli on **käyttäytymismalli (behavioral), ei synteesikelpoinen RTL**.
  Ei todista piirin ajoitusta, pinta-alaa eikä FPGA/ASIC-synteesikelpoi-
  suutta. `always_comb`/`function automatic` -rakenteet ja hierarkkinen
  suora muistiosoitus eivät sellaisenaan synteesoidu.
- Edellisen session testipenkki (`pqc_cluster_verified_tb.sv`, ei tässä
  repossa) hylättiin: sen oma osoitelaskenta oli sisäisesti ristiriitainen
  (base_addr_lane1=16 vs. data sijoitettu osoitteisiin 32-63). Tämä on
  uusi, itsekonsistentti pari - DUT ja testipenkki kirjoitettu yhdessä.

Seuraava askel M2:een: tuo `idx` ulos `lane_fsm`:sta jotta per-butterfly-
zeta-indeksointi on mahdollinen, laajenna yhdestä NTT-tasosta kahdeksaan
(level 7..0, Cooley-Tukey), lisää oikea pankinvalinta osoitteesta neljälle
pankille (tässä versiossa aina bank0).

## Arkkitehtuuri (M1-skoopissa toteutettu)

- Montgomery-reduktio (behavioral, ei pipelinoitu)
- Yksi jaettu pankki (bank0), round-robin-arbitroitu 2 lanen kesken
- 2-lane FSM: IDLE → REQ_READ → COMPUTE → REQ_WRITE → (seuraava/DONE)

## Toolchain

- Icarus Verilog 12.0 (testattu tässä ympäristössä, ei vielä Pi5:llä)
- Python `gen_vectors.py` → `.memh` → SV-testipenkki

## Yhteys TrustCore NX:ään

NTT256 on Kyber/Dilithium PQC-operaatioiden ydin.
Tämä RTL siirtyy suoraan TrustCore NX ASIC:iin — synteesikelpoisen
uudelleenkirjoituksen jälkeen (M3/M4).


