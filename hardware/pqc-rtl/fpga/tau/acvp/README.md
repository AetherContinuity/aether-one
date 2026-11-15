# NIST ACVP -vektorit CI-regressiolle (ML-KEM-512 Encaps)

`encaps_tc1.txt`, `encaps_tc2.txt`, `encaps_tc3.txt`: testiryhma tgId=1
(ML-KEM-512, encapsulation), tcId=1..3.

**Lahde:** `usnistgov/ACVP-Server`, commit
`975de31eb83d87039ec88934fdc47d8c312b892d`, tiedosto
`gen-val/json-files/ML-KEM-encapDecap-FIPS203/internalProjection.json`
(sha256 `a556952ce869bb89c3a3196a701dad89647c193a34c86eafb61a9d710d5b810f`),
haettu 2026-10-02.

**Generointi:**
`python3 m2-golden/gen_mlkem_nist_encaps_vector.py <tcId> <json> fpga/tau/acvp/encaps_tc<tcId>.txt`

**Muoto** (yksi heksaluku per rivi, little-endian pakattu): `ek`, `m`,
odotettu `K`, odotettu `c`.

**Huomio aiemmista vektoreista.** NIST:n `encapDecap`-esimerkkitiedosto
(`"isSample": true`) on generoitu uudelleen heinakuun 2026 jalkeen:
repossa ennestaan olevia `../encaps_top_nist_vector.txt`- ja
`../decaps_top_nist_vectors.txt`-vektoreita ei loydy ylla mainitun
commitin tiedostosta. Niiden lahdecommitia ei ole kirjattu (juuren
`KORJAUSLISTA.md` A10). KeyGen-vektori
(`../../../vectors/mlkem_keygen_nist_vector.txt`) vastaa saman commitin
`ML-KEM-keyGen-FIPS203`-tiedoston tcId=1:ta.

## Taydet vektorisarjat (lisatty 2026-11-15)

`{keygen,encaps,decaps}_{512,768}.txt`: kaikki NIST:n ML-KEM-512- ja
ML-KEM-768-tapaukset samasta commitista (975de31): keyGen tgId 1/2
(25 + 25), encapsulation tgId 1/2 (25 + 25), decapsulation tgId 4/5
(10 + 10).

**Generointi:**
`python3 m2-golden/gen_mlkem_acvp_vectors.py ML-KEM-768 <keyGen.json> <encapDecap.json> fpga/tau/acvp`

Generaattori ajaa jokaisen tapauksen golden-mallin lapi ja keskeytyy, jos
tulos poikkeaa NIST:sta. `run_acvp_mlkem_full.sh <sarja> --verify-source`
toistaa generoinnin kiinnitetysta lahteesta ja vertaa tiedostoihin.

**Muoto:** ensimmainen rivi = tapausmaara. Per tapaus:
- keygen: `tcId`, d, z, ek, dk
- encaps: `tcId`, ek, m, K, c
- decaps: `tcId hylkays`, dk, c, K (hylkays = 1, jos NIST:n reason on
  "modified ciphertext")
