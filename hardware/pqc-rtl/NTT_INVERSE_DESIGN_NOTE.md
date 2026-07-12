# M3 Issue #8, Vaihe 3 — NTT⁻¹ Design Note

**Päivämäärä:** 2026-07-12
**Tila:** Suunnitteludokumentti ennen RTL-tyota. Vaihe 1 ja Vaihe 2
(K-PKE.Decryptin datapolku ennen inverse-NTT:ta) ovat taydellisesti
validoitu (ks. commit-historia) - tama on viimeinen puuttuva
algoritminen primitiivi ennen Vaihe 4:aa (Compress1 + end-to-end).

## 1. Algoritmitason maarittely (FIPS 203:n lopullinen teksti)

**Algoritmi 9, NTT(f) - jo lane_fsm:ssa:**
```
1: f_hat <- f
2: i <- 1
3: for (len <- 128; len >= 2; len <- len/2)
4:   for (start <- 0; start < 256; start <- start+2*len)
5:     zeta <- zeta^BitRev7(i) mod q
6:     i <- i+1
7:     for (j <- start; j < start+len; j++)
8:       t <- zeta * f_hat[j+len]
9:       f_hat[j+len] <- f_hat[j] - t
10:      f_hat[j] <- f_hat[j] + t
```

**Algoritmi 10, NTT^-1(f_hat) - puuttuu RTL:sta:**
```
1: f <- f_hat
2: i <- 127
3: for (len <- 2; len <= 128; len <- 2*len)
4:   for (start <- 0; start < 256; start <- start+2*len)
5:     zeta <- zeta^BitRev7(i) mod q
6:     i <- i-1
7:     for (j <- start; j < start+len; j++)
8:       t <- f[j]
9:       f[j] <- t + f[j+len]
10:      f[j+len] <- zeta*(f[j+len] - t)
11: f <- f * 3303 mod q     [JOKAINEN alkio kerrotaan 3303:lla = 128^-1 mod q]
```

## 2. Tarkat erot (neljä, ei vain silmukkajarjestys)

| # | Ero | NTT (Alg. 9) | NTT^-1 (Alg. 10) |
|---|---|---|---|
| 1 | Tasojarjestys | len: 128->2 (taso 6->0) | len: 2->128 (taso 0->6), KAANTEINEN |
| 2 | Zeta-indeksi i | 1, kasvava | 127, VAHENEVA |
| 3 | **Itse aritmetiikka** | t=zeta*b ENSIN, sitten a+t ja a-t (SAMA t molemmissa) | a+b (EI zetaa!) yhteen ulostuloon, zeta*(b-a) TOISEEN - eri termit, zeta VAIN yhdessa haarassa |
| 4 | Lopputulos | ei lisaskaalausta | KAIKKI 256 kerrointa * 3303 mod q lopuksi |

**Rivi 3 on tarkein huomio:** taman EI ole vain "silmukka toisin pain"
-ongelma. NTT:n butterfly laskee saman valiarvon t=zeta*b KAHTA
ulostuloa varten (a+t, a-t). NTT^-1:n butterfly laskee ERI asian:
toinen ulostulo on suora a+b (ei zetaa ollenkaan), toinen on
zeta*(b-a) (zeta VASTA erotuksen jalkeen, ja erotus on b-a, ei a-b).

## 3. Arkkitehtuurivertailu — jaettu datapolku vai erillinen moduuli?

**Kayttajan oma kysymys:** voisiko forward/inverse jakaa saman
datapolun, ohjattuna mode-lipulla?

**Vastaus: KYLLA, tama on jarkeva ja toteutettavissa ilman
kohtuutonta ohjauslogiikan monimutkaistumista.** Perustelu:

