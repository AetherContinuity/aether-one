import os
import requests
import xml.etree.ElementTree as ET

# Multi-point FMI places (comma separated)
PLACES = [p.strip() for p in os.getenv("FMI_PLACES", "Helsinki,Kuopio,Oulu,Rovaniemi").split(",") if p.strip()]

FMI_WFS = "https://opendata.fmi.fi/wfs"

def _parse_fmi_simple_obs(xml_bytes: bytes) -> dict:
    """Parse FMI WFS 'simple observations' response defensively.

    FMI XML namespaces can vary slightly; we focus on commonly present elements:
      - omop:parameterName
      - omop:resultValue
    """
    root = ET.fromstring(xml_bytes)
    ns = {
        "wfs": "http://www.opengis.net/wfs/2.0",
        "omop": "http://inspire.ec.europa.eu/schemas/omop/2.9",
    }

    data = {}
    for member in root.findall(".//wfs:member", ns):
        name = member.find(".//omop:parameterName", ns)
        val = member.find(".//omop:resultValue", ns)
        if name is None or val is None:
            continue
        try:
            data[name.text] = float(val.text)
        except Exception:
            continue
    return data

def get_fmi_data(place: str):
    params = {
        "service": "WFS",
        "version": "2.0.0",
        "request": "getFeature",
        "storedquery_id": "fmi::observations::weather::simple",
        "place": place,
        "maxlocations": "1",
    }
    try:
        r = requests.get(FMI_WFS, params=params, timeout=10)
        r.raise_for_status()
        data = _parse_fmi_simple_obs(r.content)
        return {"place": place, "temp": data.get("t2m"), "wind": data.get("ws_10min")}
    except Exception:
        return None

def calculate_time_lock():
    results = [get_fmi_data(p) for p in PLACES]
    valid = [r for r in results if r and r.get("temp") is not None and r.get("wind") is not None]

    if not valid:
        return {"status": "UNKNOWN", "time_p": 0.0, "metrics": {"t_med": None, "w_med": None}, "points": []}

    temps = sorted([r["temp"] for r in valid])
    winds = sorted([r["wind"] for r in valid])

    # Worst-2-of-N
    t_med = (temps[0] + temps[1]) / 2 if len(temps) >= 2 else temps[0]
    w_med = (winds[0] + winds[1]) / 2 if len(winds) >= 2 else winds[0]

    # Risks (0..1)
    t_risk = min(1.0, max(0.0, (0.0 - t_med) / 25.0))   # 0C -> 0, -25C -> 1
    w_risk = min(1.0, max(0.0, (10.0 - w_med) / 10.0))  # 10m/s -> 0, 0m/s -> 1
    time_p = (t_risk * 0.6) + (w_risk * 0.4)

    status = "OK"
    if w_med < 3.0 and t_med < -15.0:
        status = "CRITICAL"
    elif w_med < 5.0 or t_med < -10.0:
        status = "WEAK"

    return {
        "status": status,
        "time_p": round(time_p, 2),
        "metrics": {"t_med": round(t_med, 2), "w_med": round(w_med, 2)},
        "points": valid,
    }
