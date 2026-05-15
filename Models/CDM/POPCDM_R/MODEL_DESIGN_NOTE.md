# POPCDM Design Note

This is the **reference note** for linking the POPCODE + CDM model to our continuous color reproduction task, and for resuming work (simulation, diagnostics, **model fitting**).

Update this document as implementation and assumptions evolve.

## 1) Task Summary (Current Understanding)

- Participants encode an array of color patches presented on an invisible spatial ring around fixation.
- Ring geometry: approximately 5 deg visual angle diameter (2.5 deg eccentricity).
- Patch arrangement can be:
  - evenly spaced, or
  - non-uniformly spaced.
- Set size varies by condition.
- Color assignment can be:
  - all unique, or
  - include exact repeats.
- After encoding, display is removed and followed by masking / retention delay.
- At test, one spatial location is cued and a color wheel is shown at fixation.
- Participant reports remembered color by selecting hue on the wheel.

Primary observed variables:
- Response error (circular difference between reported hue and target hue).
- Response time (RT).

## 2) Why POPCODE + CDM For This Task

- POPCODE provides a probabilistic representation over circular feature space (hue angle).
- CDM provides dynamics for continuous report and RT, producing joint predictions over:
  - error angle, and
  - decision time.
- Combined POPCDM links memory representation quality and competition (POPCODE) to report/RT behavior (CDM).

Intuition:
- POPCODE shapes where drift is likely to point in angular space.
- CDM turns that directional evidence into a response distribution and timing.

## 3) Model Components in This Repo

- `besselFPT.R`
  - Low-level first-passage time stack for radial process:
  - `findzero`, `besselzero`, `dhamana`, `dserafin`, `bessel2`.

- `popcode.R`
  - Feature-space component:
  - `vm(kappa, nw)` for von Mises density on angle bins.
  - `popcode(P, nw)` returning angle PMF (`pang`) from tuning + Gumbel mean baseline.

- `popcdm300.R`
  - Integrated POPCDM script:
  - helper circshift functions,
  - `cdm_core(P, nw, h, tmax)` (no nondecision-time convolution),
  - `popcdm300(P, nw, h, tmax, return_components = FALSE)` wrapper with POPCODE mixing and Ter/St handling.
  - Optional `return_components = TRUE`: returns `Pang` and per-source-bin `Ptheta_components` matrix (for decomposition plots).

- `trial_gen.R`
  - Trial construction layer (editable design factors):
  - `gen_trial(...)` for one trial,
  - `validate_design(...)`, `make_conditions(...)`, `gen_trial_table(...)` for multi-condition blocks.

- `p_mapping.R`
  - Trial-to-parameter mapping for **population scaling only** (see §16):
  - `default_beta()` — baselines for `baseAlpha`, `baseKappa`, and fixed CDM scalars (`vnorm`, `eta1`, `eta2`, `a`, `ter`, `st`),
  - `map_trial_to_params(trial, beta, pop_tune = c("alpha","kappa"))`.

- `sim_runner.R`
  - Simulation execution layer:
  - `cond_key()` for grouping plots,
  - optional **smoothed** joint sampling from `Gt` before inverse-CDF draw,
  - `sim_mode = "error_only"` vs `"response"` (see §17),
  - `sim_from_table(..., reuse_dist = TRUE)` — one `popcdm300` per distinct `(itemN, mode, redundantN, pop_tune)` then many draws,
  - `sim_one_trial(...)`,
  - ggplot-oriented helpers: `plot_cond_pair`, `plot_all_cond_pairs` (base graphics; prefer `Simulation01.Rmd` for slides).

- `vis_sim.R`
  - Lightweight summaries on `sim_from_table` output (optional): `summarize_sim`, histogram helpers (uses `cond_key` without `pop_tune`; extend if needed).

- **Notebooks / demos**
  - `popcdm_figure_walkthrough.Rmd` — ggplot walkthrough of `pang`, `Ptheta` / RT decomposition, `Gt` heatmap/contour/3D, slide-style captions in prose above chunks.
  - `Simulation01.Rmd` — end-to-end trial table → `sim_from_table` → ggplot faceted error/RT histograms (custom label map and panel order).
  - `popcdm300_demo.Rmd` — earlier structural checks.
  - `TempTest.R` — minimal script mirror of a simulation run (parameters may drift from `Simulation01.Rmd`; prefer one canonical file for fitting prep).

## 4) Current Parameterization

### POPCDM wrapper parameter vector

`P = c(vnorm, eta1, eta2, a, alpha, kappa, ter, st)`

