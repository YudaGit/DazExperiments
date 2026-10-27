# POPCDM theory testing — working notes

> **Consolidated project note:** `../POPCDM_CauchyCDM_master_work_note.md` is the primary cross-model theory, comparison, publication, and forward-work record. This file remains the detailed POPCDM route log.

Redundancy 2024 VWM data · lab IDs AQ, ES, HC, PG, YL · nine conditions  
S2C2, S4C2NR, S4C2R, S4C4, S6C2NR, S6C2R, S6C4NR, S6C4R, S6C6  
Filter: valid error, RT 300–3000 ms (~4490 trials each).

Goal: test the manuscript Gumbel-max / LCM **power-law on POP amplitude** inside POPCDM, while CDM jointly accounts for RT and response angle. `popcdm2` math is not changed.

Current default baseline is **H0a**. H1 is the nested power-law restriction of H0a.

---

## How to run

```matlab
cd POPCDM_Matlab

% Fit (overwrites TheoryFits/pop_theory_<name>_full_results.mat)
% In pop_fit_theory.m:
%   hypothesisNames = ["H0a","H0b"];   % baselines
%   hypothesisNames = "H1";            % power-law, warm-starts from saved H0a
pop_fit_theory

% Plot saved fits (no refit)
plot_saved_pop_theory_results("pop_theory_H0a_full_results.mat")
plot_saved_pop_theory_results("pop_theory_H1_full_results.mat", "YL")

% POP vs CDM angle kernel (edit the parameter block, then run)
sim_pop_vs_cdm_theta
```

Optimizer: 16 parallel `fmincon` starts, interior-point, MaxIter 2000.  
Grid: `nw = 50`, `tmax = 3`, `h = tmax/300`.

---

## Folder map

| File | Role |
|---|---|
| `popcdm2.m` | Generative model (supervisor). Polar drift from LCM popcode; CDM first passage. σ = 1. |
| `cdm.m`, `besselzero.m` | Circular diffusion + Bessel roots |
| `pop_theory_models.m` | Sel / Pvar / Pfix layouts, bounds |
| `pop_theory_expand_P.m` | Full P → 9-condition POPCDM params (set-size vnorm + 3-β α) |
| `popcdm_nll_theory.m` | Joint NLL |
| `run_popcdm_theory_fit.m` | Parallel fmincon runner |
| `pop_fit_theory.m` | Entry script |
| `plot_saved_pop_theory_results.m` | Replay angle/RT diagnostics from `.mat` |
| `sim_pop_vs_cdm_theta.m` | Overlay POP drift, CDM\|drift=0, mixed response |
| `validate_popcdm2.m` | Smoke check of `popcdm2` |
| `TheoryFits/` | Current H0a / H0b / H1 full results (17 Aug 2026) |

**Earlier 9-parameter track (kept, not the theory stack):**  
`pop_fit_9a3v.m` / `pop_fit_9k3v.m`, `run_popcdm_grouped_vnorm_fit.m`, matching `.mat` results and `Figures/`. Those used **U/NR/R vnorms**, not set size.

**Supervisor notes:** `PopCodeNotes.txt`, `fig1.jpg`, `fig2.jpg`.

---

## Current model spec

Shared RT skeleton (H0a, H0b, H1):

- 3 vnorms by **set size**: S2 / S4 / S6 (R and NR at the same S share v)
- singleton η₁, a, ter, st
- η₂ fixed at `e^(−6)`
- v, a ∈ [2, 12]; α / A2 ub = 300; κ ub = 30; β ∈ [−1, 0]

| Model | POP layer | Free |
|---|---|---|
| **H0a** (default) | 1 κ, 9 α | 17 |
| H0b | 1 α, 9 κ | 17 |
| **H1** | 1 κ, A2 + β_U, β_NR, β_R | 12 |

H1 amplitude (manuscript path):

