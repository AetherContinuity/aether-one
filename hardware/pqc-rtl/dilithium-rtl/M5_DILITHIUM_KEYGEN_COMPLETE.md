# M5-DILITHIUM-001: KOKO ML-DSA-65.KeyGen_internal VALMIS

**Paivamaara:** 2026-07-19
**Tila:** TAYDELLINEN, PAASTA-PAAHAN-VALIDOITU VIRSTANPYLVAS

## Mika tama on

`pqc_dilithium_keygen_top.sv` yhdistaa KAIKKI nelja itsenaisesti
todistettua DK-rakennuspalikkaa (DK1 NTT, DK2 ExpandA, DK3 ExpandS,
DK4 t-laskenta+Power2Round+pakkaus) YHDEKSI TAYDEKSI ML-DSA-65
KeyGen_internal -orkestroinniksi (FIPS 204 Algoritmi 6):

```
zeta(32 tavua)
   |
   v
seed_bytes = SHAKE256(zeta||K||L, 128 tavua)
   |
   +-- rho(32), rho_prime(64), K_key(32)
   |
   v
A_hat = ExpandA(rho)         [DK2]
s1,s2 = ExpandS(rho_prime)   [DK3]
   |
   v
t = NTT^-1(A_hat @ NTT(s1)) + s2   [DK1+DK4]
t1,t0 = Power2Round(t)             [DK4]
   |
   v
ek = pack_ek(rho,t1)
dk = pack_dk(rho,K_key,ek,pack_s(s1),pack_s(s2),pack_t0(t0))
```

## Testitulos

```
Valmis 87118 syklin jalkeen
OK: ek (1952 tavua) tasmaa taydellisesti
OK: dk (4032 tavua) tasmaa taydellisesti
PASS: KOKO ML-DSA-65.KeyGen_internal TOIMII PAASTA PAAHAN
```

**PASS TAYDELLISESTI** - seka `ek` (1952 tavua) etta `dk` (4032
tavua) tasmaavat TAYDELLISESTI `dilithium-py`:n omaan
`_keygen_internal()`-tulokseen, kaytettyna SUORAAN kirjaston omilla
funktioilla (ei omaa rinnakkaista Python-uudelleentoteutusta).

**Huomio suoritusajasta:** taman kokoisen, monivaiheisen putken
simulointi Icarus Verilogilla vaatii huomattavasti realiaikaa
(useita minuutteja) tulkkauksen omista kustannuksista johtuen - tama
ei ole merkki ongelmasta, vaan odotettu seuraus SEITSEMAN peräkkaisen
alimoduulin (SHAKE256-siemen, ExpandA:n 30 SHAKE128-nayttestysta,
ExpandS:n 11 SHAKE256-nayttestysta, 5 forward-NTT:ta,
matriisikertolasku, 6 inverse-NTT:ta, dk:n oma SHAKE256) taydesta
ketjuttamisesta.

## Koko DK-rakennuspalikoiden lopullinen tila

| Palikka | Tila |
|---|---|
| DK1: NTT (forward+inverse, Barrett-reduktio) | ✅ |
| DK2: ExpandA (A-matriisi, 30 polynomia) | ✅ |
| DK3: ExpandS (s1+s2, 11 polynomia) | ✅ |
| DK4: t-laskenta+Power2Round+ek/dk-pakkaus | ✅ |
| **Koko KeyGen-orkestrointi (huippumoduuli)** | ✅ **TAYDELLINEN** |

## Matkan varrella loydetyt ja korjatut asiat (yhteenveto)

1. Barrett-reduktion arkkitehtuurivalinta (Montgomeryn sijaan) -
   valtti tunnetun ohjelmistopuolen sudenkuopan kokonaan.
2. A-matriisin j/i-jarjestys ExpandA:ssa - tarkistettu huolellisesti
   kirjaston lahdekoodista etukateen.
3. rho_prime:n oikea leveys (64 tavua, ei 32) ExpandS:ssa - loydetty
   ja korjattu itse ennen testausta.
4. Bittileveysvirhe Power2Round:n r1_out-poiminnassa - loydetty ja
   korjattu itse ennen testausta.
5. **SUURIN LOYDOS:** vaara hajautusfunktion valinta (SHA3-512
   SHAKE256:n sijaan) dk-pakkauksen tr=H(ek)-laskennassa - loytyi
   laajan, kayttajan ohjaaman debug-tutkimuksen kautta (ks.
   KECCAK_MULTIBLOCK_001.md). VAHVISTI etta Keccak-infrastruktuuri
   itsessaan on TAYSIN VIRHEETON.

## Seuraavat askeleet

1. Synteesi + suorituskykymittaus koko KeyGen-orkestroinnille (sama
   rajaus kuin DK1/DK2:ssa - P&R vaatii pidemman ajan kuin taman
   tyoymparistin yksittaiset komennot sallivat)
2. **DK5: ML-DSA-65.Verify_internal** (suunnitelman mukaisesti
   seuraava, EI silmukkaa - rakenteellisesti suoraviivaisin jaljella
   olevista kolmesta paaoperaatiosta)
3. DK6: ML-DSA-65.Sign_internal (vaikein, sisaltaa hylkayssilmukan)
