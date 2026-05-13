"""MQ9Reader — MQ-9 kaasusensori Explorer HAT / ADS1115 kautta."""
import logging
import time
import math
from .base_sensor import BaseSensor, SensorReading

logger = logging.getLogger(__name__)

MQ9_V_CLEAN_AIR = 0.4   # Volttia puhtaassa ilmassa
MQ9_V_MAX = 3.3          # Pi5 ADC max


def _try_explorerhat_read(channel: int = 0) -> float:
    """Lue ADC-kanava Explorer HAT Pro -kirjastolla."""
    try:
        import explorerhat
        value = explorerhat.analog.read(channel)
        return float(value)
    except ImportError:
        raise RuntimeError("explorerhat not installed")
    except Exception as e:
        raise RuntimeError(f"Explorer HAT read error: {e}")


def _try_ads1115_read(channel: int = 0) -> float:
    """Fallback: ADS1115 I2C ADC."""
    try:
        import board
        import busio
        import adafruit_ads1x15.ads1115 as ADS
        from adafruit_ads1x15.analog_in import AnalogIn
        i2c = busio.I2C(board.SCL, board.SDA)
        ads = ADS.ADS1115(i2c)
        ch = AnalogIn(ads, getattr(ADS, f"P{channel}"))
        return ch.voltage
    except ImportError:
        raise RuntimeError("adafruit_ads1x15 not installed")
    except Exception as e:
        raise RuntimeError(f"ADS1115 read error: {e}")


class MQ9Reader(BaseSensor):
    def __init__(self, channel: int = 0, backend: str = "auto"):
        """
        backend: "explorerhat" | "ads1115" | "mock"
        """
        super().__init__(f"mq9_ch{channel}")
        self.channel = channel
        self.backend = backend
        self._mock_time = 0.0

    def _read_voltage(self) -> tuple[float, str]:
        if self.backend in ("explorerhat", "auto"):
            try:
                return _try_explorerhat_read(self.channel), "explorerhat"
            except RuntimeError as e:
                if self.backend == "explorerhat":
                    raise
                logger.debug(f"Explorer HAT unavailable: {e}")

        if self.backend in ("ads1115", "auto"):
            try:
                return _try_ads1115_read(self.channel), "ads1115"
            except RuntimeError as e:
                if self.backend == "ads1115":
                    raise
                logger.debug(f"ADS1115 unavailable: {e}")

        # Mock fallback — realistinen simulaatio
        self._mock_time += 0.1
        base = 0.5
        wave = 0.3 * math.sin(self._mock_time * 0.2)
        noise = 0.05 * math.sin(self._mock_time * 3.7)
        mock_v = base + wave + noise
        logger.warning("MQ9Reader: using MOCK data — no hardware found")
        return mock_v, "mock"

    def read(self) -> SensorReading:
        voltage, source = self._read_voltage()

        # Normalisoi: puhtaasta ilmasta max-piikkiin → 0.0–1.0
        normalized = self.clamp(
            (voltage - MQ9_V_CLEAN_AIR) / (MQ9_V_MAX - MQ9_V_CLEAN_AIR)
        )

        reading = SensorReading(
            sensor_id=self.sensor_id,
            raw_value=round(voltage, 4),
            normalized=round(normalized, 4),
            unit="V",
            source=source,
            confidence=1.0 if source != "mock" else 0.3,
        )
        self._last_reading = reading
        return reading
