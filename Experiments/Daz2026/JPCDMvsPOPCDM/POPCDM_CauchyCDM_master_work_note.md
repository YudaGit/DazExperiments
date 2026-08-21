# CDM front-end comparison: master theory-testing work note

**Project:** Redundancy 2024 visual working-memory continuous recall  
**Models:** CDM with Jones--Pewsey, wrapped-Cauchy, and POP/Luce front ends
**Participants:** AQ, ES, HC, PG, YL  
**Conditions:** S2C2, S4C2NR, S4C2R, S4C4, S6C2NR, S6C2R, S6C4NR, S6C4R, S6C6  
**Current data filter:** valid response error and response time from 300 to 3000 ms  
**Last consolidated:** 21 August 2026

This is the primary conceptual and empirical record for the front-end comparison project. It is designed to support continued model development and later conversion into manuscript Introduction, Model, Results, and Discussion sections. Route-specific notes remain the detailed implementation logs:

- `POPCDM_Matlab/POPCDM_theory_testing.md`
- `JPCDM_Matlab/JPCDM_theory_testing.md`
- `CauchyJP/CauchyCDM_theory_testing.md`

## 1. Research question

This is a theoretical and empirical project comparing circular decision models for visual working-memory continuous recall. All candidate models retain the general circular diffusion model as the decision layer. The central question is which front end should feed the CDM so that the resulting joint model provides the best account of behavioural response-angle and response-time data.

The central theoretical problem is not only which probability distribution fits best. It is how stochastic variability should be assigned to latent memory evidence, retrieval or directional selection, decision formation, and final response. The experimental data constrain the combined process strongly, but do not independently identify every stage of noise.

The candidate front ends currently in scope are:

1. **JPCDM:** a Jones--Pewsey directional front layer coupled to the CDM.
2. **CauchyCDM:** the Jones--Pewsey special case with `psi=-1`, equivalent to a wrapped-Cauchy directional front layer.
3. **POPCDM:** a von Mises population-code front end with Gumbel-max noise and maximum decoding, implemented through a Luce-choice transformation before the CDM.

The working goal is to identify the best front-end specification for the general CDM, not to compare CDM against non-CDM response models.

## 2. Evidence-status vocabulary

To keep later manuscript claims disciplined, entries use these labels:

- **Implemented:** present in the current code.
- **Validated:** numerical or interface behaviour has been explicitly checked.
- **Empirical result:** obtained from the current five-participant fits or diagnostics.
- **Interpretation:** theoretically motivated reading of a result, not uniquely identified by the data.
- **Open test:** required before a publication-level conclusion.

## 3. Shared data and decision skeleton

The current comparable POPCDM and CauchyCDM routes use participant-level joint likelihoods for response angle and RT over nine conditions. Current shared decisions include:

- three drift norms grouped by set size, S2/S4/S6;
- shared radial drift variability, boundary separation, nondecision time, and nondecision-time range;
- tangential drift variability fixed at `exp(-6)`;
- diffusion scale fixed at 1;
- target-centred errors with no categorical phase bias;
- 50 unique response-angle grid points;
- 300 interior time points over a 3 s model horizon;
- numerical conditioning on the behavioural RT-selection interval, 0.3--3.0 s;
- 16 bounded `fmincon` starts with the interior-point algorithm and `1e-6` stopping tolerances.

The models differ in their front-layer distribution, parameterization, hard boxes, and currently one likelihood-boundary convention described in Section 6. The older JPCDM fits are historically informative and have been superseded by the current JP H0a/H0b route for future formal comparisons.

## 4. POPCDM route

### 4.1 Generative interpretation

The current POPCDM composition is:

```text
memory activation
-> Gumbel-max/Luce directional selection
-> CDM accumulation and boundary crossing
-> response
```

The POP layer is based on the Oberauer population-code measurement model. In its standalone use, Gumbel-max noise and maximum-likelihood response selection are represented efficiently through Luce's choice rule. The fitted POP distribution can therefore represent variability arising from memory and response selection rather than a cleanly isolated encoding distribution.

### 4.2 Current hypotheses

**H0a: conditional amplitude**

- one shared POP concentration `kappa`;
- nine condition-specific amplitudes `alpha`;
- 17 free parameters in total.

**H0b: conditional concentration**

- one shared `alpha`;
- nine condition-specific `kappa` values;
- 17 free parameters in total.

**H1: power-law amplitude restriction**

- one shared `kappa`;
- estimated reference amplitude `A2`;
- route-specific exponents `beta_U`, `beta_NR`, and `beta_R`;
- 12 free parameters in total;
- theoretically required exponent box `beta in [-1, 0]`.

For unredundant and nonredundant routes,

$$
\alpha = A_2\left(\frac{N_c}{2}\right)^\beta.
$$

For redundant conditions with multiplicity term $m=S-C+1$,

$$
\alpha = A_2\left(\frac{N_c}{2}\right)^\beta m^{-\beta}.
$$

The theoretical single-item intercept is

$$
A_1=A_2 2^{-\beta},
$$

so $A_1 \geq A_2$ when $\beta \leq 0$.

The equality

