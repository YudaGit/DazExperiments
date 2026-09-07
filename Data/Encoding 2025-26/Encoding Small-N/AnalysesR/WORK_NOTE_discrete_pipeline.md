# Experiment 1 (Small-N) — discrete pipeline work note

**Updated:** 1 Sep 2026 (pitstop — pipeline paused here)  
**Primary script:** `s1_smallN_analysis_discrete.Rmd`  
**Stan interface:** `s1_vm_ladder_stan.R`  
**Stan models:** `stan/vm_ladder_L0.stan`, `L1.stan`, `L2.stan`  
**Data:** `S1_smallN_model_ready.csv` (4 IDs × 10 sessions; ~4200 trials/ID)  
**IDs:** AQ→P01, HC→P02, YILIU→P03, YDL→P04

---

## Status (where we left off)

**Section 3 (VM ladder) is the active manuscript path.** Fitting complete for L0/L1/L2 × 2κ/14κ (20 slim caches, ~60 MB). Sections **3.4–3.6** implemented and debugged; re-knit from **`vm-ladder-setup`** when resuming.

| Section | Status | Notes |
|---------|--------|-------|
| 3.1 L0 | Done | Fit + κ plots (2κ/14κ) |
| 3.2 L1 | Done | Fit + κ/γ plots |
| 3.3 L2 | Done | Fit + κ/γ/β plots; **both 2κ and 14κ** fitted |
| 3.4 | Done | LOO + full cell params + session offsets/changes |
| 3.5 | Done | Theory contrasts + plots (fixed `kappa_struct` filter + empty-facet bug) |
| 3.6 | Done | PPC: all sessions pooled, L0/L1/L2 overlay + dashed components |
| 4 cirSD brms | **Deprecated** | Keep in Rmd for now; not for manuscript |
| 7–11 MLE | Unchanged | Reliability checks |

**Primary model choice (provisional):** L2 **2κ** for P01–P03; **L1 2κ** for P04 (L2 adds no LOO gain, β ≈ 0).

---

## Analysis path (manuscript)

1. **Descriptive** — cirSD / RT by cue × duration (Section 2).  
2. **Primary inference** — hierarchical **SignedErr von Mises mixture ladder** (Stan, Section 3).  
3. **Reliability / MLE checks** — mixture cells, simple VM, κ free vs tied (Sections 7–11).

**Dropped for manuscript:** AbsErr Student-t brms ladder (wrong scale for circular errors).  
**Dropped for manuscript:** cirSD brms (Section 4) — duration/cue effects are composition-driven; generative VM models supersede regression on cell summaries.

---

## VM ladder (Stan) — design

| Level | Components | κ structure | Key parameters |
|-------|------------|---------------|----------------|
| **L0** | VM(0, κ) only | 2κ or 14κ | `log_kappa_base`, session offsets |
| **L1** | VM + uniform guess γ | 2κ or 14κ | + `gamma_cd_logit` per Cue×Duration cell |
| **L2** | VM + swap β + guess γ | 2κ or 14κ | + `beta_cd_logit`, `gfrac_cd_logit` (γ = (1−β)×gfrac) |

Session 1 = reference; session offsets on log-κ (L0–L2) and logit-γ/β (L1–L2).  
LOO/WAIC for model comparison; cell params exported with median + 95% CrI.

---

## Model comparison (LOO)

### L0: 2κ vs 14κ (indicative — no guess component)
14κ wins all four (ΔLOO 22–57). **Not used to choose κ** — extra κ soaks misspecification.

### L1: 2κ vs 14κ
Split 2–2; all ΔLOO < 14 (within SE). **→ 2κ preferred** (parsimony).

### L2: 2κ vs 14κ
14κ nudges ahead for P01–P03; P04 favours 2κ. All ΔLOO small vs SE (~68–85):

| ID | Better | ΔLOO (2κ − 14κ) |
|----|--------|-----------------|
| P01 | 14κ | 1.6 |
| P02 | 14κ | 4.1 |
| P03 | 14κ | 16.4 |
| P04 | **2κ** | 5.3 |

Same story as L1: **2κ preferred** for parsimony.