- Free **A2** = POP α at Nc = 2 (shared across routes)
- Theoretical single-item intercept: `A1_route = A2 × 2^(−β_route)`
- Baseline (S = C): `α = A1_U × Nc^β_U`
- NR (S ≠ C): `α = A1_NR × Nc^β_NR`
- R: `α = A1_R × Nc^β_R × m^(−β_R)`, where `m = S − C + 1`
- Compact: `α = A2 × (Nc/2)^β`, additionally multiplied by `m^(−β)` for R

At Nc = 2, baseline and NR recover α = A2, so **S2C2 = S4C2NR = S6C2NR**.

---

## Working steps (what we actually did)

1. **Nested theory tests** on 2024 redundancy data, then simplified to H0a / H0b vs H1. Raised α ub (to 300), 16 starts, MaxIter 2000, free st, `fmincon` (not MultiStart OutputFcn). η₂ floor in `popcdm2` matched theory (`e^(−6)`).

2. **H0a vs H0b:** condition-varying α is the right default for most people; κ-varying (H0b) helps AQ/YL. Three grouped vnorms beat a single vnorm. Did not raise κ ub.

3. **H1 power-law** nested in H0a. Fair nesting held (H1 NLL worse than H0a). BIC: H1 only for HC; H0a for ES/PG; H0b for AQ/YL. β pinned at −1.

4. **Route-specific β** is implemented: S = C uses β_U; S ≠ C NR uses β_NR; R uses β_R and m. Identical H1 α on the three Nc = 2 baseline/NR cells is algebra, not a bug.

5. **Why POP α ≫ manuscript Gumbel-max α:** manuscript fitted errors directly (`P(θ) = POP`). POPCDM mixes POP through CDM. Circular diffusion already supplies an error tail, so the encoder inflates α (and often κ) toward a delta. Confirmed with `sim_pop_vs_cdm_theta`. Overlap of POP and response requires **large** a × v (tight CDM) *and* a POP that is still wider than that kernel. Fitted people sit in tight-POP + tight-CDM, so CDM is a real share of observed error.

6. **RT is not a redundancy effect.** Matched R vs NR mean RT is ~0–5% of person mean and flips sign. Load slowing (S2→S6, ~+90 to +196 ms) is real; accuracy (not time) carries conditions. Kind-grouped (U/NR/R) vnorms were almost equal.

7. **Recut vnorms to set size.** Same 17 parameters, better H0a NLL for everyone vs U/NR/R (YL −136, ES −67). All people: v_S2 > v_S4 > v_S6. R and NR at the same S now share the CDM kernel.

8. **a, v boxes.** [5,10] pinned ES a at 5 (worse NLL). Working box is **[2, 12]**; all H0a a and v estimates are interior. Tighter CDM (~7–11° circ SD) did **not** bring α down to manuscript scale.

9. **H1 after set-size + [2,12]:** same diagnosis as before. β still at −1 for 4/5.

---

## Latest numbers (17 Aug 2026)

H0a 09:39 · H1 09:50 · v, a ∈ [2, 12] · set-size vnorms.

### H0a vnorms (all interior)

| ID | v_S2 | v_S4 | v_S6 | a |
|---|---|---|---|---|
| AQ | 5.31 | 5.19 | 5.07 | 9.29 |
| ES | 9.76 | 8.32 | 7.30 | 3.57 |
| HC | 9.21 | 8.63 | 8.01 | 5.82 |
| PG | 7.72 | 7.59 | 7.25 | 9.17 |
| YL | 6.86 | 6.53 | 6.10 | 8.41 |

### H1 vs H0a

| ID | H0a NLL | H1 NLL | ΔNLL | ΔBIC | β_U / β_NR / β_R | A2 |
|---|---|---|---|---|---|---|
| AQ | 3123.0 | 3180.6 | +57.5 | +73 | −1* / −1* / −1* | 38 |
| ES | 1178.8 | 1298.0 | +119.2 | +196 | −1* / **−0.29** / **−0.79** | 35 |
| HC | 1333.2 | 1343.5 | +10.3 | **−22** | −1* / −1* / −1* | 65 |
| PG | 2968.6 | 3082.8 | +114.2 | +186 | −1* / −1* / −1* | 20 |
| YL | 2623.0 | 2726.0 | +103.1 | +164 | −1* / −1* / −1* | 24 |