$$
\alpha_{S2C2}=\alpha_{S4C2NR}=\alpha_{S6C2NR}=A_2
$$

is an algebraic implication of H1, not an implementation error.

### 4.3 Critical POPCDM implementation and specification changes

**Implemented:**

1. The original theory-testing stack was reorganized into H0a, H0b, and nested H1 specifications using explicit free/fixed parameter maps.
2. Drift norm was changed from U/NR/R grouping to set-size S2/S4/S6 grouping. This matches the empirical RT load effect and prevents R/NR accuracy differences from being absorbed into separate CDM kernels.
3. Radial variability, boundary, nondecision time, and nondecision-time range were made shared across conditions for the current comparison.
4. Tangential variability was fixed at `exp(-6)` consistently in model expansion and the forward model.
5. The drift and boundary boxes were widened from `[5,10]` to `[2,12]` after the narrower box pinned ES at its boundary and worsened fit.
6. The amplitude upper bound was raised to 300 because the joint model requires much larger POP concentration than the standalone response-angle measurement model.
7. H1 was implemented with route-specific exponents while retaining the theoretically required `[-1,0]` range.
8. The likelihood was aligned to the JPCDM 50-by-300 interior grid by dropping POPCDM's final time column and conditioning density on retained RTs.
9. The full fits use 16 explicit starts, parallel local optimization, 2,000 maximum iterations, and 20,000 maximum function evaluations.
10. Dedicated diagnostics were added for POP-only versus CDM noise partition and for RT conditional on response-error region.

The mathematical supervisor model `popcdm2` itself was deliberately not reparameterized. Identification changes were made through scientifically interpretable parameter grouping and constraints.

### 4.4 POPCDM empirical results

**Empirical result:** H0a generally outperformed H0b, although AQ and YL benefited from H0b. H1 was worse in NLL than its nesting model H0a for every participant. Only HC preferred H1 by BIC.

| ID | H0a NLL | H0b NLL | H1 NLL | Preferred POP baseline |
|---|---:|---:|---:|---|
| AQ | 3123.02 | 3106.92 | 3180.57 | H0b |
| ES | 1178.78 | 1291.93 | 1297.99 | H0a |
| HC | 1333.16 | 1339.98 | 1343.46 | H0a |
| PG | 2968.57 | 3123.37 | 3082.82 | H0a |
| YL | 2622.98 | 2550.60 | 2726.03 | H0b |

Four participants placed at least one H1 exponent at the lower bound `-1`. This is not evidence that the allowed theoretical range should be widened. H0a implies baseline amplitude reductions steeper than the admissible power law, and the shared `A2` restriction cannot reproduce unequal conditional amplitudes at `Nc=2` without affecting redundant conditions through the multiplicity term.

### 4.5 POPCDM noise-partition result

**Empirical result:** the fixed-direction CDM kernel is narrow, with approximately 8.7 degree circular SD and virtually no mass beyond 45 degrees. It mainly transfers central probability into the shoulder. The POP component fitted inside the joint model becomes narrower than a standalone POP fit, while the combined model recovers a similar aggregate final distribution.

Mean partition across participants and conditions:

| Stage | Central <=15 deg | Shoulder 15--45 deg | Tail >45 deg |
|---|---:|---:|---:|
| Observed | .674 | .230 | .096 |
| POP-only refit | .655 | .251 | .094 |
| POP component in H0a | .722 | .190 | .088 |
| Fixed-direction CDM | .961 | .039 | <.001 |
| Combined H0a | .652 | .256 | .092 |

**Interpretation:** this is not simple uncompensated double-noise overdispersion. It is noise reallocation and weak stage identification. Shared `kappa` determines the basic POP shape; conditional `alpha` suppresses or restores the POP noise floor after the CDM has supplied shoulder dispersion. Large `alpha` values therefore do not provide a transparent scale of memory strength.

The fitted `alpha` range is itself theoretically diagnostic. In the current POPCDM fits, `alpha` often needs a very large range, roughly from the low tens to well above 200. Raising `alpha` reduces the Gumbel/Luce noise floor and approximates high precision; lowering `alpha` restores far-tail mass by making the front-layer selection noisier and heavier-tailed. This makes `alpha` do more than scale memory strength. It becomes the main control over how much far-tail behavioural variability is assigned to the POP layer rather than to the CDM.

The resulting concern is conceptual. The standalone POP layer was originally positioned as a VWM continuous-report behavioural measurement model. Its Gumbel/Luce noise term is therefore an umbrella behavioural noise term that can absorb variability introduced during encoding, maintenance or consolidation, retrieval, decision formation, and response selection. When that layer is placed before a CDM, a response-selection-like operation is followed by another response-selection or response-commitment operation. The two mechanisms are not identical, but the sequential composition risks duplicating decision-level noise unless the POP operation is reinterpreted as latent memory-evidence variability rather than final behavioural response selection.

### 4.6 POPCDM RT-by-error result

**Empirical result:** observed tail responses were 124 ms slower than central responses on average, but H0a predicted only 13 ms slowing.

