# POPCDM Design Note

This is a living note for linking the POPCODE + CDM model to our continuous color reproduction task.
Update this document progressively as implementation and model assumptions evolve.

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
  - `popcdm300(P, nw, h, tmax)` wrapper with POPCODE mixing and Ter/St handling.

- `trial_gen.R`
  - Trial construction layer (editable design factors):
  - `gen_trial(...)` for one trial,
  - `validate_design(...)`, `make_conditions(...)`, `gen_trial_table(...)` for multi-condition blocks.

- `p_mapping.R`
  - Trial-to-parameter mapping layer:
  - `default_beta()`, `map_trial_to_params(...)`.

- `sim_runner.R`
  - Simulation execution layer:
  - `sim_one_trial(...)`, `sim_from_table(...)`,
  - returns full trial metadata + mapped parameters + sampled behavior (`response_deg`, `error_deg`, `rt`).

- `vis_sim.R`
  - Simulation visualization/summaries:
  - condition key helper, circular/error/RT summaries,
  - error histogram and RT histogram by condition,
  - side-by-side condition plot helper.

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

## 5) Mapping Task Factors -> Model Parameters (Working Hypotheses)

These are hypotheses to refine, not final commitments.

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

1. Define a trial generator for task design variables:
   - set size, spatial arrangement, target index, color assignment constraints.
2. Define a parameter-link function:
   - from condition/task factors to POPCDM parameters.
3. Generate synthetic trials with `popcdm300`.
4. Compare simulated and human summaries:
   - error histogram / circular stats,
   - RT quantiles,
   - conditional error-RT trends.

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

## 9) Trial -> Parameter Mapping Scaffold (Initial)

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
     - `baseline` (`redundant_n = 0`)
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
  - `response_deg`, `error_deg`, `abs_error_deg`, `rt`.

This schema allows direct:
- trial-level debugging,
- condition-level aggregation,
- observed-vs-simulated overlays for error and RT.

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

## 15) Session Handoff (Next-Day Resume)

This section is intended to let work continue from a different machine without chat history.

### Current code status

- POPCDM core/model scripts:
  - `besselFPT.R`
  - `popcode.R`
  - `popcdm300.R` (contains `cdm_core` + `popcdm300`)
- Trial generation:
  - `trial_gen.R`
  - includes `gen_trial`, `validate_design`, `make_conditions`, `gen_trial_table`
  - invalid condition combinations are filtered automatically.
- Parameter mapping:
  - `p_mapping.R`
  - includes `default_beta`, `map_trial_to_params`
- Simulation:
  - `sim_runner.R`
  - includes `sim_one_trial`, `sim_from_table`
  - outputs full trial info + parameters + behavior (`response_deg`, `error_deg`, `rt`)
- Visualization:
  - `vis_sim.R`
  - includes condition summaries and basic error/RT distribution plots

### Confirmed condition validity rules (implemented)

Let `N = itemN`, `R = redundantN`:
- `baseline`: `R = 1` (all unique)
- `homoR`: `R = N`, only meaningful for `N >= 2`
- `R_R` / `R_NR`: `N >= 3` and `2 <= R < N`

### Quick smoke-test sequence

```r
source("trial_gen.R")
source("sim_runner.R")
source("vis_sim.R")

design <- list(
  itemN = 1:6,
  mode = c("baseline", "R_R", "R_NR", "homoR"),
  preDur = c(0.2, 0.4),
  retDur = 0.8,
  min_sep = 30,
  even_positions = TRUE,
  redundantN = 1:6
)

x <- gen_trial_table(design, reps_per_cell = 50, seed = 42)
sim <- sim_from_table(x$trial_table)
sum_tab <- summarize_sim(sim)
head(sum_tab)
plot_cond_pair(sim, cond = unique(cond_key(sim))[1])
```

### Planned next step

- Keep current single-condition plotting tools.
- Next implementation target (deferred): multi-panel condition plotting helper.
- After that: start visual interface scaffolding (settings panel + model-state visualization panel).

