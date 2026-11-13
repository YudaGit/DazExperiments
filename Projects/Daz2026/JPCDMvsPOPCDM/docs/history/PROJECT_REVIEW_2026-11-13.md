# Project assessment and proposed reorganization

Assessment date: 13 November 2026. This is a review and recommendation, not a replacement for the model specifications or a numerical validation of the fitted likelihoods. Existing code, fits, figures, and notes have been left unchanged.

## 1. Scientific identity

The central question is: **what psychologically interpretable distribution of latent memory direction can serve as the front end of a circular diffusion model, while accounting for both recall error and response time?**

The three candidate roles are:

- **Free-shape Jones–Pewsey:** the flexible directional benchmark. Its usefulness establishes what descriptive flexibility buys; it does not by itself specify how memory generates that variability.
- **POP / signal-discrimination route:** the alternative motivated by activation and response-selection models. Its exact implemented equation must be identified before interpreting comparisons with Oberauer's signal-discrimination model.
- **Wrapped Cauchy:** the JP special case at psi = -1, with an independently motivated connection to stochastic memory formation and resource/sample allocation. The resource law remains a hypothesis to specify and test in this dataset.

Use “wrapped Cauchy” in formal writing. The active team implementation uses dispersion gamma = kappa_mu, rho = exp(-gamma), and circular SD = sqrt(2 gamma). Larger gamma means broader memory directions. JP concentration has a different scale: at psi = -1, rho = tanh(K/2). A parameter dictionary should prevent treating these numerical kappas as interchangeable.

The project now contains two linked strands: front-end comparison and exploratory development of the decision/timing architecture. The latter is necessary because unexplained RT structure can affect estimates and interpretation of memory dispersion. Keep the front-end question central in the manuscript; present the H0–H3 sequence as the work needed to make that comparison informative.

## 2. What is where

| Location | Present role | Recommended treatment |
|---|---|---|
| `POPvJPvCauchy/` | Active team-core Re2024 workflow | Keep as the working analysis root for now |
| `POPCDM_CauchyCDM_master_work_note.md` | Conceptual framing, manuscript outline, issue register | Retain its theory material; reconcile its current-results passages |
| `POPvJPvCauchy/POPCDM_stage_work_note.md` | Latest operational summary, including later H3 fits | Starting source for current fit provenance, checked against saved files |
| `POPvJPvCauchy/Notes/` | Historical master and stage development record | Historical evidence; do not read old next-step lists as current instructions |
| `POPCDM_Matlab/`, `JPCDM_Matlab/`, `CauchyJP/` | Earlier implementations, analyses, and diagnostics | Preserve as named legacy stages; their H0/H1 labels have different meanings |
| `Example Fitting Package/`, active `Examples/` | Supplied reference code and other datasets | Keep separate from Re2024 results; record origins and use explicitly |
| Active `Investigations/` | Small numerical investigation | Development/audit material |

The actual active folder is `POPvJPvCauchy`, rather than `POPvsJPvsCauchy`.

The workspace is approximately 766 MB, of which about 686 MB is active `TestFits`. Four MAT aggregates are approximately 133 MB each; several other aggregates are about 6 MB. Mixed MATLAB save formats account for at least part of this difference. Storage is secondary to provenance: do not discard or re-save these files as an initial cleanup step.

## 3. Latest recorded empirical position

Prepared data contain five participants, nine conditions, radians for response error and seconds for RT. Retained totals are AQ 4,488; ES 4,488; HC 4,495; PG 4,492; YL 4,497: 22,460 trials in total. Conditions distinguish item count S, unique-colour count C, and R/NR cue state. Baseline cells with S = C carry an NR suffix but are treated as baseline in grouped timing models.

The active Cauchy sequence is substantial:

1. H0: nine free memory dispersions and shared decision parameters, 14 parameters.
2. H1_eta / H1_vnorm / H1_ter: release one decision component across cells, 22 parameters each.
3. H_satDecision: descriptive headroom, 38 parameters.
4. H2: two 20-parameter allocations of load/context effects.
5. H3: four matched 18-parameter routes comparing set-size/colour grouping of drift strength or timing, with cue offsets.

The current route CSVs give these BIC leaders among the fitted Cauchy candidates:

| Participant | Lowest recorded BIC route | BIC | Interpretation limit |
|---|---|---:|---|
| AQ | H3_1v_tcolor | 5942.56 | Shared drift; colour/cue timing |
| ES | H3_1t_vcolor | 1942.20 | Shared Ter; colour/cue drift |
| HC | H2_tsensitive | 2310.36 | Only 2.07 BIC better than H3_1v_tcolor |
| PG | H3_1v_tcolor | 5659.97 | Effectively tied with Ter/set grouping: difference 0.15 |
| YL | H2_tsensitive | 4633.33 | Colour/cue drift H3 is close: difference 4.24 |