| Region | Observed mean RT | H0a mean RT |
|---|---:|---:|
| Central | 1.417 s | 1.435 s |
| Shoulder | 1.450 s | 1.447 s |
| Tail | 1.541 s | 1.448 s |

The fitted model attributed approximately 93% of tail responses to a tail-region latent POP direction. Thus large directional errors are already generated in the front layer, but a badly directed selection retains roughly the same drift strength as a correct selection and can be executed too quickly.

**Interpretation:** directional reliability and decision strength need a theoretically derived coupling. A weak latent evidence state should both increase directional uncertainty and reduce CDM drift strength. An arbitrary angle-dependent drift function would fit this signature but would not provide an adequate theory.

The RT miss is manuscript-relevant rather than merely diagnostic. The model underpredicts far-tail RT by roughly 100 ms or more because far-tail responses are attributed mostly to badly directed POP selections whose CDM drift norm is still as strong as a near-target selection. The data imply that large directional errors are not only less accurate but also slower, so the process account must explain why error magnitude carries timing information even when mean RT effects across experimental conditions are relatively small.

The 9-alpha/1-kappa and 9-kappa/1-alpha POP specifications also reveal a shape tradeoff. The 9-alpha/1-kappa route usually wins, suggesting that condition-specific amplitude is the stronger baseline degree of freedom. However, participants with larger cross-condition response-angle variability can favour the 9-kappa/1-alpha route. The current interpretation is that conditional `alpha` is better at allocating far-tail mass, whereas conditional `kappa` can better adjust the shoulder region. Neither parameterization is a fully satisfactory account of peak, shoulder, tail, and RT-by-error structure.

## 5. CauchyCDM route

### 5.1 Generative interpretation

With Jones--Pewsey shape fixed at `psi=-1`, the front layer becomes a wrapped-Cauchy distribution over latent CDM drift direction:

```text
wrapped-Cauchy latent drift-direction variability
-> CDM accumulation and boundary crossing
-> response
```

Increasing Cauchy `kappa` narrows the latent direction distribution and reduces far-tail mass. Unlike the current POP layer, this front layer does not perform a separate Gumbel-max/Luce response-selection operation before diffusion.

### 5.2 H0 specification

Cauchy H0 has 16 free parameters:

- three set-size drift norms;
- shared radial variability;
- shared boundary separation;
- shared nondecision time;
- shared nondecision-time range;
- nine condition-specific wrapped-Cauchy `kappa` values.

Fixed values are `psi=-1`, tangential variability `exp(-6)`, diffusion scale 1, and phase bias 0.

### 5.3 Critical CauchyCDM model and implementation changes

The supplied JP-CDM example was not used unchanged. The following alterations must be reported:

1. **Compiled shape restriction:** `psi=-1` was specialized in `vjp300rot.c`, removed from the runtime MEX parameter vector, and made impossible to estimate accidentally.
2. **Cauchy algebra:** the generic Jones--Pewsey evaluator was replaced by the algebraically equivalent wrapped-Cauchy density for `psi=-1`.
3. **Tangential variability interface:** tangential variability became a runtime MEX argument; H0 fixes it at `exp(-6)` in MATLAB.
4. **Memory safety:** the Bessel-switch loop now checks its array bound before indexing.
5. **Computational cache:** 50 Bessel roots and corresponding J1 values are cached once per MEX process. This changes runtime, not predictions.
6. **Removed example-specific machinery:** the supplied four-condition stimulus-phase and categorical-bias components are not used; the current model operates on target-centred errors.
7. **Shared nondecision time:** condition-specific example nondecision times were replaced by the shared POP-comparison specification.
8. **Condition mapping:** drift norm is grouped by set size and Cauchy concentration is free across nine conditions.
9. **Matrix convolution:** row-wise uniform nondecision-time convolution was replaced by a single `conv2` operation over the angle-by-RT matrix. Maximum discrepancy from the row-wise reference was below `9e-16`.
10. **Numeric hot path:** repeated objective evaluation uses direct numeric indexing rather than constructing condition tables. Labelled tables remain in the reporting path.
11. **Build protection:** fitting and validation check whether the MEX is absent or older than its C source and rebuild when required.
12. **Environment:** the MEX was compiled with Microsoft Visual C++ 2022 and statically linked GSL 2.8 libraries. Redistribution must comply with the GSL license.

**Validated:** retained joint mass was approximately .9993, circular symmetry error was below `7e-16`, increasing `kappa` reduced tail mass, obsolete runtime `psi` input was rejected, matrix convolution matched the reference, and MATLAB Code Analyzer reported no issues in the optimized path.

### 5.4 Parameter boxes

The Cauchy boxes follow the supplied JP-CDM example rather than the wider POPCDM boxes:

| Parameter | Lower | Upper |
|---|---:|---:|
| Drift norm | 0 | 7.5 |
| Cauchy `kappa` | 0 | 7.5 |
| Radial variability | 0.01 | 4 |
| Boundary | 0.5 | 5 |
| Nondecision time | 0 | 1.5 |
| Nondecision-time range | 0 | 0.7 |

The radial lower bound is 0.01 rather than the example's formal zero because the compiled forward model applies that numerical floor.

### 5.5 Full Cauchy H0 results

