# Cauchy-CDM theory testing — working notes

> **Consolidated project note:** `../POPCDM_CauchyCDM_master_work_note.md` is the primary cross-model theory, comparison, publication, and forward-work record. This file remains the detailed CauchyCDM route log.

Redundancy 2024 VWM data · lab IDs AQ, ES, HC, PG, YL · nine conditions  
S2C2, S4C2NR, S4C2R, S4C4, S6C2NR, S6C2R, S6C4NR, S6C4R, S6C6  
Filter: valid response error and RT 300–3000 ms.

## Theoretical role

The front layer is a distribution over latent CDM drift direction, not a standalone response-selection model. Jones–Pewsey ψ is fixed at −1, giving the wrapped-Cauchy distribution. This allows substantial directional tails without importing the POP/Gumbel-max response-selection operation into the CDM.

The wrapped-Cauchy parameter κ controls concentration. Increasing κ narrows the latent direction distribution and reduces far-tail mass. The model then mixes complete circular-diffusion first-passage distributions over those latent directions.

## Alterations from the supplied JP-CDM example

1. `vjp300rot.c` is specialized at compile time to ψ = −1. ψ was removed from the runtime MEX parameter vector and cannot be estimated accidentally.
2. The generic Jones–Pewsey evaluator was replaced by the algebraically equivalent wrapped-Cauchy density for ψ = −1.
3. Tangential drift variability is now a runtime MEX input rather than hard-coded at `0.01`; H0 fixes η₂ at `exp(−6)` to match the POPCDM decision skeleton.
4. The unsafe Bessel-switch loop now checks its array bound before indexing.
5. The 50 Bessel roots and J1 values are cached once per MEX process. This changes computation time, not predictions.
6. The example's four-condition stimulus-phase and categorical-bias machinery is not used. H0 models target-centred response error with no categorical bias.
7. Nondecision time is shared across conditions, matching the current POPCDM theory route, rather than condition-specific as permitted by the example.
8. Drift norm is grouped by set size S2/S4/S6. κ is free in each of the nine conditions.
9. Uniform nondecision-time convolution is vectorized without changing the model. The supplied wrapper loops over response-angle rows; the Cauchy wrapper uses MATLAB `conv2` to apply the same one-dimensional uniform kernel to the complete angle-by-RT matrix and truncates to the same 300-point time grid. Numerical comparison gave a maximum absolute density difference of `6.66e-16`; the convolution step was approximately 3.5 times faster in the pre-fit benchmark.
10. The optimization likelihood expands the 16-element H0 vector by direct numeric indexing. The reporting path still creates a labelled condition table, but table construction is excluded from the repeated objective calculation. This is a computational change only; the set-size and condition mappings are unchanged.

## H0 specification

Free parameters (16):

- v_S2, v_S4, v_S6
- shared η₁
- shared boundary a
- shared ter
- nine condition-specific wrapped-Cauchy κ values
- shared st

Fixed parameters:

- ψ = −1, compiled
- η₂ = `exp(−6)`
- σ = 1
- phase bias = 0

## Parameter boxes

The boxes follow the hard constraints in the supplied `vwmjp61.m` example, not the wider POPCDM boxes:

| Parameter | Lower | Upper | Reason |
|---|---:|---:|---|
| vnorm | 0 | 7.5 | JP-CDM hard box |
| κ | 0 | 7.5 | JP-CDM hard box |
| η₁ | 0.01 | 4 | hard box `[0,4]`, raised to compiled floor |
| a | 0.5 | 5 | JP-CDM hard box |
| ter | 0 | 1.5 | JP-CDM hard box |
| st | 0 | 0.7 | JP-CDM hard box |

Initial values are v = 4, κ = 3, η₁ = 0.6, a = 4, ter = 0.25, and st = 0.15, informed by the supplied example fit.

## Fitting procedure

Full mode uses 16 bounded `fmincon` starts, interior-point optimization, 2,000 maximum iterations, 20,000 maximum function evaluations, and `1e−6` optimality/step/function tolerances. Starts run on seven parallel workers, the largest process pool verified to start reliably on this machine. This changes elapsed time only; all 16 starts are retained. Results checkpoint after every participant and resume only when the saved parameter layout and bounds match H0.

## Validation before fitting

