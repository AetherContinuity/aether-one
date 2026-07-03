# RVV-kiihdytys — Montgomery-reduktio (koeversio)

## Mitä tämä TODISTAA

`mont_rvv.c` laskee Kyber-tyylisen Montgomery-reduktion RISC-V Vector
-intrinsiceillä, 8 arvoa rinnakkain. Todennettu:

- Bittitarkka Python-golden-mallia vastaan (`gen_vectors.py`, sama Q/QINV
  kuin RTL M1:ssä ja `wem_bridge`:ssä).
- Negatiivikontrolli: rikottu odotusarvo -> FAIL, exit 1.
- **VLEN-riippumaton.** Sama binääri ajettu kahdesti, VLEN=256:lla ja
  QEMU:n oletuksella VLEN=128:lla — molemmat 8/8. Silmukka (`i += vl`)
  käsittelee kumman tahansa rekisterileveyden oikein.

Ristikäännetty `riscv64-linux-gnu-gcc`:llä, ajettu `qemu-riscv64-static`:lla.
Aja itse: `bash run_rvv_test.sh`.

## Mitä tämä EI todista (tietoinen rajaus)

- **Ei ole ASIC/FPGA-rauta.** QEMU on TCG-emulaattori, ei sykkitarkka
  malli. Ei todista suorituskykyä, virrankulutusta eikä ajoitusta.
- **Ei koko liboqsin RVV-porttausta.** Yksi funktio (Montgomery-reduktio),
  ei koko Kyber/Dilithium-primitiivijoukkoa.
- **Ei sido tätä `oqs_rvv_provider/provider.c`:hen.** Se on yhä 4-rivinen
  stubi (`AetherOne_Platform_v1_0_FullInstaller`-paketista, ei tässä
  repossa). Tämä koodi on rakennuspalikka jolle provider voisi perustua,
  ei itse provider.
- **VLEN=256/128 ovat QEMU:n emuloimia arvoja**, ei mitatusta oikeasta
  RVV-raudasta (esim. SiFive P670, VLEN=256 natiivisti). Emuloitu oikein
  toimiva koodi ei takaa oikeaa toimintaa fyysisellä piirillä, mutta
  vähentää riskiä koska logiikka ei ole VLEN-spesifistä.

## Löydetty sudenkuoppa (dokumentoitu, jotta ei toistu)

Ensimmäinen käännös/ajo ilman silmukointia (`__riscv_vsetvl_e32m1(8)`
kerran, ei toistettuna) läpäisi hiljaa väärin QEMU:n oletus-VLEN=128:lla:
`vl` palautui arvolla 4, koodi käsitteli vain neljä ensimmäistä elementtiä
kahdeksasta, loput jäivät nollaksi ilman virhettä. Korjaus: `while`-silmukka
`i += vl`, standardi RVV-stripmining-kuvio. Ilman golden-vektorivertailua
tämä bugi ei olisi näkynyt — output "näytti" järkevältä (ensimmäiset neljä
lukua olivat oikein).

## Toolchain

```
riscv64-linux-gnu-gcc -march=rv64gcv -O2 mont_rvv.c -o mont_rvv
qemu-riscv64-static -cpu rv64,v=true,vlen=256,elen=64 -L /usr/riscv64-linux-gnu ./mont_rvv
```