**Empirical result:** all 80 starts returned positive exit flags. Selected solutions all had exit flag 2 and no run reached the iteration limit.

| ID | Trials | NLL under periodic likelihood | AIC | BIC |
|---|---:|---:|---:|---:|
| AQ | 4488 | 2947.04 | 5926.07 | 6028.62 |
| ES | 4488 | 1005.32 | 2042.64 | 2145.19 |
| HC | 4495 | 1137.66 | 2307.31 | 2409.88 |
| PG | 4492 | 2780.45 | 5592.91 | 5695.47 |
| YL | 4497 | 2314.65 | 4661.30 | 4763.88 |

Only ES had two starts within one NLL unit of the selected solution. The other participants had one winning solution within that range. This does not invalidate the winners, but indicates that the best basin was not repeatedly recovered to within one NLL unit.

**Boundary audit:** AQ and PG placed boundary separation effectively at the upper cap of 5. ES placed S2 drift norm at 7.472 on an upper bound of 7.5. HC and YL were comfortably interior. All fitted Cauchy concentration values were interior. These cases require sensitivity fits after likelihood harmonization; the primary fit was not silently widened.

### 5.6 Cauchy diagnostics

**Empirical result:** overall mean absolute observed-model proportion error was .0497 for angle bins and .0224 for RT bins.

RT proportions were generally reproduced closely. Angle fits often assigned too much probability to the central region and too little to the 15--45 degree shoulder. The heavy-tailed layer nevertheless captured substantial far-tail mass in broad conditions such as YL S6C4NR and S6C6NR.

**Interpretation:** a wrapped-Cauchy directional layer is useful, but a single symmetric shape does not fully reproduce the empirical combination of sharp peak, shoulder, and tail across all conditions.

The theoretical advantage of the Cauchy route is that heavy tails are native to the memory-stage directional distribution. This makes the tail interpretable as latent memory variability while leaving response selection, timing, residual diffusion, and response commitment to the CDM. That division of labour is cleaner than the current POPCDM sequence, where a Gumbel/Luce response-selection-like operation precedes the CDM.

## 6. Provisional empirical comparison

### 6.1 Important likelihood mismatch

**Open test / current limitation:** POPCDM was fitted with an angular interpolation grid open at `+pi`. CauchyCDM was fitted after periodically closing the grid. Between three and six retained trials per participant fell beyond the last open-grid angle. Under the POP convention these observations receive the likelihood floor rather than circular interpolation.

The reported periodic Cauchy NLL, AIC, and BIC therefore must not be compared directly with the saved POP values in a publication table.

As a conservative diagnostic, the fitted Cauchy solutions were reevaluated under the same open-grid convention as POPCDM, without refitting:

| ID | Best POP NLL | POP model | Cauchy NLL under open grid | Provisional Cauchy advantage |
|---|---:|---|---:|---:|
| AQ | 3106.92 | H0b | 3013.83 | 93.09 |
| ES | 1178.78 | H0a | 1076.99 | 101.79 |
| HC | 1333.16 | H0a | 1248.58 | 84.58 |
| PG | 2968.57 | H0a | 2925.02 | 43.55 |
| YL | 2550.60 | H0b | 2433.17 | 117.43 |

Cauchy H0 uses 16 parameters and the POP baselines use 17. The provisional advantage therefore survives a conservative common-convention evaluation and would also be favoured by information criteria. Nevertheless, the formal comparison requires periodic closure and refitting of both routes.

### 6.2 Current empirical assessment

**Interpretation supported by current evidence:** CauchyCDM is the stronger empirical baseline. It provisionally improves joint fit for every participant with one fewer parameter. This conclusion is strong but not yet publication-final because likelihood harmonization and refitting remain outstanding.

The marginal diagnostics add nuance. POPCDM's aggregate angle partition was close to observed after internal noise reallocation. CauchyCDM shows a recurring central-versus-shoulder discrepancy. Its joint-likelihood advantage may therefore reflect fine-grained angle-by-RT structure rather than superiority in every marginal feature.

Graphically, CauchyCDM can look acceptable even where the peak/shoulder/tail proportion split is not as close as POPCDM. Using the current saved diagnostics, POPCDM H0a has lower angle-bin mean absolute error than Cauchy H0 across the central/shoulder/tail bins: approximately .034 versus .050. The difference is largest for central and shoulder mass, where Cauchy tends to overpredict central responses and underpredict shoulder responses. The important point for now is that CauchyCDM wins the joint fit despite this marginal proportion-split disadvantage.

## 7. Theoretical comparison

### 7.1 Why CauchyCDM is currently cleaner

The Cauchy route gives the two layers distinct formal jobs:

- front layer: across-trial uncertainty in latent drift direction;
- CDM: accumulation, timing, residual diffusion, and response commitment.

It avoids placing a complete Gumbel-max/Luce response-selection mechanism before a second decision process. Its fitted concentration parameter is therefore easier to interpret as directional dispersion than POPCDM's conditional amplitude, which also regulates noise allocation between layers.

### 7.2 Why POPCDM remains theoretically important