- Rivit 1-2 (tasojarjestys, zeta-indeksi) EIVAT vaadi RTL-muutosta
  ollenkaan - nama ohjataan jo ULKOISESTI (pair_dist, base_addr,
  zeta_lane0/1 ovat ajonaikaisia portteja, M2:n oma "aikataulu-
  tiedosto"-arkkitehtuuri). NTT^-1 tarvitsee vain OMAN, kaanteisen
  aikataulutiedoston (sama zeta-taulukko, luettu toiseen suuntaan,
  eri pair_dist-jarjestys) - EI mitaan uutta lane_fsm-logiikkaa
  tata varten.
- Rivi 3 (itse butterfly-aritmetiikka) vaatii YHDEN uuden 1-bittisen
  `mode`-portin lane_fsm:aan, joka muuttaa S_COMPUTE-tilan laskentaa:
  ```
  if (mode == FORWARD) begin
    t = montgomery_reduce(b_reg * zeta_in);
    ap_reg <= mod_add(a_reg, t);
    bp_reg <= mod_sub(a_reg, t);
  end else begin // INVERSE
    ap_reg <= mod_add(a_reg, b_reg);                          // EI zetaa
    bp_reg <= montgomery_reduce(mod_sub(b_reg, a_reg) * zeta_in); // zeta VASTA erotuksen jalkeen
  end
  ```
  Tama on KAKSI muxia (valitse mika kaava laskee ap_reg/bp_reg) - ei
  uutta kertolaskuyksikkoa, uudelleenkayttaa SAMAN montgomery_reduce-
  funktion ja SAMAT mod_add/mod_sub-funktiot molemmissa moodeissa.
- Rivi 4 (lopullinen *3303) ON oma, erillinen lisavaihe - EI kuulu
  butterfly-silmukkaan ollenkaan (ajetaan VASTA kaikkien 7 tason
  jalkeen, kertaalleen). Tama sopii luontevasti omaksi pieneksi
  moduulikseen (sama periaate kuin `pqc_polyadd.sv` - 256 rinnakkaista
  vakiokertoa, ei silmukkaa).

**Johtopaatos: lane_fsm saa YHDEN uuden portin (`mode`), EI uutta
moduulia butterflylle itselleen.** Erillinen, pieni "final scale"
-moduuli tarvitaan lopulliseen *3303-vaiheeseen.

## 4. Toteutussuunnitelma (kayttajan oman jarjestyksen mukaisesti)

1. **Muokkaa lane_fsm:aa** (`pqc_rvv_cluster_2lane.sv`): lisaa `mode`-
   portti, ehdollinen S_COMPUTE-logiikka ylla kuvatun mukaisesti.
   Regressiotestaa VALITTOMASTI kaikki olemassa olevat NTT-testit
   (M1, 2b, 2c-i, 2c-ii, 3b, 3c, Vaihe 2) `mode=FORWARD`-oletuksella -
   varmista ettei mikaan rikkoutunut ENNEN inverse-puolen lisaamista.
2. **Uusi "final scale" -moduuli** (`pqc_ntt_final_scale.sv`): 256
   rinnakkaista *3303 mod q -kertoa, sama rakenne kuin polyadd.
3. **Uusi kaanteinen aikataulutiedosto**: sama zeta-taulukko kuin
   eteenpain-NTT:lla, luettuna KAANTEISESSA jarjestyksessa (i=127->1),
   len-jarjestys 2->128.
4. **Itsenainen validointi**: NTT^-1(NTT(f)) == f kaikilla testi-f:lla,
   RTL:ssa (ei vain golden-mallissa, joka on jo todistanut taman M2
   Vaihe 2a:ssa) - TAMA ENNEN Vaihe 8:n integraatiota.
5. **Vasta sen jalkeen**: liita K-PKE.Decryptin Vaihe 2:n jalkeen
   (sum_hat -> NTT^-1 -> final_scale -> w), sitten Compress1(w) +
   koko ketju end-to-end (Vaihe 4).

Jokainen vaihe todennetaan erikseen ennen seuraavaan siirtymista,
sama kurinalaisuus kuin koko projektissa tahan asti.

## 5. Vaihe 1/4 valmis, Vaihe 4 (round-trip) EPAONNISTUI - tarkasti rajattu loydos (2026-07-12)

**Tehty:** `mode`-portti lisatty `lane_fsm`:aan (kaikki 10 instanssia
paivitetty, regressio: 7/7 aiempaa testia PASS muuttumattomana).
`pqc_ntt_final_scale.sv` (lopullinen *3303) todennettu ITSENAISESTI,
PASS. Kaanteinen aikataulu (`ntt_inverse_schedule.txt` +
`ntt_inverse_level6_zeta.txt`) generoitu suoraan `ntt_inv()`:n omasta
silmukkarakenteesta.

**Round-trip-testi (`NTT^-1(NTT(f)) == f`, AIDOLLA RTL:lla molempiin
suuntiin) EPAONNISTUI - mutta tarkasti rajatulla tavalla:**

- **Vaikutusalue: TASMALLEEN indeksit 64-127 ja 192-255** - ei mitaan
  muuta. Nama ovat juuri lane1:n oma osoitealue tasolla 6 (base=64,
  pair_dist=128 -> osoitteet 64-127 ja 192-255).
- **Lane0:n alue (0-63, 128-191) on TAYSIN OIKEIN** kaikissa 256
  testatuissa kertoimessa.
- **Monissa (ei kaikissa) virheellisissa arvoissa tasmalleen 2x-kerroin**:
  esim. odotettu 1125 -> saatu 2250; odotettu 225 -> saatu 450;
  odotettu 1218 -> saatu 2436; odotettu 672 -> saatu 1344; odotettu
  244 -> saatu 488. Ei kaikki virheet ole tasan 2x (esim. odotettu
  2730 -> saatu 2131 ei ole selvaa kerrannaista), mutta riittavan moni
  on tasan 2x etta se on todennakoisesti merkityksellinen johtolanka,
  ei sattumaa.

**Tutkimussuunnitelma seuraavalle kierrokselle (EI aloitettu viela):**

1. Vaihekohtainen vertailu golden-malliin: tallenna muisti-tila
   JOKAISEN tason (0..6) jalkeen seka golden-mallista etta RTL:sta,
   ei vain lopputulosta. Jos taso 5 tasmaa ja taso 6 ei, bugi on
   kaytannossa paikallistettu yhteen butterfly-vaiheeseen.
2. Tarkista ENSIN lane1:n OHJAUS (ei viela itse butterfly-aritmetiikka):
   twiddle/zeta-valinta, pankkiosoite, lane-select-signaali, tason 6:n
   ajoitus lane1:lla - koska lane0 kayttaa TASMALLEEN samaa logiikkaa
   ja toimii oikein, ero on todennakoisemmin ohjauksessa (esim. vaara
   zeta tai vaara osoite lane1:lle) kuin itse laskentakaavassa
   (joka on sama molemmille laneille).
3. Vasta taman jalkeen tarkista butterfly-operaation aritmetiikka
   itsessaan, jos ohjaus osoittautuu oikeaksi.

**Ei tehty mitaan uusia RTL-muutoksia taman loydoksen jalkeen** -
tama commit dokumentoi tarkan, rajatun tilanteen ennen seuraavaa
tutkimuskierrosta, valttaakseen useamman muutoksen sekoittumisen
keskenaan (sama periaate joka johti Montgomery-virheen loytamiseen
aiemmin: rajaa tarkasti ennen kuin korjaat).
