# B4: rekisteri- ja BRAM-budjetti — ennakkorekisteröinti

**Kirjattu:** 2026-11-16, ennen yhtään tämän kysymyksen Yosys-ajoa.
Muutokset tuloksen jälkeen: `B4-POIKKEAMA-N.md`.

## Kysymys

Miksi ML-KEM-orkestroinnin synteesi ei ole valmistunut (KORJAUSLISTA B4)?
Mahtuuko nykyinen arkkitehtuuri ECP5:lle lainkaan?

## Analyyttinen arvio (tehty ennen mittausta)

`b4/rekisteri_arvio.py`: always_ff-sijoitettujen signaalien deklaroidut bitit
ytimen omalla tasolla (ei alimoduuleja: Keccak, NTT, SampleNTT, CBD).
K=3, COEFF_W=16:

| Moduuli | Rekisteribittejä (oma taso) |
|---|---|
| `pqc_mlkem_decaps_a_core` | 84 952 |
| `pqc_mlkem_decaps_b1_core` | 201 765 |
| `pqc_mlkem_keygen_core` | 146 983 |
| `pqc_mlkem_encaps_top` | 10 883 (+ oma b1_core) |
| `pqc_mlkem_decaps_top` | 2 (+ a_core + b1_core) |
| `pqc_tau_integrated_wrapper` | 39 158 |

Kääre kokonaisuutena, alimoduulit pois lukien:
39 158 + 146 983 + (10 883 + 201 765) + (2 + 84 952 + 201 765) ≈ **685 000**.

Vertailu: LFE5U-25F:ssä on 24 288 ja LFE5U-85F:ssä 83 640 FF:ää.
Suurin yksittäinen erä on A-matriisi (K² polynomia × 4096 bittiä = 36 864
bittiä per ydin), ja sama matriisi on kolmessa ytimessä.

## Hypoteesit ja hylkäyssäännöt

**H1 (arvio vastaa synteesiä).** Yosys (`proc; opt; memory -nomap; opt_clean`,
ei flattenia) antaa `pqc_mlkem_decaps_a_core`:n omalle tasolle (K=3)
FF-bittimäärän välillä 50–110 % arviosta, eli 42 476–93 447. Alaraja on
väljä, koska Yosys poistaa vakiobitit (esim. 12-bittisten kertoimien ylimmät
4 bittiä 16-bittisissä rekistereissä). *Hylätään*, jos tulos on välin
ulkopuolella. Jos Yosys ei valmistu kahdessa tunnissa tai 6 GiB:n
muistirajassa, H1 jää ratkaisematta ja se kirjataan.

**H2 (ei mahdu).** Nykyinen arkkitehtuuri ei mahdu ECP5-25F:lle eikä
ECP5-85F:lle. Seuraa H1:stä: jos a_core yksinään on yli 24 288 FF:ää, H2
pätee 25F:lle. 85F:lle H2 nojaa arvioon (koko kääre ≈ 685 000) ja on sitä
varmempi, mitä lähempänä H1:n tulos on 100 %:a.

**H3 (BRAM riittää polynomeille).** Ei mitata tässä, vain lasketaan: kääreen
polynomit (KeyGen 24, kaksi b1-ydintä à 30, a_core 10 = 94 kpl,
256 × 16 bittiä) vievät 94 / 4 ≈ 24 DP16KD-lohkoa (1024 × 18), kun
25F:ssä niitä on 56. Tämä on arkkitehtuuriehdotuksen lähtökohta, ei tulos.

## Mitä tämä ei kerro

- LUT-määrää ei ennusteta. Laajat kombinatoriset polut (ByteEncode/Decode
  koko polynomille kerralla) lisäävät LUT-tarvetta, mutta sitä ei arvioida.
- Alimoduulien (Keccak, NTT, SampleNTT, CBD) rekisterit puuttuvat arviosta.
- H3 ei todista, että BRAM-arkkitehtuuri toimisi: muistiporttien määrä ja
  käyttöjärjestys rajoittavat sitä.