POPCDM offers the more ambitious substantive memory theory. It links set size, colour structure, redundancy, population activation, and a theoretically constrained scaling law. Cauchy H0 currently estimates nine unconstrained condition concentrations and does not explain why those concentrations differ.

The power-law failure is scientifically informative rather than a reason to discard POP theory. It shows that the standalone measurement-model scaling does not transfer straightforwardly into the current sequential POP-plus-CDM composition. The failure may reflect the duplicated role of response selection, weak identification at large amplitude, an incorrect scaling law, or some combination of these.

For CauchyCDM to become more than a strong descriptive baseline, its condition-specific `kappa` values should be constrained by the same family of memory-capacity theories that motivated the POPCDM amplitude law. The relevant targets are Smith and colleagues' sample-size model, attention-weighted sample-size model, and related power-law formulations. If Cauchy `kappa` scales across conditions as these models predict, the Cauchy route would combine a cleaner process architecture with strict, theory-rooted constraints on memory-stage variability.

### 7.3 Shared unresolved limitation

Both current routes make latent directional deviation largely independent of drift strength. CauchyCDM removes the duplicate response-selection interpretation but still allows a distant drift direction to retain the same norm as a near-target direction. It may therefore share POPCDM's inability to generate sufficiently slow tail responses.

**Open test:** run the same RT-by-error and latent-direction attribution diagnostic for CauchyCDM before claiming that it provides a better process account of joint angle and RT.

### 7.4 Current theoretical judgement

- **Better current process architecture:** CauchyCDM.
- **Richer memory theory:** POPCDM.
- **Better current empirical baseline:** provisionally CauchyCDM.
- **Best complete theory:** not yet established.

A defensible current manuscript statement is:

> A wrapped-Cauchy directional front layer provides a more parsimonious and process-clean account than the present sequential population-code measurement model, while the population-code route retains the stronger substantive account of memory and redundancy. The remaining challenge is to derive a joint latent-evidence mechanism that couples directional reliability to decision strength.

## 8. Publication-facing claims and cautions

### Claims currently supported

1. A front layer is required because fixed-direction CDM contributes almost no far-angle tail mass.
2. The POP and CDM stages can reallocate central and shoulder variability while producing similar final angle marginals.
3. Conditional POP amplitude is not a pure, directly interpretable memory-strength parameter in the joint model.
4. The constrained POP power law is not supported as a general participant-level account in the present composition.
5. Wrapped-Cauchy directional variability provides a strong and parsimonious empirical baseline.
6. Response-error tails are behaviourally slower than central responses, requiring a connection between directional reliability and decision strength.
7. In the harmonized current JP comparison, JP H0b outperforms POPCDM H0 for every participant, but the constrained Cauchy special case still outperforms JP H0b with one fewer parameter.

### Claims not yet supported

1. That CauchyCDM has publication-final lower AIC/BIC than POPCDM, pending harmonized refits.
2. That the wrapped-Cauchy distribution is uniquely preferred over other theoretically defensible heavy-tailed directional families.
3. That CauchyCDM explains RT conditional on error better than POPCDM.
4. That fitted front-layer dispersion can be uniquely assigned to encoding, maintenance, retrieval, or response selection.
5. That widening the Cauchy decision boxes would or would not alter the model comparison.
6. That unrestricted JPCDM is the preferred JP-family account, because the current H0b result remains worse than Cauchy despite having one extra parameter.

## 9. Prioritized next work

1. **Harmonize the likelihood.** Periodically close both angular grids, retain identical 50-by-300 time coordinates, use the same RT conditioning and floor, validate pointwise equivalence of the likelihood wrapper, and refit POP H0a/H0b and Cauchy H0.
2. **Run Cauchy RT-by-error diagnostics.** Compare observed and predicted central/shoulder/tail RT distributions and calculate posterior latent-direction attribution.
3. **Run targeted Cauchy bound sensitivity.** After harmonization, widen boundary for AQ/PG and S2 drift norm for ES. Treat this as sensitivity analysis, not replacement of the original example-informed fit.
4. **Compare models formally.** Report participant NLL, AIC, BIC, parameter count, start recovery, boundary contact, and diagnostic errors under the common likelihood.
5. **Test an evidence-strength coupling.** Derive a latent evidence variable that jointly controls directional concentration and drift norm. Avoid an unconstrained angle-dependent drift patch.
6. **Preserve the POP theory test.** Evaluate whether a revised memory-only POP representation, without a completed response-selection operation, permits the theoretically required power law to remain in `beta in [-1,0]`.
7. **Consider constrained Cauchy structure.** Replace nine unrelated concentrations with a theoretically motivated condition law only after H0 establishes the descriptive target that such a law must reproduce.
8. **Quantify peak/shoulder/tail tradeoffs across front ends.** Compare observed, POPCDM, JPCDM, and CauchyCDM region proportions under the same bins and likelihood convention.
9. **Keep RT central in the model assessment.** Treat RT as a meaningful constraint on VWM continuous-recall models even when condition-level mean RT effects are modest.
10. **Extend diagnostics to current JP H0b.** Run RT-by-error and region-proportion comparisons for JP H0b alongside POPCDM and CauchyCDM.

