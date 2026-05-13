import random
from typing import Dict, Any

def get_mock_state() -> Dict[str, Any]:
    """Return pseudo-random sensor values for demo/testing."""
    return {
        "voc_ppb": random.uniform(50, 600),
        "geiger_cpm": random.uniform(10, 80),
        "lidar_obstacles": random.randint(0, 3),
    }
