# POPvJPvCauchy Stage Work Note

## Project Stage

This folder contains a new team-provided model asset package for comparing POP, Jones-Pewsey, and Cauchy front ends attached to a circular diffusion model (CDM) core. The immediate goal is to understand the provided fitting assets, learn the wrapper/fitting workflow, and then implement comparable wrappers for the Daz VWM continuous recall dataset.

For now, the C cores are left as provided, except that `vjp300rot.c` has already been updated manually to use `atan2` for the drift-angle vector function. Further C-core edits should wait until the total-mass indexing issue is clarified with the team.

## Contents And Roles

- `vpop300rot.c`: POP / population-code front end with fixed amplitude and Gumbel noise parameter `xi`.
- `vjp300rot.c`: Jones-Pewsey front end with free `psi`.
- `vcau300rot.c`: Wrapped Cauchy front end.
- `pgpop1.m`: POP likelihood wrapper for small range, `M = [1, 2, 3, 4]`.
- `pgpop1a.m`: POP likelihood wrapper for large range, `M = [1, 2, 4, 6]`.
- `vwmjp61.m`: JP likelihood wrapper for small range, `M = [1, 2, 3, 4]`.
- `vwmjp61a.m`: JP likelihood wrapper for large range, `M = [1, 2, 4, 6]`.
- `mvwm23.m`, `mvwm23a.m`: Marginal angle and RT plotting for four-condition fits.
- `qvwm23.m`: RT quantile-by-error diagnostic plot.
- `pgcomp26.m`: Comparison plot for two prediction structures.
- `setfig*.m`: Figure layout helpers.
- `pg32.mat`, `pg34.mat`: Saved JP/Cauchy-style fit assets from the team.
- `pgp2.mat`, `pgp4.mat`: Saved POP fit assets from the team.
- `Paul26a.mat`: Team dataset asset.
- `DazSecondTranche.txt`: Team notes and example commands/results.
- `totalmassDemo1.m`: Local demonstration script for checking C linear indexing.

## Data Mapping

The team notes identify Paul's multirange replication data as:

- `pga4`: small range experiment, corresponding to `M = [1, 2, 3, 4]`.
- `pga6`: large range experiment, corresponding to `M = [1, 2, 4, 6]`.

The likely wrappers are:

- `pgpop1.m` fits POP to `pga4`.
- `pgpop1a.m` fits POP to `pga6`.
- `vwmjp61.m` fits JP/Cauchy-style JP front-end models to `pga4`.
- `vwmjp61a.m` fits JP/Cauchy-style JP front-end models to `pga6`.

The `.mat` files appear to store example fitted parameter vectors and predictions:

- `pg32.mat`: JP/Cauchy constrained fit for small range.
- `pg34.mat`: JP/Cauchy constrained or free-Psi fit for large range.
- `pgp2.mat`: POP fit for small range.
- `pgp4.mat`: POP fit for large range.

This mapping should be verified by loading each `.mat` file and inspecting variable names before using these assets as templates.

## C-Core Architecture Notes

All three C cores share the same broad CDM architecture:

1. Approximate the front-end angular distribution using `njsteps = 21` latent drift-angle grid points.
2. Convert each latent angle into a 2D CDM drift vector.
3. Evaluate the CDM over a response/error grid with `nw = 50` angular bins plus one wraparound row.
4. Evaluate RT over `sz = 300` time bins.
5. Mix the CDM predictions across the 21 weighted latent drift directions.

The 21 latent drift-angle points are not random samples and are not the same as the 50 response-angle bins. They are an evenly spaced quadrature-like approximation to the front-end distribution.

The response grid has `nw + 1` stored rows because the final row duplicates the first row to close the circular domain for interpolation. This duplicate row should not be double-counted when integrating over unique angular bins.

## Important Numerical Clarifications

### `noise`

The `noise` argument in `bessel2` is not a psychological Gumbel/noise parameter. It is a numerical threshold for stitching together two approximations to the zero-drift first-passage-time density:

- `dhamana`: Bessel/eigenvalue-series solution.
- `dserafin`: short-time asymptotic approximation.

The code uses `dserafin` while the Bessel-series density is below the threshold, then switches to `dhamana`.

### `sz`

`sz` is the number of RT/time bins in the C core. In these files, `sz = 300`.

## Potential C-Core Issues To Revisit

### Total-Mass Indexing

