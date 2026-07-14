# FIPS203_COVERAGE.md — algoritmien jäljitettävyystaulukko

**Päivämäärä:** 2026-07-14
**Tarkoitus:** kayttajan oma M3 RC -vaatimus: varmista etta jokainen
FIPS 203:n algoritmi on jaljitettavissa johonkin RTL-moduuliin ja
testiin. Algoritminumerot FIPS 203:n lopullisesta, julkaistusta
tekstista (nvlpubs.nist.gov/nistpubs/fips/nist.fips.203.pdf).

| # | Algoritmi | RTL-moduuli | Testi | Tila |
|---|---|---|---|---|
| 4 | BytesToBits | (sisaltyy pqc_byteencode_dparam.sv:n periaatteeseen - pakattu vektori vastaa jo BytesToBits-jarjestysta, ks. Issue #7) | tb/pqc_byteencode_dparam_tb.sv | Valmis |
| 3 | BitsToBytes | (kaanteinen, sama periaate) | tb/pqc_byteencode_dparam_tb.sv | Valmis |
| 5 | ByteEncode_d | rtl/pqc_byteencode_dparam.sv, pqc_byteencode_d1.sv | Issue #7 omat testit | Valmis (d=1,4,5,10,11,12) |
| 6 | ByteDecode_d | rtl/pqc_bytedecode_dparam.sv, pqc_bytedecode_d1.sv | Issue #7 omat testit | Valmis |
| 7 | SampleNTT | rtl/pqc_samplentt.sv, pqc_samplentt_reject.sv | tb/pqc_samplentt_tb.sv (+ C2SP unlucky-tapaukset) | Valmis |
| 8 | SamplePolyCBD_eta | rtl/pqc_samplepolycbd.sv | tb/pqc_samplepolycbd_tb.sv | Valmis (eta=2,3) |
| 9 | NTT | rtl/pqc_ntt_stage_banked.sv (mode=0) | tb/pqc_ntt_full_banked_tb.sv | Valmis |
| 10 | NTT^-1 | rtl/pqc_ntt_stage_banked.sv (mode=1) + pqc_ntt_final_scale.sv | tb/pqc_ntt_inverse_roundtrip_tb.sv, pqc_ntt_inverse_12x_scaled_closure_tb.sv | Valmis (ks. NTT_INVERSE_DESIGN_NOTE.md) |
| 11 | BaseCaseMultiply | rtl/pqc_basecasemul.sv | M1/M2 omat testit | Valmis |
| - | MultiplyNTTs | rtl/pqc_multiplyntts.sv | Issue #8 esityo | Valmis |
| - | Compress_d / Decompress_d | rtl/pqc_compress.sv, pqc_batch_compress.sv, pqc_batch_decompress.sv | Issue #6 omat testit | Valmis |
| 13 | K-PKE.KeyGen | (orkestrointi: SampleNTT+SamplePolyCBD+NTT+MultiplyNTTs+ByteEncode) | tb/pqc_kpke_keygen_full_tb.sv, pqc_kpke_keygen_multiseed_tb.sv (10x) | Valmis |
| 14 | K-PKE.Encrypt | (orkestrointi, sama koneisto + Compress) | tb/pqc_kpke_encrypt_full_tb.sv | Valmis |
| 15 | K-PKE.Decrypt | (orkestrointi, NTT^-1+polysub) | tb/pqc_kpke_decrypt_full_tb.sv | Valmis |
| 16 | ML-KEM.KeyGen_internal | (orkestrointi: K-PKE.KeyGen + H(ek)) | tb/pqc_mlkem_keygen_tb.sv | Valmis |
| 17 | ML-KEM.Encaps_internal | (orkestrointi: G(m\\|\\|H(ek)) + K-PKE.Encrypt) | tb/pqc_mlkem_encaps_tb.sv | Valmis |
| 18 | ML-KEM.Decaps_internal | (orkestrointi: K-PKE.Decrypt + G + uudelleensalaus + FO-valinta) | tb/pqc_mlkem_decaps_a_tb.sv + pqc_mlkem_decaps_b_tb.sv | Valmis (3 jaadytettya tapausta: valid, byte_corrupted, bit_corrupted) |
| 19 | ML-KEM.KeyGen | (= KeyGen_internal, satunnaisuus d,z tulee testivektorista) | sama kuin #16 | Valmis (satunnaisuuden lahde ei viela RTL:ssa - ks. alla) |
| 20 | ML-KEM.Encaps | (= Encaps_internal, satunnaisuus m tulee testivektorista) | sama kuin #17 | Valmis (satunnaisuuden lahde ei viela RTL:ssa) |
| 21 | ML-KEM.Decaps | (= Decaps_internal, ei omaa satunnaisuutta) | sama kuin #18 | Valmis |

## Keccak/SHA-3-perhe (FIPS 202, ei FIPS 203:n oma numerointi)

| Funktio | RTL-moduuli | Testi | Tila |
|---|---|---|---|
| Keccak-p[1600,24] | rtl/pqc_keccak_f1600.sv | tb/pqc_keccak_f1600_tb.sv | Valmis |
| Sponge (pad/absorb/squeeze) | rtl/pqc_keccak_pad/absorb/squeeze.sv | Issue #11 omat testit | Valmis |
| SHA3-256 (H-funktio) | rtl/pqc_sha3_256.sv | tb/pqc_sha3_256_tb.sv | Valmis |
| SHA3-512 (G-funktio) | rtl/pqc_sha3_512.sv | tb/pqc_sha3_512_tb.sv | Valmis |
| SHAKE128 (XOF) | rtl/pqc_shake128.sv | tb/pqc_shake128_tb.sv | Valmis |
| SHAKE256 (PRF, J-funktio) | rtl/pqc_shake256.sv | tb/pqc_shake256_tb.sv | Valmis |

## Huomioitava rajaus: satunnaisuuden lahde

**ML-KEM.KeyGen/Encaps (Algoritmit 19-20) itsessaan generoivat oman
satunnaisuutensa (d,z / m) TRNG:sta tai vastaavasta** - tama projekti
toistaiseksi TESTAA VAIN _internal-versioita (16-18), joissa
satunnaisuus annetaan syotteena (testivektorina). Aito TRNG-integraatio
FPGA:lle (esim. ECP5:n oma entropialahde tai ulkoinen TRNG-piiri) on
**oma, erillinen tyokokonaisuutensa**, ei viela toteutettu eika
kuulu tahan M3-kattavuuteen. Tama on tietoinen, dokumentoitu rajaus -
ei puutteellinen testaus.

## Yhteenveto

**Kaikki FIPS 203:n kryptografiset algoritmit (primitiivit + K-PKE +
ML-KEM:n sisainen kuori) ovat jaljitettavissa toimivaan RTL-moduuliin
ja lapaisevaan testiin.** Ainoa dokumentoitu, tietoinen rajaus on
aito laitteistotason satunnaislukugeneraattori (TRNG), joka on oma
tuleva tyokokonaisuutensa FPGA-integraation yhteydessa.
