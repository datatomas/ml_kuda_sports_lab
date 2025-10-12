# ML CUDA Sports Lab
Weak Supervision → Class Imbalance → Data Augmentation (& video) — CUDA-ready.

Each stage is reproducible on its own but also feeds the next stage in the pipeline.

---



## 🚀 Pipeline Stages

### 1) Weak Supervision at Scale
- **Goal:** generate large, weakly labeled datasets from text or event data.
- Build labeling functions (LFs) for UFC or Hockey commentary.
- Combine overlapping signals with a label model (majority or weighted vote).
- Export **probabilistic labels** `y_prob` for downstream training.
- Evaluate coverage, conflict, and accuracy on a small clean dev set.

### 2) Class Imbalance Mitigation
- **Goal:** handle uneven label distributions.
- Implement and compare:
  - Weighted Cross-Entropy (inverse frequency)
  - Focal Loss (γ tuning)
  - Class-Balanced Loss (effective number)
  - Cost-matrix & threshold moving
  - Optional: `WeightedRandomSampler` oversampling
- Report macro-F1, AUCPR, calibration, and per-class metrics.

### 3) Data Augmentation & Visual Modeling
- **Goal:** expand data diversity and move to GPU-intensive image/video models.
- Label-preserving spatial/temporal transforms: flip, rotate, crop, color jitter, blur, motion jitter.
- Train heavy visual backbones (ResNet, ViT, SlowFast, X3D, TimeSformer) on CUDA.
- Combine the best imbalance technique with augmentation and measure gains.

---

## ⚙️ Environment Setup — Local Bootstrap & Use the NVIDIA GPU

This repo is designed to work on a machine with an AMD iGPU (Ryzen/Raphael) **and** an NVIDIA dGPU (RTX 50-series). You do **not** need to disable the iGPU; PyTorch will use the NVIDIA card.

### 0.1 NVIDIA driver (Fedora, one-time)
```bash
sudo dnf install \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda nvidia-settings nvidia-persistenced
sudo reboot
Verify after reboot:
nvidia-smi
#0.2 Clone the repo
git clone https://github.com/datatomas/ml_kuda_sports_lab.git
cd ml_kuda_sports_lab
#0.3 Create a Python 3.12 venv (recommended for PyTorch wheels)
# install 3.12 if missing
sudo dnf install -y python3.12 python3.12-venv

# make & activate venv
/usr/bin/python3.12 -m venv ~/.venvs/cuda312
source ~/.venvs/cuda312/bin/activate
python -m pip install --upgrade pip

#0.4 Install dependencies (one requirements file  for libraries one bootstrap for cpu installation)

### 0.4 Install dependencies (choose ONE)

# A) NVIDIA GPU wheels (recommended)
pip install -r requirements.txt --index-url https://download.pytorch.org/whl/cu124
# (fallback) pip install -r requirements.txt --index-url https://download.pytorch.org/whl/cu121

# B) Build PyTorch from source (advanced; requires CUDA toolkit or builds CPU-only)
# one-liner:
git clone --recursive https://github.com/pytorch/pytorch && cd pytorch && \
pip install -r requirements.txt && \
USE_CUDA=1 CUDA_HOME=/usr/local/cuda MAX_JOBS=$(nproc) python setup.py develop

# from repo root, venv active
pip install -e .

# run the per-module GPU check
python -m ml_kuda_sports_lab.gpu_test

# (optional) run the package entrypoint if __main__.py exists
# python -m ml_kuda_sports_lab

# programmatic check
python - <<'PY'
import ml_kuda_sports_lab as m
res = m.gpu_test(verbose=True)
print(res)
PY


#Activate your venv
# 1) Activate the venv
source ~/.venvs/cuda312/bin/activate

# 2) Sanity check: these MUST point to the venv
which python
python -V
python -c "import sys; print(sys.executable)"

# 3) Verify packages in THIS interpreter
python -c "import torch, numpy; print('torch', torch.__version__); print('numpy', numpy.__version__)"

# 4) (A) Quick run by path (stays within venv)
python /home/tomassuarez/data/Documents/Gitrepos/ml_kuda_sports_lab/src/ml_kuda_sports_lab/gpu_test.py

# 4) (B) Or install your package in editable mode so `-m` works from anywhere
cd /home/tomassuarez/data/Documents/Gitrepos/ml_kuda_sports_lab
python -m pip install -e .

# Now this will work (still inside the venv)
python -m ml_kuda_sports_lab.gpu_test


#fix invalid torch versions
# 2) Remove the old build to avoid conflicts
pip uninstall -y torch torchvision torchaudio triton
python -m pip uninstall -y torch torchvision torchaudio triton 'nvidia-*'
python -m pip cache purge

#2) Build PyTorch from your clone
# If your clone is old, sync it to a release that supports sm_120 (2.8+)
git fetch --all --tags
git checkout v2.8.0        # or 'main' if you prefer latest
git submodule sync
git submodule update --init --recursive

pip install -U pip setuptools wheel
pip install -U cmake ninja typing_extensions filelock sympy mpmath jinja2 networkx
#
export CUDA_HOME="$(dirname "$(dirname "$(which nvcc)")")"
export USE_CUDA=1
export USE_NINJA=1
export MAX_JOBS="$(nproc)"
# Compile exactly for your GPU arch; you can add others if you like.
export TORCH_CUDA_ARCH_LIST="12.0"

# Fedora often ships very new GCC. If NVCC complains, allow it:
export NVCC_FLAGS="-allow-unsupported-compiler"
# (Only use the above if you hit a GCC version mismatch error.)
# From pytorch repo root
pip install -e .

# From pytorch repo root
pip install -e .


3) (Optional) Build vision/audio from source to match

I#f you use them:

# torchvision (match the PyTorch tag; for 2.8.0 it's 0.19.x)
git clone https://github.com/pytorch/vision.git
cd vision
git checkout v0.19.0
pip install -e .
cd ..

# torchaudio (match tag)
git clone https://github.com/pytorch/audio.git
cd audio
git checkout v2.5.0
pip install -e .
cd ..

#Verify
python - <<'PY'
import sys, torch
print("python:", sys.executable)
print("torch:", torch.__version__, "cuda:", torch.version.cuda)
print("CUDA available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("device:", torch.cuda.get_device_name(0))
    print("capability:", torch.cuda.get_device_capability(0))
    print("arch list:", torch.cuda.get_arch_list())
PY


#run by path
/home/tomassuarez/data/Documents/Gitrepos/ml_kuda_sports_lab/src/ml_kuda_sports_lab/torch_test.py