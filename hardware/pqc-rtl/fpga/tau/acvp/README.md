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
