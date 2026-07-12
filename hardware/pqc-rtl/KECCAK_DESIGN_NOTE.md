# M3 Issue #9 — Keccak / SHA-3-perhe: suunnittelumuistio

**Päivämäärä:** 2026-07-12
**Tila:** Suunnitteludokumentti ennen RTL-tyota. Ei koodia viela - sama
periaate kuin M2_DESIGN_NOTE.md (NTT) ja M3_BYTEENCODE_DESIGN_NOTE.md
(ByteEncode/Decode) noudattivat ennen omaa RTL-tyotaan.

Tarkistettu FIPS 202:n (NIST:n virallinen SHA-3-standardi) lopullisesta
tekstista (nvlpubs.nist.gov/nistpubs/fips/nist.fips.202.pdf) ennen
taman dokumentin kirjoittamista - ei muistista.

## 1. Miksi tama on oma tyokokonaisuutensa, ei "seuraava moduuli"

M3_DESIGN_NOTE.md (2026-07-12) tunnisti jo etta Keccak on "laajuudeltaan
verrattavissa koko M2:n NTT-tyohon". Nyt kun Issue #6/#7/#8 ovat
valmiit, tama on VIIMEINEN puuttuva algoritminen palanen ennen taydellista
ML-KEM-tyokalua - mutta se on rakenteeltaan TAYSIN ERILAINEN kuin mikaan
tahan mennessa tehty: eri tilarakenne (5x5x64-bittinen taulukko, ei
256-alkioinen kerroin-taulukko), eri operaatiot (bittitason XOR/rotaatio/
permutaatio, ei modulaariaritmetiikka mod q), ja eri kayttotarve
(muuttuva pituinen tulo/lahto, ei kiintea 256-alkioinen polynomi).

## 2. Algoritmitason maarittely (FIPS 202:n lopullinen teksti)

### 2.1 Keccak-p[1600,24] permutaatio

Tila: 1600 bittia, jarjestettyna 5x5-taulukoksi 64-bittisia "lane"-
sanoja (A[x][y], x,y=0..4, kukin 64 bittia z-suunnassa). 24 kierrosta,
kukin kierros = iota o chi o pi o rho o theta (jarjestys: theta,rho,pi,chi,iota).

Viisi askelta (FIPS 202 3.2, tarkistettu):

- **theta**: A'[x][y][z] = A[x][y][z] XOR (XOR_y' A[x-1][y'][z]) XOR
  (XOR_y' A[x+1][y'][z-1]) - joka bitti XORataan kahden "paritettisumman"
  kanssa naapuripylvaista. Indeksit mod 5 (x,y) ja mod 64 (z).
- **rho**: A'[x][y][z] = A[x][y][z+offset(x,y)] - kiertaa jokaista
  lanea omalla, KIINTEALLA offsetilla (taulukko FIPS 202:sta - EI
  aloiteta hand-derivoimaan muistista, otetaan suoraan viitetoteutuksesta
  ja TODENNETAAN itsenaisesti ennen kayttoa, ks. 5).
- **pi**: A'[x][y] = A[(x+3y) mod 5][x] (permutoi lanejen SIJAINTEJA,
  ei sisaltoa - uudelleenjarjestaa 25 lanea kiinteän kaavan mukaan).
- **chi**: A'[x][y][z] = A[x][y][z] XOR ((NOT A[x+1][y][z]) AND
  A[x+2][y][z]) - EPALINEAARINEN askel (ainoa AND-operaatio koko
  permutaatiossa).
- **iota**: A'[0][0] = A[0][0] XOR RC(i) - XORaa KIERROSKOHTAISEN
  vakion (24 eri 64-bittista vakiota, yksi per kierros) VAIN lane
  (0,0):aan. RC-vakiot generoidaan LFSR-pohjaisella algoritmilla
  (FIPS 202 Algoritmi 5, rc-funktio) - EI hand-derivoida muistista,
  TODENNETAAN itsenaisesti tunnettua referenssia vasten ennen kayttoa.

### 2.2 Sponge-rakenne ja KECCAK[c]

`KECCAK[c] = SPONGE[KECCAK-p[1600,24], pad10*1, 1600-c]`

- rate r = 1600-c (bittia), capacity c (bittia), r+c=1600 aina.
- **Absorbointi**: syote pehmennetaan pad10*1:lla (lisaa bitti 1, sitten
  nollia, sitten bitti 1, kunnes pituus on r:n monikerta), jaetaan
  r-bittisiin lohkoihin, kukin XORataan tilan "rate"-osaan (ensimmaiset
  r bittia), Keccak-p ajetaan lohkon valissa.
