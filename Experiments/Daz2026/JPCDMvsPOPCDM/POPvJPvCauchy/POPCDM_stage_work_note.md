# POPvJPvCauchy Current Work Note

## Note Map And Immediate Priorities

The [master work note](../POPCDM_CauchyCDM_master_work_note.md) is the current
manuscript outline and ordered modelling plan (updated 23 September 2026).
Its R1-R7 issue assessments and M0-M7 work steps supersede historical next-step
proposals. This file retains the operational assets and recorded fit state.

Before additional large fits, complete the source/MEX and saved-vector audit,
then check circular closure, normalization, RT conditioning/convolution,
diagnostic summaries, and latent-angle convergence. Source inspection has
identified potential differences between the fitted joint density and saved
angular/conditional summaries; impact on the compiled fits is not yet measured.
Clarify the POP selection rule for matched front-end fits, and explicitly
justify this project's resource-to-dispersion law before constrained fits.
The team draft is a separate theory publication: its derivations and data
provide external background, not Re2024 results. Questions about its equations
are source clarifications if we adopt them, not a requirement to revise or
complete that publication. Our core audits concern the Re2024 implementation.
No C edits or refits were performed during the documentation reorganization.

## Purpose

This is a VWM continuous-recall model-comparison project. POP, free-Psi
Jones-Pewsey (JP), and team wrapped-Cauchy front ends are compared while
sharing a circular diffusion model (CDM) decision layer. Cauchy is the active
route for RT specification work; POP and JP remain first-class comparison
routes and will be updated to the eventual successful Cauchy specification.

## Active Assets

- `prepareRe2024Data.m` prepares the five Re2024 participants and nine
  conditions. Response error is radians; RT is seconds.
- `test_fit_re2024.m`, `test_ylcauchy.m`, and
  `re2024_cauchy_hypothesis_spec.m` are the active Cauchy fit pipeline.
- `test_ylpop.m`, `test_yljp.m`, and `test_yljpcau.m` are retained for the
  later matched POP/JP comparison.
- `vcau300rot.c`, `vjp300rot.c`, and `vpop300rot.c`, plus their MEX files,
  are the active model cores. `vjp300rot.c` uses `atan2` for drift-angle
  rotation. No further C-core change is currently authorized.
- `Re2024_POPvJPvCauchy_prepared.mat` is the prepared participant-by-condition
  data asset.

## Canonical Cauchy Fits

All canonical results live in `TestFits` at their existing paths. Do not move
these directories without updating the fitting and plotting scripts.

| Route | Free parameters | Decision-stage structure |
|---|---:|---|
| `H0` | 14 | Shared `vnorm`, `eta`, `a`, `Ter`, `st`; nine cellwise `kappa_mu` values. |
| `H1_eta` | 22 | Nine cellwise `eta`; shared `vnorm` and `Ter`; nine cellwise `kappa_mu` values. |
| `H1_vnorm` | 22 | Nine cellwise `vnorm`; shared `eta` and `Ter`; nine cellwise `kappa_mu` values. |
| `H1_ter` | 22 | Nine cellwise `Ter`; shared `vnorm` and `eta`; nine cellwise `kappa_mu` values. |
| `H_satDecision` | 38 | Nine cellwise values each for `vnorm`, `eta`, and `Ter`; nine cellwise `kappa_mu` values; shared `a` and `st`. Diagnostic upper bound only. |
| `H2_factorial` | 20 | Set-size vnorm, colour-count eta, Base/R/NR Ter; nine cellwise kappa_mu and shared a/st. |
| `H2_tsensitive` | 20 | Set-size vnorm, shared eta, colour-count Ter plus signed R/NR offsets; nine cellwise kappa_mu and shared a/st. |

Canonical aggregate files:

- `TestFits/H0_kappaCell_sharedDecision/H0_kappaCell_sharedDecision_20260915_130513.mat`
- `TestFits/H1_eta/H1_eta_20260914_165156.mat`
- `TestFits/H1_vnorm/H1_vnorm_20260914_174346.mat`
- `TestFits/H1_ter/H1_ter_20260914_193853.mat`
- `TestFits/H_satDecision/H_satDecision_20260922_114249.mat` (diagnostic only)
- `TestFits/H2_factorial/H2_factorial_20260922_143302.mat`
- `TestFits/H2_tsensitive/H2_tsensitive_20260922_152336.mat`

## Current Results And RT Interpretation

Cellwise eta can improve raw likelihood for some participants but generally
does not earn its eight-parameter complexity cost. Cellwise vnorm and cellwise
Ter improve BIC over H0 for all participants, with their relative advantage
varying by participant. This identifies residual condition-level decision/RT
structure, but does not yet license a saturated final model.

Empirically, slow tail responses are clearest in high-colour-load conditions
and are often more pronounced in redundancy-related cells. The completed H2
comparison tested a small set of theory-led RT-factor parameterizations. Preserve nine cellwise Cauchy `kappa_mu`
values throughout this work so the front-end memory account remains available
for later attention-weighted sample-size scaling tests.

`H_satDecision` was fitted as the pre-H2 diagnostic from the
projected canonical H0, H1_eta, H1_vnorm, and H1_ter solutions, plus six broad
random starts. Its purpose is to determine the remaining joint-fit headroom
and parameter trade-offs before choosing a lower-dimensional H2 RT-factor
model. It is not a candidate final specification.