- `vnorm`: drift norm (magnitude).
- `eta1`, `eta2`: radial / tangential drift variability terms.
- `a`: decision boundary / criterion.
- `alpha`: population coding tuning amplitude.
- `kappa`: von Mises concentration (tuning sharpness).
- `ter`: nondecision time mean component.
- `st`: nondecision time variability width (uniform convolution width).

### CDM core parameter vector

`Pi = c(v1, v2, eta1, eta2, sigma, a)`

With `sigma` fixed at 1.0 by scaling convention in current implementation.

## 5) Mapping Task Factors -> Model Parameters

**Implemented mapping (current code):** see **§16** (`p_mapping.R` — `colorN` scaling and `pop_tune`).

The bullets below remain **design hypotheses** for future extensions (e.g. fitting cue effects on `vnorm`, retention on `eta`, trial-dependent rotation of `pang`), not what `map_trial_to_params` currently implements.

- Set size increase may reduce representational precision:
  - likely affects `kappa` and/or `alpha`,
  - may also influence variability terms `eta1`, `eta2`.
- Similarity / crowding among colors may flatten or broaden angular representation:
  - candidate effects on `alpha`, `kappa`.
- Retention interval may degrade representation:
  - candidate effects on `kappa`, `eta1`, `eta2`, and maybe `vnorm`.
- Response/motor overhead conditions may shift nondecision parameters:
  - `ter`, `st`.

Open question:
- Which task manipulations should influence drift magnitude (`vnorm`) versus representational shape (`alpha`, `kappa`)?

## 6) Simulation Targets

The model should reproduce, condition-wise:
- Circular error distributions.
- Error dispersion / tail properties.
- RT distributions and error-RT relationship.

### RT as a primary behavioral output

RT is not secondary in this framework. POPCDM predicts a joint structure:
- angular report outcomes (`Ptheta` / slices of `Gt`), and
- temporal dynamics (`Gt` over time, `Mt` as conditional mean decision time).

Model interpretation:
- memory quality / representational competition affects both error and RT shape;
- nondecision parameters (`ter`, `st`) capture encoding/motor components not explained by accumulation alone.

## 7) Immediate Next Steps

1. **Model fitting:** define likelihood (continuous/circular error × RT), parameter vector, and optimizer loop; reuse `popcdm300` + `map_trial_to_params` (or successor).
2. Compare fitted vs human summaries by condition: circular error stats, RT quantiles, joint diagnostics.
3. Extend `p_mapping` / `pang` if needed: trial-dependent population code (target hue, layout) — see §13 and original roadmap.
4. Optional: multi-panel ggplot helpers consolidated from `Simulation01.Rmd` patterns.

## 8) Trial Matrix (Current Experiment) -> Simulation Inputs

Based on `TrialMatrix.m` currently in `POPCDM_R`:

- Set size is fixed:
  - `ItemN = 6`.
- Redundancy is fixed for this experiment:
  - `RedundantN = 3` (three items share an identical hue per trial).
- Cue type:
  - `CueType = 'R'` (target from redundant pool) or
  - `CueType = 'NR'` (target from nonredundant pool).
- Timing factors are explicit:
  - `PresDur`, `RetDur`.
- Color generation constraints:
  - one duplicate hue assigned to `R` positions,
  - remaining hues unique and minimum circular distance (`minDist = 30`) from duplicate and each other.
- Spatial arrangement:
  - equally spaced base positions with random start angle,
  - then position order shuffled per trial.

This gives an explicit trial-level design table that can feed simulation.

## 9) Trial -> Parameter Mapping (Historical Scaffold)

**Superseded for current simulations.** The regression-style mapping sketched below was an early placeholder. The repository now uses the **explicit `colorN` / mode rules** in **§16**.

For archival context, the earlier idea was:

For each trial, define:
- design variables `X` from TrialMatrix:
  - `ItemN`, `RedundantN`, `CueType`, `PresDur`, `RetDur`,
  - optional derived summaries (e.g., target-nontarget similarity around cued item).
- parameter transform `f(X; beta)` producing:
  - `P = (vnorm, eta1, eta2, a, alpha, kappa, ter, st)`.

Practical initial mapping (for current single-set-size experiment):

- Baseline free parameters:
  - `vnorm0, eta10, eta20, a0, alpha0, kappa0, ter0, st0`.
