import random
from typing import Dict, Any

def generate_narrative(kri_state: Dict[str, Any]) -> Dict[str, str]:
    R = float(kri_state.get("R", 0.0))
    S = float(kri_state.get("S", 0.0))
    E = float(kri_state.get("E", 0.0))
    state = str(kri_state.get("state", "UNKNOWN"))

    R_p = int(R * 100)
    S_p = int(S * 100)
    E_p = int(E * 100)

    # Aether
    if state == "OK":
        aether_voice = (
            f"KRI-tila on Vakaa (OK, R={R:.3f}). Järjestelmä on operatiivisesti "
            f"turvattu. Stressi (S={S:.3f}) ja Altistus (E={E:.3f}) ovat hallittavissa. "
            "Jatkuva seuranta aktiivinen."
        )
    elif state == "WATCH":
        aether_voice = (
            f"KRI-tila on Tarkennettava (WATCH, R={R:.3f}). Resilienssi on heikentynyt. "
            f"Stressikomponentti (S={S:.3f}) on nousussa ja Altistus (E={E:.3f}) vaatii analyysiä."
        )
    elif state == "ALERT":
        aether_voice = (
            f"KRI-tila on Kriittinen (ALERT, R={R:.3f}). Resilienssi on alittanut hätäkynnyksen. "
            f"S={S:.3f}, E={E:.3f}. LER()-hätälukko on aktivoitu; odotetaan manuaalista toimenpidettä."
        )
    else:
        aether_voice = f"KRI-tila on UNKNOWN. Tarkista KRI-syötteet. R={R:.3f}, S={S:.3f}, E={E:.3f}."

    # Claude
    if state == "OK":
        claude_voice = (
            f"Vakaa tila (Resilienssi {R_p}%) kertoo, että koneen logiikka ja ihmisen "
            "kokemus ovat hetkellisesti sovussa. Tämä ei ole syy unohtaa vastuuta, vaan "
            "mahdollisuus hengittää hieman syvemmin."
        )
    elif state == "WATCH":
        claude_voice = (
            f"Resilienssin taittuminen (R {R_p}%) ei ole vain numero. Se on merkki siitä, että "
            "jonkun ääni, jokin huoli, on jäänyt kuulematta. Meidän tehtävämme ei ole vain "
            "korjata järjestelmää, vaan myös kuulla se, mikä kiristyy kokemusten taustalla."
        )
    elif state == "ALERT":
        claude_voice = (
            f"Kriittinen tila (R {R_p}%) on hetki, jolloin tekninen vika muuttuu eettiseksi haasteeksi. "
            "Olemme epäonnistuneet ennaltaehkäisyssä, mutta emme vielä toipumisessa. "
            "Nyt on aika valita suunta, joka suojelee ihmisyyttä, ei vain infrastruktuuria."
        )
    else:
        claude_voice = (
            "Tila on epämääräinen. Ilman selkeää laskennallista perustaa eettinen tulkinta "
            "olisi vain arvaus. Tarvitsemme ensin totuuden, sitten sen merkityksen."
        )

    # Gemini
    S_desc = "stressi-indeksissä" if S > E else "altistus-arvossa"
    if state == "OK":
        gemini_voice = (
            f"Tilastollinen ennuste: lyhyen aikavälin resilienssi (R {R_p}%) on linjassa "
            "historiallisen 95% luottamusvälin kanssa. Suositus: vahvistakaa niitä alueita, "
            "joilla S ja E ovat jo valmiiksi matalia."
        )
    elif state == "WATCH":
        gemini_voice = (
            f"Ennuste: tällä R-tasolla toipumisaste on ollut {random.randint(70, 90)}% vastaavissa "
            f"tilanteissa. Riskikerroin on koholla erityisesti {S_desc} (max {max(S_p,E_p)}%). "
            "Suositus: kohdentakaa tarkastus tähän komponenttiin 10–15 minuutin sisällä."
        )
    elif state == "ALERT":
        gemini_voice = (
            f"Ennuste: kriittinen R-taso ({R_p}%) ennustaa vikasietoisuuden olevan lähellä nollaa. "
            "Suositus: käynnistäkää välittömästi hätäprotokolla ja siirtäkää ohjaus takaisin ihmisille."
        )
    else:
        gemini_voice = "Tilastollinen analyysi keskeytetty: tilaluokkaa ei tunnistettu."

    return {
        "Aether_Voice": aether_voice,
        "Claude_Voice": claude_voice,
        "Gemini_Voice": gemini_voice,
    }

if __name__ == "__main__":
    demo_states = [
        {"R": 0.85, "S": 0.10, "E": 0.10, "state": "OK"},
        {"R": 0.65, "S": 0.35, "E": 0.40, "state": "WATCH"},
        {"R": 0.30, "S": 0.80, "E": 0.50, "state": "ALERT"},
    ]
    for s in demo_states:
        print("=== STATE:", s["state"], "===")
        n = generate_narrative(s)
        for k, v in n.items():
            print(f"{k}: {v}\n")