- MEX compiled with Microsoft Visual C++ 2022 and static GSL 2.8.
- Retained joint mass: 0.9993.
- Circular symmetry error: `6.25e−16`.
- Tail mass decreases from .608 at κ = 0.5 to .010 at κ = 4.
- Obsolete input containing a runtime ψ is rejected.
- Cached forward call: approximately 12 ms.

## Diagnostics

Each participant receives observed/model angle-density and RT-density figures, central/shoulder/tail angle proportions, fixed-bin RT proportions, and a proportion CSV under `Figures/H0/`.

## Full-fit results

Completed 18 August 2026. Each participant was fitted with all 16 planned starts. All 80 `fmincon` runs returned a positive exit flag, and each selected minimum had exit flag 2. No run reached the 2,000-iteration limit; the largest observed count was 238 iterations.

| Participant | Trials | NLL | AIC | BIC | Elapsed min | Second-best NLL gap |
|---|---:|---:|---:|---:|---:|---:|
| AQ | 4,488 | 2,947.04 | 5,926.07 | 6,028.62 | 8.9 | 2.45 |
| ES | 4,488 | 1,005.32 | 2,042.64 | 2,145.19 | 8.0 | 0.28 |
| HC | 4,495 | 1,137.66 | 2,307.31 | 2,409.88 | 8.2 | 7.86 |
| PG | 4,492 | 2,780.45 | 5,592.91 | 5,695.47 | 8.3 | 8.18 |
| YL | 4,497 | 2,314.65 | 4,661.30 | 4,763.88 | 16.9 | 6.31 |

Only ES had two starts within 1 NLL unit of the selected minimum; each other participant had one. The selected minima are therefore valid winners of the planned multistart search, but the best basin was not repeatedly recovered within one NLL unit for four participants. Raw start-level estimates, NLLs, flags, iterations, and function counts remain in the result MAT file.

### Parameter-bound audit

All condition-specific κ estimates were interior. HC and YL were comfortably interior on every parameter. Two participants placed boundary separation effectively at the example-derived upper bound: AQ `a = 4.9992` and PG `a = 4.9995`, against an upper bound of 5. ES placed `v_S2 = 7.4724` near its upper bound of 7.5. These are genuine sensitivity flags for later bounded-box checks; the primary H0 fit was not silently rerun with wider bounds.

### Angle and RT diagnostics

Mean absolute observed-model proportion error across all participant-condition-bin cells was 0.0497 for response angle and 0.0224 for RT. Participant angle MAE ranged from 0.0463 to 0.0554; RT MAE ranged from 0.0167 to 0.0262.

The RT proportions are generally reproduced closely. The angle diagnostics reveal a recurring shape discrepancy: the model often places too much probability in the central `|error| <= 15 degrees` region and too little in the 15–45 degree shoulder, particularly for AQ's nonredundant conditions. The Cauchy front layer nevertheless captures substantial far-tail mass in broad conditions such as YL S6C4NR and S6C6NR. Thus H0 supports the usefulness of a heavy-tailed front layer, while also indicating that a single symmetric wrapped-Cauchy shape does not fully reproduce the empirical combination of peak, shoulder, and tail across conditions.

Machine-readable summaries are saved as `CauchyFits/cauchycdm_H0_fit_audit.csv`, `CauchyFits/cauchycdm_H0_parameter_estimates.csv`, and `CauchyFits/cauchycdm_H0_diagnostic_summary.csv`.

## Cross-model status (18 August 2026)

Cauchy H0 currently gives lower joint NLL than the best POP baseline for every participant while using one fewer parameter. The comparison is provisional because Cauchy was fitted with periodic angular closure and POP was fitted with an open grid at `+pi`. Under a conservative open-grid reevaluation of the existing Cauchy fits, its advantage remained 44--117 NLL points per participant. Both models require a common periodically closed likelihood and full refitting before publication-level AIC/BIC claims.

The Cauchy route currently has the cleaner process interpretation: its front layer is latent drift-direction variability rather than a completed response-selection mechanism. It remains a descriptive H0 with nine condition concentrations and does not yet explain redundancy effects. It may also share POPCDM's failure to predict slower tail responses because direction and drift norm remain independent. Full comparison logic and the expandable research roadmap are in `../POPCDM_CauchyCDM_master_work_note.md`.
