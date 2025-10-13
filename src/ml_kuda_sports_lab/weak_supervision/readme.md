# Hockey Draft Weak Labeling — How to Interpret Tags & Apply to Your Dataset

This README explains **what tags mean**, **how to derive them** from your columns, and **how to use them as weak labels** for a first-pass model you can train later. It is written specifically for the dataset you uploaded (with columns shown below).

---

## 1)  Columns in the Data Set (from kaggle) & What We Can Use
https://www.kaggle.com/datasets/adryenestewart/nhldraftpicks
https://www.kaggle.com/code/mattop/nhl-draft-player-analysis-1963-2022
**Draft-time features (OK for rules):**

- `id`, `year`, `overall_pick`, `team`, `player`, `nationality`, `position`, `age`, `amateur_team`, `height`, `weight`

**Outcome / post-draft fields (use only for evaluation, NEVER in rules):**

- `to_year`, `games_played`, `goals`, `assists`, `points`, `plus_minus`, `penalties_minutes`, `goalie_games_played`, `goalie_wins`, `goalie_losses`, `goalie_ties_overtime`, `save_percentage`, `goals_against_average`, `point_shares`

> Rationale: weak labels must be created **only** from information available at draft time; otherwise you leak the answer.

---

## 2) What Are “Tags”? (Derived, human-readable features)

We’ll derive three tags used by the weak labeling rules:

### 2.1 `pick_tier` — bucket the overall pick
Lower `overall_pick` means earlier (better).

| Tier      | Definition |
|-----------|------------|
| `top10`   | `overall_pick ≤ 10` |
| `r1`      | `11–32` |
| `r2`      | `33–64` |
| `mid`     | `65–150` |
| `late`    | `151–199` |
| `r7plus`  | `≥ 200` |

### 2.2 `pos_group` — compress positions
Map `position` to one of:
- `F` (forwards): `C`, `LW`, `RW`
- `D` (defense): `D`
- `G` (goalie): `G`
- `NA` (unknown/other): anything else or missing

### 2.3 `org_quartile` — historic org success (optional, weak prior)
From **training years only**, compute each NHL org’s **hit-rate**:  
`hit_rate_team = mean(games_played ≥ 200)`  
Label the team to a quartile: `Q1_best`, `Q2`, `Q3`, `Q4_worst`. If not enough history → `NA`.

> This captures “where these teams are going” without using future info on the same players.

---

## 3) The Weak Labeling Rules (Labeling Functions / LFs)

Each LF outputs one of **SUCCESS (1)**, **FAIL (0)**, or **ABSTAIN** (no vote). We combine them with a label model (e.g., Snorkel) to get a probability `p_success` per player.

### 3.1 Level 1 — Pick-only (works even if only `overall_pick` exists)

- `LF_top10`: if `overall_pick ≤ 10` → **SUCCESS**
- `LF_round1`: if `11 ≤ overall_pick ≤ 32` → **SUCCESS**
- `LF_round2_mid`: if `33 ≤ overall_pick ≤ 64` → **lean SUCCESS**
- `LF_midlate`: if `65 ≤ overall_pick ≤ 150` → **lean FAIL**
- `LF_round7_plus`: if `overall_pick ≥ 200` → **FAIL**
- `LF_missing_pick`: if `overall_pick` missing → **ABSTAIN**

> Confidence intent (for the label model): `top10` > `round1` > `r2_mid` > `midlate` > `r7_plus`.

### 3.2 Level 2 — Position-aware (adds coverage when `position` is present)

**Skaters (F = C/LW/RW):**
- `LF_fwd_top60`: `pos_group == F` **and** `overall_pick ≤ 60` → **SUCCESS**
- `LF_fwd_late_fail`: `pos_group == F` **and** `overall_pick ≥ 180` → **FAIL**
- Tie-breaker: if `65–120` and `F` → **ABSTAIN** (let pick-only dominate)

**Defense (D):**
- `LF_def_top45`: `pos_group == D` **and** `overall_pick ≤ 45` → **SUCCESS**
- `LF_def_65_120_fail`: `pos_group == D` **and** `65 ≤ overall_pick ≤ 120` → **lean FAIL**
- `LF_def_180_plus_fail`: `pos_group == D` **and** `overall_pick ≥ 180` → **FAIL**

