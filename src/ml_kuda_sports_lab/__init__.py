__all__ = ["gpu_test", "torch_test", "run_checks"]

def __getattr__(name):
    if name == "gpu_test":
        from .gpu_test import check_cuda as _gpu_test
        return _gpu_test
    if name == "torch_test":
        from .torch_test import torch_present as _torch_test
        return _torch_test
    if name == "run_checks":
        # Build the function lazily so imports are light
        def _run_checks(verbose: bool = True):
            from .torch_test import torch_present
            from .gpu_test import check_cuda
            t = torch_present(verbose=verbose)
            g = check_cuda(verbose=verbose)
            return {"torch": t, "cuda": g}
        return _run_checks
    raise AttributeError(name)
