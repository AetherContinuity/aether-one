# Katselmoinnit (Kimi K3.1 Pro)

Riippumaton LLM-katselmointi, sama työkalu kuin `AetherContinuity/ogas3`:ssa
(`tools/katselmointi.py`, workflow `katselmointi`).

- Pyyntö: `<nimi>-pyynto.txt`. Mukaan kaikki, mitä katselmoija tarvitsee:
  Kimillä ei ole verkkoa eikä repoa. Rivinumerot koodiin.
- Vastaus: `<nimi>-vastaus-<pvm>.md`, committautuu automaattisesti.
- Ajo PR:ssä: label `kimi-katselmointi`. Mainissa: Actions → katselmointi → Run workflow.
- Vaatii salaisuuden `MOONSHOT_API_KEY` (repo tai organisaatio).

Katselmointi on lausunto, ei mittaus. Jokainen löydös tarkistetaan koodia ja
simulaatiota vasten ennen kuin siitä kirjataan mitään KORJAUSLISTA.md:hen.