These are saved-fit rankings, pending the numerical audit already specified in the notes. They support investigating structured timing and evidence effects. They do not establish a universal timing architecture or selective psychological influence.

Cellwise eta does not earn its BIC cost for four participants relative to H0; ES improves but prefers other routes. Both cellwise vnorm and Ter improve BIC over H0 for all five. The saturated model reveals remaining fit headroom but is not the final account. The notes report that restricted timing models have not consistently resolved slow errors.

The early front-end benchmark in `TestFits/Archive/InitialFrontEndComparison` is a separate stage. Its summary favours free JP by BIC for all five participants over POP and JP-Cauchy under that stage's settings. Earlier sibling-folder notes report other rankings. These comparisons must retain their implementation and architecture labels; they cannot be combined into one final model-ranking table.

## 4. Specific cleanup issues

### Conflicting current narratives

The master note is dated 23 September and lists H2 as the BIC leader for four participants. The stage note incorporates September 29–30 H3 fits and AQ warm-start corrections. The saved CSVs support the later account. Make one current overview authoritative, with dated historical milestone tables clearly labelled. The master also lists the original H2 aggregate under its maintenance section, whereas the stage note identifies the corrected merged aggregate.

The AQ H1_ter aggregate retains its original September 14 filename despite a later replacement of AQ's fit. Thus filenames alone cannot identify a run's immutable contents. Preserve this history in a manifest and use new versioned outputs for future corrections.

### POP model identity

The inspected `vpop300rot.c` computes von Mises tuning plus `xi * EulerGamma`, then normalizes those positive weights. This is a linear normalization of tuning plus a constant floor. It does not implement the raw-activation Gumbel-max rule, which produces softmax probabilities. Oberauer explicitly distinguishes linear Luce normalization from Luce on exponentially transformed activation, the latter equivalent to Gumbel SDT.

