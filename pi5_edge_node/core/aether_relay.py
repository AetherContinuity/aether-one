import asyncio
import hashlib
import json
from fastapi import FastAPI
from pydantic import BaseModel
from typing import Dict, Any, Optional

from .config import settings
from .lr_core import lr_evaluate
from .kri_engine import compute_kri
from .trustcore.client import TrustCoreClient, TrustCoreConfig
from drivers.mock_sensors import get_mock_state
from ui.web_ui import router as ui_router

# Sensor reader integration
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))
from sensor_reader import MQ9Reader, AetherCamReader

app = FastAPI(title=settings.app_name)
app.include_router(ui_router, prefix="/ui", tags=["ui"])


class SensorState(BaseModel):
    voc_ppb: float = 0.0
    geiger_cpm: float = 0.0
    lidar_obstacles: int = 0


# Simple in-memory caches for demo
SENSOR_CACHE: Dict[str, Any] = {
    "voc_ppb": 0.0,
    "geiger_cpm": 0.0,
    "lidar_obstacles": 0,
    "attestation_status": "UNKNOWN",
    "attestation_timestamp": None,
}

LAST_DECISION: Dict[str, Any] = {
    "status": "UNKNOWN",
    "score": 0.0,
    "details": {},
    "decision_hash": None,
}

trustcore_client: Optional[TrustCoreClient] = None

# Sensor singletons (v7.1 integration)
_mq9: Optional[MQ9Reader] = None
_cam: Optional[AetherCamReader] = None


def _hash_decision(payload: Dict[str, Any]) -> str:
    """Stable SHA-256 over canonical JSON."""
    b = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(b).hexdigest()


@app.on_event("startup")
async def startup_event():
    global trustcore_client, _mq9, _cam

    # Initialize sensors (v7.1)
    _mq9 = MQ9Reader(backend="auto")
    _cam = AetherCamReader()
    print("📡 Sensors initialized (MQ9 + AetherCam)")

    # Initialize TrustCore client (optional)
    try:
        trustcore_client = TrustCoreClient(
            TrustCoreConfig(
                server_url=settings.attestation_server_url,
                policy_id=settings.attestation_policy_id,
            )
        )
        print("✅ TrustCore v0.1 initialized")
    except Exception as e:
        trustcore_client = None
        print(f"⚠️  TrustCore init failed: {e}")

    asyncio.create_task(sensor_update_loop())

    if settings.attestation_enabled and trustcore_client is not None:
        asyncio.create_task(attestation_loop())


async def sensor_update_loop():
    """Update mock sensors and compute latest LR decision."""
    while True:
        state = get_mock_state()
        SENSOR_CACHE.update(state)

        # Compute decision snapshot
        lr = lr_evaluate(SENSOR_CACHE)
        decision_payload = {
            "score": lr.score,
            "status": lr.status,
            "details": lr.details,
        }
        dh = _hash_decision(decision_payload)
        LAST_DECISION.update({
            **decision_payload,
            "decision_hash": dh,
        })
        SENSOR_CACHE["decision_hash"] = dh

        await asyncio.sleep(2.0)


async def attestation_loop():
    """Periodically attest device state to remote TrustCore server."""
    while True:
        try:
            if trustcore_client is not None:
                # Include decision_hash in attestation if available
                result = await trustcore_client.attest(SENSOR_CACHE)
                SENSOR_CACHE["attestation_status"] = result.get("status", "UNKNOWN")
                SENSOR_CACHE["attestation_timestamp"] = result.get("ts")
                print(f"🔐 Attestation: {SENSOR_CACHE['attestation_status']}")
        except Exception as e:
            SENSOR_CACHE["attestation_status"] = "FAIL"
            SENSOR_CACHE["attestation_timestamp"] = None
            print(f"❌ Attestation failed: {e}")

        await asyncio.sleep(max(5, int(settings.attestation_interval)))


@app.get("/health")
async def health():
    return {"status": "ok", "app": settings.app_name}