- Condition effects:
  - `alpha = alpha0 + b_alpha_cue * I(CueType='R') + b_alpha_ret * RetDur`
  - `kappa = kappa0 + b_kappa_cue * I(CueType='R') + b_kappa_ret * RetDur`
  - `vnorm = vnorm0 + b_v_pres * PresDur + b_v_ret * RetDur`
  - `eta1, eta2` optionally modulated by retention (memory noise growth).
  - `ter = ter0 + b_ter_pres * PresDur`
  - `st = st0` (or condition-specific if needed)

Constrain via transforms:
- positive params (`vnorm`, `eta1`, `eta2`, `a`, `kappa`, `ter`, `st`) via exp/softplus or lower bounds;
- `alpha` can be bounded to meaningful range if needed.

Note:
- with `ItemN=6` fixed, set-size effects are not identifiable in this dataset and should be held constant or deferred.
- `CueType` and timing factors are the first meaningful manipulators here.

## 10) Simulation Pipeline (Near-Term)

1. Read/generate trial table from TrialMatrix logic.
2. For each trial:
   - compute mapped parameter vector `P_trial`,
   - run `popcdm300(P_trial, nw, h, tmax)`.
3. Sample synthetic behavior:
   - sample `(theta, t)` from trial `Gt` grid, or
   - sample `theta` from `Ptheta` and `t` conditional on theta.
   - **Current implementation:** see **§17** (`sim_runner.R`: optional mass smoothing + inverse-CDF on flattened joint; `reuse_dist` batches same-`P` trials).
4. Convert to experiment-like outputs:
   - reported hue, circular error, RT.
5. Aggregate by condition:
   - error density, circular SD / precision,
   - RT quantiles and mean,
   - error-RT coupling.

### Current trial generation architecture

We now separate trial generation into two levels for flexibility and readability:

1. Single-trial generator:
   - `gen_trial(set_size, mode, pre_dur, ret_dur, min_sep, redundant_n, ...)`
   - supports:
     - `baseline` (`redundant_n = 1` — all unique hues under current convention)
     - `homoR` (`redundant_n = itemN`)
     - `R_R` and `R_NR` (`0 < redundant_n < itemN`)
2. Multi-condition block generator:
   - `gen_trial_table(design, reps_per_cell | n_trials_total, seed)`
   - design vectors can include:
     - `itemN` (e.g., 1:6),
     - `mode`,
     - `preDur`,
     - `retDur`,
     - `min_sep`,
     - spatial arrangement flag.

This keeps all experimental parameters editable and supports future UI control panels.

### Current redundancy and mode validity rules

For each trial, let `N = itemN`, `R = redundantN`:

- `baseline`:
  - valid when `R = 1` (effectively all unique hues).
- `homoR`:
  - valid when `R = N`, and only meaningful for `N >= 2`.
- partial redundancy (`R_R`, `R_NR`):
  - valid when `N >= 3` and `2 <= R < N`.

Condition generation behavior:
- full candidate combinations are generated from design vectors,
- invalid combinations are filtered out automatically,
- generator warns with dropped/kept counts.

This supports single unified design specs (e.g., `itemN = 1:6`, full mode list) without manual splitting.

## 11) Visualization Roadmap (Keep In Mind)

Planned visualizations for simulation diagnostics and manuscript figures:

- Model-state plots:
  - `Ptheta` overlays by condition,
  - `Gt` heatmaps (theta x time),
  - `Mt(theta)` curves.
- Behavioral overlays:
  - observed vs simulated error distributions,
  - observed vs simulated RT quantiles / CDF,
  - conditional RT by absolute error bins.
- Trial-structure views:
  - color layout and target type (`R`/`NR`) examples,
  - similarity summaries vs predicted parameter changes.

Implementation note:
- Keep these visualizations scriptable and reproducible from the same trial table + parameter map.

## 12) Simulation Output Schema (Current)

Simulation outputs are designed for verification and manuscript-ready analyses.
Per simulated trial, keep:

- Condition factors:
  - `itemN`, `mode`, `redundantN`, `cue_type`, `preDur`, `retDur`, `min_sep`.
- Full trial definition:
  - `hues` (all item hues),
  - `loc_deg` (all item locations),
  - `is_redundant` (logical mask),
  - `target_idx`, `target_hue`, `target_loc_deg`.
- Mapped model parameters:
  - `vnorm`, `eta1`, `eta2`, `a`, `alpha`, `kappa`, `ter`, `st`.
- Simulated behavior:
  - `response_deg` (may be `NA` in `sim_mode = "error_only"`),
  - `error_deg`, `abs_error_deg`, `rt`.

This schema allows direct:
- trial-level debugging,
- condition-level aggregation,
- observed-vs-simulated overlays for error and RT.