The completed saturated fit exactly reproduced the four source-route NLLs at
its first four starts, confirming correct nesting. It improved NLL beyond the
best 22-parameter H1 for every participant (AQ 17.19, ES 30.77, HC 23.74,
PG 21.69, YL 35.12), and also improved AIC. Its BIC was worse for every
participant because it adds 16 parameters beyond those H1s (BIC costs: AQ
+100.18, ES +73.01, HC +87.09, PG +91.18, YL +64.34 relative to the best H1).
The saturated parameter profiles are highly route- and condition-dependent;
therefore they are evidence of residual headroom and component trade-off, not
evidence for a cellwise final decision architecture. A descriptive three-region
RT check found no consistent additional reduction in slow-tail RT error beyond
the best single-component H1.

## H2 RT-Factor Routes

Both H2 routes retain nine cellwise Cauchy `kappa_mu` values, three
set-size-specific `vnorm` values (`S2`, `S4`, `S6`), shared `a` and `st`, and
20 free parameters in total. Each automatically includes the canonical H0
solution as its first start, followed by four local perturbations and 19 broad
random starts.

- `H2_factorial`: eta is grouped by unique colour count (`C2`, `C4`, `C6`);
  Ter is grouped by task state (`Base`, `R`, `NR`). This is the primary
  psychologically factorized candidate.
- `H2_tsensitive`: eta is shared; Ter has `C2`, `C4`, and `C6` baseline terms
  plus additive `R` and `NR` timing offsets. The offsets may be positive or
  negative, but linear constraints ensure that every derived condition Ter is
  between 0 and 1 seconds. This is the timing-sensitive rival in which colour
  count is assigned to non-decision timing rather than eta.

These routes compare two mechanistic allocations of the same experimental
structure. They should be evaluated against each other by BIC and, critically,
by whether their QVWM diagnostics reduce the persistent slow-tail RT miss.

The completed comparison favours `H2_tsensitive` over `H2_factorial` by BIC
for every participant. `H2_factorial` is not preferred over the best prior H1
for any participant. `H2_tsensitive` is the best BIC route currently fitted
for AQ (5969.80), HC (2310.36), PG (5671.95), and YL (4633.33); ES instead
retains the cellwise-vnorm H1 (1964.76 versus 2019.78). This supports a
colour-count-dependent baseline timing process plus small cue-state timing
offsets, with individual differences in whether those offsets are primarily
R or NR. Only AQ and YL improve both NLL and BIC over their best H1; HC
and PG improve BIC with slightly worse NLL. The fitted C2/C4/C6 Ter baselines
increase monotonically for every participant. Eta remains near its H0 value in the timing-sensitive route.

Neither H2 route consistently improves the descriptive slow-tail median-RT
error beyond the best single-component H1. Thus `H2_tsensitive` is the current
parsimonious global joint-fit leader for four participants, but the unresolved
tail RT mismatch remains an explicit diagnostic target rather than solved.

### ES Strategy Note

ES has the largest absolute Ter values in the H1 and H2 timing-sensitive
solutions, while its Ter pattern is comparatively stable relative to its large
condition-specific vnorm changes. In `H2_tsensitive`, ES has a high baseline
timing profile (C2 507 ms, C4 567 ms, C6 580 ms), a modest R offset (+64 ms),
and a near-zero NR offset (+7 ms). This is consistent with an interpretation
in which ES responds slowly but with relatively stable non-decision timing,
while condition/cue differences are expressed more strongly through decision
evidence dynamics. It is also consistent with the independently observed
strategy of reversing R and NR. Treat this as a participant-level strategy
hypothesis to be checked against trial behaviour and task records, not as a
deduction from Ter alone. Small across-condition Ter differences do not
establish small trial-level timing variability; inspect st and RT distributions.

## Primary Figures

- `Figures/Re2024_QVWM`: participant-level equal-mass RT-by-signed-error
  diagnostics for canonical H0/H1 and H2_tsensitive routes.
- `Figures/Re2024_BestH1_H2ts_marginals`: per-participant best-H1/H2 marginal
  comparisons. Prediction provenance for final figures is pending the R7 audit.
- `Figures/Re2024_RT_regions`: empirical central/shoulder/tail RT summaries.
- `Figures/KappaShift_H0_H1`: how H1 decision flexibility shifts fitted
  front-end dispersion.
- `Figures/KappaRhoScale_H0_H1`: exploratory kappa/rho scaling plots. Scaling
  is paused pending the next theory step.

## C-Core Caveat

The shared cores store an `(nw + 1)` by `sz` response-time matrix to duplicate
the circular wraparound response row. A potential total-mass column-stride
inconsistency is present in the inspected source: the write path uses
`(nw + 1) * k + i`, whereas one normalization read uses `nw * k + i`.
The empirical impact remains unmeasured. This mass feeds Ptheta and mixture
weights for returned moments; the joint Gt likelihood is separately normalized
in the wrapper. Do not assume identical effects on all outputs. The outer
mixture's Gt endpoint closure, source/MEX agreement, retained-RT summaries,
Ter/st convention, and quadrature also need validation. See master R7 for
isolated-build checks and refit criteria. Leave production C cores unchanged
until the team discussion and audit are complete.

## Records Outside The Live Workflow

- `Notes/POPCDM_stage_history_20260914-15.md` retains the detailed dated
  development record and superseded route terminology.
- `TestFits/Archive/InitialFrontEndComparison` contains early POP/JP/JP-Cauchy
  comparison runs. Consult it only when explicitly reviewing that stage.
- `Examples` contains the supplied team examples and datasets; `Examples/LocalLearning`
  contains `DazPOP1.m`.
- `Investigations/Ccore` holds the standalone C indexing demonstration.

## 23 September 2026 Documentation Consolidation

The prior master is preserved in `Notes/CDM_master_history_through_20260923.md`.
The new master records the Introduction outline, primary literature, seven
retained-issue action plans, and ordered manuscript completion steps. Historical
fit rankings remain recorded; no fitting, core, or plotting code changed.