## 10. Reproducibility map

### POPCDM

- Main note: `POPCDM_Matlab/POPCDM_theory_testing.md`
- Forward model: `POPCDM_Matlab/popcdm2.m`
- Theory models: `POPCDM_Matlab/pop_theory_models.m`
- Joint likelihood: `POPCDM_Matlab/popcdm_nll_arrays.m`
- Full fits: `POPCDM_Matlab/TheoryFits/`
- Noise partition: `POPCDM_Matlab/Figures/NoisePartition/`
- RT by error: `POPCDM_Matlab/Figures/RTByError/`

### CauchyCDM

- Main route note: `CauchyJP/CauchyCDM_theory_testing.md`
- Compiled core: `CauchyJP/vjp300rot.c`
- MATLAB wrapper: `CauchyJP/cauchycdm2.m`
- Joint likelihood: `CauchyJP/cauchycdm_nll_arrays.m`
- Model specification: `CauchyJP/cauchycdm_model.m`
- Full fit: `CauchyJP/CauchyFits/cauchycdm_H0_full_results.mat`
- Fit audit: `CauchyJP/CauchyFits/cauchycdm_H0_fit_audit.csv`
- Parameter estimates: `CauchyJP/CauchyFits/cauchycdm_H0_parameter_estimates.csv`
- Diagnostic summary: `CauchyJP/CauchyFits/cauchycdm_H0_diagnostic_summary.csv`
- Figures: `CauchyJP/Figures/H0/`

### JPCDM

- Main route note: `JPCDM_Matlab/JPCDM_theory_testing.md`
- Entry script: `JPCDM_Matlab/jp_fit_theory.m`
- Forward model wrapper: `JPCDM_Matlab/jpcdm1.m`
- Compiled core: `JPCDM_Matlab/vjp300rot.c`
- Model specification: `JPCDM_Matlab/jpcdm_model.m`
- Model expansion: `JPCDM_Matlab/jpcdm_expand_P.m`
- Joint likelihood: `JPCDM_Matlab/jpcdm_nll.m`, `JPCDM_Matlab/jpcdm_nll_arrays.m`
- Current fit runner: `JPCDM_Matlab/run_jpcdm_theory_fit.m`
- Current diagnostics: `JPCDM_Matlab/jpcdm_diagnostics.m`
- Current outputs: `JPCDM_Matlab/JPFits/`, `JPCDM_Matlab/Figures/H0a/`, `JPCDM_Matlab/Figures/H0b/`
- Historical fits: `JPCDM_Matlab/jp_fit_9p3v3ter_results.mat`, `JPCDM_Matlab/jp_fit_9k3v3ter_results.mat`
- Historical grouped fits: `JPCDM_Matlab/jp_fit_freePsi_groupedVnorm_results.mat`, `JPCDM_Matlab/jp_fit_freeKappa_groupedVnorm_results.mat`
- Parameter exports: `JPCDM_Matlab/condFitTable.xlsx`, `JPCDM_Matlab/condFit_rounded.xlsx`
- Current limitation: the comparable JP route has been implemented, but new H0a/H0b full-fit results have not yet been recorded in this master note.

## 11. Append-only research log template

Add future work below using this structure. Do not overwrite earlier entries when an interpretation changes; mark it superseded and link the new evidence.

### 2026-08-21: project framing and current front-end comparison

**Question:**
What is the project-level purpose of the JPCDM, CauchyCDM, and POPCDM comparisons?

**Status:**
Interpretation / empirical result.

**Model and code changes:**

- No code change.
- The master work note was reframed from a two-route POPCDM versus CauchyCDM record into a general CDM front-end comparison record.
- Candidate front ends are Jones--Pewsey, wrapped-Cauchy as the `psi=-1` Jones--Pewsey special case, and von Mises population coding with Gumbel-max/Luce maximum decoding.

**Fit specification:**

- Existing baseline-spec comparisons and diagnostics remain as recorded above.

**Results:**

- Superseded by the 2026-08-21 harmonized JP H0a/H0b results below.
- Historical saved baseline comparisons suggested POPCDM won against JPCDM, but those JP fits used older parameter groupings and are no longer the relevant comparison.
- The Jones--Pewsey route still needs constraints for theoretical interpretability; the Cauchy special case at `psi=-1` is currently the strongest JP-family route.

**Interpretation:**
The research question is not whether a CDM is needed, but which latent directional front end should be paired with the general CDM for continuous-recall VWM data. The historical POP-versus-JP comparison has been superseded by the harmonized JP H0b result, which beats POPCDM H0 but still loses to Cauchy. The unrestricted JP family should be treated cautiously because extra shape flexibility improves descriptive freedom without beating the constrained Cauchy special case.

**Manuscript consequence:**
The Introduction and Model Comparison framing should present all candidates as CDM variants with different front-end assumptions. Claims about JP should distinguish the general Jones--Pewsey family from the theoretically restricted Cauchy case.

**Next decision:**
Use the harmonized JP H0b result in the common baseline comparison table and decide whether unrestricted JP should be retained as a flexibility benchmark or omitted from the main theoretical comparison.

