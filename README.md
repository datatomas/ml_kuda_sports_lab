ML CUDA Sports Lab — Single-File Setup & Usage (TXT)
====================================================

This is a single TXT file that contains EVERYTHING you need:
- how to run modules **by file path**,
- CUDA/CPU install recipes with **correct PyTorch version combos**,
- optional source builds (torch/vision/audio),
- verification commands,
- repo structure + tests guidance,
- troubleshooting, and a suggested .gitignore snippet.



1) Run the code (by file path first)
------------------------------------
(Recommended for quick checks; no package install required.)

    # Activate your venv (created below)
    source ~/.venvs/cuda312/bin/activate

    # Run modules directly by path
    python src/ml_kuda_sports_lab/tests/gpu_test.py
    python src/ml_kuda_sports_lab/tests/torch_test.py
    python src/ml_kuda_sports_lab/weak_labeling/nhl_drafts_wl.py

If you prefer `-m` style imports, install once in editable mode:

    python -m pip install -e .
    python -m ml_kuda_sports_lab.gpu_test



2) Environment (Fedora + NVIDIA)
--------------------------------
2.0  Install NVIDIA driver (one-time; reboot afterwards)

    sudo dnf install \
      https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
      https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda nvidia-settings nvidia-persistenced
    sudo reboot

After reboot, verify:

    nvidia-smi

2.1  Clone & create Python 3.12 virtualenv

    git clone https://github.com/datatomas/ml_kuda_sports_lab.git
    cd ml_kuda_sports_lab

    # Install Python 3.12 if missing, then create venv
    sudo dnf install -y python3.12 python3.12-venv
    /usr/bin/python3.12 -m venv ~/.venvs/cuda312
    source ~/.venvs/cuda312/bin/activate
    python -m pip install --upgrade pip



3) Install dependencies (choose ONE)
------------------------------------
3.A  **Recommended — GPU wheels (RTX 50-series → CUDA 12.8)**

    # Core libs
    python -m pip install pandas numpy scikit-learn pillow tqdm azure-functions

    # PyTorch CUDA 12.8 wheels (Python 3.12)
    python -m pip install --index-url https://download.pytorch.org/whl/cu128 \
      torch==2.8.0 torchvision==0.23.0 torchaudio==2.8.0

3.B  **Alternative — CUDA 12.4 wheels**

    python -m pip install --index-url https://download.pytorch.org/whl/cu124 \
      torch==2.6.0 torchvision==0.21.0 torchaudio==2.6.0

3.C  **CPU-only** (no GPU)

    python -m pip install pandas numpy scikit-learn pillow tqdm azure-functions
    python -m pip install torch==2.8.0 torchvision==0.23.0 torchaudio==2.8.0



4) Verify the GPU & versions
----------------------------
    python - <<'PY'
import torch, torchvision, torchaudio, sys
print("python:", sys.executable)
print("torch:", torch.__version__, "cuda:", torch.version.cuda, "cuda_available:", torch.cuda.is_available())
print("torchvision:", torchvision.__version__, "| torchaudio:", torchaudio.__version__)
if torch.cuda.is_available():
    print("device:", torch.cuda.get_device_name(0))
    print("arch list:", torch.cuda.get_arch_list()[:8])
PY



5) Optional: Build from source (advanced)
-----------------------------------------
Use this ONLY if you need custom patches or bleeding-edge features.
Build **torch** first, then **torchvision** and **torchaudio** at tags that
match your installed torch major.minor.

System deps for media (Fedora):

    sudo dnf groupinstall -y "Development Tools"
    sudo dnf install -y ffmpeg ffmpeg-devel sox sox-devel libsndfile libsndfile-devel \
                        libjpeg-turbo-devel libpng-devel libtiff-devel openjpeg2-devel \
                        libavcodec-devel libavformat-devel libavutil-devel \
                        libswresample-devel libswscale-devel

