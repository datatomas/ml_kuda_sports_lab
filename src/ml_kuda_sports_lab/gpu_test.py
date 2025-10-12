# src/ml_kuda_sports_lab/gpu_test.py
def check_cuda(verbose=True):
    import torch
    info = {
        "torch_version": torch.__version__,
        "cuda_available": torch.cuda.is_available(),
    }
    if info["cuda_available"]:
        info["device_count"] = torch.cuda.device_count()
        info["device_name"] = torch.cuda.get_device_name(0)
    if verbose:
        print("torch:", info["torch_version"])
        print("CUDA available:", info["cuda_available"])
        if info["cuda_available"]:
            print("CUDA device count:", info["device_count"])
            print("Device[0]:", info["device_name"])
    return {"ok": info["cuda_available"], **info}

if __name__ == "__main__":
    check_cuda(verbose=True)
