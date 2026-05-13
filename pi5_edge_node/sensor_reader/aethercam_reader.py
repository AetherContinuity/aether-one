"""AetherCamReader — S21 IP-kamera MJPEG stream, liike-/kirkkausanalyysi."""
import logging
import time
import math
from .base_sensor import BaseSensor, SensorReading

logger = logging.getLogger(__name__)

DEFAULT_STREAM_URL = "http://192.168.1.100:8080/video"  # IP Webcam (Android)
FRAME_INTERVAL = 0.5


def _fetch_jpeg_frame(url: str, timeout: float = 2.0) -> bytes:
    """Hakee yhden JPEG-kehyksen HTTP-streamistä."""
    import urllib.request
    with urllib.request.urlopen(url, timeout=timeout) as resp:
        data = b""
        while True:
            chunk = resp.read(1024)
            if not chunk:
                break
            data += chunk
            if b"\xff\xd9" in data:  # JPEG EOF marker
                end = data.index(b"\xff\xd9") + 2
                start = data.rfind(b"\xff\xd8", 0, end)
                if start >= 0:
                    return data[start:end]
    raise RuntimeError("Could not extract JPEG frame")


def _brightness_from_jpeg(jpeg_bytes: bytes) -> float:
    """Laske keskimääräinen kirkkaus 0.0–1.0."""
    try:
        from PIL import Image
        import io
        img = Image.open(io.BytesIO(jpeg_bytes)).convert("L")
        pixels = list(img.getdata())
        return sum(pixels) / (len(pixels) * 255.0)
    except ImportError:
        pass

    try:
        import cv2
        import numpy as np
        arr = np.frombuffer(jpeg_bytes, dtype=np.uint8)
        img = cv2.imdecode(arr, cv2.IMREAD_GRAYSCALE)
        return float(np.mean(img)) / 255.0
    except ImportError:
        pass

    raise RuntimeError("Neither Pillow nor OpenCV available")


class AetherCamReader(BaseSensor):
    def __init__(self, stream_url: str = DEFAULT_STREAM_URL):
        super().__init__("aethercam")
        self.stream_url = stream_url
        self._prev_brightness: float | None = None
        self._mock_t: float = 0.0

    def read(self) -> SensorReading:
        source = "aethercam"
        try:
            jpeg = _fetch_jpeg_frame(self.stream_url)
            brightness = _brightness_from_jpeg(jpeg)

            # Aktivaatiotaso = muutos edellisestä kehyksestä
            if self._prev_brightness is not None:
                delta = abs(brightness - self._prev_brightness)
                normalized = self.clamp(delta * 5.0)  # herkistys
            else:
                normalized = brightness

            self._prev_brightness = brightness

        except Exception as e:
            logger.warning(f"AetherCam stream unavailable ({e}) — using mock")
            # Mock: hitaasti aaltoileva signaali
            self._mock_t += FRAME_INTERVAL
            normalized = self.clamp(0.4 + 0.3 * math.sin(self._mock_t * 0.3))
            brightness = normalized
            source = "mock"

        reading = SensorReading(
            sensor_id=self.sensor_id,
            raw_value=round(brightness if source != "mock" else normalized, 4),
            normalized=round(normalized, 4),
            unit="brightness_delta",
            source=source,
            confidence=1.0 if source != "mock" else 0.3,
        )
        self._last_reading = reading
        return reading