Only HC prefers H1 on BIC. Only ES β_NR and β_R sit in the intended band [−0.85, −0.25]. H0a implied baseline log-log slopes (S2C2→S6C6) are about **−2.2 to −3.8**; even β = −1 is too shallow (α ratios 11–62× vs 3×).

---

## Insights that should constrain the next spec

**A2 is estimated; A1 is theoretical; scaling uses A1.** Because β ≤ 0, A1 ≥ A2. Cn ↑ lowers α from A1. On R, α first drops with Cn then rises with m.

**β at −1 is not a plotting failure.** The fitter’s box is [−1, 0]. The MLE sits on the floor because (i) H0a Nc drop is steeper than `Nc^(−1)`, (ii) shared A2 cannot match unequal Nc = 2 cells without exploding R via `m^(−β)`. Tightening β to [−0.85, −0.25] would pin at −0.85, not put it in the interior.

**POPCDM α is not on the manuscript scale.** Same `popcode` object, different job: pre-decision drift-angle mix vs error-only LCM. CDM (σ = 1, barrier a, η₁) smears even a delta encoding. High α is “make POP a spike and live with remaining CDM smear.”

**Do not reparameterize `popcdm2`.** Identification can be changed by how we group v and α. Shared `κc = a × v` was discussed and dropped; the supervisor model stays as written.

**H0a α gaps at Nc=2 are not all in the error histograms.**  
AQ / ES / PG: S2C2 vs S4C2NR vs S6C2NR mean |error| and circ SD are almost the same (~1–2°). H0a still splits α a lot (ES 271 / 102 / 199). Likely weak identification once α is already large, shared κ, set-size v trading with α, and S2C2 being a singleton cell.  
HC / YL: S2C2 really is better (+5–7° mean |error| at S4/S6, Nc = 2). There a set-size hit at fixed Cn is real.

So H1’s “all Nc=2 share A2” is closer to **AQ/ES/PG data** than to H0a’s free αs. The power-law’s main failure is the steep **baseline** S2C2 → S4C4 → S6C6 drop, not S2 vs S4C2NR for everyone.

## Theoretical noise partition

The standalone POP model is a measurement model for final response angles. Its von Mises activation plus Gumbel-max/Luce-choice operation does not isolate memory noise from response-selection noise. When fitted directly to continuous-report errors, its noise term can absorb variability arising during encoding, maintenance, retrieval, decision, and response selection.

In the current POPCDM composition, `popcode` first returns a probability distribution over selected polar directions. `popcdm2` then treats those directions as a distribution of CDM drift directions, and the CDM performs a second stochastic response-selection process through diffusion and boundary crossing:

`memory activation → Gumbel-max/Luce direction selection → CDM accumulation → response`

This creates a theoretically plausible duplication of response-level noise. The two contributions are nonlinear and cannot be described as simply additive variance, but both stages can generate response dispersion, shoulders, and tails. Conditional α may consequently act as an implicit noise-allocation parameter: very large α suppresses the POP contribution so that CDM noise dominates, whereas smaller α restores POP shoulder and tail mass where the shared κ and CDM kernel cannot match a condition’s shape.

The publication-level question is therefore not merely which extra amplitude function improves fit. It is which stochastic operations belong to the latent memory representation and which belong to decision formation. A cleaner process account would have the form:

`latent memory evidence → CDM drift field → diffusion and boundary crossing → response`

Retaining Gumbel variability before the CDM is defensible only to the extent that it represents variability in latent memory evidence. Retaining a complete response-selection operation before another response-selection model requires an explicit theoretical justification or a principled partition of their roles.