The C code writes `Gt` as a matrix with `(nw + 1)` rows and `sz` columns:

```c
Gt[(nw + 1) * k + i] = ...
```

But in the `totalmass` block, it currently reads:

```c
Gt[nw * k + i]
```

The team correctly noted that the wraparound row should not be double-counted. That is handled by looping only over `i < nw`. The separate issue is the column stride. Since each stored time column has `nw + 1` rows, the column offset should still use `(nw + 1) * k` even when integrating only the first `nw` unique rows.

This should be clarified with the team before editing the model cores.

### Bounds Check In `while`

The current pattern:

```c
while (Gth[i] < noise && i < sz)
```

is not ideal because `Gth[i]` is evaluated before checking `i < sz`. A defensive version would be:

```c
while (i < sz && Gth[i] < noise)
```

This is probably not an active fitting problem if `noise` is tiny and `Gth` crosses it normally, but it is safer C.

## Wrapper Lessons For Daz Implementation

When writing the new Daz POPCDM wrapper:

- Keep parameter order explicit.
- Unpack named parameters immediately after building each condition vector.
- Preserve comparable condition structure across POP, JP, and Cauchy.
- Make sure `delta`, `Ter`, and `st` are read from their intended positions.
- Keep set-size-based RT parameterization in view, because earlier diagnostics showed RT is better organized by set size than by cue type or unique colour count.
- Treat team POP wrappers as useful learning examples, but do not copy their parameter indexing without checking.

## Suggested Learning Path

The best starting point for learning is `pgpop1.m`, because it is the POP wrapper for the simpler small-range case and has the same overall likelihood structure as `pgpop1a.m`.

After understanding `pgpop1.m`, compare it with `vwmjp61.m` to see which parts are generic CDM wrapper structure and which parts are POP-specific. Then adapt the pattern to the Daz dataset.


## 2026-09-14: current H1 direction and review record

H0 has already been fitted. Current runner/wrapper inconsistencies reflect an interrupted H1 edit and do not establish a fault in the saved H0 fits. The next substantive test is a shared redundancy increment in Ter, fitted jointly across all nine conditions with baseline as the zero-increment case. Prioritize the team-Cauchy core and preserve its dispersion convention. The C2/C4+ eta extension is deferred as an exploratory benchmark. No model code or fit was changed during this documentation update.

The full staged plan, evidence qualifications, saved-H0 verification versus refitting criteria, future latent-information model specification, POP-rule clarification, and latent-grid timing/convergence guidance are recorded in the [master work note](../POPCDM_CauchyCDM_master_work_note.md), entry “2026-09-14: staged H1 plan following review of the team-core fits”. That entry supersedes earlier next-step priorities where they conflict.


## 2026-09-14: H1 redundancy-Ter implementation completed

Implemented in all four test_yl wrappers and test_fit_re2024. H1 now appends one parameter, deltaTerRed, to each unchanged H0 vector (including after psi in free JP). The condition-specific timing parameter is TerC = Ter + deltaTerRed * (S > C). The indicator is [0,1,1,0,1,1,1,1,0], so R and NR share the same increment. Eta remains shared. deltaTerRed has hard bounds [0,1] seconds, no additional soft penalty within those bounds, and initial value 0.05 s. This is a nonnegative extra-delay hypothesis: zero nests H0; negative redundancy effects are not estimated. The baseline Ter bounds are unchanged; the derived redundant Ter is their sum, not independently capped at the old baseline upper bound.

The interrupted eta-C2/C4+ extension is replaced. H0 is still the default when the optional hypothesis argument is omitted. H0's latent grid remains 21 directions; C sources/MEX files, response/time grids, existing parameters and their bounds, timing convolution, RT selection, numerical likelihood, optimizer settings, and existing diagnostics were not changed. The incomplete scalar-eta H0 indexing in the Cauchy wrapper was restored to shared eta.

Run team Cauchy with `output = test_fit_re2024("H1", "cauchy");`, or all three default front ends with `output = test_fit_re2024("H1");`. Results default to TestFits/H1_redundancyTer_setsizeVnorm_sharedEta. Checkpoints and the CSV summary include TerBaseline, deltaTerRed, and TerRedundant in seconds. Other H1 parameters are jointly optimized as before; the existing 10-start initialization scheme is retained (no automatic loading of H0 starts).