### Cross-level (best LOO per ID, from slim cache)
| ID | Best overall | L2 − L1 (elpd, 2κ) |
|----|--------------|---------------------|
| P01 | L2_14k | +19.6 (L2_2k) |
| P02 | L2_14k | +12.9 (L2_2k) |
| P03 | L2_14k | +31.9 (L2_2k) |
| P04 | **L1_2k** | L2 −5.5 (worse) |

L0→L1: huge gain (+357 to +784 elpd) from adding γ.  
L1→L2: clear gain for P01–P03 from swap β; **P04 unchanged / slightly worse** (β ≈ 0.05 NR, swap negligible).

---

## Primary parameters (L1 2κ, pooled over duration & session)

| ID | Cue | κ [CrI] | circSD | γ [CrI] |
|----|-----|---------|--------|---------|
| P01 | NR | 4.3 [3.4–5.3] | 30° | 0.24 [0.16–0.35] |
| P01 | R | 14.1 [11.7–17.1] | 15° | 0.04 [0.02–0.08] |
| P02 | NR | 4.8 [3.9–5.8] | 28° | 0.16 [0.09–0.26] |
| P02 | R | 10.7 [8.8–12.7] | 18° | 0.04 [0.02–0.08] |
| P03 | NR | 7.9 [6.3–9.9] | 21° | 0.32 [0.23–0.42] |
| P03 | R | 32.4 [26.3–39.9] | 10° | 0.04 [0.02–0.08] |
| P04 | NR | 1.6 [1.1–2.3] | 56° | 0.42 [0.22–0.59] |
| P04 | R | 9.4 [7.3–11.9] | 19° | 0.11 [0.07–0.19] |

**Pattern:** R ≫ NR in κ; γ much higher for NR (esp. P04). Under **2κ**, NR duration effect mainly via **γ↓** (50→350 ms), not κ.

---

## L2 2κ (pooled summary)

| ID | Cue | κ | γ | β (swap) | p(target) |
|----|-----|---|---|----------|-----------|
| P01 | NR | 4.5 | 0.14 | 0.09 | 0.77 |
| P01 | R | 14.6 | 0.04 | 0.02 | 0.95 |
| P02 | NR | 4.9 | 0.08 | 0.06 | 0.85 |
| P03 | NR | 7.8 | 0.16 | 0.12 | 0.70 |
| P04 | NR | 1.8 | 0.40 | 0.05 | 0.55 |

NR 50 ms → 350 ms (S1, L2): γ falls (P01 0.15→0.10; P04 0.44→0.23); β small except P03 (~0.30 at 50 ms).

---

## Section 3 exports & chunks

### 3.4 — comparison + parameters + session
Writes (reload without refit):

| File | Content |
|------|---------|
| `vm_ladder_best_2k.csv` | Best 2κ model per level × ID |
| `vm_ladder_cross_level_loo.csv` | All 6 models × 4 IDs |
| `vm_ladder_all_cell_params.csv` | **3360 rows** — every Cue×Duration×Session cell, all models |
| `vm_ladder_session_offsets.csv` | S2–S10 offsets on κ, γ, β |
| `vm_ladder_session_cell_change.csv` | S10 − S1 per cell |

### 3.5 — theory contrasts
| File | Content |
|------|---------|
| `vm_ladder_theory_contrasts.csv` | Gain (R−NR), duration (350−50), session (S10−S1) on κ/γ/β |

Plots: duration contrast by cue (2κ); γ gain R−NR by duration.

### 3.6 — posterior predictive checks
- **All sessions pooled** (~300 trials/cell)
- **16 panels:** rows = NR/R × 50/350 ms; columns = P01–P04
- **Solid:** L0 / L1 / L2 mixture PDF (purple / green / orange)
- **Dashed:** components (target, uniform, swap1–3); colour = model level
- Helpers: `vm_ppc_pooled_cell()`, `vm_ppc_compare_levels()` in `s1_vm_ladder_stan.R`

---

## Interpretation notes (for when you return)

1. **14κ κ still varies by duration in L1/L2** — L1 and L2 14κ κ plots look nearly identical; span often *larger* than L0 (removing γ reveals sharper conditional target VM). LOO does not penalise enough to prefer 2κ structurally, but **2κ is the parsimonious choice**; NR duration → γ (and β at L2).

