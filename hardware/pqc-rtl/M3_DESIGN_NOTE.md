# M3 Design Note — ML-KEM Encapsulation/Decapsulation Pipeline

**Päivämäärä:** 2026-07-12
**Tila:** Suunnitteludokumentti ennen lisää RTL-työtä. NTT (M2) ja
BaseCaseMultiply (M3 #1) ovat valmiit ja todennetut.

## 1. Miksi tämä dokumentti tarvitaan ennen jatkoa

"Koko encapsulation/decapsulation-putki" on liian iso yksittäinen
askel — sama virhe jota M2_DESIGN_NOTE.md korjasi NTT:n kohdalla
(liian iso, huonosti rajattu tavoite ennen kuin riippuvuudet on
kartoitettu). Kartoitetaan FIPS 203:n oma algoritmirakenne ennen
seuraavaa RTL-riviä.

## 2. FIPS 203:n täydellinen algoritmilista (sisällysluettelosta)

Jarjestyksessä spesifikaation oman rakenteen mukaan:

| # | Algoritmi | Riippuvuus | Tila |
|---|---|---|---|
| 4 | ByteEncode_d | ei mitaan (puhdas bittipakkaus) | EI ALOITETTU |
| 5 | ByteDecode_d | ei mitaan (puhdas bittipurku) | EI ALOITETTU |
| — | Compress_d / Decompress_d | ei mitaan (puhdas skaalaus+pyoristys) | EI ALOITETTU |
| 6 | SampleNTT(B) | XOF (SHAKE128) ulostulo | **RIIPPUU KECCAKISTA** |
| 7 | SamplePolyCBD_eta(B) | PRF (SHAKE256) ulostulo | **RIIPPUU KECCAKISTA** |
| 9 | NTT(f) | - | ✅ VALMIS (M2) |
| 10 | NTT^-1(f_hat) | - | ✅ VALMIS (M2) |
| — | BaseCaseMultiply | - | ✅ VALMIS (M3 #1) |
| 13 | K-PKE.KeyGen(d) | SampleNTT, SamplePolyCBD, NTT, G (SHA3-512) | RIIPPUU KECCAKISTA |
| 14 | K-PKE.Encrypt(ek,m,r) | SampleNTT, SamplePolyCBD, NTT, BaseCaseMultiply, Compress | RIIPPUU KECCAKISTA |
| 15 | K-PKE.Decrypt(dk,c) | NTT, BaseCaseMultiply, Decompress | EI RIIPU KECCAKISTA (!) |
| 16 | ML-KEM.KeyGen_internal | K-PKE.KeyGen, H (SHA3-256) | RIIPPUU KECCAKISTA |
| — | ML-KEM.Encaps/Decaps_internal | K-PKE.*, G, H, J (SHAKE256) | RIIPPUU KECCAKISTA |

**ML-KEM kayttaa nelja SHA-3-perheen funktiota: SHA3-256, SHA3-512,
SHAKE128, SHAKE256** (kaikki Keccak-permutaation paalle rakennettuja).
Tata ei ole viela toteutettu missaan muodossa taman projektin RTL-
puolella.

## 3. Kaksi riippumatonta tyohaaraa

Tama riippuvuuskartta paljastaa etta tyo jakautuu luontevasti KAHTEEN
erilliseen, toisistaan riippumattomaan haaraan:

**Haara A — bittimanipulaatio (ei tarvitse Keccakia):**
ByteEncode/ByteDecode, Compress/Decompress. Nama voidaan toteuttaa ja
todentaa TAYSIN RIIPPUMATTA Keccak-tyosta. Pieni, nopeasti todennettava
askel joka ei vaadi mitaan uutta kryptografista infrastruktuuria.

**Haara B — Keccak/SHA-3-perhe (iso, oma tyokokonaisuutensa):**
SHAKE128, SHAKE256, SHA3-256, SHA3-512 vaativat Keccak-f[1600]-
permutaation (24 kierrosta, 5x5x64-bittinen tila, theta/rho/pi/chi/iota-
vaiheet) - tama on itsessaan yhta iso ellei isompi tyo kuin koko NTT
oli. EI aloiteta tata viela taman dokumentin puitteissa - vaatii oman
suunnitteludokumenttinsa kun sen aika tulee.

## 4. Ehdotettu jarjestys

1. **M3 #2**: Compress_d / Decompress_d RTL:ssa. Yksinkertaisin
   mahdollinen seuraava askel - puhdasta pyoristysta ja skaalausta,
   ei tilaa, ei silmukoita. Golden-malli FIPS 203:n kaavasta:
   `Compress_d(x) = round((2^d/q) * x) mod 2^d`
   `Decompress_d(y) = round((q/2^d) * y)`
2. **M3 #3**: ByteEncode_d / ByteDecode_d RTL:ssa. Bittien pakkaus/
   purku taulukoiden valilla, d=1..12. Hieman monimutkaisempi kuin
   Compress (muuttuva bittileveys), mutta yha ei-tilallinen/
   yksinkertainen kombinatorinen tai lyhyt-piipelinen looginen ongelma.
3. **K-PKE.Decrypt on ainoa taman haaran algoritmi joka EI tarvitse
   Keccakia** (NTT + BaseCaseMultiply + Decompress, kaikki jo valmiina
   Compress/Decompress:n jalkeen) - voitaisiin periaatteessa koota ja
   todentaa kokonaisuutena KIINTEALLA (kasin syotetylla) salaisella
   avaimella ilman etta KeyGen/Encrypt on viela olemassa - hyva
   valietappi ennen Keccak-tyota.
4. Vasta tama jalkeen: Keccak/SHA-3-perhe omana, isona tyokokonaisuutenaan
   (oma design note kun sen aika tulee).
5. Vasta senkin jalkeen: K-PKE.KeyGen, K-PKE.Encrypt, ja lopuksi
   ML-KEM:n omat KeyGen/Encaps/Decaps-kaareet jotka kayttavat K-PKE:ta.

## 5. Mita tama EI ratkaise viela

Tama dokumentti ei toteuta mitaan koodia - se vain kartoittaa
riippuvuudet ja jarjestyksen. Keccakin oma suunnittelu (permutaation
RTL-rakenne, sponge-rakenne SHAKE:lle) on kokonaan oma, myohempi
tyo jota ei aloiteta tassa.