Validation in MATLAB R2024b, with existing MEX cores and Re2024 data: all four wrappers exactly reproduced H0 joint predictions/objectives at deltaTerRed=0; free H1 added the expected AIC/BIC penalty, while fixed zero increment reproduced H0 criteria. A 0.1 s increment shifted time coordinates by exactly 0.1 s in all six redundancy conditions and left baseline condition predictions unchanged. H0/H1 runner catalogs evaluated successfully. POP/JP/JP-Cauchy H0 matched pre-edit wrappers exactly. All five saved team-Cauchy H0 checkpoints reproduced raw NLL and penalized objective with zero difference. Code Analyzer reported zero messages for the five edited MATLAB files. No optimization or fitting was run; no saved fit artifacts were modified.

## 2026-09-14: targeted Cauchy H0 boundary refit and H0/H1 quantile diagnostics

The H1 Ter-redundancy fits placed deltaTerRed effectively at its lower bound for all participants (0.024–0.815 ms). To distinguish a genuine H1 benefit from an H0 local-minimum issue, each H1 solution was projected onto H0 by dropping deltaTerRed and then reoptimized with the same fmincon settings. All five H0 boundary refits converged with exit flag 2. H0 NLL was lower than H1 for every participant: AQ 2929.662627 versus 2929.748714, ES 1026.309393 versus 1026.417581, HC 1162.866527 versus 1162.968731, PG 2791.295630 versus 2791.377573, and YL 2324.917721 versus 2325.002272. Thus the prior H1 improvements relative to older H0 outputs reflected different H0 optimization basins, not support for a positive redundancy-specific Ter increment.

The targeted boundary-refit results are retained under their canonical route name, `TestFits/H1_vnorm_sn/`. The temporary H0/H1 conditional-quantile comparison confirmed that their curves were nearly superimposed, as expected from the boundary result; it was then removed in favour of the team-style figures below.

The temporary H0/H1 comparison figures were removed after review. `qvwm23.m` now retains its supplied four-condition route and adds a Re2024-only nine-condition branch using the team figure convention: five fitted quantiles (.1, .3, .5, .7, .9) as dash-dot black curves; empirical equal-mass signed-error-bin quantiles connected in black; and the original coloured markers. The Re2024 branch reads actual prediction time spacing rather than assuming the original example's 4 s grid. The retained fit can be plotted with `plot_cauchy_h1_vnorm_sn_qvwm23.m` into `Figures/Cauchy_H1_vnormSN_QVWM23/`.

## 2026-09-14: Ter H1 retired; saturated conditional-eta H1 prepared

The Ter-redundancy H1 is retired because its fitted increment was effectively zero and the targeted H0 refits yielded lower NLL for every participant. The whole `TestFits/H1_redundancyTer_setsizeVnorm_sharedEta/` directory was removed. Redundant per-participant checkpoint files were also removed from the historical fit directories; their aggregate `.mat` result files and CSV summaries remain. The H0 QVWM23 helper now reads the retained aggregate boundary-refit file, so it does not depend on deleted checkpoints.

The next H1 is a saturated, descriptive diagnostic. It replaces H0's one shared eta with nine freely estimated eta parameters, one for each condition in the prepared-data order: `S2C2NR`, `S4C2NR`, `S4C2R`, `S4C4NR`, `S6C2NR`, `S6C2R`, `S6C4NR`, `S6C4R`, and `S6C6NR`. It therefore adds eight free parameters relative to H0. All other components remain exactly as in H0: the three set-size vnorm values, nine front-end dispersion values, boundary `a`, baseline `Ter`, `st`, the 21 latent drift directions, C/MEX cores, response/time grids, likelihood, bounds, optimizer settings, and multistart scheme. There is no R/NR-specific Ter term in this route.

The H1 is useful for observing the empirical eta pattern before proposing a lower-dimensional, theory-led restriction. It does not by itself show that eta should vary by C, redundancy, or cue type. Equal eta values exactly nest H0; MATLAB checks confirmed exact equality of objective and predictions for POP, JP, JP-Cauchy, and team Cauchy under that constraint. Fit team Cauchy with `output = test_fit_re2024("H1", "cauchy");`. Results will be written to `TestFits/H1_cellwiseEta_setsizeVnorm/`.

## 2026-09-14: YL saturated-eta H1 warm-start refit

