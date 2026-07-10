# PQC RTL — NTT256 Kiihdytin (TrustCore NX -polku)

SystemVerilog RTL-prototyyppi NTT256-kiihdyttimelle.
Pi 5 toimii simulointiympäristönä ennen FPGA-siirtymää.

## Tila

| Milestone | Kuvaus | Tila |
|-----------|--------|------|
| M1 (skoopattu) | 1 NTT-taso, 16 butterflya/lane, pankkikonflikti | ✅ TODENNETTU 2026-07-02, ks. rajaus alla |
| M2 Vaihe 1 | Per-butterfly zeta-indeksointi | ✅ TODENNETTU 2026-07-10, ks. rajaus alla |
| M2 Vaihe 2 | Koko Kyber-NTT (7 tasoa, 128 lehteä) + BaseCaseMultiply, ks. [M2_DESIGN_NOTE.md](M2_DESIGN_NOTE.md) | ⛔ EI ALOITETTU |
| M2 Vaihe 3 | Neljä muistipankkia, oikea osoitus, konfliktinhallinta | ⛔ EI ALOITETTU |
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

**M2 Vaihe 1:n todennettu skoopin rajaus (2026-07-10):**
`idx` viety ulos `lane_fsm`:sta uutena output-porttina (`idx_out`),
kumpikin lane indeksoi jaettua `tw_window`-taulukkoa OMALLA idx-arvollaan
kiinteän `tw_window[0]`:n sijaan. Sama toolchain, sama
`run_m1_test.sh`. PASS kahdella eri satunnaissiemenella, plus KAKSI
negatiivikontrollia:
1. Tahallaan rikottu golden-arvo -> FAIL oikein (peritty M1:sta).
2. **Uusi:** tahallaan palautettu vanha `tw_window[0]`-kytkentä (M1:n
   rajaus) -> testi FAILaa oikein 61 virheella, ja testipenkin oma
   negatiivikontrolli tunnistaa tarkalleen syyn ("tulos tasmaa TAYSIN
   idx0-only-vaaraan ennusteeseen"). Todistaa etta per-butterfly-
   indeksointi OIKEASTI vaikuttaa tulokseen, ei vain etta koodi kaantyy.

Mitä M2 Vaihe 1 TODISTAA (M1:n lisaksi):
- Kumpikin lane käyttää OMAA per-butterfly-zetaansa (16 eri zeta-arvoa,
  ei enää yhtä yhteistä), bittitarkasti Python-golden-mallia vastaan.
- Vaarin-indeksoinnin negatiivikontrolli: jos RTL indeksoisi vain
  `tw_window[0]`:aa (M1:n vanha kayttays), 68/128 sanaa tasmaisi silti
  sattumalta vaaraan ennusteeseen mutta EI kaikki 128 - testi erottaa
  taman oikeasta kaytoksesta oikein molemmissa suunnissa.

Mitä tämä EI todista (tietoinen rajaus, ei piilotettu):
- Ei koko 256-pisteen NTT:tä, vain yksi taso, 16 butterflya per lane.
- Lane0 ja lane1 kayttavat SAMAA tw_window-taulukkoa SAMALLA idx-arvolla
  (molemmat butterfly-indeksit 0..15 per lane kayttavat tw_window[sama
  idx]) - tama ei viela mallinna oikean 256-pisteen NTT:n globaalia
  butterfly-asemointia, jossa eri lanet kasittelisivat eri butterfly-
  alueita eri zetoilla. Tama on M2 Vaihe 2:n laajuus.
- Malli on **käyttäytymismalli (behavioral), ei synteesikelpoinen RTL**.
  Ei todista piirin ajoitusta, pinta-alaa eikä FPGA/ASIC-synteesikelpoi-
  suutta. `always_comb`/`function automatic` -rakenteet ja hierarkkinen
  suora muistiosoitus eivät sellaisenaan synteesoidu.
- Edellisen session testipenkki (`pqc_cluster_verified_tb.sv`, ei tässä
  repossa) hylättiin: sen oma osoitelaskenta oli sisäisesti ristiriitainen
  (base_addr_lane1=16 vs. data sijoitettu osoitteisiin 32-63). Tämä on
  uusi, itsekonsistentti pari - DUT ja testipenkki kirjoitettu yhdessä.

Seuraava askel M2 Vaihe 2:een: **KORJATTU 2026-07-10, ks.
[M2_DESIGN_NOTE.md](M2_DESIGN_NOTE.md).** Alkuperäinen suunnitelma
("8 tasoa, 256 pistetta, Cooley-Tukey") oli matemaattisesti ristiriidassa
Kyberin oman rakenteen kanssa - Kyberin Q=3329:lla ei ole primitiivista
512. yksikönjuurta (3328/512=6,5, ei kokonaisluku), joten NTT pysähtyy
7 tasoon (128 lehteä, asteen-2 polynomeja) ja vaatii BaseCaseMultiply-
vaiheen pistetulolle. Oikea suunnitelma: laajenna 7 tasoon (level 6..0),
toteuta oikea globaali butterfly-asemointi
molemmille laneille eri zeta-alueilla. Sama testifilosofia (golden-malli
+ RTL + bittitarkka vertailu + positiivinen testi + negatiivikontrolli).
Vasta tämän jälkeen M2 Vaihe 3 (neljä pankkia, oikea osoitus,
konfliktinhallinta) - laskennan pitää olla todistetusti oikein ennen
muistiosajärjestelmän monimutkaistamista, jotta virheen lähde
(matematiikka vs. muistiohjaus) pysyy erotettavissa.

## Arkkitehtuuri (M1 + M2 Vaihe 1 -skoopissa toteutettu)

- Montgomery-reduktio (behavioral, ei pipelinoitu)
- Yksi jaettu pankki (bank0), round-robin-arbitroitu 2 lanen kesken
- Per-butterfly zeta-indeksointi jaetusta tw_window-taulukosta (M2 Vaihe 1)
- 2-lane FSM: IDLE → REQ_READ → COMPUTE → REQ_WRITE → (seuraava/DONE)

## Toolchain

- Icarus Verilog 12.0 (testattu tässä ympäristössä, ei vielä Pi5:llä)
- Python `gen_vectors.py` → `.memh` → SV-testipenkki

## Yhteys TrustCore NX:ään

NTT256 tässä käyttää Kyberin (ML-KEM) 16-bittistä Montgomery-reduktiota
(Q=3329). **Ei ML-DSA/Dilithium** — Dilithiumin Montgomery on 32-bittinen
(Q=8380417, R=2^32). Dual-Pi-protolle (ML-DSA-65-allekirjoitus) tämä M1/
M2 Vaihe 1 ei kelpaa sellaisenaan (sama Kyber-parametrisointi molemmissa);
tarvitaan erillinen 32-bittinen Dilithium-Montgomery
(ks. hardware/pqc-rtl/rvv/README.md).
Tämä RTL siirtyy suoraan TrustCore NX ASIC:iin — synteesikelpoisen
uudelleenkirjoituksen jälkeen (M3/M4).