2. **Asymmetric κ (next model variant):** 2κ for R (flat across duration); for NR either duration-varying κ *or* a **linear log-κ trend** (2 params vs 7 free) — duration already carried by γ under current 2κ.

3. **Session:** enters as additive offsets; γ session effects can be substantial; see `vm_ladder_session_offsets.csv` and cell-level S10−S1 table.

4. **PPC:** check NR 50 ms heavy uniform tails; L2 swap bumps at ±120° for misfit at specific hues.

---

## Compact claims

1. **Generative VM mixture** on SignedErr is the primary model; AbsErr Student-t and cirSD regression are superseded.  
2. **γ (guess)** separates NR broad error from R precision; duration mainly reduces guessing on NR.  
3. **2κ** sufficient once γ (and β) in model; 14κ L0 advantage was misspecification.  
4. **Swap (β)** improves LOO for 3/4 IDs; optional for P04 (YDL).  
5. **Next refinement:** asymmetric κ for NR; interpret 3.5 contrasts + 3.6 PPC for manuscript figures.

---

## Cache (slim, Sep 2026)

Full Stan chain CSVs **removed** (~32 GB → **~60 MB**).  
Each fit folder keeps `fit_meta.rds` only:

- `param_draws`, `cell_params`, `loo`, `waic`, `summary`, `prep`, `stan_data`  
- Reload via `vm_load_fit_cache(raw, level, kappa_struct)` or `readRDS(.../fit_meta.rds)`  
- New fits auto-slim via `slim_vm_fit_meta()` in `fit_vm_stan()`  
- Batch cleanup: `prune_vm_stan_cache()`

| Product | Path |
|---------|------|
| LOO tables | `bayes_primary_discrete/vm_ladder_L{0,1,2}_loo.csv` |
| Cross-level LOO | `bayes_primary_discrete/vm_ladder_cross_level_loo.csv` |
| Full cell params | `bayes_primary_discrete/vm_ladder_all_cell_params.csv` |
| Theory contrasts | `bayes_primary_discrete/vm_ladder_theory_contrasts.csv` |
| Session tables | `vm_ladder_session_offsets.csv`, `vm_ladder_session_cell_change.csv` |
| Slim fits | `bayes_primary_discrete/vm_stan/{ID}_{L0\|L1\|L2}_{2k\|14k}/fit_meta.rds` |
| MLE mixture (reliability) | `mixture_cells/`, `bayes_primary_discrete/mixture_kappa_*` |

---

## Resume checklist

1. Open `s1_smallN_analysis_discrete.Rmd`; run **`vm-ladder-setup`** (sources updated `s1_vm_ladder_stan.R`).  
2. Skip refit chunks 3.1–3.3 unless models change — load from slim cache.  
3. Run **3.4** → **3.5** → **3.6** for tables/plots/exports.  
4. Review PPC panels and theory contrasts; draft figure captions.  
5. Optional: comment out or remove Section 4 from knit path.  
6. Optional: fit **asymmetric κ** Stan variant (NR duration trend, R pooled).  
7. Manuscript figures: likely L2 2κ (P01–P03), L1 2κ (P04); descriptives from Section 2.

---

## Bugs fixed this session (Sep 2026)

| Issue | Fix |
|-------|-----|
| `kappa_struct` missing in theory contrasts | Added to `vm_theory_contrasts()` mutate |
| 3.5 empty facet (`dur350` filtered out) | Broadened contrast filter; fixed duration/cue parsing |
| PPC single session (n=30) | `vm_ppc_pooled_cell()` — all sessions, trial-weighted PDF |
| PPC polar + ad-hoc scale | Linear axis; radian→degree density; L0/L1/L2 overlay |
| Parallel fit `model_id` bug | PSOCK cluster |
| L2 param extraction | Fixed `beta_*`, `gfrac_*` names |
| Cache bloat | Slim `fit_meta.rds`; chain CSVs pruned |

---

## Prior exploratory step (not for manuscript)

AbsErr Student-t brms ladder (L0–L2 on |error|) — replaced because VWM errors are circular and heavy tails reflect mixture components, not outliers.