5.1  torch (example: v2.8.0)

    git clone --recursive https://github.com/pytorch/pytorch
    cd pytorch && git checkout v2.8.0 && git submodule update --init --recursive

    python -m pip install -U cmake ninja typing_extensions filelock sympy mpmath jinja2 networkx

    # GPU build
    export USE_CUDA=1
    export CUDA_HOME="$(dirname "$(dirname "$(command -v nvcc)")")"
    export MAX_JOBS="$(nproc)"
    export TORCH_CUDA_ARCH_LIST="12.0"          # RTX 50-series (Lovelace-next)
    export NVCC_FLAGS="-allow-unsupported-compiler"  # helps with newer Fedora GCC

    python -m pip install -e .
    cd ..

5.2  torchvision + torchaudio (match your torch)

For torch **2.8.x** use **vision v0.23.0** and **audio v2.8.0**.
(Your earlier 0.19.0/2.5.0 pair was the mismatch causing conflicts.)

    # torchvision (video)
    git clone https://github.com/pytorch/vision.git
    cd vision && git checkout v0.23.0
    export FORCE_CUDA=1 WITH_FFMPEG=1
    python -m pip install -e .
    cd ..

    # torchaudio
    git clone https://github.com/pytorch/audio.git
    cd audio && git checkout v2.8.0
    export USE_FFMPEG=1
    python -m pip install -e .
    cd ..

Sanity check after source builds:

    python - <<'PY'
import torch, torchvision, torchaudio
print("torch:", torch.__version__, "cuda:", torch.version.cuda)
print("vision:", torchvision.__version__)
print("audio:", torchaudio.__version__)
PY

[Note] For latest stable releases and least friction, prefer the **prebuilt wheels** in section 3.


6) Repo structure & tests
-------------------------
Current structure (good):
    src/ml_kuda_sports_lab/      # package code
    bootstrap.sh
    pyproject.toml
    README.md (or this TXT)
    requirements.txt
    .vscode/settings.json

Recommendation:
- Keep package code under `src/ml_kuda_sports_lab/` (as is).
- Create a top-level `tests/` folder to separate tests from library code.

Example:
    tests/
      test_gpu.py
      test_loss_funcs.py

Minimal test example (tests/test_gpu.py):

    import torch

    def test_cuda_flag_exists():
        assert isinstance(torch.cuda.is_available(), bool)

Run tests:

    python -m pip install pytest
    pytest -q



7) Troubleshooting
------------------
- ModuleNotFoundError: No module named 'torch'
  -> You’re not in the venv, or torch didn’t install. Activate venv and install
     a valid trio:
       CUDA 12.8/CPU: torch==2.8.0  torchvision==0.23.0  torchaudio==2.8.0
       CUDA 12.4:     torch==2.6.0  torchvision==0.21.0  torchaudio==2.6.0

- GPU shows False but you installed CUDA wheels
  -> Check driver: `nvidia-smi`. Ensure you used the **cu128** index for torch 2.8.x.

- NVCC vs GCC complaints on Fedora (source builds)
  -> export NVCC_FLAGS="-allow-unsupported-compiler"


8) Suggested .gitignore (copy/paste)
------------------------------------
    # Python
    __pycache__/
    *.py[cod]
    *.so
    *.egg-info/
    .build/
    dist/

    # Virtual envs
    .venv/
    venv/
    .venvs/
    venvs/

    # VS Code
    .vscode/*
    !.vscode/settings.json
    !.vscode/launch.json
    !.vscode/extensions.json


9) Quick commands reference
---------------------------
Activate venv:
    source ~/.venvs/cuda312/bin/activate

Run by path:
    python src/ml_kuda_sports_lab/gpu_test.py
    python src/ml_kuda_sports_lab/torch_test.py

Install package (editable):
    python -m pip install -e .

GPU verify:
    python - <<'PY'
import torch; print(torch.__version__, torch.cuda.is_available())
if torch.cuda.is_available(): print(torch.cuda.get_device_name(0))
PY

All set. For most users, **section 3.A** + **section 4** is enough.