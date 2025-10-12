#!/usr/bin/env python3
# Minimal PyTorch sanity check

from __future__ import annotations
import sys, re
from pathlib import Path

def _detect_source(torch_path: Path) -> str:
    # Heuristic: site-packages → wheel; repo with .git nearby → local
    if "site-packages" in [p.lower() for p in torch_path.parts]:
        return "wheel"
    for parent in list(torch_path.parents)[:6]:
        if (parent / ".git").exists():
            return "local"  # likely editable/source build
    return "unknown"

def _pyver_on_path(torch_path: Path) -> str | None:
    m = re.search(r"python(\d+\.\d+)", str(torch_path))
    return m.group(1) if m else None

def torch_present(verbose: bool = True) -> dict:
    try:
        import torch  # noqa
    except Exception as e:
        if verbose:
            print(f"torch import failed: {e}")
        return {"ok": False, "error": repr(e)}

    import torch  # type: ignore
    info = {
        "ok": True,
        "python_exe": sys.executable,
        "python_version": f"{sys.version_info.major}.{sys.version_info.minor}",
        "torch_version": getattr(torch, "__version__", "unknown"),
        "cuda_runtime": getattr(torch.version, "cuda", None),
        "cuda_available": False,
        "install_source": None,
        "torch_path": None,
        "python_path_mismatch": False,
        "has_vision": False,
        "has_audio": False,
    }

    tp = Path(torch.__file__).resolve()
    info["torch_path"] = str(tp)
    info["install_source"] = _detect_source(tp)

    # Check torch path’s pythonX.Y vs actual interpreter’s X.Y
    py_on_path = _pyver_on_path(tp)
    if py_on_path and py_on_path != info["python_version"]:
        info["python_path_mismatch"] = True

    # CUDA
    try:
        info["cuda_available"] = bool(torch.cuda.is_available())
    except Exception:
        pass

    # Optional extras (just presence)
    try:
        import torchvision  # noqa
        info["has_vision"] = True
    except Exception:
        pass
    try:
        import torchaudio  # noqa
        info["has_audio"] = True
    except Exception:
        pass

    if verbose:
        print(f"python: {info['python_exe']}")
        print(f"torch: {info['torch_version']}  cuda: {info['cuda_runtime']}")
        print(f"CUDA available: {info['cuda_available']}")
        if info["cuda_available"]:
            try:
                print(f"CUDA device count: {torch.cuda.device_count()}")
                print(f"Device[0]: {torch.cuda.get_device_name(0)}")
                maj, min_ = torch.cuda.get_device_capability(0)
                print(f"capability: {maj}.{min_}")
            except Exception:
                pass
        print(f"install source: {info['install_source']}  (path: {info['torch_path']})")
        if info["python_path_mismatch"]:
            print("WARNING: python version mismatch between interpreter and torch path")
        print(f"extras: vision={info['has_vision']} audio={info['has_audio']}")

        # If only base torch is around, say it plainly (your request)
        if info["ok"] and not info["has_vision"] and not info["has_audio"]:
            print("note: only base torch is installed (no torchvision/torchaudio)")

    return info


if __name__ == "__main__":
    out = torch_present(verbose=True)
    # If you prefer a non-zero exit on failure, uncomment:
    # import sys; sys.exit(0 if out.get("ok") else 1)
