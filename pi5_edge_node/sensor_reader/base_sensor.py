"""BaseSensor — yhteinen rajapinta Aether One -sensoreille."""
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Optional


@dataclass
class SensorReading:
    sensor_id: str
    raw_value: float
    normalized: float       # 0.0 – 1.0
    unit: str
    source: str             # "mq9" | "aethercam" | "mock"
    confidence: float = 1.0


class BaseSensor(ABC):
    def __init__(self, sensor_id: str):
        self.sensor_id = sensor_id
        self._last_reading: Optional[SensorReading] = None

    @abstractmethod
    def read(self) -> SensorReading:
        """Lue sensori ja palauta normalisoitu arvo."""
        ...

    def last(self) -> Optional[SensorReading]:
        return self._last_reading

    @staticmethod
    def clamp(value: float, lo: float = 0.0, hi: float = 1.0) -> float:
        return max(lo, min(hi, value))
