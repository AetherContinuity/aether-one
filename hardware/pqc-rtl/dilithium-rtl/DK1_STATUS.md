# M5-DILITHIUM-001 DK1: 32-bittinen NTT-ydin

**Paivamaara:** 2026-07-19
**Tila:** Ensimmainen rakennuspalikka (Barrett-kertolaskureduktio) VALMIS.

## Arkkitehtuurivalinta: Barrett Montgomery-domainin sijaan

**Peruste:** `dilithium-golden/M5_DILITHIUM_001_PLAN.md` (osio 4)
dokumentoi etta rvv-dilithium-ohjelmistototeutus loysi "vaaran
Montgomery-etumerkkikonvention" KAHDESTI eri kohdissa. Barrett-
reduktio valttaa TAMAN kokonaan: arvot pysyvat koko ajan normaali-
alueella (0..Q-1), ei tarvetta Montgomery-domainiin/-domainista
muuntamiselle eika sen omalle etumerkkikonvention sekaannukselle.

Tama on TIETOINEN, dokumentoitu arkkitehtuurivalinta - EI sama
lahestymistapa kuin ohjelmistoreferenssissa, koska FPGA-DSP-lohkot
mahdollistavat suoran 23x23-bittisen kertolaskun ilman Montgomeryn
omaa optimointitarvetta (joka oli alun perin motivoitu OHJELMISTON
jakolaskun kalleudesta - RTL:ssa modulo-operaatio VOIDAAN toteuttaa
suoraan Barrett-piirilla ilman vastaavaa kustannusta).

## Barrett-parametrit (Q=8380417)

- k=46 (siirtomaara), m=floor(2^46/Q)=8396807
- Vahvistettu Pythonilla 100000 satunnaisella parilla ENNEN RTL-
  tyota: 0 virhetta.

## Toteutus ja testitulos

`pqc_dilithium_barrett_mulmod.sv` - taysin kombinatorinen (sama
periaate kuin `pqc_compress.sv`, `pqc_multiplyntts.sv` jne).

```
PASS: Barrett mulmod tasmaa taydellisesti kaikille 506 testitapaukselle
```

506 testitapausta = 6 reunatapausta (0,0 / Q-1,Q-1 / jne) + 500
satunnaista paria, verrattu SUORAAN Pythonin `(a*b)%Q`:hun.

## Seuraava askel

Yksittainen Cooley-Tukey-butterfly (t=zeta*b mod Q; out_a=(a+t)%Q;
out_b=(a-t)%Q, HUOM out_b:n oma modulo-alivuoto vaatii oman
kasittelynsa koska a-t voi olla negatiivinen) - testattava YHTA
butterfly-operaatiota vasten `dilithium-py`:n omasta `to_ntt()`-
metodista ENNEN koko 256-kertoimisen NTT-skeduloinnin rakentamista.

## Butterfly VALMIS ja todennettu (2026-07-19, jatko)

**Toteutus:** `pqc_dilithium_ntt_butterfly.sv` - uudelleenkayttaa
suoraan todistetun Barrett mulmod -moduulin, lisaa CT-butterflyn oman
yhteen-/vahennyslaskun huolellisella etumerkinkasittelylla.

**Loydetty ja korjattu ITSE, ENNEN testausta:** `a_out`/`b_out`-
nimeaminen oli aluksi VAIHTUNUT paikoiltaan verrattuna dilithium-py:n
omaan kaavaan (`coeffs[j]=a+t`, `coeffs[j+l]=a-t`) - korjattu heti
huomattuani, ennen ensimmaista testiajoa.

**Testivektorit generoitu KIRJASTON OMILLA zeta-arvoilla**
(`ring.ntt_zetas`), EI omalla bittikaannosfunktion uudelleen-
toteutuksella - suoraan ML-KEM-tyon oman opetuksen mukaisesti.

**Testitulos:**
```
PASS: NTT-butterfly tasmaa taydellisesti kaikille 504 testitapaukselle
```

**PASS TAYDELLISESTI ENSIMMAISELLA TESTIAJOLLA** - huolellinen
etumerkinkasittely (dokumentoitu tunnettu sudenkuoppa, ks. osio
"Arkkitehtuurivalinta") kannatti: ei loydetty bugia joka olisi
liittynyt juuri tahan, aiemmin ohjelmistopuolella kahdesti loydettyyn
virhetyyppiin.

**Zeta-ROM generoitu** (`dilithium_ntt_zetas.memh`, 256*23-bittinen),
suoraan kirjaston `ring.ntt_zetas`-listasta.

## Seuraava askel

Koko 256-kertoimisen NTT:n skedulointi (7 tasoa, l=128..1,
"schedule ROM" -periaatteella kuten ML-KEM:ssa) - HUOM Dilithiumin
oma k-indeksointi ("k=k+1" sekventiaalisesti KAIKKIEN butterflyjen
yli, ei per-taso nollattuna) ON YKSINKERTAISEMPI kuin ML-KEM:n
kaksikaistainen pankki-arkkitehtuuri - saattaa mahdollistaa
suoraviivaisemman, YHDEN-butterflyn-per-sykli-mallin ensimmaisessa
versiossa.
