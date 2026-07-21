# M3-MLKEM-002: Encaps/Decaps NIST ACVP -suunnitelma (seuraava istunto)

**Tila:** suunniteltu, EI viela toteutettu.
**Related:** `M3_MLKEM_ACVP_STATUS.md`, `dilithium-rtl/NIST_ACVP_STATUS.md`,
`REPORTING-DISCIPLINE.md`

## Paatos joka TAYTYY tehda ENNEN ajoa, ei jalkeen

**Vaihekohtaiset syklit vs. kokonaissumma.** FO-vertailun
(Fujisaki-Okamoto, implisiittinen hylkays Decaps_internal:issa)
kannalta kiinnostava mahdollinen ero valid- ja rejection-polkujen
valilla syntyy NIMENOMAAN Decaps:n omien B-vaiheiden SISALLA
(uudelleensalaus K-PKE.Encrypt:lla + vertailu c'==c + K/K_bar-
valinta) - EI koko operaation kokonaissyklimaarassa, jossa nama
erot voivat hukkua identtisiin, molemmilla poluilla samoihin
K-PKE-vaiheisiin.

**PAATOS: testipenkki mittaa syklit VAIHEKOHTAISESTI, EI VAIN
kokonaissumma.** Konkreettisesti Decaps_internal:in oma FSM
(tai sen testipenkki) lisaa erilliset laskurit vahintaan naille
vaiheille:
1. `dk_split` (dk:n jako dkPKE/ek/h/z-osiin)
2. `kpke_decrypt` (alkuperainen salauksen purku, tuottaa m')
3. `g_hash` (G(m'||h) -> K',r')
4. `kpke_encrypt_reencrypt` (uudelleensalaus K-PKE.Encrypt:lla r':lla)
5. `compare_c` (c'==c-vertailu)
6. `j_hash` (J(z||c) -> K_bar, AINA laskettu FO:n omalla
   vakioaikaisuusvaatimuksella riippumatta vertailun tuloksesta -
   TARKISTETTAVA etta RTL TODELLA laskee taman AINA, ei ehdollisesti)
7. `k_select` (K vs. K_bar -valinta vertailun tuloksen mukaan)

Jokaisen vaiheen oma sykliaika kirjataan EROTELTUNA valid- ja
rejection-testitapauksille. Tama on muutaman rivin lisays
testipenkkiin (laskuri per tila + `$display` vaiheen paattyessa),
mutta PAATOS TAYTYY tehda ENNEN ensimmaista ajoa - jalkikateen
lisatty vaihejako ei anna samaa vertailuarvoa kuin alusta asti
suunniteltu.

## Miksi tama EI OLE VIELA sivukanava-analyysia

Tama on TOIMINNALLISEN simulaation oma syklimaara (Icarus Verilog,
diskreetti aika), EI mitattu ajoitus tai tehonkulutus oikealla
laitteistolla. JOS valid- ja rejection-polkujen syklimaarat EROAVAT
tassa simuloinnissa, se on ENSIMMAINEN, KVANTITATIIVINEN vihje
etta RTL:n oma toteutus EI ole vakioaikainen (esim. jos `compare_c`
tai `k_select` sisaltaa ehdollisen HAARAUTUMISEN joka vaikuttaa
FSM:n omaan TILASIIRTYMAAN eika vain DATAAN) - MUTTA se EI viela
todista mitaan OIKEAN laitteiston sivukanavavuodosta (reititys,
kellon jitter, lampoefektit jne. voivat vaikuttaa eri tavoin).
Tama on kayttajan oma, tarkka rajaus: "ilmainen sivutuote testista
jonka ajat joka tapauksessa", EI korvike toggle-proxy-tyokalulle
tai oikealle mittaukselle.

## Etukateen kirjattu ennuste (2026-07-21, ENNEN ajoa)

**Toteutuksen tarkistus tehty ENSIN** (`pqc_mlkem_decaps_b1_core.sv`,
rivit 664-679; `pqc_mlkem_decaps_a_core.sv`:n oma silmukkarakenne):

- Vertailu `match_out <= (c_in === c_prime)` tapahtuu YHDESSA
  tilasiirtymassa (`S_WAIT_SHAKE256`->`S_DONE`), joka riippuu VAIN
  `shake256_done`-signaalista - EI mistaan c_in/c_prime:n SISALLOSTA.
  Tama ON TAYSI, LEVEA `===`-vertailu (kombinatorinen koko 768
  tavulle YHDESSA lausekkeessa), EI tavukohtainen silmukka jolla
  olisi mahdollisuus varhaiseen keskeytykseen.
- `K_bar = J(z||c)` (SHAKE256) LASKETAAN AINA, EHDOTTA - ei
  vertailun tuloksesta riippuen. Tama ON juuri FO:n oma
  vakioaikaisuusvaatimus toteutettuna oikein RTL-tasolla.
- `pqc_mlkem_decaps_a_core.sv`:n omat silmukat paattyvat KIINTEISIIN
  laskuriarvoihin (`load_idx==255`, `sched_idx==63` jne.) - EI
  mihinkaan DATA-ARVOON perustuen.

**ENNUSTE (kirjattu ENNEN vaihekohtaisten syklien mittaamista):**
kaikki seitseman vaihe (ks. ylla) tuottavat SAMAN syklimaaran
valid- ja rejection-testitapauksille - **EI eroa** minkaan vaiheen
kohdalla, mukaan lukien `compare_c` ja `k_select`, koska molemmat
tapahtuvat YHDESSA, DATASTA RIIPPUMATTOMASSA tilasiirtymassa.

**Taman ennusteen merkitys KUMPAANKIN suuntaan (kirjattu etukateen,
jotta tulosta ei tulkita jalkikateen narratiiviin sopivaksi):**
- **JOS ennuste toteutuu ("ei eroa"):** tama EI ole pettymys eika
  merkitykseton tulos - se ON tulos. Se RAJAA FO-vuotokysymyksen
  POIS syklitasolta tassa TOTEUTUKSESSA, ja siirtaa sen sinne missa
  se OIKEASTI elaisi: datariippuvaan KYTKENTAAKTIIVISUUTEEN (toggle-
  count) tai vertailun OMAAN gate-tason toteutukseen (esim. XOR-
  puun oma rakenne, EI nakyvissa RTL-tasolla).
- **JOS ero LOYTYY JOSSAIN vaiheessa siita huolimatta etta
  toteutus NAYTTAA vakioaikaiselta:** TAMA OLISI ITSESSAAN loydos -
  joko (a) mittausvirhe (esim. testipenkin oma ajoituslogiikka,
  EI RTL) TAI (b) jokin RTL:n oma, tata tarkistusta EDELTAVA
  rakenne (esim. SampleNTT:n oma hylkaysnaytteistys, joka ON
  aidosti data-riippuvainen iteraatiomaaraltaan - TARKISTAMATON
  taman ennusteen omassa katselmuksessa) tuo eron muualta kuin
  itse FO-vertailusta.

**Jos toteutus OLISI ollut sen sijaan tavukohtainen silmukka
varhaisella keskeytyksella (`if (c[i] != c_prime[i]) break`),
ennuste olisi PAINVASTAINEN - eron PUUTTUMINEN olisi tallöin ITSE
mittausvirhe. Ennuste on siis EHDOLLINEN taman spesifisen RTL-
toteutuksen (tayysi rinnakkainen vertailu) lukemiselle, EI sokea.**

1. `mlkem_golden.py`:n oma vahvistus valittua NIST-tcId:ta vasten
   (Python ENSIN, RTL VASTA sen jalkeen).
2. RTL Encaps 3-5 vektoria (triviaali polku, ei haarautumista).
3. RTL Decaps 3-5 vektoria, PRIORISOIDEN NIST:n omia implicit-
   rejection-tapauksia (rikottu ciphertext, odotettu K_bar=J(z||c))
   itse generoitujen (`byte_corrupted`, `bit_corrupted`) sijaan -
   ks. kayttajan oma huomio, taman projektin OMAT hylkaystestit
   EIVAT korvaa NIST:n riippumattomia vektoreita.
4. Vaihekohtaiset syklit kirjataan JOKAISELLE Decaps-tapaukselle
   (seka valid etta rejection) taulukkona `M3_MLKEM_ACVP_STATUS.md`:aan.
5. `check_reporting_discipline.sh` ajetaan ENNEN commit-vaihetta.

## Tarkka termi joka pitaa kirjoittaa NAIN, ei lyhentaa (2026-07-21, ENNEN mittausta)

FSM-katkelma vahvistaa viela yhden asian: `K_final_out <= (c_in ===
c_prime) ? K_prime_in : shake256_out` on ITSESSAAN syklivakio
DATARIIPPUVA multiplekseri - molemmat K-ehdokkaat (`K_prime_in` ja
`shake256_out`) OVAT jo rekistereissa valmiina, ja valinta tapahtuu
YHDESSA syklissa riippumatta siita kumpi valitaan.

**KUN ennuste (ei syklitasoeroa, molemmilla ehdoilla: vakioaikainen
vertailu JA J-hash aina laskettu) TOTEUTUU, OIKEA johtopaatos ON
TASMALLEEN RAJATTU:**

> "Decaps on **SYKLITASOLLA** vakioaikainen."

**EI:**

> "Decaps on vakioaikainen."

**Miksi tama ero on kirjoitettava eksplisiittisesti tulosten yhteyteen
(EI vain tahan suunnitteludokumenttiin):** "syklitasolla vakioaikainen"
on juuri sellainen vaite joka LYHENEE lainauksissa muotoon
"vakioaikainen" ellei rajaus ole naulattu TEKSTIIN siina kohaa missa
tulos esitetaan, EI vain jossain aiemmassa suunnitteludokumentissa
josta lainaaja ei valttamatta lue asti loppuun.

**Jaljelle jaava vuotopinta taman mittauksen JALKEEN ON MAARITELMALLISESTI
kytkentaaktiivisuus (toggle) vertailu- ja mux-logiikassa** - TAMA ON
`toggle-count-proxy`-tyokalun oma kohde, EI syklilaskurin. Syklilaskuri
EI VOI havaita eroa joka syntyy SAMALLA syklilla tapahtuvasta, mutta
DATASTA RIIPPUVASTA kytkentamaarasta (esim. `c_in === c_prime`:n oma
XOR-puu kytkee eri maaran portteja riippuen SIITA MISSA KOHDASSA
c_in ja c_prime eroavat, vaikka TULOS ja AIKA ovat molemmat vakioita).

## Seuraus infrastruktuurivalinnalle (kirjattu ETUKATEEN, ei jalkikateen)

Jos Decaps-mittaus vahvistaa ennusteen (EI syklitasoeroa) - taman
JALKEEN `SymbiYosys` vs. `toggle-count-proxy` -valinta ON KAYTANNOSSA
jo ratkennut: SymbiYosys todistaisi TOIMINNALLISIA invariantteja jotka
OVAT JO ACVP-ankkuroituja (vahvistaisi jo vahvinta, todennetuinta
osaa). Toggle-proxy kohdistuisi AINOAAN jaljella olevaan
TUNTEMATTOMAAN (kytkentaaktiivisuus). Tama paatos ON EHDOLLINEN
Decaps-mittauksen omalle tulokselle - JOS mittaus TUOTTAA yllatyksen
(syklitasoero loytyy), TAMA paatos ON UUDELLEENARVIOITAVA, ei
automaattisesti voimassa.

## Tulos (2026-07-21, JALKEEN mittauksen)

Ennuste TOTEUTUI TASAN puhtaassa saman-avaimen vertailussa (Phase A,
Phase B, kokonaissykli KAIKKI tasan samat molemmilla poluilla, ks.
`M3_MLKEM_ACVP_STATUS.md`). Decaps on SYKLITASOLLA vakioaikainen
SALAISEN DATAN suhteen - ExpandA:n oma, julkiseen `rho`:hon sidottu
vaihtelu ON dokumentoitu ja vakioaikakonvention mukainen, EI vuoto.

**Infrastruktuurivalinta RATKESI kuten ehdollisesti kirjattiin:**
Decaps EI tuottanut yllatysta, joten `toggle-count-proxy` kohdistuu
AINOAAN jaljella olevaan tuntemattomaan (kytkentaaktiivisuus), ja
`SymbiYosys` vahvistaisi jo ACVP-ankkuroitua toiminnallisuutta.

## Seuraavan kierroksen oma edellytys (kirjattu ETUKATEEN, kayttajan oma vaatimus)

**Seuraava kierros ON infrastruktuurihanke, EI jatkumo tallle
mittaukselle - ERI LUONTEINEN sessio.** Sille EI ole golden-vektoreita
joita vasten verrata (toisin kuin taman ja kaikkien aiempien
kierrosten oma ACVP-ankkurointi) - sen sijaan MITTAUSMENETELMA ITSE
TAYTYY validoida ENSIN, ennen kuin sita kaytetaan Decapsin
kytkentaaktiivisuuden mittaamiseen.

**Konkreettinen vaatimus ennen `toggle-count-proxy`-tyokalun
soveltamista Decapsiin:** rakenna TUNNETUSTI VUOTAVA "leikkitoteutus"
(esim. tarkoituksella epatasa-arvoinen if/else-vertailu jonka TIEDETAAN
kuluttavan eri maaran kytkentoja per haara) ja VAHVISTA etta
`toggle-count-proxy` NAKEE taman TUNNETUN vuodon ENNEN kuin sen
tulosta Decapsille tulkitaan luotettavaksi. Sama periaate kuin
negatiivikontrolleissa yleensa: todista ETTA mittari NAKEE vian, VASTA
SITTEN vaita ettei vikaa OLE kohteessa. Tama EI ole vapaaehtoinen
askel - ilman sita "toggle-count-proxy nayttaa ei-eroa Decapsille"
-tulos olisi yhta tulkinnanvarainen kuin taman kierroksen oma
alkuperainen (korjattu) 5-eri-avaimen mittaus oli ennen sekavuustekijan
tunnistamista.

## Rajaus

Tama EI ole toggle-count-proxy-infrastruktuurin rakentamista eika
SymbiYosys-integraatiota - naista keskustellaan VASTA kun taulukko
(KeyGen+Encaps+Decaps, molemmat FIPS 203 ja FIPS 204) on suljettu.
