
Each stage is reproducible on its own but also feeds the next stage in the pipeline.

---

## 🚀 Pipeline Stages

### 1️⃣ Weak Supervision at Scale
- **Goal:** generate large, weakly labeled datasets from text or event data.
- Build labeling functions (LFs) for UFC or Hockey commentary.
- Combine overlapping signals with a label model (majority or weighted vote).
- Export **probabilistic labels** `y_prob` for downstream training.
- Evaluate coverage, conflict, and accuracy on a small clean dev set.

### 2️⃣ Class Imbalance Mitigation
- **Goal:** handle uneven label distributions.
- Implement and compare:
  - Weighted Cross-Entropy (inverse frequency)
  - Focal Loss (γ tuning)
  - Class-Balanced Loss (effective number)
  - Cost-matrix & threshold moving
  - Optional: `WeightedRandomSampler` oversampling
- Report macro-F1, AUCPR, calibration, and per-class metrics.

### 3️⃣ Data Augmentation & Visual Modeling
- **Goal:** expand data diversity and move to GPU-intensive image/video models.
- Label-preserving spatial/temporal transforms:
  - Flip, rotate, crop, color jitter, blur, motion jitter
- Train heavy visual backbones (ResNet, ViT, SlowFast, X3D, TimeSformer) on CUDA.
- Combine the best imbalance technique with augmentation and measure gains.

---

## ⚙️ Environment Setup

```bash
# clone
git clone https://github.com/datatomas/ml_kuda_sports_lab.git
cd ml_kuda_sports_lab

# create environment (conda or venv)
conda create -n cuda_sports python=3.11 -y
conda activate cuda_sports

# install dependencies
pip install -r env/requirements.txt
