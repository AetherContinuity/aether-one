#!/usr/bin/env python3
"""M3 Release Candidate: monisiemeninen K-PKE.KeyGen-testivektorit,
SAMASSA simulaatiossa peräkkäin ajettavaksi (kayttajan oma ehdotus:
paljasta rekisterien jaanteet, reset-ongelmat, FSM:n tilavuodot jotka
yksittainen testi ei valttamatta havaitse). Kayttaa K-PKE.KeyGenia
(pienempi kuin koko ML-KEM-ketju, jo todistettu toimivaksi Issue #15:ssa) -
taydentava, RTL-tasoinen versio golden-mallin omasta 1000-syotteen
regressiosta."""

import sys
import os
import random
sys.path.insert(0, os.path.dirname(__file__))
from kpke_encrypt_golden import kpke_keygen

K_dim, ETA1 = 2, 3
N_TRIALS = 10  # RTL-simulaatioaika huomioiden - golden-mallin oma 1000-regressio jo tehty
outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")


def pack_bytes(b):
    val = 0
    for i, byte in enumerate(b):
        val |= byte << (i * 8)
    return val


random.seed(4242)

with open(os.path.join(outdir, "kpke_keygen_multiseed_vectors.txt"), "w") as f:
    f.write(f"{N_TRIALS}\n")
    for trial in range(N_TRIALS):
        d = bytes(random.randrange(256) for _ in range(32))
        z = bytes(random.randrange(256) for _ in range(32))
        ekPKE, dkPKE, A, t_hat, rho = kpke_keygen(d, K_dim, ETA1)
        ek = ekPKE
        # dk lasketaan taydellisesti Issue #15:n omalla H(ek)-kaavalla
        from keccak_golden import sha3_256
        dk = dkPKE + ek + sha3_256(ek) + z

        f.write(f"{pack_bytes(d):064x}\n")
        f.write(f"{pack_bytes(z):064x}\n")
        f.write(f"{pack_bytes(ek):x}\n")
        f.write(f"{pack_bytes(dk):x}\n")

print(f"{N_TRIALS} monisiemenista K-PKE.KeyGen-testitapausta generoitu")
