# TVM → RISC-V — kiinteapainoinen lineaarikerros (koeversio)

## Mitä tämä TODISTAA

`build_model.py` rakentaa yhden Dense-kerroksen (y = xW^T + b) TVM Relax
-mallina, todistaa sen oikeaksi x86:lla NumPy-referenssiä vastaan, ja
ristikääntää sen RISC-V+V-kohteelle (`llvm -mtriple=riscv64-linux-gnu
-mattr=+v`). Tulos on aito RISC-V-ELF (todennettu `file`-komennolla:
"UCB RISC-V, RVC, double-float ABI").

`harness.c` kutsuu käännetyn `.so`:n vientisymboleita (`__tvm_ffi_transpose`,
`__tvm_ffi_matmul`, `__tvm_ffi_add`) suoraan `TVMFFISafeCallType`-ABI:lla —
**ei TVM-runtimea**, koska sitä ei ole cross-käännetty RISC-V:lle. ABI on
luettu asennetun `tvm_ffi`-paketin `include/tvm/ffi/c_api.h` ja
`include/dlpack/dlpack.h` -tiedostoista, ei arvattu.

Todennettu:
- Kutsukäytäntö: `(void* handle, TVMFFIAny* args, int32_t num_args, TVMFFIAny* result)`,
  ulostulo on osa `args`-taulukkoa (in-out-tyyli), ei erillinen paluuarvo.
  Tämä hypoteesi testattiin ensin x86:lla ennen RISC-V-porttausta.
- Koko ketju (transpose → matmul → add) PASS QEMU:ssa golden-arvoja vastaan.
- Negatiivikontrolli: rikottu odotusarvo -> FAIL, exit 1.

Aja itse: `bash run_tvm_test.sh`.

## Mitä tämä EI todista (tietoinen rajaus)

- **Ei ole ASIC/FPGA/oikea RISC-V-rauta.** QEMU-emulaatio, ei sykkitarkka.
- **Ei koko TVM-runtimea RISC-V:llä.** Vain kolme yksittäistä compute-kernelia
  kutsuttu suoraan raaka-ABI:lla, ei `relax.VirtualMachine`-tason ajoa,
  ei moduulien latausta/rekisteröintiä, ei muistinhallintaa TVM:n omalla
  allokaattorilla.
- **Yksi pieni malli** (4->2 lineaarinen kerros), ei mikään oikea
  sensorimalli tai ML-putki jota Aether One -paketeissa mainitaan
  (`hello_sensor_tvm.py` — sen `model_arm.so`/`model_graph.json`/
  `model_params.bin` ovat yhä tyhjiä tiedostoja, ei koskettu tässä).
- **TVM-FFI-ABI on version 0.25 mukainen.** Voi muuttua TVM:n
  seuraavissa versioissa (ABI on jo muuttunut kerran aiemmasta
  PackedFunc-mallista, dokumentoitu tässä READMEssa löytöhetkellä).

## Toolchain

```
pip install apache-tvm
riscv64-linux-gnu-gcc -O2 harness.c -o harness_riscv -L. -l:model_riscv.so -Wl,-rpath,'$ORIGIN'
qemu-riscv64-static -L /usr/riscv64-linux-gnu -E LD_LIBRARY_PATH=. ./harness_riscv
```

## Seuraava askel jos jatketaan

TVM:n C-runtime (`libtvm_runtime`) ristikäännettynä RISC-V:lle mahdollistaisi
oikean `.so`-latauksen ja moduulikutsun sen sijaan että kutsutaan yksittäisiä
kerneleitä suoraan. Isompi työ, ei tehty tassa.
