#!/usr/bin/env bash
set -euo pipefail

# ================================================
# Config (override via env):                      #
#   VENV_PATH=~/.venvs/cuda312                   #
#   PKGS="pandas numpy ..."                       #
#   WITH_TORCH=1|0                                #
#   TORCH_SOURCE=1|0       # build from local src #
#   TORCH_NIGHTLY=1|0      # use nightly wheels   #
#   TORCH_CUDA=auto|cu128|cu124|cpu               #
#   TORCH_VER=...  TV_VER=...  TA_VER=...         # optional, else matrix picks #
#   PYTORCH_REPO=~/src/pytorch  TORCH_TAG=v2.8.0  #
# ================================================

VENV_PATH="${VENV_PATH:-$HOME/.venvs/cuda312}"

# Base dev/runtime packages (keeps your originals + build helpers present)
PKGS_DEFAULT="pandas numpy scikit-learn pillow tqdm azure-functions ninja cmake"
PKGS="${PKGS:-$PKGS_DEFAULT}"

# Torch toggles
WITH_TORCH="${WITH_TORCH:-1}"
TORCH_SOURCE="${TORCH_SOURCE:-0}"           # 1 = build from source (PyTorch clone)
TORCH_NIGHTLY="${TORCH_NIGHTLY:-0}"         # 1 = nightly wheels (e.g., cu129 when available)
TORCH_CUDA="${TORCH_CUDA:-auto}"            # auto|cu128|cu124|cpu

# Optional explicit pins (if empty, we pick sane versions via a matrix)
TORCH_VER="${TORCH_VER:-}"
TV_VER="${TV_VER:-}"
TA_VER="${TA_VER:-}"

# Source build config
PYTORCH_REPO="${PYTORCH_REPO:-$HOME/src/pytorch}"
TORCH_TAG="${TORCH_TAG:-v2.8.0}"

# Prefer Python 3.12 for venv (good for torch wheels)
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

# Keep site-packages clean (avoid mixing user-site)
export PYTHONNOUSERSITE=1
python -m pip install --upgrade pip setuptools wheel

# Detect NVIDIA GPU
USE_GPU=0
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
  USE_GPU=1
fi

# Install base pkgs
echo "==> Installing base Python packages: $PKGS"
pip install $PKGS

# ---------- Helpers -----------------------------------------------------------

# Choose wheel index by flavor/nightly
choose_index_url() {
  local flavor="$1" nightly="$2"
  if [[ "$nightly" == "1" ]]; then
    case "$flavor" in
      cu129|cu128) echo "https://download.pytorch.org/whl/nightly/cu129" ;; # nightly often hosts latest CUDA
      cu124)       echo "https://download.pytorch.org/whl/nightly/cu124" ;;
      cpu)         echo "https://download.pytorch.org/whl/nightly/cpu" ;;
      *)           echo "https://download.pytorch.org/whl/nightly/cu129" ;;
    esac
  else
    case "$flavor" in
      cu128) echo "https://download.pytorch.org/whl/cu128" ;;
      cu124) echo "https://download.pytorch.org/whl/cu124" ;;
      cpu)   echo "" ;;
      *)     echo "https://download.pytorch.org/whl/cu128" ;;
    esac
  fi
}

# Fill default version matrix *only if* not explicitly pinned by env
# Stable combos known-good on Python 3.12:
#   cu128 → torch 2.8.0, torchvision 0.23.0, torchaudio 2.8.0
#   cu124 → torch 2.6.0, torchvision 0.21.0, torchaudio 2.6.0
set_version_matrix() {
  local flavor="$1" nightly="$2"
  # If nightly: *strongly* prefer letting pip resolve (no pins), unless user pinned.
  if [[ "$nightly" == "1" ]]; then
    return 0
  fi
  if [[ -z "${TORCH_VER}" || -z "${TV_VER}" || -z "${TA_VER}" ]]; then
    case "$flavor" in
      cu124)
        : "${TORCH_VER:=2.6.0}"
        : "${TV_VER:=0.21.0}"
        : "${TA_VER:=2.6.0}"
        ;;
      cpu|cu128|*)
        : "${TORCH_VER:=2.8.0}"
        : "${TV_VER:=0.23.0}"
        : "${TA_VER:=2.8.0}"
        ;;
    esac
  fi
}

# Query compute capability (e.g., "12.0")
detect_cc() {
  if command -v nvidia-smi >/dev/null 2>&1; then
    local cc
    cc="$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -n1 || true)"
    [[ -n "${cc// }" ]] && echo "$cc" || echo ""
  else
    echo ""
  fi
}

# ---------- Torch via wheels --------------------------------------------------