@app.get("/sensors", response_model=SensorState)
async def read_sensors():
    return SensorState(**SENSOR_CACHE)


@app.get("/lr")
async def lr_status():
    return {
        "score": float(LAST_DECISION.get("score", 0.0)),
        "status": LAST_DECISION.get("status", "UNKNOWN"),
        "details": LAST_DECISION.get("details", {}),
        "decision_hash": LAST_DECISION.get("decision_hash"),
    }


@app.get("/decision")
async def decision_status():
    """Explicit endpoint for last decision + hash."""
    return LAST_DECISION


@app.get("/kri")
async def kri_status():
    kri = compute_kri(SENSOR_CACHE)
    return {
        "R": kri.R,
        "S": kri.S,
        "E": kri.E,
        "kri": kri.kri,
        "constructive": kri.constructive,
        "deltas": kri.deltas,
    }


@app.get("/attestation")
async def attestation_status():
    return {
        "status": SENSOR_CACHE.get("attestation_status", "UNKNOWN"),
        "timestamp": SENSOR_CACHE.get("attestation_timestamp"),
        "device_id": trustcore_client.pqc.get_device_id() if trustcore_client else None,
        "tpm_available": trustcore_client.tpm_available if trustcore_client else False,
        "decision_hash": LAST_DECISION.get("decision_hash"),
    }


# ═══ Sensor Endpoints (v7.1 integration) ════════════════════════════════════

@app.get("/sensor/mq9")
async def sensor_mq9():
    """MQ-9 kaasusensori (Explorer HAT / ADS1115 / mock)."""
    if _mq9 is None:
        return {"error": "MQ9 not initialized"}
    import time
    reading = _mq9.read()
    return {
        "sensor_id": reading.sensor_id,
        "raw_value": reading.raw_value,
        "normalized": reading.normalized,
        "unit": reading.unit,
        "source": reading.source,
        "confidence": reading.confidence,
        "timestamp": time.time(),
    }


@app.get("/sensor/aethercam")
async def sensor_aethercam():
    """AetherCam IP-kamera stream (S21 / mock)."""
    if _cam is None:
        return {"error": "AetherCam not initialized"}
    import time
    reading = _cam.read()
    return {
        "sensor_id": reading.sensor_id,
        "raw_value": reading.raw_value,
        "normalized": reading.normalized,
        "unit": reading.unit,
        "source": reading.source,
        "confidence": reading.confidence,
        "timestamp": time.time(),
    }


@app.get("/node_status_realtime")
async def node_status_realtime():
    """
    Yhdistelmä: lukee molemmat sensorit → laskee KRI suoraan.
    Käyttää runtime-clean TrustCore v1.0 C-ydintä.
    """
    if _mq9 is None or _cam is None:
        return {"error": "Sensors not initialized"}
    
    import time
    mq9 = _mq9.read()
    cam = _cam.read()

    # Map sensorit R/S/E:hen (demo mapping)
    # MQ9 → S (Stress/environmental quality)
    # Cam → E (situational awareness/exposure)
    # R computed from both
    S = mq9.normalized
    E = cam.normalized
    R = max(0.0, 1.0 - 0.5 * (S + E))

    # Käytä TrustCore v1.0 native KRI
    sensor_state = {"R": R, "S": S, "E": E}
    kri_result = compute_kri({"voc_ppb": S * 500, "geiger_cpm": E * 100, "lidar_obstacles": 0})

    return {
        "sensors": {
            "mq9": {
                "normalized": mq9.normalized,
                "source": mq9.source,
                "confidence": mq9.confidence
            },
            "aethercam": {
                "normalized": cam.normalized,
                "source": cam.source,
                "confidence": cam.confidence
            },
        },
        "R": round(R, 4),
        "S": round(S, 4),
        "E": round(E, 4),
        "kri": kri_result.kri,
        "constructive": kri_result.constructive,
        "deltas": kri_result.deltas,
        "timestamp": time.time(),
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8080)
