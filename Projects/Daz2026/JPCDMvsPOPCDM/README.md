# Memory variability in the circular diffusion model

Authoritative project overview. Updated 13 November 2026. Active analysis folder: **`POPvJPvCauchy/`** (retain this spelling and path).

## Question and argument

What theoretically and psychologically plausible component should describe latent memory-direction variability before circular diffusion? Compare free-shape Jones–Pewsey (JP), the implemented POP activation/selection front end, and wrapped Cauchy (JP at psi = -1), using joint recall-error and response-time data.

A defensible account of memory variability is necessary for interpreting the residual variability in decision evidence and timing. Otherwise decision parameters may compensate for an inadequate memory component. Recent Cauchy results suggest that colour-dependent nondecision-time baselines and cue deltas can map experimental structure meaningfully. This is encouraging evidence for the decomposition; its robustness across front ends and numerical implementations remains to be tested.

The wrapped-Cauchy route is motivated both empirically and by a separate team theory project connecting memory formation and resource allocation. This project's contribution is empirical comparison and testing on Re2024. Its allocation-to-dispersion law is still to be specified and fitted; the other project's derivations and datasets are not our Results.

## Current evidence

Re2024 comprises AQ, ES, HC, PG, YL, nine modelled conditions and 22,460 retained trials (RT 0.3–3 s). Item count S, unique-colour count C, and R/NR cue state distinguish conditions. Baseline S=C cells are stored with NR suffixes but are modelled as baseline, rather than NR offset cells.

The active Cauchy workflow has 11 fitted routes: shared decision baseline, three single-component releases, saturated decision diagnostic, two H2 factor models, and four equal-complexity H3 restrictions. All retain nine free memory dispersions. See the [model dictionary](docs/model_dictionary.md) for descriptive names and formal groupings.

| Participant | Lowest recorded Cauchy BIC | BIC | Qualification |
|---|---|---:|---|
| AQ | Shared drift; colour/cue timing (`H3_1v_tcolor`) | 5942.56 | Corrected AQ H1 and H2 are included in the comparison |
| ES | Colour/cue drift; shared timing (`H3_1t_vcolor`) | 1942.20 | More parsimonious than cellwise H1 drift |
| HC | Set drift; colour/cue timing (`H2_tsensitive`) | 2310.36 | Only 2.07 ahead of H3 colour/cue timing |
| PG | Shared drift; colour/cue timing (`H3_1v_tcolor`) | 5659.97 | Ter/set route differs by only 0.15 |
| YL | Set drift; colour/cue timing (`H2_tsensitive`) | 4633.33 | Colour/cue drift H3 differs by 4.24 |

These are **recorded saved-fit rankings**, not numerically validated final model-selection claims. The [55-record comparison export](docs/current_cauchy_comparison.csv) includes objective penalties, AIC/BIC, boundary flags and optimization success counts. The CSV and MAT scalar fields agree; forward likelihood reproduction and numerical convergence remain pending.

Cellwise drift and timing each improve BIC over the shared-decision baseline for all five participants. Cellwise eta does not earn its complexity cost for four participants; ES improves but favours other routes. H2 timing baselines increase with unique-colour count in all five saved fits. Restricted timing accounts remain useful without consistently resolving slow-error RT. Participant differences and near ties should remain visible.

The earlier front-end benchmark and sibling-folder results belong to distinct historical specifications. Their rankings differ. Final matched POP/JP/Cauchy comparison under an agreed common decision architecture is **not complete**. Older statements that H2 leads for four participants are historical September milestones, superseded by H3 and AQ corrections above.

## Navigation and ownership of information

| Document / asset | Responsibility |
|---|---|
| This overview | Current scientific question, evidence, decisions and priorities; replaces the old master note |
| [Model dictionary](docs/model_dictionary.md) | Equations, parameter scales, route identifiers and psychological interpretations |
| [Results manifest](POPvJPvCauchy/results_manifest.csv) | Exact canonical fit paths, hashes, corrections, data snapshot and validation status |
| [Stage work note](POPvJPvCauchy/POPCDM_stage_work_note.md) | Operational detail and development updates; defer here for project-level status |
| [Research plan](docs/research_plan.md) | Remaining comparisons, theory decisions, drafting and stopping boundaries |
| [Numerical audit](docs/numerical_audit.md) | Specific source findings, checks, measured outcomes and refit criteria |
| [Decision log](docs/decisions.md) | Dated decisions and unresolved POP interpretation |
| [Manuscript workspace](manuscript/README.md) | Planned supervisor-facing draft and evidence map |
| [Figure index](POPvJPvCauchy/Figures/README.md) | Exploratory archive and provisional manuscript candidates |
| [Legacy index](Legacy/README.md) | Earlier implementation stages and supplied fitting package |
| [History](docs/history/README.md) | Previous master and initial assessment, preserved as snapshots |

Keep current rankings here and in the generated comparison export. Specific notes should add dated operational evidence and link here, rather than maintaining competing project summaries. Old H labels remain stable computational aliases; descriptive names are the preferred reading labels. Do not rename saved vectors or hypotheses merely to improve exposition.

## Runnable assets and safe replay

In MATLAB, start in `POPvJPvCauchy` and add only that directory to the front of the path. Avoid `addpath(genpath(projectRoot))`: legacy folders contain conflicting core/helper names.

```matlab
cd POPvJPvCauchy
addpath(pwd, '-begin')
[fitFile, record] = re2024_result_file("H2_tsensitive");
saved = load(fitFile, 'allResults');   % reads corrected canonical aggregate
plot_re2024_h1_marginals             % saved predictions only
plot_re2024_besth1_h2ts_marginals     % saved predictions only
plot_re2024_qvwm                    % saved predictions only
```

Replay exports to fresh timestamped subfolders under `Figures/Exploratory/Replays` and writes a result-provenance CSV. Existing predictions retain their audit limitations. The canonical manifest, rather than latest timestamps or wildcard matches, selects results. Original H2 files remain intact.

Preparation: `prepareRe2024Data(csvPath, participants, false)` returns data without overwriting the prepared asset. With an omitted path, `RE2024_DATA_FILE` takes precedence; otherwise the function searches ancestor folders for repository `Data/Redundancy 2024/Modelling/POPCDM/DazPreprocessed.csv`. Retained units and filters are unchanged.

Fitting: `test_fit_re2024` uses `re2024_cauchy_hypothesis_spec` and `test_ylcauchy`; it currently registers **Cauchy only**. It rebuilds stale/missing MEX files, prepares data with saving enabled, and starts optimization. Do not use it as a replay command. Use a new run label for future fits. Numerical changes and refits are the next scientific stage, not part of this reorganization.

## Next decisions

1. Reproduce saved vectors and complete isolated numerical checks before final predictions or comparisons.
2. Clarify POP's intended activation scale and selection equation; preserve current model identity meanwhile.
3. Select a small common decision-architecture set for matched POP/JP/Cauchy fits.
4. Specify the resource-to-Cauchy-dispersion law, including S/C/multiplicity and exponent conventions, before constrained fits.
5. Draft now with provisional findings; add uncertainty/recovery and validation evidence before strong mechanistic claims.

No current result proves a unique psychological stage, consolidation mechanism, universal architecture, or general superiority across datasets. The project's completion does not require pursuing every possible slow-error extension.
