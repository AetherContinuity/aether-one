#!/usr/bin/env python3
"""M3-MLKEM-002: ACVP encapDecap-FIPS203 Decaps -> decaps_top_nist_
vectors.txt (usea tapaus). Jokainen tapaus luokitellaan valid/
rejection RIIPPUMATTOMASTI Pythonin omalla c'==c-laskennalla (EI
luoteta pelkkaan JSON:n 'reason'-kenttaan, vaikka se onkin
vahvistettu tasmaavaksi - ks. M3_MLKEM_ACVP_STATUS.md)."""

import json
import sys
sys.path.insert(0, '.')
from keccak_golden import sha3_512, shake256
from kpke_encrypt_golden import kpke_encrypt
from mlkem_golden import kpke_decrypt

K_dim, ETA1, ETA2, DU, DV = 2, 3, 2, 10, 4
DK_LEN, C_LEN, K_LEN = 1632, 768, 32

def pack_bytes(b):
    v = 0
    for i, byte in enumerate(b):
        v |= byte << (i * 8)
    return v

def classify_and_check(dk, c, k_expect):
    dkPKE = dk[0:384*K_dim]
    ekPKE = dk[384*K_dim:768*K_dim+32]
    h = dk[768*K_dim+32:768*K_dim+64]
    z = dk[768*K_dim+64:768*K_dim+96]

    m_prime = kpke_decrypt(dkPKE, c, K_dim, DU, DV)
    G_out = sha3_512(m_prime + h)
    K_prime, r_prime = G_out[:32], G_out[32:]
    K_bar = shake256(z + c, 32)
    c_prime, _, _ = kpke_encrypt(ekPKE, m_prime, r_prime, K_dim, ETA1, ETA2, DU, DV)

    rejection = (c != c_prime)
    K_final = K_bar if rejection else K_prime
    assert K_final == k_expect, "K ei tasmaa golden-malliin - pysaytetaan ennen RTL-vaihetta"
    return rejection

def main(tc_ids):
    with open('/home/claude/acvp-server/gen-val/json-files/'
              'ML-KEM-encapDecap-FIPS203/internalProjection.json') as f:
        d = json.load(f)

    tests_by_id = {}
    for tg in d['testGroups']:
        if tg['tgId'] == 4:
            for t in tg['tests']:
                tests_by_id[t['tcId']] = t
            break

    with open("fpga/tau/decaps_top_nist_vectors.txt", "w") as f:
        f.write(f"{len(tc_ids)}\n")  # otsikkorivi: vektorien maara
        for tc_id in tc_ids:
            t = tests_by_id[tc_id]
            dk = bytes.fromhex(t['dk'])
            c = bytes.fromhex(t['c'])
            k_expect = bytes.fromhex(t['k'])

            assert len(dk) == DK_LEN, f"tcId={tc_id}: dk pituus vaara"
            assert len(c) == C_LEN, f"tcId={tc_id}: c pituus vaara"
            assert len(k_expect) == K_LEN, f"tcId={tc_id}: k pituus vaara"

            rejection = classify_and_check(dk, c, k_expect)
            reason = t['reason']
            independent_label = "rejection" if rejection else "valid"
            match = (("modified" in reason.lower() and rejection) or
                     ("valid" in reason.lower() and not rejection))
            assert match, f"tcId={tc_id}: JSON:n reason ('{reason}') ja riippumaton luokka ('{independent_label}') RISTIRIIDASSA"

            f.write(f"{tc_id} {1 if rejection else 0}\n")
            f.write(f"{pack_bytes(dk):0{DK_LEN*2}x}\n")
            f.write(f"{pack_bytes(c):0{C_LEN*2}x}\n")
            f.write(f"{pack_bytes(k_expect):0{K_LEN*2}x}\n")
            print(f"tcId={tc_id}: luokka={independent_label} (reason='{reason}', tasmaa: {match})")

if __name__ == "__main__":
    # Oletus: kaksi valid + kolme rejection (priorisoitu suunnitelman
    # mukaisesti hylkayspolkuja)
    tc_ids = [int(x) for x in sys.argv[1:]] if len(sys.argv) > 1 else [76, 79, 77, 78, 80]
    main(tc_ids)
