#!/usr/bin/env bash
set -euo pipefail

# ---- Config (edit if you want) --------------------------------------------
VENV_PATH="${VENV_PATH:-$HOME/.venvs/cuda312}"
# Base packages you want locally. You can override with:
#   PKGS="pandas numpy ..." ./bootstrap_min.sh
PKGS="${PKGS:-pandas numpy scikit-learn pillow tqdm azure-functions}"
# Torch versions that have wheels for Python 3.12 at time of writing
TORCH_VER="${TORCH_VER:-2.5.1}"
TV_VER="${TV_VER:-0.20.1}"
TA_VER="${TA_VER:-2.5.1}"
# ---------------------------------------------------------------------------

# Prefer Python 3.12 for PyTorch wheels
PYBIN="/usr/bin/python3.12"
if [[ ! -x "$PYBIN" ]]; then
  echo "NOTE: /usr/bin/python3.12 not found; using default python3"
  PYBIN="$(command -v python3)"
fi

# Create venv if missing
if [[ ! -d "$VENV_PATH" ]]; then
  "$PYBIN" -m venv "$VENV_PATH"
fi

# Activate venv
# shellcheck disable=SC1090
source "$VENV_PATH/bin/activate"
python -m pip install --upgrade pip wheel

# Detect NVIDIA GPU (for CUDA wheels). Fallback to CPU wheels if none.
USE_GPU=0
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
  USE_GPU=1
fi

echo "==> Installing base Python packages: $PKGS"
pip install $PKGS

if [[ "$USE_GPU" -eq 1 ]]; then
  echo "==> NVIDIA GPU detected. Installing PyTorch CUDA wheels (trying cu124 then cu121)..."
  if pip install --index-url https://download.pytorch.org/whl/cu124 \
      "torch==${TORCH_VER}" "torchvision==${TV_VER}" "torchaudio==${TA_VER}"; then
    :
  elif pip install --index-url https://download.pytorch.org/whl/cu121 \
      "torch==${TORCH_VER}" "torchvision==${TV_VER}" "torchaudio==${TA_VER}"; then
    :
  else
    echo "WARN: CUDA wheels not available for this platform. Installing CPU wheels from PyPI."
    pip install "torch==${TORCH_VER}" "torchvision==${TV_VER}" "torchaudio==${TA_VER}"
  fi
else
  echo "==> No NVIDIA GPU detected. Installing CPU wheels for PyTorch."
  pip install "torch==${TORCH_VER}" "torchvision==${TV_VER}" "torchaudio==${TA_VER}"
fi

# Minimal sanity check (does not run your app or project requirements)
python - <<'PY'
import sys
print("python:", sys.version.split()[0])
try:
    import torch
    print("torch:", torch.__version__, "| cuda_available:", torch.cuda.is_available(), "| cuda_rt:", getattr(torch.version, "cuda", None))
    if torch.cuda.is_available():
        print("device:", torch.cuda.get_device_name(0))
    import pandas as pd; import numpy as np
    print("pandas:", pd.__version__, "| numpy:", np.__version__)
except Exception as e:
    print("Sanity check error:", e)
    raise
PY

echo
echo "✅ Base environment ready."
echo "Activate later with:"
echo "  source \"$VENV_PATH/bin/activate\""
