# Adoption plan: MATLAB-style fitting procedure → R `popcdm` + custom data

This document translates the **JayGuExperiment1** workflow (parameter vector `P`, selector `Sel`, objective assembly, and two-stage optimisation) into a repeatable plan for your **R** implementation and **your own trial layout** (e.g. Redundancy 2024 long-format CSV). Copy this file into your target R project repository when you start implementation.

---

## 1. What to replicate (conceptual contract)

You are **not** porting the 2×4 data cell layout. You **are** porting these ideas:

| Concept | Role |
|--------|------|
| **Full parameter vector `P`** | Fixed length `np`; each index has a documented meaning (drift, κ, η, ψ, bias, `Ter`, variability, β, … per *your* model). |
| **Binary selector `Sel` (length `np`)** | `1` = free (passed to optimiser), `0` = fixed (held at values in `Pfix`). |
| **`Pvar` / `Pfix` split** | Optimiser updates only `Pvar`; every likelihood evaluation **rebuilds** `P` with `P(Sel==1) <- Pvar`, `P(Sel==0) <- Pfix`. |
| **Structural constraints** | Equalities between parameters (shared `Ter`, one β, linked κ via power law, etc.) enforced **inside** the likelihood after unpacking `P`, keyed off `Sel` or explicit model flags—not only by the optimiser. |
| **Scalar objective** | One number per call: typically **negative log-likelihood** (NLL) to **minimise**, or LL to **maximise**—pick one convention and use it consistently in R and when comparing to MATLAB. |
| **Bounds** | Box constraints on **free** parameters only; optional **soft** “preferred” region vs **hard** numerical fences (see `jgjp5.m` penalty logic). |
| **Two-stage optimisation** | (A) global / bounded search with weak priors on range; (B) local polish from the best point. |

**Reference implementation files (this repo):**

- `jgjp5.m` — unpack `P`, apply `Sel`-driven constraints, compute objective and predictions.
- `setopt.m` — `fminsearch` options (Nelder–Mead polish).
- `set_jgjp5.m` — `particleswarm` + hybrid `fmincon`; anonymous wrapper `x ↦ jgjp5(x, Pfix, Sel, Data)`.
- `JayGuNotesExperiment1.txt` — narrative on simplex vs swarm syntax and `Sel` example.

---

## 2. Your data side (independent of MATLAB layout)

**Source example:** `Data/Redundancy 2024/data2_final.csv` (long format, one row per trial).

**Trial-level quantities for a circular CDM + RT joint model** (align with your `popcdm` spec):

- **Stimulus angle** (radians, consistent with generative model): e.g. from `target_angle_norotation` after `deg2rad` and your convention for signed principal values.
- **Signed angular error** (radians): from `response_error` (degrees) via `atan2(sin(θ), cos(θ))` after `deg2rad`, *or* equivalent definition verified against `response_derotated_degress` and target (wrapped difference).
- **RT (seconds):** `response_RT / 1000` if stored in ms.
- **Design factors** for mapping trials to parameters: e.g. `uid`, `session`, `num_itemsi`, `redundanti`, `Cnd`, `Gestalt` (note: `Gestalt` is NA for redundant trials in that CSV—decide drop vs separate model stratum).

**Deliverable:** a small R module that:

1. Reads and cleans trials (exclusion flags: `too_fast_trigger`, `too_slow_trigger`, `started_outof_center`, etc.).
2. Builds **your** design index: either a **cell-like nested structure** (`list` by factors) or a **tibble + key column** `cell_id`—whatever your likelihood loops over.
3. Documents **one row** of the internal trial matrix columns (stimulus, error, RT, optional fourth column) so it matches `popcdm` expectations.

No requirement to match Jay’s `2×4` `Data{i,j}`; only requirement is **your likelihood knows how to slice trials given `P`**.

---

## 3. Your model side (`popcdm` in R)

### 3.1 Define the parameter map

1. Choose **`np`** and a **named list or integer index contract** for `P[1:np]` (publish in `R/parameters.R` or roxygen in one place).
2. For each candidate model (nested variants), define:
   - default **`P`** (starting or fixed reference),
   - **`Sel`**,
   - any **internal copying rules** (same pattern as `jgjp5.m` lines ~81–157).

### 3.2 Single entry point for the objective

Implement one R function, e.g.:

```r
popcdm_nll(P_var, P_fix, sel, data, trace = FALSE)
```

Responsibilities:

- Reassemble full `P` from `P_var`, `P_fix`, `sel`.
- Apply structural constraints.
- Optionally apply penalties for out-of-box parameters (mirror hard/soft boxes if needed).
- Loop over **your** design cells (or trials with a lookup table), call **density / likelihood** for each trial, return **scalar** NLL (or LL—choose one).

Keep **prediction / post-fit summaries** (e.g. joint density slices for QQ plots) in a separate function or as optional outputs so optimisers only depend on the scalar.

### 3.3 Where the heavy math lives

- If `popcdm` already evaluates log-density in R: vectorise where possible; profile hot paths.
- If density is in **C/C++** (like `vjp300rot.c` here): define a thin **Rcpp** (or `.Call`) boundary; keep **parameter packing** in R identical to this plan so you can debug without recompiling often.