Consequently, label the current result by its implemented equation and establish whether the intended SDT comparator was tested elsewhere. Do not silently rename the existing fit as that comparator or silently replace its equation. Reference: [Oberauer (2023), especially Eq. 4 and the model-space discussion](https://doi.org/10.1037/rev0000328).

### Runtime and portability

- `prepareRe2024Data.m` defaults to the former `Documents/GitHub/...` location, which does not exist here. The corresponding raw CSV exists at `/Users/prefabteam_ysl/Developer/DazExperiments/Data/Redundancy 2024/Modelling/POPCDM/DazPreprocessed.csv`.
- The runner calls the preparation function with its default path and rewrites the prepared MAT file. Establish explicit data configuration and a documented frozen prepared-data version before rerunning.
- `test_fit_re2024.m` currently registers only Cauchy, despite accepting `requestedModels`. The POP/JP wrappers remain available, but there is no current matched three-front-end catalogue in this runner.
- `plot_re2024_qvwm.m` and `plot_re2024_besth1_h2ts_marginals.m` require exactly one matching H2 aggregate. There are two: the original and corrected merged files. Replace wildcard selection with explicit manifest paths.
- The private theory draft link in the notes points to a missing Downloads file. A `cau26.pdf` exists under `/Users/prefabteam_ysl/Developer/DazExperiments/Projects/Encoding2526/`; its version/content was not assessed in this review. Link the intended version and keep its theoretical contribution distinct from this project's empirical results.
- Repeated core and plotting-helper names across folders create MATLAB path-shadowing risks. Use explicit project paths and capture resolved MEX paths; avoid recursively adding all historical folders.

### Numerical status

Source inspection agrees with the already recorded issues: stored-column stride in total-mass calculation, missing explicit outer-mixture Gt wrap closure, inconsistent provenance of joint likelihood and returned angular summaries, conditional-median calculation, RT-window conditioning, and nondecision-time convolution conventions. Latent-angle resolution also remains to be assessed.

These have different possible consequences. A summary-only correction requires regenerated figures; a likelihood change can require affected refits. Inspecting C source does not establish which production MEX outputs or fitted likelihoods change. Run isolated comparisons at saved vectors before deciding.

An older note treats a lower Cauchy NLL than free JP as evidence for the restriction. If the models are truly nested with mapped bounds and the same likelihood, free JP must be able to reproduce the Cauchy solution. Such a likelihood reversal calls for an embedding/optimization check. A valid BIC preference for the simpler Cauchy remains possible after that check.

### Figure status

QVWM has both participant subfolders and flattened exports with overlapping names; byte hashing found no exact duplicate PNGs in the active figure tree. Treat them as potentially different versions until their sources are known. Preserve exploratory figures and publish a separate curated set with explicit run provenance. The current primary figure list does not cover the full H3 comparison.

## 5. Proposed organization

Start with a small documentation layer while retaining existing runnable paths:

```text
README.md                       project question, status, entry points
docs/
  current_status.md             current evidence, decisions, priorities
  model_dictionary.md           equations, parameter scales, route definitions
  decisions.md                  dated choices with rationale
  numerical_audit.md            measured results and refit decisions
manuscript/
  working_draft                 collaborative research draft
  evidence_map.md               claims linked to results and figure sources
POPvJPvCauchy/
  [existing code and results retained initially]
  results_manifest.csv          explicit canonical files and status
  Figures/manuscript/           curated exports after validation
```

Use one current-status document and link to the detailed operational material. Avoid maintaining the same numerical narrative in three notes. Once stable, the old master can become a historical planning document, with its useful theory material migrated deliberately.

The results manifest should have one record per route/run, identifying the canonical aggregate, summary CSV, participant coverage, parameter-layout version, source/MEX hashes, data version, correction/parent run, validation status, and figure consumers. Record the AQ merged aggregate as such. A second participant-level export can hold raw NLL, objective penalty, AIC/BIC, optimization information, and boundaries.

Keep model family separate from decision architecture in future names, for example `frontend=cauchy; decision=vShared_tColourCue; memory=cellwise`. Retain existing H labels as aliases so old results remain interpretable. The H1/H2/H3 numbering is a development history, not an explanation for supervisors.

Physical relocation of legacy folders and splitting active code into `src`, `scripts`, and `results` can follow later, after references and MATLAB path resolution are controlled. Use small reviewable moves. Avoid a global rename/refactor at the same time as a numerical correction. Track text/code in the parent version-control repository if present, with a deliberate policy for large MAT outputs and platform-specific MEX binaries.

## 6. Recommended next work and drafting boundary

1. **Reconcile the record:** create the overview, dictionary, explicit manifest, and a current comparison table including H3 and the corrected AQ fits. Record old milestones as history.
2. **Make replay reliable:** configure data paths, resolve canonical files explicitly, capture code/MEX provenance, and reproduce saved vectors. The remaining YL H1_ter nesting miss is a specific follow-up, rather than a reason to restart all fits.
3. **Measure the numerical issues:** use separate builds, then classify changes as prediction-only or likelihood-changing. Refit only where justified.
4. **Complete the scientific comparison:** agree POP's equation and a small common set of decision architectures; run matched POP/JP/Cauchy comparisons. Avoid choosing a unique architecture for each front end or participant to manufacture a ranking.
5. **Test the memory theory:** define the resource-to-gamma law, item/colour/multiplicity allocation, and fixed versus free exponent before fitting constraints jointly with decision parameters. This is central to the project's theoretical motivation.

Drafting can begin alongside steps 1–3. The first supervisor-facing document should be a coherent research draft with provisional Results and an explicit short list of unresolved decisions. It need not wait for every proposed extension, but it should not present pending comparisons or allocation tests as completed findings.

A useful narrative is: research question and candidate mechanisms; shared CDM and experimental design; exploratory decision/timing development; current empirical findings and limitations; planned matched front-end and allocation tests. Keep exhaustive run history and numerical details in supporting material. The separate theory manuscript supplies background and predictions with attribution; it is not part of this project's Results.

## 7. What this review verified

- Read the master, current stage note, relevant historical synthesis, sibling implementation notes, and team example notes.
- Inspected active preparation, specification, runner, likelihood, build, core, and plotting code.
- Checked the 55 participant/route records in all 11 canonical Cauchy summary CSVs against aggregate MAT scalar fields. NLL, minus2LL, AIC, and BIC agree to within 1e-7. This checks saved-file consistency, not forward-model reproduction.
- The CSV field named NLL represents the optimization objective. HC H0 has a small saved objective penalty of approximately 0.0013714; the other 54 checked records have objective minus ll2/2 within 1e-7 of zero. Future exports should distinguish these quantities explicitly. Signed raw NLL was not recomputed.
- Inspected prepared trial counts and a regional RT figure, inventoried files, checked figure hashes, located the moved raw-data/theory-draft paths, and consulted Oberauer's primary paper for the response-rule distinction.
- Did not run MATLAB, rebuild MEX files, evaluate new likelihoods, optimize models, modify production code, relocate existing files, or draft the manuscript.