The first diagnostic is `diagnose_popcdm_noise_partition.m`. It compares observed angle distributions with (a) a standalone POP-only refit, (b) the POP component extracted from the joint H0a fit, (c) the fixed-direction CDM kernel, and (d) the combined H0a POPCDM prediction. It reports circular SD, mean absolute error, and probability in central (≤15°), shoulder (15–45°), and tail (>45°) regions. The standalone refit is necessary because POP parameters estimated inside POPCDM have already adapted to CDM noise.

### Noise-partition diagnostic results (18 Aug 2026)

The standalone comparison used the same POP structure as H0a: one shared κ and nine condition-specific α parameters. It was refitted to response angles only. These angle-only NLL values must not be compared numerically with POPCDM joint angle–RT NLL values.

Mean probabilities across 5 people × 9 conditions:

| Stage | Circ SD | Mean |error| | Central ≤15° | Shoulder 15–45° | Tail >45° |
|---|---:|---:|---:|---:|---:|
| Observed | 28.22° | 19.97° | .674 | .230 | .096 |
| POP-only refit | 31.50° | 22.21° | .655 | .251 | .094 |
| POP component in H0a | 29.62° | 20.18° | .722 | .190 | .088 |
| CDM, fixed drift at 0 | 8.68° | 6.43° | .961 | .039 | <.001 |
| Combined H0a POPCDM | 31.18° | 22.05° | .652 | .256 | .092 |

The fixed-direction CDM is narrow and contributes virtually no tail beyond 45°, but it moves substantial probability from the central region into the 15–45° shoulder. The POP component estimated inside H0a is correspondingly too concentrated in the center and too light in the shoulder. Combining it with CDM reconstructs almost the same aggregate partition as the standalone POP-only fit.

This reallocation is also visible in κ. The standalone versus H0a shared-κ estimates were AQ 12.04 vs 15.87, ES 15.30 vs 29.95, HC 9.86 vs 11.97, PG 16.32 vs 21.08, and YL 10.74 vs 13.26. Joint fitting raised κ for every person, narrowing the POP component before CDM broadening was applied.

The diagnostic therefore does **not** show simple uncompensated overdispersion: the joint model adapts its POP parameters and fits the final angle distribution reasonably well. It shows **noise reallocation and weak stage identification**. Standalone POP and POPCDM can produce similar final peak/shoulder/tail partitions through different internal mechanisms. In H0a, CDM supplies much of the shoulder while the Gumbel/Luce POP component supplies nearly all of the far tail.

This helps explain the conditional α pattern. Because shared κ fixes the basic POP shape and CDM contributes almost no far-tail mass, α remains responsible for suppressing or restoring the POP noise floor. Conditions with little tail mass drive α toward very large, weakly identified values; conditions with appreciable tail mass require a sharp α reduction. The large α range is therefore not a transparent scale of memory strength. It partly reflects the burden placed on α to allocate tail noise after shoulder noise has been reassigned to CDM.

Files produced by the diagnostic are in `Figures/NoisePartition/`: a complete stage-by-condition CSV, standalone POP parameter estimates, an aggregate table, a saved MATLAB output structure, and one summary figure per participant.

### RT conditional on response error (18 Aug 2026)

`diagnose_popcdm_rt_by_error.m` tests the process signature that is lost in angle marginals. It compares observed and H0a-predicted RT distributions within central, shoulder, and tail response regions. It also reconstructs every POP-direction component of the fitted mixture and calculates the posterior latent POP region for each predicted response region. The reconstructed joint densities matched `popcdm2` to a maximum absolute difference of `3.6e−15`.

Mean RT across participant × condition cells:

| Response region | Observed | H0a POPCDM |
|---|---:|---:|
| Central ≤15° | 1.417 s | 1.435 s |
| Shoulder 15–45° | 1.450 s | 1.447 s |
| Tail >45° | 1.541 s | 1.448 s |