### 2026-08-21: POPCDM limitations, Cauchy rationale, and RT agenda

**Question:**
What deeper theoretical and diagnostic lessons follow from the POPCDM, JPCDM, and CauchyCDM comparisons?

**Status:**
Interpretation / empirical result / open test.

**Model and code changes:**

- No code change.
- The master note was extended to record the POPCDM noise-allocation concern, the CauchyCDM theoretical rationale, and the RT-focused modelling agenda.

**Fit specification:**

- POPCDM: current baseline results include 9-alpha/1-kappa and 9-kappa/1-alpha variants.
- CauchyCDM: fitted to the same Redundancy 2024 data with a procedure designed to be comparable to the POP route, with one fewer parameter in the baseline specification.
- RT structure: current evidence favours grouping `vnorm` by set size rather than by number of unique colours or cue type.

**Results:**

- POPCDM requires a large `alpha` range, approximately low tens to above 200, to manage far-tail mass and the Gumbel/Luce noise floor.
- Increasing `alpha` suppresses the front-layer noise floor and approximates high precision; decreasing `alpha` restores far-tail mass.
- The 9-alpha/1-kappa POP specification usually beats 9-kappa/1-alpha, but individuals with greater cross-condition response-angle variability can favour 9-kappa/1-alpha.
- The two POP specifications appear to capture different parts of the distribution: 9-alpha/1-kappa is better for far-tail mass, whereas 9-kappa/1-alpha can better adjust shoulder mass.
- POPCDM misses far-tail RT by roughly 100 ms or more, so the reason for this failure should be explicitly addressed in the manuscript.
- CauchyCDM wins the current comparison with one fewer parameter and better fit on nearly all evaluated metrics.
- POPCDM may capture the peak/shoulder/tail proportion split better than CauchyCDM in some summaries, but the size of that advantage still needs formal quantification because Cauchy looks acceptable graphically.
- Set-size grouping of `vnorm` is empirically preferable to grouping drift norm by unique colour count or cue type.

**Interpretation:**
POPCDM's main conceptual issue is that the POP layer carries an umbrella behavioural noise term inherited from its role as a standalone continuous-report measurement model. That umbrella term can include encoding, maintenance, retrieval, decision, and response-selection variability. When placed before a CDM, the Gumbel/Luce operation and the CDM both contribute response-selection-like variability, creating a possible duplication of decision-level noise. CauchyCDM is cleaner because the heavy tail belongs naturally to latent memory-stage directional variability, while the CDM retains the response-selection and timing role.

The empirical RT result strengthens this concern. Large response errors are slower, but POPCDM makes them too fast because a badly selected POP direction can still be passed to CDM with normal drift strength. This suggests that future models need a latent evidence variable that jointly controls directional reliability and decision strength.

The larger research goal is to determine whether CauchyCDM can outperform or at least match other CDM front-end specifications across additional datasets. If it can, and if its `kappa` parameter scales across conditions according to the sample-size, attention-weighted sample-size, or related power-law models from Smith and colleagues, then it would provide a theoretically sound and strongly constrained CDM account for VWM continuous recall.

**Manuscript consequence:**
RT should be presented as an important constraint on VWM continuous-recall modelling even when experimental-condition mean RT effects are not large. The manuscript should argue that response-angle fits alone are insufficient because they can hide stage-allocation problems that RT-by-error reveals.

**Next decision:**
Quantify the Cauchy versus POP peak/shoulder/tail differences; run RT-by-error diagnostics for CauchyCDM; and develop a constrained Cauchy `kappa` law based on sample-size, attention-weighted sample-size, and power-law predictions.

### 2026-08-21: consistency audit against saved fits

**Question:**
Do the saved fit artifacts contradict the current master-note claims?

**Status:**
Validated / caveat / open test.

**Model and code changes:**

- No code change.
- Saved `.mat`, `.csv`, and `.xlsx` artifacts were checked against the master-note claims.

**Fit specification:**

- Current POP theory fits: `POPCDM_Matlab/TheoryFits/pop_theory_H0a_full_results.mat`, `pop_theory_H0b_full_results.mat`, and `pop_theory_H1_full_results.mat`.
- Current Cauchy H0 fit: `CauchyJP/CauchyFits/cauchycdm_H0_full_results.mat`.
- Historical JP fits: `JPCDM_Matlab/jp_fit_9p3v3ter_results.mat`, `jp_fit_9k3v3ter_results.mat`, `jp_fit_freePsi_groupedVnorm_results.mat`, and `jp_fit_freeKappa_groupedVnorm_results.mat`.

**Results:**

- Current POP H0a/H0b/H1 NLLs match the master table.
- Current Cauchy H0 periodic-likelihood NLLs match the master table and remain lower than the current best POP baseline for every participant.
- Historical JPCDM NLLs are much worse than current POP and Cauchy fits, but those JP fits are not a clean current-baseline comparison because their parameter groupings and decision skeleton differ from the current POP/Cauchy specification.
- POPCDM H0a has better current central/shoulder/tail angle-bin MAE than Cauchy H0, approximately .034 versus .050, despite Cauchy winning the joint likelihood.
- Cauchy H0 angle-bin error is concentrated in central and shoulder mass: it tends to overpredict central responses and underpredict shoulder responses. Tail-bin MAE is smaller for both models.

