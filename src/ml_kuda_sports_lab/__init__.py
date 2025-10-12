# src/ml_kuda_sports_lab/__init__.py
__all__ = ["gpu_test"]

def __getattr__(name):
    if name == "gpu_test":
        # lazily resolve to the function when accessed
        from .gpu_test import check_cuda as _gpu_test
        return _gpu_test
    raise AttributeError(name)
