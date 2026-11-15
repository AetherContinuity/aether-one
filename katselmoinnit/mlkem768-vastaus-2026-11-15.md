# Katselmointi (LLM) — lausunto, ei mittaus

```json
{
 "pyynto": "katselmoinnit/mlkem768-pyynto.txt",
 "pyynto_sha256": "1b0730144d47bf44d5c4ab9e540f6e8958f44b93492b5c58e6f87cd69b26f7a3",
 "malli": "kimi-k3.1-pro",
 "response_model": "kimi-k3.1-pro",
 "effort": "max",
 "aika": "2026-11-15T21:39:08+00:00",
 "finish_reason": "length",
 "usage": {
  "prompt_tokens": 61212,
  "completion_tokens": 32000,
  "total_tokens": 93212,
  "cached_tokens": 61184,
  "completion_tokens_details": {
   "reasoning_tokens": 31700
  },
  "prompt_tokens_details": {
   "cached_tokens": 61184,
   "cache_write_tokens": 0
  }
 },
 "hinta_usd": 0.4424
}
```

Käytän alla lyhenteitä **KG** = `pqc_mlkem_keygen_core.sv`, **A** = `pqc_mlkem_decaps_a_core.sv`, **B1** = `pqc_mlkem_decaps_b1_core.sv`, **DT/ET** = decaps/encaps-top, **WB** = Wishbone-kääre, **TB** = `mlkem_acvp_tb.sv`, **GEN** = vektorigeneraattori ja **RUN** = `run_acvp_mlkem_full.sh`.

## K=4:n staattinen tarkistus

En löydä näytetyistä oletusparametreista suoraa K=4:n off-by-one- tai leveysvirhettä:

- Oletukset `ETA1=(K==2)?3:2`, `DU=(K==4)?11:10` ja `DV=(K==4)?5:4` ovat FIPS 203:n mukaiset kaikilla k=2,3,4 (KG:42, B1:31–34).
- K=4 tuottaa oikein `DKPKE_BYTES=1536`, `EK_BYTES=1568`, `DK_BYTES=3168` ja `C_BYTES=1568`.
- Ilmoitettujen SHA3/
