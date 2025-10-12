def test_package_imports():
    import ml_kuda_sports_lab as m
    assert callable(m.gpu_test)

def test_torch_present():
    import torch
    assert hasattr(torch, "__version__")

def test_cuda_flag_runs():
    from ml_kuda_sports_lab.gpu_test import check_cuda
    out = check_cuda(verbose=False)
    assert "torch_version" in out
    assert "cuda_available" in out
