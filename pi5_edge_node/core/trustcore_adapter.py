import ctypes
from pathlib import Path

class TrustCoreNative:
    """ctypes wrapper for the deterministic TrustCore v1.0 C core."""

    def __init__(self, lib_path=None):
        if lib_path is None:
            lib_path = Path(__file__).parent / "trustcore_native" / "libtrustcore.so"
        self.lib = ctypes.CDLL(str(lib_path))

        self.lib.tc_calculate_kri.argtypes = [ctypes.c_float, ctypes.c_float, ctypes.c_float]
        self.lib.tc_calculate_kri.restype = ctypes.c_float

        self.lib.tc_calculate_dissonance.argtypes = [
            ctypes.c_float, ctypes.c_float, ctypes.c_float,
            ctypes.POINTER(ctypes.c_float),
            ctypes.POINTER(ctypes.c_float),
            ctypes.POINTER(ctypes.c_float),
        ]
        self.lib.tc_calculate_dissonance.restype = ctypes.c_int32

    def kri(self, R: float, S: float, E: float) -> float:
        return float(self.lib.tc_calculate_kri(R, S, E))

    def dissonance(self, R: float, S: float, E: float):
        dR = ctypes.c_float(0.0)
        dS = ctypes.c_float(0.0)
        dE = ctypes.c_float(0.0)
        constructive = self.lib.tc_calculate_dissonance(
            R, S, E,
            ctypes.byref(dR), ctypes.byref(dS), ctypes.byref(dE)
        )
        return {
            "constructive": bool(constructive),
            "delta_R": float(dR.value),
            "delta_S": float(dS.value),
            "delta_E": float(dE.value),
        }
