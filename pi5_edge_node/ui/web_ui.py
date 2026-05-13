from fastapi import APIRouter
from fastapi.responses import HTMLResponse

router = APIRouter()


@router.get("/", response_class=HTMLResponse)
async def index():
    # Very minimal inline UI – no external assets needed
    html = """
    <!doctype html>
    <html>
    <head>
        <meta charset="utf-8">
        <title>Aether One Pi5 – Live View</title>
        <style>
            body { font-family: sans-serif; margin: 2rem; }
            h1 { margin-bottom: 0.5rem; }
            .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 1rem; }
            .card { border: 1px solid #ddd; border-radius: 12px; padding: 1rem; }
            .label { color: #555; font-size: 0.9rem; }
            .value { font-size: 1.35rem; font-weight: bold; margin-top: 0.2rem; }
            .mono { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace; }
            .pass { color: green; }
            .fail { color: red; }
            .unknown { color: orange; }
            .small { font-size: 0.85rem; color: #444; margin-top: 0.5rem; line-height: 1.35; }
        </style>
    </head>
    <body>
        <h1>Aether One Pi5 – Live Telemetry</h1>
        <p>Simple demo dashboard. Data refreshes every 3 seconds.</p>

        <div class="grid">
            <div class="card">
                <div class="label">VOC (ppb)</div>
                <div class="value" id="voc">–</div>
            </div>
            <div class="card">
                <div class="label">Geiger (CPM)</div>
                <div class="value" id="geiger">–</div>
            </div>
            <div class="card">
                <div class="label">LiDAR obstacles</div>
                <div class="value" id="lidar">–</div>
            </div>

            <div class="card">
                <div class="label">LR status</div>
                <div class="value" id="lr_status">–</div>
                <div class="small mono">decision_hash: <span id="decision_hash">–</span></div>
            </div>

            <div class="card">
                <div class="label">TrustCore v1.0 (C core)</div>
                <div class="value" id="tc_kri">–</div>
                <div class="small">
                    R: <span class="mono" id="tc_R">–</span><br>
                    S: <span class="mono" id="tc_S">–</span><br>
                    E: <span class="mono" id="tc_E">–</span><br>
                    LR-D: <span class="mono" id="tc_d">–</span>
                </div>
            </div>

            <div class="card">
                <div class="label">Attestation (TrustCore v0.1)</div>
                <div class="value unknown" id="attestation">–</div>
                <div class="small mono">device_id: <span id="device_id">–</span></div>
            </div>
        </div>

        <script>
            async function fetchData() {
                try {
                    const s = await fetch("/sensors").then(r => r.json());
                    const lr = await fetch("/lr").then(r => r.json());
                    const kri = await fetch("/kri").then(r => r.json());
                    const att = await fetch("/attestation").then(r => r.json());

                    document.getElementById("voc").innerText = s.voc_ppb.toFixed(1);
                    document.getElementById("geiger").innerText = s.geiger_cpm.toFixed(1);
                    document.getElementById("lidar").innerText = s.lidar_obstacles;

                    document.getElementById("lr_status").innerText =
                        lr.status + " (" + lr.score.toFixed(2) + ")";
                    document.getElementById("decision_hash").innerText = (lr.decision_hash || "–").slice(0, 16) + "…";

                    // TrustCore v1.0
                    document.getElementById("tc_R").innerText = kri.R.toFixed(2);
                    document.getElementById("tc_S").innerText = kri.S.toFixed(2);
                    document.getElementById("tc_E").innerText = kri.E.toFixed(2);
                    document.getElementById("tc_kri").innerText = "KRI=" + kri.kri.toFixed(2);
                    document.getElementById("tc_d").innerText = kri.constructive ? "✅" : "⚠️";

                    // Attestation
                    const attEl = document.getElementById("attestation");
                    const st = (att.status || "UNKNOWN").toString().toUpperCase();
                    attEl.innerText = st;
                    attEl.className = "value " + (st === "PASS" ? "pass" : (st === "FAIL" ? "fail" : "unknown"));
                    document.getElementById("device_id").innerText = att.device_id || "–";
                } catch (e) {
                    console.error(e);
                }
            }
            fetchData();
            setInterval(fetchData, 3000);
        </script>
    </body>
    </html>
    """
    return html
