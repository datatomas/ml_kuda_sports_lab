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