**Interpretation:**
No direct contradiction was found in the saved POPCDM and CauchyCDM numbers. The main correction is evidential status: claims about unrestricted JPCDM should be framed as historical and provisional until JP is refitted under the current harmonized front-end comparison design. The POP-versus-Cauchy story also needs to hold two facts together: Cauchy is the stronger current joint-likelihood baseline, while POP currently reproduces coarse angle-region proportions better.

**Manuscript consequence:**
Do not present the old JP numbers as a formal model-comparison table beside current POPCDM and CauchyCDM. If JP is included, either refit it under the harmonized specification or label it as a historical flexibility benchmark. Also report marginal angle-bin diagnostics separately from joint likelihood so readers can see that Cauchy's likelihood advantage does not mean it wins every descriptive summary.

**Next decision:**
Decide whether unrestricted JPCDM remains a main manuscript model. If yes, run a harmonized JPCDM refit; if no, position the Jones--Pewsey family through the constrained Cauchy special case and discuss unrestricted JP only as a prior exploratory benchmark.

### 2026-08-21: current comparable JPCDM H0a/H0b route

**Question:**
How should unrestricted JP-CDM be brought up to date with the current POPCDM and CauchyCDM routes?

**Status:**
Implemented / open test.

**Model and code changes:**

- Added `JPCDM_Matlab/JPCDM_theory_testing.md` as the JP route log.
- Added `jpcdm_model.m`, `jpcdm_expand_P.m`, `jpcdm_nll.m`, `run_jpcdm_theory_fit.m`, `jpcdm_diagnostics.m`, and `jp_fit_theory.m`.
- Updated `jpcdm1.m`, `vjp300rot.m`, and `vjp300rot.c` so tangential variability is passed at runtime.
- Updated `jpcdm_nll_arrays.m` to use periodic angular closure before interpolation.
- Older JP grouped-vnorm runners and saved fits are retained as historical artifacts.

**Fit specification:**

- JP H0a: one shared `kappa`, nine condition-specific `psi` values, 17 free parameters.
- JP H0b: one shared `psi`, nine condition-specific `kappa` values, 17 free parameters.
- Shared skeleton: set-size `vnorm`; shared `eta1`, `a`, `ter`, and `st`; `eta2=exp(-6)`; `phi=0`; diffusion scale 1; RT conditioning 0.3--3.0 s; 50 angle grid points; 300 time points over `tmax=3`; 16 `fmincon` starts for full fits.

**Results:**

- JP H0a and H0b full fits completed for all five participants.
- JP H0b beat JP H0a for every participant.
- JP H0b beat the best POP H0 baseline for every participant.
- Cauchy H0 beat JP H0b for every participant despite using one fewer parameter.

| ID | Best POP H0 NLL | JP H0a NLL | JP H0b NLL | Cauchy H0 NLL |
|---|---:|---:|---:|---:|
| AQ | 3106.92 | 3089.14 | 2949.65 | 2947.04 |
| ES | 1178.78 | 1237.58 | 1017.30 | 1005.32 |
| HC | 1333.16 | 1211.73 | 1147.12 | 1137.66 |
| PG | 2968.57 | 3081.45 | 2800.08 | 2780.45 |
| YL | 2550.60 | 2550.99 | 2344.38 | 2314.65 |

**Interpretation:**
JP remains an unrestricted shape-family benchmark. It does not need a POP-style H1 amplitude law in the current project logic because the constrained Cauchy special case already beats the best unrestricted JP H0 route. The useful JP degree of freedom is condition-specific `kappa`, not condition-specific `psi`, but estimating a shared `psi` does not improve enough over fixing `psi=-1`.

**Manuscript consequence:**
If unrestricted JP is included in the manuscript, use the new current H0a/H0b route rather than the historical JP result files. The current result supports treating unrestricted JP as a flexibility benchmark rather than a main theoretical account, because Cauchy is better and more parsimonious.

**Next decision:**
Add current JP H0b to the cross-model diagnostic suite, especially RT-by-error, then update the formal comparison table with NLL/AIC/BIC, convergence, boundary, and proportion diagnostics.

### YYYY-MM-DD: short title

**Question:**  
What theoretical or empirical issue was tested?

**Status:**  
Implemented / validated / empirical result / interpretation / open test.

**Model and code changes:**

- File and function changed.
- Mathematical or computational change.
- Whether predictions changed or only runtime changed.
- Whether recompilation was required.

**Fit specification:**

- Participants and exclusions.
- Parameterization and bounds.
- Starts, optimizer, stopping criteria, and random seed.
- Likelihood and grid convention.

**Results:**

- NLL, AIC, BIC, convergence, boundary contact, and diagnostics.
- Links to machine-readable outputs and figures.

**Interpretation:**  
What the result supports, what it does not identify, and plausible alternatives.

**Manuscript consequence:**  
Candidate sentence, figure, table, or section affected.

**Next decision:**  
The specific follow-up that would distinguish competing explanations.