## 16) Current trial → P mapping (`p_mapping.R`)

**Purpose:** vary only the **population layer** (`alpha` or `kappa`) with a simple deterministic rule from trial structure; keep **`vnorm`, `eta1`, `eta2`, `a`, `ter`, `st`** at values supplied in `default_beta()` / per-run `beta` list.

**Definitions:**

- `colorN = itemN - redundantN + 1` (distinct-color count under `trial_gen` conventions).

**Scaling factor** applied to the **tuned** parameter (`pop_tune`):

- **Baseline, `R_NR`, `homoR`:** `scale = 1 / sqrt(colorN)`.
- **`R_R`:** `scale = 1 / sqrt(colorN) * sqrt(redundantN)`.

**`pop_tune`:**

- `"alpha"`: `alpha = baseAlpha * scale`, `kappa = baseKappa` (fixed at base).
- `"kappa"`: `kappa = baseKappa * scale`, `alpha = baseAlpha` (fixed at base).

**API:**

- `default_beta()` — named list with `baseAlpha`, `baseKappa`, `vnorm`, `eta1`, `eta2`, `a`, `ter`, `st`.
- `map_trial_to_params(trial, beta = default_beta(), pop_tune = c("alpha","kappa"))` — `trial` is a list or row-compatible structure with `set_size`, `redundant_n`, `mode`.

**Fitting note:** treat `baseAlpha`, `baseKappa`, and/or fixed CDM scalars as free parameters; extend `map_trial_to_params` if likelihood needs cue- or timing-specific shifts beyond this scaffold.

## 17) Simulation runner (`sim_runner.R`)

**Outputs:** per-trial dataframe with design factors, mapped `P`, list columns for trial layout, and draws `error_deg`, `rt`, etc.

**Key behaviors:**

1. **`reuse_dist` (default `TRUE`):** groups trials by `(itemN, mode, redundantN, pop_tune)` (via `pop_params_key`), runs **`popcdm300` once** per group, draws **N** independent `(theta, t)` samples from the same joint.

2. **Sampling:** builds discrete cell masses proportional to `Gt * Δθ * Δt`, optionally **Gaussian-smoothed** on the mass matrix (`smooth_gt`, `smooth_theta_bw`, `smooth_time_bw`), then **inverse-CDF** sampling using `U ~ Uniform(0,1)` on the flattened distribution (equivalent in distribution to one multinomial draw per trial).

3. **`sim_mode`:**
   - `"error_only"`: `error_deg` from sampled model angle (wrapped); `response_deg = NA` (no target-hue addition).
   - `"response"`: reconstructs wheel `response_deg` from `target_hue` + sampled angle, then `error_deg` vs target.

4. **`cond_key(sim_df)`:** concatenates `itemN`, `mode`, `redundantN`, `cue_type`, `preDur`, `retDur` for faceting (does not include `pop_tune`; add if comparing alpha vs kappa runs on one table).

## 18) Diagnostic figures (notebooks)

