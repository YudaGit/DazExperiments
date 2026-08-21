# JPCDM theory testing -- working notes

> **Consolidated project note:** `../POPCDM_CauchyCDM_master_work_note.md` is the primary cross-model theory, comparison, publication, and forward-work record. This file is the detailed JPCDM route log.

Redundancy 2024 VWM data · lab IDs AQ, ES, HC, PG, YL · nine conditions

Filter: valid response error, RT 300--3000 ms.

Goal: fit unrestricted Jones--Pewsey front-end CDM baselines under the same current comparison skeleton used by POPCDM and CauchyCDM. JP is included as an unrestricted shape-family benchmark. It does not proceed to the POPCDM H1 scaling law here because POPCDM already outperformed the historical JP route at the H0 level, and the current JP role is to provide a harmonized H0a/H0b comparison.

## How to run

```matlab
cd JPCDM_Matlab

% Full current comparable fits
jp_fit_theory

% Or run one route
run_jpcdm_theory_fit("H0a", "full")
run_jpcdm_theory_fit("H0b", "full")

% Smoke checks
run_jpcdm_theory_fit("H0a", "smoke")
run_jpcdm_theory_fit("H0b", "smoke")
```

`ensure_jpcdm_mex` rebuilds `vjp300rot` when the MEX is absent or older than `vjp300rot.c`.

## Current comparable model skeleton

- joint participant-level angle and RT likelihood;
- same participant IDs and nine-condition order as POPCDM/CauchyCDM;
- valid response error and RT 0.3--3.0 s;
- three `vnorm` parameters grouped by set size: S2, S4, S6;
- shared radial drift variability `eta1`;
- tangential drift variability `eta2 = exp(-6)` passed at runtime;
- shared boundary `a`, nondecision time `ter`, and nondecision-time range `st`;
- diffusion scale fixed at 1 and JP centre `phi = 0`;
- 50 angle grid points and 300 time points over `tmax = 3`;
- periodic angular closure in the likelihood;
- 16 `fmincon` starts, interior-point, MaxIter 2000, MaxFunctionEvaluations 20000, tolerances `1e-6`.

## Current H0 specifications

| Model | JP front layer | Free parameters |
|---|---|---:|
| H0a | one shared `kappa`, nine condition-specific `psi` values | 17 |
| H0b | one shared `psi`, nine condition-specific `kappa` values | 17 |

CauchyCDM is the `psi = -1` constrained JP-family special case with nine condition-specific `kappa` values and 16 free parameters.

## Files

| File | Role |
|---|---|
| `jpcdm1.m` | MATLAB wrapper around the JP MEX core with explicit `eta2` support |
| `vjp300rot.c` | JP MEX source; now expects `[vnorm,kappa,eta1,eta2,phi,psi,sigma,a]` |
| `jpcdm_model.m` | H0a/H0b parameter layouts and bounds |
| `jpcdm_expand_P.m` | Expand fitted vector to condition-level parameters |
| `jpcdm_nll.m` | Nine-condition joint NLL |
| `jpcdm_nll_arrays.m` | Single-condition joint likelihood with periodic angular closure |
| `run_jpcdm_theory_fit.m` | Current checkpointed multistart runner |
| `jpcdm_diagnostics.m` | Angle/RT figures and proportion CSVs |
| `jp_fit_theory.m` | Entry script for H0a and H0b |
| `JPFits/` | Current comparable fit outputs |
| `Figures/H0a/`, `Figures/H0b/` | Current diagnostic figures and proportion CSVs |

## Historical route

Older files such as `run_jpcdm_grouped_vnorm_fit.m`, `jp_fit_9p3v3ter_results.mat`, `jp_fit_9k3v3ter_results.mat`, `jp_fit_freePsi_groupedVnorm_results.mat`, and `jp_fit_freeKappa_groupedVnorm_results.mat` are retained as historical exploratory fits. They used older parameter grouping and/or timing conventions and should not be presented as publication-final comparisons against the current POPCDM/CauchyCDM fits.

## Current caveats

- The JP source has been updated for runtime `eta2`; old MEX binaries must be rebuilt before fitting.
- H0a/H0b are descriptive baselines, not theory-constrained scaling models.
- Unrestricted JP can be flexible in shape; publication claims should distinguish descriptive fit from a psychologically constrained front-end account.
- Formal model comparison still requires running the current JP fits and then comparing NLL/AIC/BIC, convergence, boundary contact, angle-bin diagnostics, RT-bin diagnostics, and RT-by-error diagnostics under the same reporting convention as POPCDM and CauchyCDM.

## Current H0 results (21 Aug 2026)

Both current JP H0 routes completed for all five participants with 16 converged starts per participant and best exit flag 2.

| ID | JP H0a NLL | JP H0b NLL | Better JP H0 |
|---|---:|---:|---|
| AQ | 3089.14 | 2949.65 | H0b |
| ES | 1237.58 | 1017.30 | H0b |
| HC | 1211.73 | 1147.12 | H0b |
| PG | 3081.45 | 2800.08 | H0b |
| YL | 2550.99 | 2344.38 | H0b |

H0b, with condition-specific `kappa` and shared `psi`, dominates H0a. This means condition-specific concentration is the useful JP degree of freedom in the current comparable specification; condition-specific shape at a shared concentration is not competitive.

Comparison with Cauchy H0:

| ID | Cauchy H0 NLL | JP H0b NLL | JP H0b - Cauchy |
|---|---:|---:|---:|
| AQ | 2947.04 | 2949.65 | +2.61 |
| ES | 1005.32 | 1017.30 | +11.98 |
| HC | 1137.66 | 1147.12 | +9.47 |
| PG | 2780.45 | 2800.08 | +19.63 |
| YL | 2314.65 | 2344.38 | +29.73 |

Cauchy H0 still wins every participant despite using one fewer parameter. This strongly supports the `psi=-1` restriction as a useful and parsimonious JP-family constraint.

Comparison with best POP H0:

| ID | Best POP H0 NLL | JP H0b NLL | JP H0b - best POP |
|---|---:|---:|---:|
| AQ | 3106.92 | 2949.65 | -157.27 |
| ES | 1178.78 | 1017.30 | -161.47 |
| HC | 1333.16 | 1147.12 | -186.04 |
| PG | 2968.57 | 2800.08 | -168.49 |
| YL | 2550.60 | 2344.38 | -206.22 |

The current JP H0b route reverses the historical conclusion that POPCDM wins the JP comparison. Once JP is harmonized to the current skeleton, JP H0b beats the best POP H0 baseline for every participant. However, Cauchy remains better and more parsimonious.

Boundary audit:

- AQ and YL place `a` near the upper boundary.
- ES and PG place shared `psi` near a boundary.
- AQ and YL have more than one start within 1 NLL point of the selected solution; the others have one.

Diagnostics:

- H0b angle-bin MAE ranges from .0389 to .0452.
- H0b RT-bin MAE ranges from .0163 to .0302.
- H0b improves angle-bin diagnostics over H0a for every participant.

Current interpretation: the JP family works best by allowing condition-specific concentration while keeping shape shared. The unrestricted shared shape does not improve on the Cauchy special case enough to justify the extra parameter. Cauchy is therefore the stronger JP-family model for the current manuscript logic.
