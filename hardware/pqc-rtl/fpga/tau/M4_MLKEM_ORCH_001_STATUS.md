# M4-MLKEM-ORCH-001: synteesikelpoinen ML-KEM.KeyGen-orkestrointi

**Paivamaara:** 2026-07-19
**Tila:** OSITTAINEN, TIETOISESTI KESKEN - ei viela taysi ML-KEM.KeyGen

## Loydos joka kaynnisti taman tyopaketin

Tarkistettaessa "ML-KEM-pohjainen istuntoavaimen muodostus TAU:lle"
-tavoitetta havaittiin: koko ML-KEM.KeyGen/Encaps/Decaps ON tahan
asti ollut olemassa VAIN testipenkkien proseduraalisena orkestrointina
(initial-lohkot) - EI synteesikelpoisena RTL:na. Jokainen ALIMODUULI
(NTT, SHA3, SamplePolyCBD, ByteEncode jne.) ON synteesikelpoinen ja
todistettu erikseen, mutta niita YHDISTAVA ohjauslogiikka ei ollut.

## Toteutettu tahan mennessa (pqc_mlkem_keygen_core.sv)

Synteesikelpoinen tilakone joka toistaa TASMALLEEN saman sekvenssin
kuin `tb/pqc_mlkem_keygen_tb.sv`:

1. ✅ SHA3-512(d||K) -> rho, sigma
2. ✅ SampleNTT(rho,i,j) x4 (KxK silmukka) -> A[i][j]
3. 🔄 PRF+SamplePolyCBD(sigma,N) x4 (2K) - ALOITETTU, EI VIELA
   testattu erikseen
4. ❌ NTT-forward x4 (2K) - EI VIELA toteutettu
5. ❌ Matriisikertolasku+summaus (t_hat) - EI VIELA toteutettu
6. ❌ ByteEncode12(t_hat)+rho -> ek - EI VIELA toteutettu
7. ❌ ByteEncode12(s_hat) -> dkPKE - EI VIELA toteutettu
8. ❌ H(ek)=SHA3-256(ek), dk-kokoaminen - EI VIELA toteutettu

## Todennettu (pqc_mlkem_keygen_core_partial_tb.sv)

- `rho` TASMAA taydellisesti Python-golden-referenssiin
  (`vectors/mlkem_keygen_vectors.txt`, sama tiedosto kuin alkuperainen
  testipenkki kayttaa) - SHA3-512-vaihe TOIMII OIKEIN synteesikelpoisena.
- Tilakone etenee koko KxK SampleNTT-silmukan lapi jumiutumatta
  (1399 sykliä), state etenee oikein S_START_CBD:hen asti.
- A[0][0]:n arvo saatiin ulos (ei viela verrattu Python-referenssiin
  erikseen - TAMA ON AVOIN, seuraava tarkistuskohta).

## Loydetty, viela ratkaisematon avoin kysymys

Alkuperainen testipenkki tekee `reset=1;@(posedge clk);reset=0;
@(posedge clk);` ENNEN JOKAISTA start-pulssia (myos peraikkaisten
SampleNTT/CBD-kutsujen valissa). TAMAN synteesikelpoisen FSM:n oma
toteutus EI VIELA tee tata - jaettu `reset`-signaali resetoisi MYOS
FSM:n oman tilan, ei vain alimoduulien sisaisen tilan.

**EI VIELA SELVITETTY:** onko tama per-kutsu-reset AIDOSTI
valttamaton oikeellisuudelle (esim. alimoduulin oma sisainen
akkumulaattori tai tila joka EI tyhjenny pelkalla start-pulssilla),
vai onko se VAIN testipenkin oma eristyskaytanto joka EI ole
tarpeen jatkuvassa, yhdessa FSM:ssa ajettavassa sekvenssissa.

**Tama on kriittinen avoin kysymys ENNEN kuin loput vaiheet
(erityisesti CBD-silmukka, joka on JO osittain toteutettu ilman
per-kutsu-resettia) voidaan todentaa luotettavasti.** Jos per-kutsu-
reset osoittautuu valttamattomaksi, koko FSM-rakenne tarvitsee oman
alimoduulikohtaisen reset-signaalinsa (erillinen paa-FSM:n omasta
resetista).

## Seuraavat askeleet (ei viela aloitettu)

1. Selvittaa per-kutsu-reset-kysymys (tarkastella SampleNTT/CBD-
   moduulien sisaista tilaa, tai testata empiirisesti: toimiiko
   CBD-silmukka oikein ilman valiresettia verrattuna golden-
   referenssiin).
2. Toteuttaa loput vaiheet (NTT-forward, matriisikertolasku,
   ByteEncode, H(ek), assembly) - jokainen erikseen testattuna
   ennen seuraavaa.
3. Lopullinen taydellinen golden-vertailu (ek, dk molemmat
   tasmaavat).
4. Vasta talloin: Encaps/Decaps-vastaavat orkestrointimoduulit
   (viela suurempi tyo).

**Tama on OMA, huomattava tyopakettinsa - ei valmis viela.**
