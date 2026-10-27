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
| `H3_1v_tcolor` | 18 | H2_tsensitive Ter mechanism with one shared vnorm; nine cellwise kappa_mu and shared eta/a/st. |
| `H3_1t_vset` | 18 | Shared Ter; three set-size vnorm baselines plus signed R/NR vnorm offsets; nine cellwise kappa_mu and shared eta/a/st. |
| `H3_1t_vcolor` | 18 | Shared Ter; three colour-count vnorm baselines plus signed R/NR vnorm offsets; nine cellwise kappa_mu and shared eta/a/st. |
| `H3_1v_tset` | 18 | Shared vnorm; three set-size Ter baselines plus signed R/NR Ter offsets; nine cellwise kappa_mu and shared eta/a/st. |

Canonical aggregate files:

- `TestFits/H0_kappaCell_sharedDecision/H0_kappaCell_sharedDecision_20260915_130513.mat`
- `TestFits/H1_eta/H1_eta_20260914_165156.mat`
- `TestFits/H1_vnorm/H1_vnorm_20260914_174346.mat`
- `TestFits/H1_ter/H1_ter_20260914_193853.mat`
- `TestFits/H_satDecision/H_satDecision_20260922_114249.mat` (diagnostic only)
- `TestFits/H2_factorial/H2_factorial_20260922_143302.mat`
- `TestFits/H2_tsensitive/H2_tsensitive_20260929_AQH3warm_merged.mat` (current best-known H2 aggregate)
- `TestFits/H3_1v_tcolor/H3_1v_tcolor_20260929_170830.mat`
- `TestFits/H3_1t_vset/H3_1t_vset_20260929_195215.mat`
- `TestFits/H3_1t_vcolor/H3_1t_vcolor_20260930_095656.mat`
- `TestFits/H3_1v_tset/H3_1v_tset_20260930_105146.mat`

The original H3_1t and H3_1v result directories are preserved under
`TestFits/Archive/H3_PreRename_20260929/`. The active aggregates and
checkpoints have matching filenames, route labels, and layout versions; fitted
parameters and NLLs are unchanged.

The original `H2_tsensitive_20260922_152336.mat` remains unchanged. AQ's H3_1v_tcolor
fit (NLL 2895.5953) was lower than the original H2 fit (2900.8089), exposing
an optimization miss in a nested model. An AQ-only H2 refit seeded from H3
matched NLL 2895.5953 exactly, with all three vnorms equal (3.9533). The
merged aggregate replaces only AQ; its BIC is 5959.4 versus H3_1v_tcolor's 5942.6.

H3_1t_vset is not the BIC winner for any participant. Against the equal-parameter
H3_1v_tcolor, its BIC is higher by AQ 55.9, ES 58.9, HC 88.9, PG 22.1, and YL
111.5. Its set-size vnorm baselines decrease with set size for all five, but
one shared Ter plus additive cue offsets on vnorm does not reproduce the
colour/cue timing fit of H3_1v_tcolor. This rejects that *specific grouping*, not
vnorm flexibility generally: ES now favours colour-grouped H3_1t_vcolor,
while HC and YL favour H2_tsensitive. H3_1t_vset solutions were re-evaluated through the
current wrapper and reproduced saved NLL exactly for all five participants.

## H3 Four-Route Comparison

All four H3 routes have 18 parameters, nine cellwise kappas, and shared
eta/a/st. Participant BIC values (lower is better):

| Participant | vnorm/set, one Ter | vnorm/colour, one Ter | one vnorm, Ter/colour | one vnorm, Ter/set |
|---|---:|---:|---:|---:|
| AQ | 5998.42 | 5968.91 | **5942.56** | 5977.45 |
| ES | 2097.93 | **1942.20** | 2039.04 | 2158.41 |
| HC | 2401.32 | 2368.47 | **2312.43** | 2361.11 |
| PG | 5682.06 | 5685.50 | **5659.97** | 5660.12 |
| YL | 4759.06 | **4637.57** | 4647.56 | 4808.64 |