---

## 4. Optimisation in R (map from MATLAB)

### 4.1 Stage A — bounded global / multi-start

MATLAB analogue: `particleswarm` with `Lb`, `Ub` on **free** parameters only (`set_jgjp5.m`).

R options (pick one to start):

- **`DEoptim::DEoptim`** — box bounds, no gradients, parallel `DEoptim.control(parallel = TRUE)`.
- **`nloptr`** with a global algorithm (e.g. `NLOPT_GN_ORIG_DIRECT`) — if you prefer deterministic global search on low–moderate dimension.
- **Manual multi-start:** sample `P_var` inside box, run many **`optim(..., method = "Nelder-Mead")`** or **`nlminb`**, keep best.

**Checklist:**

- [ ] Box bounds vector same length as `sum(sel == 1)`.
- [ ] Objective wrapper `fn(par, ...) <- popcdm_nll(par, P_fix, sel, data)`.
- [ ] Time or iteration budget (MATLAB used `MaxTime` ~ hours; scale to your cost).

### 4.2 Stage B — local polish

MATLAB analogue: `fminsearch` after good starts; `fmincon` as hybrid in swarm.

R options:

- **`optim(par, fn, ..., method = "Nelder-Mead")`** — matches “simplex” spirit; pass `P_var` from Stage A.
- **`nlminb`** — if you can supply rough box and want faster local convergence on smooth-ish regions.
- If you add **analytic gradients** later: **`optim(method = "L-BFGS-B")`** or **`nloptr`** with gradient-based local method.

**Checklist:**

- [ ] Start from **best** `P_var` of Stage A.
- [ ] Tighten tolerances compared to global stage (`setopt.m` uses `TolFun`/`TolX` ~ 1e-2; you may go tighter after profiling).
- [ ] Re-evaluate full `P` and compute AIC/BIC (or WAIC) using **same** `np` and `sum(sel)` convention as in `set_jgjp5.m` (`Stat` line) if you want cross-language comparability.

### 4.3 Identifiability and scale

- [ ] **Parameterise on a scale optimisers like** (e.g. log σ, log κ if strictly positive).
- [ ] **Check** label-switching / multimodality with **multiple random seeds** or swarm particles.
- [ ] Save **full `P`**, **`Sel`**, **`Pfix`**, **data hash / path**, **R version**, **package versions** for each fit.

---

## 5. Verification layer (before trusting fits)

1. **Simulation round-trip:** sample data from `popcdm` at known `P_true`; recover parameters within tolerance under the same `Sel`.
2. **Objective sanity:** at `P_true`, NLL should beat random `P`; gradient-free bump test (finite differences on a few coordinates).
3. **Cross-check one trial cell:** hand-compute one trial’s log-density if possible, compare to R output.
4. **MATLAB optional:** if you keep a reference MEX, compare one `P` on a **shared small subset** of trials (same stimulus/error/RT arrays).

---

## 6. Suggested implementation order (milestones)

| Phase | Goal | Done when |
|-------|------|-------------|
| **M0** | Parameter contract | `np`, names, `Sel` examples documented; one “full” `P` vector on paper or in `inst/extdata/` YAML/CSV. |
| **M1** | Data → internal format | Script loads your CSV (or RDS), filters trials, attaches `cell_id` / nested lists; unit tests on row counts per design. |
| **M2** | Likelihood only | `popcdm_nll` returns finite scalar on clean data; no optim yet. |
| **M3** | Local fit | `optim(Nelder-Mead)` from hand-picked `P_var`; curve improves vs random start. |
| **M4** | Global + hybrid | `DEoptim` (or chosen) → `optim` polish; parallel if worthwhile. |
| **M5** | Inference / export | Save `Pest`, AIC/BIC, optional `Pred`; plotting helpers for RT and angular marginals. |
| **M6** | Hierarchical / multi-subject** (optional) | If needed: extend `P`/`Sel` per subject or use partial pooling in a second layer—outside scope of the MATLAB script but plan here if on roadmap. |

---

## 7. Files to copy alongside this plan (optional reference bundle)

When moving to your R project, you may want copies of:

- This plan: `R_POPCDM_ADOPTION_PLAN.md`
- `JayGuNotesExperiment1.txt` (narrative)
- Snippets of `jgjp5.m` (parameter block + `P` assembly + penalty block) for side-by-side review

You do **not** need to copy `.mat` data or MEX binaries unless you intend to run MATLAB parity checks.

---

## 8. Open decisions (fill in as you adapt)

- [ ] **Objective sign:** minimise NLL vs maximise LL (document in README).
- [ ] **Hierarchical structure:** single-subject fits first vs mixed / partial pooling.
- [ ] **Random effects:** none (fixed `P` per subject) vs future extension.
- [ ] **Parallel:** `parallel::mclapply` / `future` for multi-start or per-subject fits.
- [ ] **Reproducibility:** `set.seed` strategy per chain / subject.

---

## 9. Revision log

| Date | Note |
|------|------|
| 2026-05-14 | Initial plan from JayGuExperiment1 review + Redundancy 2024 CSV structure. |

---

*End of plan. Next step in your R repo: implement M0–M2, then run M3 on a single subject and one design subset before scaling to full data.*