**Goalies (G):**
- `LF_goalie_early`: `pos_group == G` **and** `overall_pick ≤ 60` → **lean SUCCESS**
- `LF_goalie_late`: `pos_group == G` **and** `overall_pick ≥ 120` → **ABSTAIN** (high variance)
- `LF_goalie_180_plus_fail`: `pos_group == G` **and** `overall_pick ≥ 180` → **FAIL**

### 3.3 Level 3 — Team prior (optional & weak)

- `LF_org_top_quartile`: `org_quartile == Q1_best` → **weak SUCCESS**
- `LF_org_bottom_quartile`: `org_quartile == Q4_worst` → **weak FAIL**
- Else → **ABSTAIN**

**Conflict policy (intuitive):**
1) Earlier-pick positives override later-pick negatives.  
2) Goalie middle picks prefer **ABSTAIN** unless extreme.  
3) If nothing fires confidently → **ABSTAIN**.

---

## 4) Targets for Training & Betting

Pick one global target to train and evaluate (consistent across positions):
- **SUCCESS = 1 if `games_played ≥ 200`**, else 0 (long-term value), or
- **SUCCESS = 1 if NHL GP within 3 years ≥ X** (faster feedback).

You’ll train on historical years where outcomes are known, then score new drafts. For betting, convert `p_success` to **fair odds** (`odds = 1 / p`) and compare to market implied odds.

---

## 5) How to Apply to Your CSV (Step-by-step)

**Input:** your `nhldraft.csv` with columns:  
`id, year, overall_pick, team, player, nationality, position, age, to_year, Tag, amateur_team, height, weight, games_played, goals, assists, points, plus_minus, penalties_minutes, goalie_games_played, goalie_wins, goalie_losses, goalie_ties_overtime, save_percentage, goals_against_average, point_shares, Tag`

> We will ignore `to_year` and all outcome columns when generating weak labels.

### Step A — Create tags
- Compute `pick_tier` from `overall_pick` (table in §2.1).
- Map `position` to `pos_group` (F/D/G/NA) as in §2.2.
- (Optional) Compute `org_quartile` from historical hit-rates (only on **training years**).

### Step B — Choose a time split
Example:
- Train label model + classifier on ≤ 2015
- Dev: 2016–2018
- Test: 2019–2021

### Step C — Generate weak labels
- Apply Level 1 + Level 2 LFs (and Level 3 if you built org priors).
- Each player gets multiple votes (1/0/ABSTAIN).

### Step D — Combine votes into `p_success`
- Use a label model (e.g., Snorkel’s `LabelModel`) to learn LF accuracies/correlations and output `p_success` per row.
- If you don’t want a label model yet, you can use a **simple priority** resolution: take the strongest applicable LF according to the confidence order above; ABSTAIN if no rule fires.

### Step E — Train a discriminative model
- Model 1: **F-only**, Model 2: **D-only**, Model 3: **G-only** (separate cohorts often calibrate better).  
- Features: `overall_pick` (+ piecewise buckets), `pos_group` (one-hot if training a single model), `org_quartile`, `age`. Height/weight only if present—include **missing indicators**.  
- Train a GPU MLP with large batches & mixed precision. Optimize AUCPR and calibration.

### Step F — Evaluate on held-out years
- Report AUCPR, macro-F1, calibration (Brier score).  
- Inspect reliability curves and decision thresholds (e.g., `p_success ≥ 0.6`).

---



#Rules of thumb

Start with a guard (missing/dirty data → ABSTAIN).

Capture one idea per LF (e.g., “top-10 picks usually succeed”).

Prefer simple, monotonic conditions (ranges, thresholds).

If your rule feels like two rules, it probably is.

> Later, replace this with a proper label model to turn multiple LF votes into a calibrated `p_success`.

---

## 7) Common Pitfalls

- Using `games_played` or other outcomes in rules (leakage). Only use for evaluation and computing org quartiles on **past** years.
- Overly redundant rules. Keep LFs simple and mostly independent (pick-first, then position tweaks).
- Ignoring missingness. If you later include height/weight, add **missing indicators** and avoid hard thresholds when data is sparse.
- Not splitting by year. Always evaluate on future years.

---

## 8) TL;DR

1. Make `pick_tier`, `pos_group`, (optionally) `org_quartile` from your CSV.  
2. Apply Level 1 (pick) + Level 2 (position) rules to create weak votes.  
3. Combine into `p_success` (label model) or use the deterministic mapping above for a first pass.  
4. Train per-position models or one model with interactions.  
5. Evaluate on later years; convert probabilities to fair odds for betting.

That’s it — you can now interpret and apply the tags confidently on your dataset.