ES's colour-grouped vnorm route also beats its cellwise H1_vnorm on BIC
(1942.20 vs 1964.76): it gives up only 5.54 NLL with four fewer parameters.
Fitted ES vnorm falls C2 > C4 > C6 (7.57, 6.52, 5.91); the R and NR
increments are -1.32 and -0.68. This is a parsimonious descriptive account,
not by itself proof of a specific evidence-quality process. YL's same route
is close to H2_tsensitive (BIC 4637.57 vs 4633.33). AQ and HC favour
colour-grouped Ter; HC's H2_tsensitive improves BIC over H3_1v_tcolor by
only 2.07. PG's Ter/colour and Ter/set routes are effectively tied (BIC
difference 0.15), so its preferred timing *grouping* is unresolved.
The new fits reproduce their saved NLLs through the current wrapper; only
PG's vnorm/colour run had one non-successful start (23/24 successful).

An exact embedding test showed H3_1v_tcolor is nested in H1_ter. AQ's
original H1_ter NLL 2905.4206 missed the embedded H3 NLL 2895.5953.
An AQ-only H1_ter refit seeded from that exact H3 projection reached NLL
2892.8773 (BIC 5970.7562); this replaces AQ in the canonical H1_ter
aggregate and summary, while the other four fitted vectors are unchanged.
AQ's H1_ter now clearly beats H1_vnorm on NLL and BIC, but H3_1v_tcolor
still has lower BIC (5942.56). Eta in the AQ H1_ter refit is near its lower
bound. YL retains a smaller 0.5856 NLL nesting miss and may need a later
warm-start refit. H3_1t_vcolor likewise embeds exactly in H1_vnorm; all five
saved H1_vnorm fits satisfy the expected NLL ordering.

## Current Results And RT Interpretation

Cellwise eta can improve raw likelihood for some participants but generally
does not earn its eight-parameter complexity cost. Cellwise vnorm and cellwise
Ter improve BIC over H0 for all participants, with their relative advantage
varying by participant. This identifies residual condition-level decision/RT
structure, but does not yet license a saturated final model.

### H1 To H3 Interpretation

Keep each participant's H1 routes visible when judging H3. AQ's original
H1_ter and H1_vnorm saves looked nearly tied (NLL 2905.42 vs 2906.45), but
the warm-started H1_ter NLL is 2892.88, resolving that comparison in favour
of Ter. HC and PG also favour H1_ter; ES and YL favour H1_vnorm. These are
relative preferences, not fixed "Ter people" and "vnorm people": both H1
routes improve on H0 for every participant.

For AQ, the refitted H2_tsensitive solution has the same NLL as H3_1v_tcolor
(2895.5953), with all three set-size vnorms equal to 3.9533. Thus allowing
set-size vnorm variation adds nothing *conditional on this fitted Ter
structure*. H1 routes can trade off timing and evidence explanations, but
AQ's warm-started H1_ter improves beyond H3's NLL, while H3 retains
the BIC advantage. Equality of H2 and H3 likelihoods does not prove
that Ter absorbs every H1_vnorm effect or uniquely identify the underlying
psychological process.

The matched four-route H3 comparison tests whether set size or colour count
better groups vnorm or Ter. Broad agreement with H1 preferences is expected,
but a reversal is a diagnostic, not automatically an error: first check
optimization/nesting, then parameter trade-offs, cellwise angle and RT
predictions, and whether the grouped H3 route is too restrictive to express
the winning cellwise H1 pattern. Fit ranking alone cannot establish selective
influence.

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
for any participant. After the AQ warm-start correction, `H2_tsensitive`
has BIC 5959.37 for AQ, 2019.78 for ES, 2310.36 for HC, 5671.95 for PG,
and 4633.33 for YL. Among routes fitted so far, H3_1v_tcolor leads for AQ
(5942.56) and narrowly for PG (5659.97 vs H3_1v_tset 5660.12);
H3_1t_vcolor leads for ES (1942.20); H2_tsensitive leads for HC and YL.
Thus the colour/cue Ter account is useful for several individuals, but the
same grouping is not a universal selective-influence result. Only AQ and YL improve both NLL and BIC over their best H1; HC
and PG improve BIC with slightly worse NLL. The fitted C2/C4/C6 Ter baselines
increase monotonically for every participant. Eta remains near its H0 value in the timing-sensitive route.

Neither H2 route consistently improves the descriptive slow-tail median-RT
error beyond the best single-component H1. The colour/cue Ter mechanism is
competitive, but the unresolved tail RT mismatch remains an explicit
diagnostic target rather than solved.

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
