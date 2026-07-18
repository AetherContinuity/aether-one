# dilithium-golden: ML-DSA-65 Python-golden-malli

Kayttaa `dilithium-py`-pakettia (GiacomoPope/dilithium-py, PyPI)
VIRALLISENA, riippumattomana FIPS 204 -referenssina RTL-tyon
golden-vertailua varten - sama rooli kuin `m2-golden/`:lla oli
ML-KEM-tyossa.

**Asennus:** `pip install dilithium-py --break-system-packages`

**Kaytettavat sisaiset funktiot** (matchaa m2-golden.py:n
mlkem_keygen_internal/encaps_internal/decaps_internal-kaavaa):

```python
from dilithium_py.ml_dsa import ML_DSA_65
pk, sk = ML_DSA_65._keygen_internal(zeta)       # zeta = 32 tavua
sig = ML_DSA_65._sign_internal(sk, m, rnd)       # deterministinen jos rnd kiintea
valid = ML_DSA_65._verify_internal(pk, m, sig)
```

**TARKEA METODOLOGINEN MUISTUTUS (ML-KEM-tyosta opittu):** tama
KIRJASTO ITSESSAAN on riippumaton, jo laajasti kaytetty ja testattu
referenssi - EI oma manuaalinen uudelleentoteutuksemme. Tama on
TASMALLEEN se “taysin riippumaton virallinen funktio” -tyyppinen
vertailukohta jota Decaps-tyossa jouduttiin etsimaan VASTA sen
jalkeen kun oma manuaalinen referenssi osoittautui virheelliseksi.
Kayta AINA tata pakettia suoraan lopullisissa tarkistuksissa - ala
kirjoita omaa rinnakkaista Python-toteutusta NTT:sta/nayttestyksesta
jne. ellei ole VALTTAMATONTA (esim. valivaiheen tarkistukseen, jolloin
tulos on AINA ristiinvarmistettava tallä kirjastolla).

ML-DSA-65-parametrit (vahvistettu): N=256, Q=8380417, K=6, L=5,
ETA=4, GAMMA1=2^19, GAMMA2=(Q-1)/32, TAU=49, BETA=196, OMEGA=55, D=13.