Observed tail responses were 124 ms slower than central responses on average. H0a predicted only a 13 ms difference. The observed versus predicted tail-minus-central differences were AQ +130 vs +3 ms, ES +189 vs +42 ms, HC +70 vs +13 ms, PG +149 vs +5 ms, and YL +74 vs +2 ms. The slower-tail pattern is therefore present in every participant but is largely absent from H0a.

H0a’s latent-direction attribution was:

| Response region | Latent central | Latent shoulder | Latent tail |
|---|---:|---:|---:|
| Central response | 93.85% | 6.14% | <0.01% |
| Shoulder response | 42.87% | 56.12% | 1.01% |
| Tail response | 0.34% | 6.67% | **92.99%** |

Thus the fitted model already assigns far directional errors almost entirely to front-layer POP selection, not to diffusion away from a near-target drift. The architectural problem is that POP drift direction and CDM drift norm are independent. A badly misdirected POP selection can therefore be executed about as quickly as a correct selection, whereas behavioural tail responses are consistently slower.

This result suggests a theoretically constrained extension rather than another free noise term: memory-evidence strength should jointly determine directional reliability and decision strength. Weak evidence should both increase the probability of selecting a distant direction and provide a weaker CDM drift, producing slower tail responses. Such a mechanism would give the stages distinct roles: the front layer performs memory retrieval/selection, while the CDM governs the time and residual variability involved in committing to that selected evidence. Any implementation should derive this coupling from a latent evidence variable or retrieval-confidence quantity, not impose an arbitrary angle-dependent drift function.

Outputs are in `Figures/RTByError/`: condition-level RT summaries, the complete latent-to-response attribution matrix, aggregate tables, reconstruction checks, a saved MATLAB output structure, and one figure per participant.

**Optional next amplitude laws (still inside `popcdm2`):**

1. Separate intercepts A2_U, A2_NR, A2_R — kills the shared-A2 compromise; ES already shows interior β_NR once that tension is weaker.
2. Set-size factor `(S/2)^γ`, with γ ∈ [−1, 0] — lets S4C2NR fall below S2C2 at the same Nc. Motivated by YL/HC, not by AQ/ES/PG.
3. Before adding γ, check NLL cost of **one shared α on all Nc=2 cells** under H0a. If that is cheap for AQ/ES/PG, H1’s shared A2 is the right constraint and effort should go to the baseline (S=C) slope.

---

## Tidying (18 Aug 2026)

Removed:

- `besselzero.asv` (MATLAB autosave)
- Obsolete `TheoryFits` from renamed/abandoned hypotheses: `H0`, `H0` smoke, `H1a`, `H2`, `H3`, `H3a`, `H3b`, comparison smoke

Kept current `H0a` / `H0b` / `H1` / `comparison_full`, the 9a3v–9k3v archive, supervisor notes, and the theory/sim/plot scripts.

---

## Cross-model status (18 Aug 2026)

The wrapped-Cauchy CDM currently gives lower joint NLL than the best POP baseline for all five participants and uses 16 rather than 17 parameters. This is provisional rather than publication-final: the saved POP fits used an angular interpolation grid open at `+pi`, whereas the Cauchy fit periodically closed the grid. Reevaluating the fitted Cauchy solutions under the POP open-grid convention retained a Cauchy NLL advantage of 44--117 points per participant, but both models must be periodically closed and refitted before formal AIC/BIC comparison.

The theoretical comparison is also deliberately qualified. CauchyCDM gives the cleaner current process architecture because its front layer describes latent drift-direction variability without a preceding Gumbel-max/Luce response-selection operation. POPCDM retains the richer memory and redundancy theory, but its fitted amplitude partly allocates variability between POP and CDM and is not a transparent memory-strength scale. Both routes still need a mechanism coupling directional reliability to drift strength. Full reasoning, model edits, results, cautions, and prioritized next work are maintained in `../POPCDM_CauchyCDM_master_work_note.md`.