- **Puristus (squeeze)**: tilan rate-osa luetaan ulos r bittia kerrallaan,
  Keccak-p ajetaan valissa jos tarvitaan enemman kuin r bittia ulostuloa.

### 2.3 Kuusi hyvaksyttya instanssia (tarvitaan kaikki nelja alla merkittya)

| Funktio | Maaritelma | rate (tavua) | capacity | Tarvitaan ML-KEM:ssa? |
|---|---|---|---|---|
| SHA3-224 | Keccak[448](M-01, 224) | 144 | 448 | EI |
| SHA3-256 | Keccak[512](M-01, 256) | 136 | 512 | KYLLA (H-funktio) |
| SHA3-384 | Keccak[768](M-01, 384) | 104 | 768 | EI |
| SHA3-512 | Keccak[1024](M-01, 512) | 72 | 1024 | KYLLA (G-funktio) |
| SHAKE128 | Keccak[256](M-1111, d) | 168 | 256 | KYLLA (XOF, SampleNTT) |
| SHAKE256 | Keccak[512](M-1111, d) | 136 | 512 | KYLLA (PRF, J-funktio) |

Tavutasolla (kun syote on tavun monikerta, kaytannossa aina ML-KEM:ssa):
domain-suffiksi + pad10*1:n aloitus-1-bitti yhdistyvat YHDEKSI tavuksi:
- SHA3-*: viimeisen kokonaisen tavun jalkeen lisataan tavu 0x06.
- SHAKE-*: vastaava tavu on 0x1F.
- Molemmissa: VIIMEINEN rate-lohkon tavu XORataan 0x80:lla (pad10*1:n
  paattava 1-bitti). Jos syote tayttaa TASAN rate-lohkon rajalle asti,
  domain-tavu JA paattava 0x80 voivat osua ERI lohkoihin (domain-tavu
  omaan lohkoonsa, jota seuraa NOLLIA ja 0x80 vasta SEURAAVAN lohkon
  alussa) - reunatapaus joka TESTATAAN erikseen (ks. 5). Tarkka
  bittijarjestys (mika bitti on suffiksin ensimmainen vs. pad-bitti)
  TARKISTETAAN BITTITASOLLA ennen RTL:aa, ei oteta tata kommenttia
  sellaisenaan koodiin.

### 2.4 Mihin kutakin tarvitaan FIPS 203:ssa (ML-KEM)

Tarkistettu FIPS 203:n lopullisesta tekstista aiemmin (M3_DESIGN_NOTE.md
2, taydennetty tassa):
- G(c) = SHA3-512(c) - kaytetaan K-PKE.KeyGenissa (jakaa 32+32 tavuun)
- H(s) = SHA3-256(s) - kaytetaan ML-KEM.KeyGen_internalissa
- J(s,8) = SHAKE256(s,8) - kaytetaan Decaps_internalissa (implisiittinen hylkays)
- PRF_eta(s,b) = SHAKE256(s-b, 8*64*eta) - SamplePolyCBD:n syote
- XOF(rho,i,j) = SHAKE128(rho-i-j) - SampleNTT:n syote (rejection sampling)

## 3. Arkkitehtuurivertailu (iteratiivinen vs. purkautuva vs. rinnakkainen)

### 3.1 Vaihtoehto A - Taysin rinnakkainen (kaikki 24 kierrosta yhdessa combinatorisessa polussa)

**Hylatty valittomasti.** 24 kierrosta x (theta+rho+pi+chi+iota) yhdessa
combinatorisessa polussa tarkoittaisi valtavaa yhdistettya XOR/AND-
verkkoa ilman rekistereita valissa - kriittinen polku olisi aivan liian
pitka synteesikelpoiselle kellotaajuudelle, eika FPGA:lla ole mitaan
syyta valttaa 24 sykliä ottavaa iteratiivista ratkaisua tallaisen
edun (yhden pitkän polun) vuoksi. Ei aloiteta.

### 3.2 Vaihtoehto B - Iteratiivinen, yksi kierros per sykli (24 sykliä per permutaatio)

Yksi kierrosfunktio (theta-rho-pi-chi-iota) RTL:ssa, tila (1600 bittia,
25 x 64-bittista rekisteria) paivittyy kerran per kello, laskuri 0..23
valitsee RC(i):n. Standardi, laajalti kaytetty toteutustapa.