install_torch_wheels() {
  local prefer="$1" nightly="$2" idx flavor

  # Resolve flavor if auto
  if [[ "$prefer" == "auto" ]]; then
    if [[ "$USE_GPU" -eq 1 ]]; then
      # prefer newest supported first
      for flavor in cu128 cu124; do
        set_version_matrix "$flavor" "$nightly"
        idx="$(choose_index_url "$flavor" "$nightly")"
        echo "==> Trying PyTorch ${nightly:+(nightly) }wheels: $flavor"
        if [[ -n "$idx" ]]; then
          if [[ "$nightly" == "1" && -z "$TORCH_VER$TV_VER$TA_VER" ]]; then
            if pip install --index-url "$idx" torch torchvision torchaudio; then return 0; fi
          else
            if pip install --index-url "$idx" "torch==${TORCH_VER}" "torchvision==${TV_VER}" "torchaudio==${TA_VER}"; then return 0; fi
          fi
        fi
      done
      echo "WARN: CUDA wheels failed; falling back to CPU wheels."
      set_version_matrix cpu 0
      if [[ -z "$TORCH_VER$TV_VER$TA_VER" ]]; then
        pip install torch torchvision torchaudio
      else
        pip install "torch==${TORCH_VER}" "torchvision==${TV_VER}" "torchaudio==${TA_VER}"
      fi
    else
      echo "==> No NVIDIA GPU detected. Installing CPU wheels for PyTorch."
      set_version_matrix cpu "$nightly"
      if [[ "$nightly" == "1" && -z "$TORCH_VER$TV_VER$TA_VER" ]]; then
        pip install --index-url "$(choose_index_url cpu 1)" torch torchvision torchaudio
      else
        pip install "torch==${TORCH_VER}" "torchvision==${TV_VER}" "torchaudio==${TA_VER}"
      fi
    fi

  elif [[ "$prefer" == "cu128" || "$prefer" == "cu124" || "$prefer" == "cpu" ]]; then
    set_version_matrix "$prefer" "$nightly"
    idx="$(choose_index_url "$prefer" "$nightly")"
    echo "==> Installing PyTorch wheels: $prefer ${nightly:+(nightly)}"
    if [[ "$nightly" == "1" && -z "$TORCH_VER$TV_VER$TA_VER" ]]; then
      [[ -n "$idx" ]] && pip install --index-url "$idx" torch torchvision torchaudio || pip install torch torchvision torchaudio
    else
      [[ -n "$idx" ]] && pip install --index-url "$idx" "torch==${TORCH_VER}" "torchvision==${TV_VER}" "torchaudio==${TA_VER}" \
                      || pip install "torch==${TORCH_VER}" "torchvision==${TV_VER}" "torchaudio==${TA_VER}"
    fi
  else
    echo "ERROR: Unknown TORCH_CUDA='$prefer'"; exit 1
  fi
}

# ---------- Torch from local source ------------------------------------------

build_torch_from_source() {
  echo "==> Building PyTorch from source in: $PYTORCH_REPO (tag/branch: $TORCH_TAG)"
  if [[ ! -d "$PYTORCH_REPO/.git" ]]; then
    echo "Cloning pytorch..."
    git clone https://github.com/pytorch/pytorch.git "$PYTORCH_REPO"
  fi
  pushd "$PYTORCH_REPO" >/dev/null

  git fetch --all --tags
  git checkout "$TORCH_TAG"
  git submodule sync
  git submodule update --init --recursive

  # Build deps
  pip install -U cmake ninja typing_extensions filelock sympy mpmath jinja2 networkx

  # CUDA toolchain
  if [[ "$USE_GPU" -eq 1 ]]; then
    if ! command -v nvcc >/dev/null 2>&1; then
      echo "ERROR: nvcc not found. Install CUDA Toolkit (>=12.4) or set TORCH_CUDA=cpu (for CPU-only build)." >&2
      exit 1
    fi
    export USE_CUDA=1
    export USE_NINJA=1
    export MAX_JOBS="${MAX_JOBS:-$(nproc)}"

    CCAP="$(detect_cc)"
    if [[ -z "$CCAP" ]]; then
      echo "WARN: Could not detect compute capability; defaulting TORCH_CUDA_ARCH_LIST=12.0"
      CCAP="12.0"
    fi
    export TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-$CCAP}"

    # GCC too new on Fedora? allow
    export NVCC_FLAGS="${NVCC_FLAGS:--allow-unsupported-compiler}"

    # CUDA_HOME auto (from nvcc)
    export CUDA_HOME="${CUDA_HOME:-$(dirname "$(dirname "$(command -v nvcc)")")}"
    echo "CUDA_HOME=$CUDA_HOME | TORCH_CUDA_ARCH_LIST=$TORCH_CUDA_ARCH_LIST | MAX_JOBS=$MAX_JOBS"
  else
    echo "==> Building CPU-only PyTorch"
    export USE_CUDA=0
  fi

  # Editable install into venv
  pip install -e .

  popd >/dev/null
}

# ---------- Drive the install -------------------------------------------------

if [[ "$WITH_TORCH" -eq 1 ]]; then
  if [[ "$TORCH_SOURCE" -eq 1 ]]; then
    build_torch_from_source
  else
    install_torch_wheels "$TORCH_CUDA" "$TORCH_NIGHTLY"
  fi
fi

# ---------- Sanity check ------------------------------------------------------

python - <<'PY'
import sys
try:
    import torch, torchvision, torchaudio
    print("torch:", torch.__version__, "cuda:", torch.version.cuda)
    print("torchvision:", torchvision.__version__)
    print("torchaudio:", torchaudio.__version__)
    print("cuda available:", torch.cuda.is_available())
    if torch.cuda.is_available():
        print("device:", torch.cuda.get_device_name(0))
        print("arch list:", torch.cuda.get_arch_list()[:8])
except Exception as e:
    print("Sanity check failed:", e, file=sys.stderr); sys.exit(1)
PY

echo "✅ Done."
