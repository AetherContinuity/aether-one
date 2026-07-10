# M2 Design Note — Kyber NTT Architecture

**Päivämäärä:** 2026-07-10
**Tila:** Suunnitteludokumentti ennen RTL-työn aloittamista. Ei koodia vielä.

## 1. Miksi M1/M2 Vaihe 1 -suunnitelmaa muutetaan

M1:n ja M2 Vaihe 1:n README:t kuvasivat tavoitteeksi "koko 256-pisteen
NTT:n, monivaiheinen aikataulutin, level 7..0, Cooley-Tukey, kaikki
tasot" — täyden, 8-tasoisen, 256 yksittäiseen kertoimeen asti jakautuvan
NTT:n.

Tämä ei vastaa Kyberin/ML-KEM:n oikeaa matematiikkaa. Täysi 256-pisteen
NTT vaatisi primitiivisen 512. yksikönjuuren olemassaolon renkaassa Z_q
(2n | (q-1), missä n=256). Kyberin Q=3329, joten Q-1=3328=2^8×13.
3328/512=6,5 — ei kokonaisluku. 512. yksikönjuurta ei ole olemassa.

**Tarkistettu FIPS 203:sta (NIST:n virallinen ML-KEM-standardi) ennen
tämän dokumentin kirjoittamista** (ei vain muistista):

> "There are 128 primitive 256-th roots of unity and no primitive
> 512-th roots of unity in Zq." — FIPS 203, s. 21

> "The polynomial X^256 + 1 factors into 128 polynomials of degree 2
> modulo q" — FIPS 203, kaava 4.9

Riippumaton vahvistus kahdesta muusta lähteestä:
- Akateeminen paperi (arXiv, "Faster Post-Quantum TLS 1.3 Based on
  ML-KEM"): *"complete NTT requires 2n|(q-1), which is not satisfied
  in ML-KEM parameters. Instead, ML-KEM uses a variant of NTT, which
  deletes the last layer."*
- Avoimen lähdekoodin Rust-toteutus (walters-labs/mlkem-fips203):
  *"does not require a 512th root of unity (which does not exist in
  Z_q since 512 does not divide 3328)."*

Johtopäätös: Kyberin oikea NTT pysähtyy tasolle 6 (128 lehteä, asteen-2
polynomeja `X²-ζ`-muodossa), ei tasolle 7 (256 skalaaria). M1/M2 Vaihe 1
-suunnitelman "8 tasoa, 256 pistettä" on matemaattisesti ristiriidassa
Kyberin oman rakenteen kanssa, vaikka käyttää Kyberin Q-arvoa.

## 2. Mikä algoritmi toteutetaan

**Kyberin/ML-KEM:n oikea NTT + BaseCaseMultiply**, ei geneerinen
radix-2-FFT-tyylinen täysi NTT.

- **NTT/NTT⁻¹**: 7 tasoa (level 6..0), 128 butterflya per taso,
  BitRev7-järjestyksessä indeksoidut zeta-arvot (FIPS 203 Algoritmit
  9 ja 10).
- **Pistetulo NTT-alueessa**: koska jokainen "piste" on oikeasti
  asteen-2 polynomi (`X²-ζ^(2·BitRev7(k)+1)`-jäännösluokassa), pelkkä
  skalaarikertolasku EI RIITÄ. Tarvitaan `BaseCaseMultiply(a0,a1,b0,b1,γ)`
  (FIPS 203, nimetty algoritmi): kahden asteen-1-polynomin kertolasku
  modulo `X²-γ`, tuottaen uuden asteen-1-polynomin.

Tämä on M1:n oma Montgomery-perhonen (`t=mont_reduce(b*zeta);
a'=a+t; b'=a-t mod Q`) edelleen käyttökelpoinen NTT-tasoille itselleen
(butterfly-rakenne ei muutu) — muutos koskee (a) tasomäärää (7, ei 8)
ja (b) uutta BaseCaseMultiply-vaihetta pistetulon jälkeen, jota M1/M2
Vaihe 1 ei tarvinnut koska ne eivät vielä toteuttaneet pistetuloa
ollenkaan.

## 3. Mitä M2 todistaa (kun valmis)

M2 (korjattuna) todistaa: **RTL vastaa Kyberin/ML-KEM:n virallista
referenssialgoritmia** (FIPS 203, Algoritmit 9 ja 10 + BaseCaseMultiply),
ei vain sisäisesti johdonmukaista Python-mallia.

Todennus kolmiosaisena (2a/2b/2c), sama järjestys kuin aiemmin sovittu:

- **2a — Python-golden-malli yksin, ei RTL:ää.** 7-tasoinen NTT +
  BaseCaseMultiply. Todennetaan konvoluutiolauseen kautta:
  `INTT(NTT(a) ⊙ NTT(b))` (missä `⊙` = BaseCaseMultiply per pari)
  täsmää suoraan laskettuun negasykliseen konvoluutioon
  `a·b mod (X²⁵⁶+1)`. Riippumaton tarkistus, ei vaadi ulkoista
  referenssikoodia.
- **2b — Yksi taso RTL:ssä**, laajennus M2 Vaihe 1:n toimivasta
  rakenteesta. 128 butterflya (level 6, ensimmäinen taso), sama
  zeta-per-butterfly-periaate kuin jo todennettu.
- **2c — Kaikki 7 tasoa + BaseCaseMultiply RTL:ssä.**

Mitä M2 EI todista (rajaus, säilyy samana kuin M1/Vaihe 1): synteesi-
kelpoisuutta, piirin ajoitusta, pinta-alaa, FPGA/ASIC-suorituskykyä.
Käyttäytymismalli edelleen, ei synteesikelpoinen RTL.

## Muutoshistoria

Tämä on spesifikaatiokorjaus, ei suunnittelumieltymys. Peritty
suunnitelma (M1/M2 Vaihe 1 -README:t) kuvasi matemaattisesti
mahdotonta tavoitetta (8-tasoinen 256-pisteen NTT Kyberin Q:lla).
Kukaan aiemmista session tekijöistä ei ollut huomannut tätä ennen
tätä dokumenttia, mukaan lukien allekirjoittanut samana päivänä
kirjoitetussa M2 Vaihe 1 -READMEssa.