**Etu:** yksinkertaisin ohjauslogiikka, pienin piirikoko, suoraviivaisin
todentaa (yksi kierros kerrallaan verrattavissa golden-malliin, sama
periaate kuin NTT:n tasokohtainen debug-tyokalu joka jo osoittautui
korvaamattoman hyodylliseksi Issue #8:n NTT^-1-tyossa).

**Haitta:** 24 sykliä per permutaatio-kutsu, useita permutaatio-kutsuja
per hash-operaatio - hitain lapaisyaika kolmesta vaihtoehdosta, mutta
todennakoisesti EI pullonkaula koko ML-KEM-liukuhihnassa.

### 3.3 Vaihtoehto C - Osittain purkautuva (esim. 2 tai 4 kierrosta per sykli)

Useampi kierrosfunktion instanssi ketjutettuna combinatorisesti, N
kierrosta per kello, N-kertaa lyhyempi latenssiaika mutta N-kertaa
suurempi piirikoko ja pidempi kriittinen polku per sykli.

**Ei aloiteta viela** - tama on optimointi joka kannattaa harkita VASTA
kun Vaihtoehto B on todennettu toimivaksi ja mitattu, jos suorituskyky
osoittautuu genuiiniksi pullonkaulaksi.

### 3.4 Suositus

**Vaihtoehto B (iteratiivinen, 1 kierros/sykli) ensin.** Sama periaate
kuin NTT:ssa: yksinkertaisin toimiva rakenne todennettuna ensin,
optimointi vasta myohemmin jos mitattu tarve osoittaa sen valttamattomaksi.

## 4. Ehdotettu pilkonta (pienet, todennettavat askeleet)

1. **Keccak-p[1600,24] permutaatio-ydin** (theta,rho,pi,chi,iota RTL:ssa,
   yksi kierros per sykli, laskuri 0..23). Todennus: yksittainen
   permutaatio-kutsu tunnettua testivektoria vasten - oma Python-golden-
   malli TARKISTETTUNA tunnettua ulkoista lahdetta vasten ennen kayttoa.
2. **Sponge-kehys**: pad10*1, absorbointi (XOR + permutaatio-kutsut
   silmukassa), puristus. Testataan ERIKSEEN pienilla, kasin
   lasketuilla esimerkeilla ennen taydellisia SHA3/SHAKE-testivektoreita.
3. **SHA3-256 kokonaisuudessaan**, testattuna NIST:n omilla KAT-
   vektoreilla (ks. 5) - pienin/yksinkertaisin neljasta tarvittavasta.
4. **SHA3-512**: sama sponge-kehys, eri rate ja ulostulopituus.
5. **SHAKE128/SHAKE256**: sama sponge-kehys, eri domain-suffiksi ja
   MUUTTUVA ulostulopituus (XOF-ominaisuus).
6. Vasta taman jalkeen: integrointi FIPS 203:n G/H/J/PRF/XOF-kutsuihin
   ja SampleNTT/SamplePolyCBD-nayteenottofunktioihin (oma, myohempi
   tyokokonaisuutensa - nayteenotto ITSESSAAN on ei-triviaali, hylkays-
   pohjainen algoritmi).

## 5. Verifiointisuunnitelma

**Ensisijainen lahde:** NIST CAVP:n Secure Hash Algorithm Validation
System (SHA3VS), csrc.nist.gov/projects/cryptographic-algorithm-
validation-program/secure-hashing - viralliset ShortMsg/LongMsg-KAT-
tiedostot (.rsp-muoto) SHA3-256:lle, SHA3-512:lle, SHAKE128:lle,
SHAKE256:lle. Nama ladataan ja kaytetaan SELLAISENAAN, ei kasin
kirjoiteta uudestaan.

**Reunatapaukset jotka testataan erikseen** (ks. 2.3):
- Tyhja syote (M="")
- Syote joka tayttaa TASAN yhden rate-lohkon (domain-tavu ja 0x80
  osuvat ERI permutaatio-kutsuihin)
- SHAKE:n muuttuva ulostulopituus (lyhyempi ja pidempi kuin yksi rate-lohko)

**Golden-malli:** Python-referenssitoteutus (oma, rakennettu FIPS 202:n
tekstista suoraan) TARKISTETAAN NIST:n omia KAT-vektoreita vasten ENNEN
kuin sita kaytetaan RTL:n omana vertailukohtana - sama jarjestys kuin
kaikki aiempi tyo tassa projektissa (ei koskaan luoteta omaan
toteutukseen ilman ulkoista ankkuria).

## 6. Ei viela tehty

Tama dokumentti ei sisalla RTL-koodia, GitHub Issueja eika golden-
mallia. Seuraava askel (jos jatketaan): golden-mallin (Python) kirjoitus
ja TARKISTUS NIST:n KAT-vektoreita vasten, ENNEN ensimmaista RTL-riviä -
sama jarjestys kuin M2:n NTT:lla ja M3:n ByteEncode/Decodella.
