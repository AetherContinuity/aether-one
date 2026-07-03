#!/usr/bin/env python3
"""build_model.py - kiinteapainoinen lineaarinen malli, viety RISC-V+V .so:ksi
seka golden_data.h:ksi C-harnessia varten. Ei arvattu ABI - luettu
tvm_ffi:n c_api.h/dlpack.h:sta."""
import numpy as np
import tvm
from tvm import relax
from tvm.relax.frontend import nn

np.random.seed(42)
W = np.random.randn(2, 4).astype("float32")
b = np.random.randn(2).astype("float32")
x = np.random.randn(1, 4).astype("float32")
expected = x @ W.T + b


class TinyLinear(nn.Module):
    def __init__(self):
        super().__init__()
        self.fc = nn.Linear(4, 2, bias=True)

    def forward(self, x):
        return self.fc(x)


mod = TinyLinear()
tvm_mod, _ = mod.export_tvm(spec={"forward": {"x": nn.spec.Tensor((1, 4), "float32")}})
tvm_mod = relax.transform.LegalizeOps()(tvm_mod)

# x86-referenssiajo ennen ristikaannosta - todistaa mallin logiikan
ex_local = relax.build(tvm_mod, target="llvm")
vm = relax.VirtualMachine(ex_local, tvm.cpu())
out_local = vm["forward"](tvm.runtime.tensor(x), tvm.runtime.tensor(W), tvm.runtime.tensor(b))
assert np.allclose(out_local.numpy(), expected, atol=1e-5), "x86-ajo ei tasmaa NumPyhin - pysaytetaan ennen ristikaannosta"
print(f"x86-referenssi OK: {out_local.numpy()}")

target = tvm.target.Target({"kind": "llvm", "mtriple": "riscv64-linux-gnu", "mattr": ["+v"]})
ex_riscv = relax.build(tvm_mod, target=target)
ex_riscv.export_library("model_riscv.so", cc="riscv64-linux-gnu-gcc")
print("model_riscv.so viety")


def carr(name, arr):
    flat = arr.flatten()
    return f"static float {name}[{len(flat)}] = {{" + ",".join(f"{v:.8f}f" for v in flat) + "};"


with open("golden_data.h", "w") as f:
    f.write(carr("W_DATA", W) + "\n")
    f.write(carr("B_DATA", b) + "\n")
    f.write(carr("X_DATA", x) + "\n")
    f.write(carr("EXPECTED", expected) + "\n")
print("golden_data.h kirjoitettu")
