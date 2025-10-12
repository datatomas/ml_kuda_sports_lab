import os
import pandas as pd
import numpy as np

# ---------------- robust CSV loader ----------------
def load_csv_smart(path: str) -> pd.DataFrame:
    """Try common encodings; last resort replace undecodable bytes."""
    for enc in ("utf-8", "utf-8-sig", "cp1252", "latin-1"):
        try:
            return pd.read_csv(path, encoding=enc, engine="python")
        except UnicodeDecodeError:
            continue
    # fallback: keep going even if some bytes are bad
    return pd.read_csv(path, encoding="utf-8", encoding_errors="replace",
                       engine="python")

CSV = os.environ.get("NHL_DRAFT_CSV",
                     "/home/tomassuarez/data/Datasets/nhl-ufc/nhldraft.csv")
df = load_csv_smart(CSV)

# ---------------- helpers ----------------
def to_int_or_nan(x):
    if pd.isna(x): return np.nan
    xi = pd.to_numeric(str(x).strip(), errors="coerce")
    return np.nan if pd.isna(xi) else int(xi)

def pick_tier(p):
    p = to_int_or_nan(p)
    if pd.isna(p): return "NA"
    if p <= 10:   return "top10"
    if p <= 32:   return "r1"
    if p <= 64:   return "r2"
    if p <= 150:  return "mid"
    if p <= 199:  return "late"
    return "r7plus"

def pos_group(pos):
    pos = (str(pos) or "").strip().upper()
    if pos in {"C","LW","RW"}: return "F"
    if pos == "D": return "D"
    if pos == "G": return "G"
    return "NA"

# ---------------- tags ----------------
df["overall_pick_num"] = df["overall_pick"].apply(to_int_or_nan)
df["pick_tier"] = df["overall_pick_num"].apply(pick_tier)
df["pos_group"] = df["position"].apply(pos_group)

# ---------------- optional org quartiles (train split only) ----------------
if {"year", "games_played", "team"}.issubset(df.columns):
    train_df = df[df["year"] <= 2015].copy()
    train_df["success"] = (train_df["games_played"].fillna(0) >= 200).astype(int)
    hit = train_df.groupby("team")["success"].mean().rename("team_hit_rate")
    if len(hit) >= 4:
        qs = hit.quantile([0.25, 0.5, 0.75]).to_dict()
        def org_quartile(team):
            r = hit.get(team, np.nan)
            if pd.isna(r): return "NA"
            if r >= qs[0.75]: return "Q1_best"
            if r >= qs[0.50]: return "Q2"
            if r >= qs[0.25]: return "Q3"
            return "Q4_worst"
    else:
        def org_quartile(team): return "NA"
else:
    def org_quartile(team): return "NA"

df["org_quartile"] = df["team"].apply(org_quartile)

# ---------------- deterministic weak label ----------------
def weak_label(row):
    p = row["overall_pick_num"]
    pos = row["pos_group"]
    if pd.isna(p): return np.nan  # abstain

    # strongest positives
    if p <= 10: return 1
    if 11 <= p <= 32: return 1

    # position-aware refinements
    if pos == "D":
        if p <= 45: return 1
        if 65 <= p <= 120: return 0
        if p >= 180: return 0
    elif pos == "F":
        if p <= 60: return 1
        if p >= 180: return 0
    elif pos == "G":
        if p <= 60: return 1  # lean success
        if p >= 180: return 0

    # pick-only residuals
    if 33 <= p <= 64: return 1
    if 65 <= p <= 150: return 0
    if p >= 200: return 0

    return np.nan  # abstain

df["y_weak"] = df.apply(weak_label, axis=1)

# ---------------- optional gold label for eval ----------------
if "games_played" in df.columns:
    df["y_gold"] = (df["games_played"].fillna(0) >= 200).astype(int)

# ---------------- save & summarize ----------------
out_csv = os.environ.get("NHL_DRAFT_OUT_CSV",
                         os.path.join(os.getcwd(), "nhldraft_tagged.csv"))
parent = os.path.dirname(out_csv) or "."
os.makedirs(parent, exist_ok=True)
df.to_csv(out_csv, index=False)

coverage = df["y_weak"].notna().mean()
counts = df["y_weak"].value_counts(dropna=False).to_dict()
print(f"Loaded: {CSV}")
print(f"Wrote:  {out_csv}")
print(f"rows: {len(df)} | y_weak coverage: {coverage:.4f} | counts: {counts}")
