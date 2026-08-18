# POPCDM theory testing — working notes

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

- 3 vnorms by **set size**: S2 / S4 / S6 (R and NR at the same S share \(v\))
- singleton η₁, \(a\), ter, st
- η₂ fixed at \(e^{-6}\)
- \(v, a \in [2, 12]\); α / A2 ub = 300; κ ub = 30; β ∈ [−1, 0]

| Model | POP layer | Free |
|---|---|---|
| **H0a** (default) | 1 κ, 9 α | 17 |
| H0b | 1 α, 9 κ | 17 |
| **H1** | 1 κ, A2 + β_U, β_NR, β_R | 12 |

H1 amplitude (manuscript path):

- Free **A2** = POP α at \(N_c = 2\) (shared across routes)
- Theoretical single-item intercept: \(A_{1,\mathrm{route}} = A_2 \cdot 2^{-\beta_{\mathrm{route}}}\)
- Baseline (\(S=C\)): \(A_{1U}\, N_c^{\beta_U}\)
- NR (\(S \ne C\)): \(A_{1NR}\, N_c^{\beta_{NR}}\)
- R: \(A_{1R}\, N_c^{\beta_R}\, m^{-\beta_R}\), \(m = S - C + 1\)
- Compact: \(\alpha = A_2 \,(N_c/2)^\beta \,[m^{-\beta}\ \mathrm{if\ R}]\)

At \(N_c=2\), baseline and NR recover \(\alpha = A_2\), so **S2C2 = S4C2NR = S6C2NR**.

---

## Working steps (what we actually did)

1. **Nested theory tests** on 2024 redundancy data, then simplified to H0a / H0b vs H1. Raised α ub (to 300), 16 starts, MaxIter 2000, free st, `fmincon` (not MultiStart OutputFcn). η₂ floor in `popcdm2` matched theory (\(e^{-6}\)).

2. **H0a vs H0b:** condition-varying α is the right default for most people; κ-varying (H0b) helps AQ/YL. Three grouped vnorms beat a single vnorm. Did not raise κ ub.

3. **H1 power-law** nested in H0a. Fair nesting held (H1 NLL worse than H0a). BIC: H1 only for HC; H0a for ES/PG; H0b for AQ/YL. β pinned at −1.

4. **Route-specific β** is implemented: \(S=C\) uses β_U; \(S\ne C\) NR uses β_NR; R uses β_R and \(m\). Identical H1 α on the three \(N_c=2\) NR cells is algebra, not a bug.

5. **Why POP α ≫ manuscript Gumbel-max α:** manuscript fitted errors directly (\(P(\theta)=\mathrm{POP}\)). POPCDM mixes POP through CDM. Circular diffusion already supplies an error tail, so the encoder inflates α (and often κ) toward a delta. Confirmed with `sim_pop_vs_cdm_theta`. Overlap of POP and response requires **large** \(a\cdot v\) (tight CDM) *and* a POP that is still wider than that kernel. Fitted people sit in tight-POP + tight-CDM, so CDM is a real share of observed error.

6. **RT is not a redundancy effect.** Matched R vs NR mean RT is ~0–5% of person mean and flips sign. Load slowing (S2→S6, ~+90 to +196 ms) is real; accuracy (not time) carries conditions. Kind-grouped (U/NR/R) vnorms were almost equal.

7. **Recut vnorms to set size.** Same 17 parameters, better H0a NLL for everyone vs U/NR/R (YL −136, ES −67). All people: \(v_{S2}>v_{S4}>v_{S6}\). R and NR at the same S now share the CDM kernel.

8. **\(a,v\) boxes.** [5,10] pinned ES \(a\) at 5 (worse NLL). Working box is **[2, 12]**; all H0a \(a\) and \(v\) interior. Tighter CDM (~7–11° circ SD) did **not** bring α down to manuscript scale.

9. **H1 after set-size + [2,12]:** same diagnosis as before. β still at −1 for 4/5.

---

## Latest numbers (17 Aug 2026)

H0a 09:39 · H1 09:50 · \(v,a\in[2,12]\) · set-size vnorms.

### H0a vnorms (all interior)

| ID | \(v_{S2}\) | \(v_{S4}\) | \(v_{S6}\) | \(a\) |
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

**A2 is estimated; A1 is theoretical; scaling uses A1.** Because β ≤ 0, \(A_1 \ge A_2\). Cn ↑ lowers α from A1. On R, α first drops with Cn then rises with \(m\).

**β at −1 is not a plotting failure.** The fitter’s box is [−1, 0]. The MLE sits on the floor because (i) H0a Nc drop is steeper than \(N_c^{-1}\), (ii) shared A2 cannot match unequal Nc=2 cells without exploding R via \(m^{-\beta}\). Tightening β to [−0.85, −0.25] would pin at −0.85, not put it in the interior.

**POPCDM α is not on the manuscript scale.** Same `popcode` object, different job: pre-decision drift-angle mix vs error-only LCM. CDM (σ=1, barrier \(a\), η₁) smears even a delta encoding. High α is “make POP a spike and live with remaining CDM smear.”

**Do not reparameterize `popcdm2`.** Identification can be changed by how we group \(v\) and α. Shared \(\kappa_c = av\) was discussed and dropped; the supervisor model stays as written.

**H0a α gaps at Nc=2 are not all in the error histograms.**  
AQ / ES / PG: S2C2 vs S4C2NR vs S6C2NR mean \|error\| and circ SD are almost the same (~1–2°). H0a still splits α a lot (ES 271 / 102 / 199). Likely weak identification once α is already large, shared κ, set-size \(v\) trading with α, and S2C2 being a singleton cell.  
HC / YL: S2C2 really is better (+5–7° mean \|error\| at S4/S6, Nc=2). There a set-size hit at fixed Cn is real.

So H1’s “all Nc=2 share A2” is closer to **AQ/ES/PG data** than to H0a’s free αs. The power-law’s main failure is the steep **baseline** S2C2 → S4C4 → S6C6 drop, not S2 vs S4C2NR for everyone.

**Optional next amplitude laws (still inside `popcdm2`):**

1. Separate intercepts \(A_{2U}, A_{2NR}, A_{2R}\) — kills the shared-A2 compromise; ES already shows interior β_NR once that tension is weaker.
2. Set-size factor \( (S/2)^\gamma \), \(\gamma \in [-1,0]\) — lets S4C2NR fall below S2C2 at the same Nc. Motivated by YL/HC, not by AQ/ES/PG.
3. Before adding γ, check NLL cost of **one shared α on all Nc=2 cells** under H0a. If that is cheap for AQ/ES/PG, H1’s shared A2 is the right constraint and effort should go to the baseline (S=C) slope.

---

## Tidying (18 Aug 2026)

Removed:

- `besselzero.asv` (MATLAB autosave)
- Obsolete `TheoryFits` from renamed/abandoned hypotheses: `H0`, `H0` smoke, `H1a`, `H2`, `H3`, `H3a`, `H3b`, comparison smoke

Kept current `H0a` / `H0b` / `H1` / `comparison_full`, the 9a3v–9k3v archive, supervisor notes, and the theory/sim/plot scripts.