- **`popcdm_figure_walkthrough.Rmd`:** ggplot panels for `pang`, per-bin `Ptheta` components (optional `return_components = TRUE` in `popcdm300`), weighted sums, `Gt` heatmap/contour/**3D** (`persp`) in appendix; prose captions above chunks for slides (plots omit ggplot titles where requested).

- **`Simulation01.Rmd`:** reproducible simulation strip matching interactive experiments — `gen_trial_table` → `sim_from_table` with explicit `beta`, `label_map` / panel order for ggplot facets.

- **`popcdm_v_eta_visual.R`:** compares `cdm_core` behavior under different `eta1`/`eta2` with fixed canonical drift.

## 19) Model fitting — starting point

**Likelihood object:** for a trial (or condition cell) with fixed `P`, `popcdm300` returns joint `Gt(θ,t)` on a grid. Fitting typically requires:

- **Data:** trial-level or binned `(error_deg, rt)` or marginals / condition summaries.
- **Link:** `trial → P` via `map_trial_to_params` (current) or an extended parameterization.
- **Predicted density:** evaluate `Gt` (or smoothed grid) at observed `(θ, t)` with interpolation, or integrate over bins; align **θ** with **error** convention (`error_only` vs absolute hue).
- **Optimization:** wrap negative log-likelihood; consider **`reuse_dist`** pattern inside the objective when many trials share the same `P`.

**Code anchors:** `popcdm300.R`, `p_mapping.R`, `sim_runner.R` (`gt_joint_probs` mass construction), `get_likelihood.R` if extended for data formats.

**Open for implementation:** formal likelihood module, parameter transforms for positivity, hierarchical structure across subjects/conditions.

## 13) Open Questions Log

- [ ] Should color-space manipulations primarily alter `alpha`, `kappa`, or both?
- [ ] Best parameterization for set-size effects (shared vs condition-specific parameters)?
- [ ] Do we need explicit swap/guess components outside POPCDM, or can POPCODE mixture absorb these behaviors?
- [ ] Which diagnostics best separate roles of `eta1` vs `eta2` in this task?
- [ ] For this experiment, does `CueType='R'` mainly change precision (`kappa`) or drift competition (`alpha`)?
- [ ] Best sampling strategy from `Gt` for stable synthetic RT tails.

## 14) Change Log

- 2026-04-30: Initial draft created. Captured task-model linkage and progressive plan.
- 2026-04-30: Added explicit RT role, TrialMatrix-derived trial factors, initial trial-to-parameter mapping scaffold, simulation pipeline, and visualization roadmap.
- 2026-04-30: Added modular trial-generation architecture (`trial_gen.R`) for editable set size, array makeup modes, timing factors, and multi-condition trial blocks.
- 2026-04-30: Added explicit redundancy validity rules and invalid-condition filtering strategy.
- 2026-04-30: Added simulation runner layer and trial-wise output schema for full verification (factors + arrays + params + behavior).
- 2026-04-30: Added `vis_sim.R` for condition-wise response-error and RT distribution visualization.
- 2026-05: Replaced trial→P mapping with **`colorN` / mode scaling** (`p_mapping.R`); added **`pop_tune`**, **`reuse_dist`**, **`sim_mode`**, optional **`Gt` mass smoothing**, inverse-CDF sampling (`sim_runner.R`).
- 2026-05: Extended **`popcdm300(..., return_components = TRUE)`** for per-bin `Ptheta_components` diagnostics.
- 2026-05: Added **`popcdm_figure_walkthrough.Rmd`**, **`Simulation01.Rmd`**, **`popcdm_v_eta_visual.R`**; design note updated as fitting reference (§16–§19).

## 15) Session Handoff (Next-Day Resume)

This section is intended to let work continue from a different machine without chat history.

### Current code status

- POPCDM core/model scripts:
  - `besselFPT.R`
  - `popcode.R`
  - `popcdm300.R` (contains `cdm_core` + `popcdm300`, optional `return_components`)
- Trial generation:
  - `trial_gen.R`
  - includes `gen_trial`, `validate_design`, `make_conditions`, `gen_trial_table`
  - invalid condition combinations are filtered automatically.
- Parameter mapping:
  - `p_mapping.R`
  - includes `default_beta`, `map_trial_to_params` (`colorN` / `R_R` scaling, `pop_tune`)
- Simulation:
  - `sim_runner.R`
  - includes `sim_one_trial`, `sim_from_table`, `cond_key`, optional `Gt` smoothing, `sim_mode`, `reuse_dist`
  - outputs full trial info + parameters + behavior (`error_deg`, `rt`, etc.)
- Visualization:
  - `vis_sim.R`
  - includes condition summaries and basic error/RT distribution plots
  - Notebooks: `popcdm_figure_walkthrough.Rmd`, `Simulation01.Rmd`

### Confirmed condition validity rules (implemented)

Let `N = itemN`, `R = redundantN`:
- `baseline`: `R = 1` (all unique)
- `homoR`: `R = N`, only meaningful for `N >= 2`
- `R_R` / `R_NR`: `N >= 3` and `2 <= R < N`

### Quick smoke-test sequence

```r
source("trial_gen.R")
source("sim_runner.R")

design <- list(
  itemN = 1:4,
  mode = c("baseline", "R_R", "R_NR"),
  preDur = 0.4,
  retDur = 0.8,
  min_sep = 30,
  even_positions = TRUE,
  redundantN = 1:4
)

beta <- default_beta()  # or custom list matching p_mapping.R fields

x <- gen_trial_table(design, reps_per_cell = 50, seed = 42)
sim <- sim_from_table(
  x$trial_table,
  beta = beta,
  pop_tune = "alpha",
  sim_mode = "error_only",
  reuse_dist = TRUE
)
```

For ggplot diagnostics and custom facet labels, use **`Simulation01.Rmd`**. For model-structure figures, use **`popcdm_figure_walkthrough.Rmd`**.

### Planned next step

- Primary: **likelihood / fitting pipeline** (§19).
- Optional: unify `TempTest.R` with `Simulation01.Rmd` defaults to avoid parameter drift.