The original YL H1 fit was worse than the nested H0 because its ten starts did not include the exact H0 point. A targeted H1 refit therefore initialized all nine eta values at the targeted H0 eta and used that vector as an explicit start, alongside local perturbations and broad starts. This produced H1 NLL = 2319.383155, versus the targeted H0 NLL = 2324.917721: an improvement of 5.534566 NLL units. The H1 solution is therefore a valid nested-model improvement, not a numerical failure.

However, H1 adds eight parameters. Its AIC is 4686.766 versus H0 AIC = 4681.835, and its BIC is 4840.634 versus H0 BIC = 4784.414. Thus saturated condition-specific eta is not selected for YL despite the improved likelihood. The eta profile is also not a simple high-colour or NR pattern: its largest value is `eta_S6C2R = 0.453`, while `eta_S6C2NR = 0.099` is near the lower-bound reporting threshold. This supports treating the saturated model as a diagnostic, not an explanatory specification.

For future nested H1 fits, `test_fit_re2024` accepts an H0 aggregate result file and participant selector. It maps shared H0 eta into all H1 eta slots, guaranteeing that H1 includes the H0 solution among its starts. H1 now uses 24 starts: one exact H0 start when supplied, four local perturbations, and 19 broad starts. H0 remains at 10 starts. The current fmincon settings are retained; the issue was initialization and a multi-modal objective surface rather than failure to satisfy stopping criteria.

## 2026-09-14: Cauchy response-component audit

Three 22-parameter Cauchy diagnostic routes were fitted with 24 starts each. All retain nine condition-specific front-end `kappa_mu` values. `H0_ETA` has nine eta values with one shared vnorm and Ter; `H0_VNORM` has nine vnorm values with shared eta and Ter; `H0_TER` has nine Ter values with shared vnorm and eta. These are component audits, not final theory models: they ask which response-stage component can improve the joint angle-RT fit when the memory front end remains free by condition.

`H0_ETA` fit worse than the targeted 16-parameter H0 for every participant (NLL increases AQ +14.52, ES +62.86, HC +65.93, PG +10.89, YL +124.05). Thus condition-specific eta cannot compensate for removing the established set-size vnorm structure. This reinforces that eta is not the primary source of the unexplained condition-level joint fit structure.

Both `H0_VNORM` and `H0_TER` improved NLL and AIC for every participant. `H0_VNORM` NLL improvements versus targeted H0 were AQ 23.22, ES 136.43, HC 69.70, PG 32.16, and YL 91.04. `H0_TER` improvements were AQ 24.24, ES 88.80, HC 98.03, PG 43.80, and YL 76.25. BIC selected `H0_VNORM` for ES, HC, PG, and YL, but not AQ; it selected `H0_TER` for ES, HC, PG, and YL, but not AQ (where BIC was about 2 points worse).

The immediate conclusion is that the important remaining flexibility lies in condition-specific decision dynamics/timing, not a simple condition-specific eta account of slow errors. The preferred next modelling step should be a lower-dimensional, theory-led parameterization of vnorm and/or Ter, informed by their fitted condition patterns, while preserving Cauchy `kappa_mu` for the planned attention-weighted sample-size analysis.

## 2026-09-15: canonical Cauchy route taxonomy

The Cauchy fit routes were renamed so that `H0` now denotes the true baseline: nine condition-specific `kappa_mu` values and one shared value each for `vnorm`, `eta`, `a`, `Ter`, and `st` (14 free parameters). This baseline has been implemented but not yet fitted.

The fitted component-audit routes are now named `H1_eta` (cellwise eta), `H1_vnorm` (cellwise vnorm), and `H1_ter` (cellwise Ter); each has cellwise `kappa_mu` and 22 free parameters. The established 16-parameter model with set-size-specific vnorm is now `H1_vnorm_sn`. It is the retained targeted boundary-refit solution, formerly labelled H0. The saturated, cellwise-eta plus set-size-vnorm result is retained as `Legacy_etaCell_vnormSN`, with the YL warm-start recovery retained separately as `Legacy_etaCell_vnormSN_YL_warmstart`.

All result directories and aggregate filenames use these canonical labels. Existing aggregate MAT files retain their historical `hypothesis` field, so that the original run context is auditable without changing fitted values. Per-participant checkpoint files are redundant because the aggregate files contain all `allResults`; they were removed during this cleanup. The superseded initial `H0_teamCauchy_refit` aggregate and the one-off boundary-refit helper were removed; the retained targeted solution contains the results needed for future comparison.
