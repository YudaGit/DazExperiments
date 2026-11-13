# CDM front-end comparison: master work note and manuscript plan

Updated: 23 September 2026. Scope: Redundancy 2024; AQ, ES, HC, PG, YL.
Current status: Cauchy H0/H1/H2 fitted; matched final POP/JP comparisons and
memory-allocation constraints remain open.

### Boundary between the two projects

- **This project:** empirical and theoretical comparison of POP, JP, and
  Cauchy CDMs on Re2024; development and testing of memory/decision parameter
  structure, context-sensitive RT, individual differences, and allocation
  constraints. Its manuscript reports this project's analyses and evidence.
- **Separate team theory publication:** cau26.pdf develops the proposed
  consolidation mechanism and its mathematical foundations using other
  datasets. It is an external theoretical source for this project. We may
  apply and test its predictions with attribution; we do not claim its
  derivations, experiments, or findings as contributions of Re2024.
- Questions about that draft are source-clarification notes for discussion
  with its authors, not defects in this project's fits or assignments to
  revise the other manuscript. Completion of that publication is not a
  prerequisite for our independent diagnostics or model comparisons.
- Before adopting a scaling constraint here, specify and justify the exact
  law being tested. Clarify an external derivation only when relying on it
  for that law. Our implementation audits concern the code used for Re2024;
  they do not establish anything about the other publication's analyses.

## 1. How to use these notes

- This master is the current conceptual record, manuscript outline, and ordered
  work plan. Sections 2-3 support drafting; Sections 4-6 govern remaining work.
- [Current stage note](POPvJPvCauchy/POPCDM_stage_work_note.md): runnable assets,
  canonical results, and brief operational updates.
- [Previous master, preserved in full](POPvJPvCauchy/Notes/CDM_master_history_through_20260923.md):
  historical arguments, numerical results, earlier priorities, and the first
  milestone synthesis. Its claims and route names are historical.
- [Stage development history](POPvJPvCauchy/Notes/POPCDM_stage_history_20260914-15.md):
  implementation history, rejected redundancy-Ter test, warm starts, and renaming.
- Older route notes in POPCDM_Matlab, JPCDM_Matlab, and CauchyJP document their
  respective implementations. Do not equate their H0/H1 labels with current ones.
- Consult archived fit files and Examples only for a specific historical or
  implementation question. Canonical fits remain at their existing paths.
- Evidence labels: **recorded result** = saved fit/diagnostic; **code finding** =
  source inspection; **interpretation** = psychological account; **open test** =
  work needed. A source inspection is not validation of the compiled MEX.
- This reorganization changes documentation only. It does not authorize the
  previously deferred production C-core changes or initiate new fits.

## 2. Introduction outline

### A. Background: continuous recall and the source of error

- Continuous-report tasks reveal both sharply concentrated responses and
  substantial far-angle errors; increasing load changes the distribution.
- Competing accounts assign these errors to different mechanisms: limited
  storage, variable precision, nontarget reports, or noisy population codes.
- Literature: Zhang and Luck (2008) [L1]; Bays, Catalao, and Husain (2009)
  [L2]; van den Berg et al. (2012) [L3]; Bays (2014) [L4].
- These are established observations and theoretical alternatives. The new
  contribution is not discovering heavy tails at high load or labelling them
  as guessing/swaps, and the present C2/C4/C6 design cannot establish a sharp
  four-colour capacity threshold.

### B. Gap: error distributions alone do not locate variability

- A behavioural distribution combines variability in memory evidence,
  retrieval/decision formation, and response production.
- Distinct internal allocations can generate similar final angle distributions.
  Activation assumptions and response-selection rules must therefore be explicit.
- Oberauer (2023) [L5] supplies a framework for distinguishing measurement-model
  activation functions and selection rules. Do not treat all population models
  as equivalent to this project's POP implementation.
- Research gap: compare latent directional front ends under a common decision
  process and ask which provides an interpretable account of joint error and RT.

### C. Why a joint CDM account

- CDM links the report angle and decision time through an accumulation process;
  across-trial drift direction, drift magnitude, and within-trial diffusion make
  distinct formal contributions.
- Smith (2016) [L6] provides the circular diffusion foundation. Fennell and
  Ratcliff (2023) [L7] supplies relevant continuous-report VWM RT modelling context.
- RT quantiles conditional on error provide constraints beyond mean RT and
  marginal angle fit, even when condition-level mean RT differences are small.
- Distinguish operational components from inferred stages: eta is across-trial
  radial drift variability, not within-trial diffusion noise. Its psychological
  origin could include fluctuations in memory/attention as well as decision input.
- Avoid claiming the first joint RT/accuracy account or that CDM uniquely
  identifies consolidation, retrieval, or motor execution.

### D. Candidate front ends and theoretical rationale

- POP: von Mises tuning plus the response-selection rule actually implemented.
  Test the concern that a behavioural measurement layer reallocates variability
  already accommodated by CDM; assess amplitude/noise-floor trade-offs (R6).
- JP: Jones and Pewsey (2005) [L8] offers flexible directional shape; free psi
  tests the cost/benefit of departing from the wrapped-Cauchy special case.
  JP-CDM retains a mechanistic decision process; its free shape is currently
  less constrained by a specific memory-generation theory.
- Cauchy: the separate team theory publication [D1] proposes a derivation of
  wrapped-Cauchy latent direction from stochastic encoding/consolidation.
  Cite it as an external rationale; our contribution is comparative testing
  and application to redundancy and joint error/RT behaviour.
- The consolidation account is a theoretical hypothesis. A Cauchy marginal
  alone does not establish its generating process.
- Compare all candidates fairly; do not write the Introduction as if POP/JP
  have already been excluded or Cauchy superiority is guaranteed.

### E. Memory allocation and the redundancy manipulation

- Sample-size and attention-weighted accounts constrain how available evidence
  is allocated: Sewell et al. (2014) [L9], Smith et al. (2016) [L10], and
  Smith et al. (2018) [L11].
- Distinguish total items S, unique colours C, and repeated-colour multiplicity
  m = S - C + 1. Baseline means S = C, even where stored labels end in NR.
- The current design allows matched R versus NR comparisons at identical S/C;
  S contrasts at fixed C also change multiplicity/configuration. It is not a
  complete factorial separation of every load and context factor.
- Test whether memory dispersion follows allocation theory while additional
  timing/evidence parameters explain the response demands of context.
- Derive the mapping from effective samples to dispersion first (R5). The
  draft's set-size law does not automatically become a unique-colour law.

### F. Aims and planned narrative

- Aim 1: compare POP, JP, and Cauchy front ends under matched numerical,
  likelihood, and decision-stage assumptions.
- Aim 2: use Cauchy H0, single-component H1 audits, and restricted H2 models to
  ask how condition effects divide between memory dispersion, evidence strength,
  and timing. H_satDecision establishes descriptive headroom.
- Aim 3: test sample-size/power-law and attention-weighted constraints on the
  memory front end while estimating decision parameters jointly.
- Aim 4: assess individual strategies and unresolved slow errors using
  conditional RT and independent task information.
- Planned Results sequence: matched front-end benchmark -> H0/H1 component
  diagnosis -> H2 context-timing account -> memory scaling -> validation.
  Label the H1-to-H2 development as exploratory; validation supplies the next
  evidential step. Generalize across datasets before claiming a broadly best model.

## 3. Current evidence and claim limits

### Canonical models

All current Cauchy routes have nine cellwise kappa_mu values and shared a/st.

| Route | Free parameters | vnorm | eta | Ter |
|---|---:|---|---|---|
| H0 | 14 | Shared | Shared | Shared |
| H1_eta | 22 | Shared | Cellwise | Shared |
| H1_vnorm | 22 | Cellwise | Shared | Shared |
| H1_ter | 22 | Shared | Shared | Cellwise |
| H_satDecision | 38 | Cellwise | Cellwise | Cellwise |
| H2_factorial | 20 | S2/S4/S6 | C2/C4/C6 | Base/R/NR |
| H2_tsensitive | 20 | S2/S4/S6 | Shared | C2/C4/C6 plus R/NR offsets |

H2 timing law: Ter(c) = Ter_C(c) + delta_R I_R(c) + delta_NR I_NR(c).
Offsets are signed; fitted condition Ter values are constrained to [0,1] s.
C2/C4/C6 baselines are categorical values, not a fitted smooth complexity law.

### H2 milestone

Values below were checked against the current route summary CSVs on 23 September.
Delta is H2_tsensitive minus the best H1; negative favours H2.

| ID | Best H1 | H1 NLL | H2 NLL | Delta NLL | H1 BIC | H2 BIC | Delta BIC |
|---|---|---:|---:|---:|---:|---:|---:|
| AQ | H1_ter | 2905.42 | 2900.81 | -4.61 | 5995.84 | 5969.80 | -26.04 |
| ES | H1_vnorm | 889.88 | 925.80 | +35.92 | 1964.76 | 2019.78 | +55.02 |
| HC | H1_ter | 1064.84 | 1071.07 | +6.24 | 2314.71 | 2310.36 | -4.35 |
| PG | H1_ter | 2747.50 | 2751.87 | +4.38 | 5680.02 | 5671.95 | -8.07 |
| YL | H1_vnorm | 2233.88 | 2232.55 | -1.33 | 4652.80 | 4633.33 | -19.47 |

- **Recorded result:** H2_tsensitive leads BIC for four participants and
  outperforms H2_factorial for all five. Only AQ/YL beat their best H1 in
  both NLL and BIC. HC's BIC advantage is relatively small.
- H2 and the single-component H1s are not generally nested in one another:
  H2 gains set-size drift and structured timing simultaneously.
- C2/C4/C6 baseline Ter increases in all five fitted H2_tsensitive solutions.
  This is an estimated pattern, not an imposed monotonic constraint.
- Cellwise eta fails to earn its parameter cost for most participants; ES is an
  exception relative to H0, but still favours H1_vnorm. Eta can affect angle
  shape and the whole joint distribution, not only tail RT.
- H_satDecision improves NLL/AIC over the best H1 for every participant but
  loses BIC throughout. Broad parameter movement is evidence of trade-offs,
  not a direct map of selective psychological influence.
- The earlier uniform nonnegative redundancy-Ter increment was effectively zero.
  That test differed from the current colour-dependent baselines and signed
  R/NR offsets; its rejection does not contradict H2.
- ES has long fitted Ter and marked vnorm contrasts. Its reported R/NR reversal
  strategy is an independent lead. Small between-condition Ter variation does
  not itself demonstrate stable trial-level responding; inspect st, RT spread,
  practice/block effects, and task records.
- **Interpretation:** context-sensitive timing is a useful parsimonious account.
  Ter does not by itself distinguish retrieval, spatial mapping, motor time,
  or the duration of pre-probe consolidation.
- **Open:** current conditional-tail and marginal summaries need the diagnostic
  audit below. Historical numerical summaries must not be promoted to final
  manuscript evidence before their density provenance is checked.

## 4. Seven retained issues: argument, action, decision

### R1. POP can fit coarse angle regions better

- **Argument:** historical angle-region MAE was approximately .034 for POP
  versus .050 for JP-Cauchy, despite the latter's stronger joint likelihood.
  These are historical models/conventions, not a current team-Cauchy comparison.
  Region proportions and joint likelihood measure different features.
- **Action (diagnostic coding):** from one final RT-conditioned joint density,
  compute central |error| <= 15 degrees, shoulder 15 < |error| <= 45, and tail
  |error| > 45 probabilities per participant/condition. Integrate fractional
  angular-bin overlaps at boundaries. Export signed residuals and MAE for each
  region, participant summaries, and matched front-end comparisons.
- Decompose joint NLL into angle NLL plus conditional RT-given-angle NLL,
  using a consistent interpolated density and integration convention.
- **Decision:** retain any reproducible POP angle advantage in Results even if
  Cauchy wins information criteria. New fits are needed only for the harmonized
  comparison, not for computing these diagnostics at existing parameters.

### R2. Slow-tail RT remains a distinct target

- **Argument:** an additive Ter shift translates all error-conditional RT
  distributions before RT selection. It cannot alone generate extra tail
  slowing within a condition. Truncation can alter the observed shift.
  Better global fit therefore need not repair slow errors.
- Historical POP showed about 124 ms observed versus 13 ms predicted
  tail-minus-central mean slowing. This is a historical diagnostic, not an H2 result.
- **Action (diagnostics and simulation first):** recompute regional RT quantiles
  and tail-minus-central differences from the selected joint density; retain
  signed-error equal-mass QVWM figures. Compare model bin-integrated quantiles
  at the empirical bin boundaries, alongside the conventional pointwise curves.
- Hold parameters fixed and vary eta, vnorm, and Ter separately, then examine
  joint changes in angle probabilities and RT quantiles. Use simulations and
  recovery before fitting further mechanisms.
- **Conditional extension:** if a substantial residual survives validation,
  test a shared latent information state linking directional dispersion and
  drift strength. Integrate the same latent state through both links, then
  apply RT selection to the full mixture. First establish identifiability.
- **Decision:** a supported residual can be reported as a limitation; it does
  not force an indefinitely expanding model before manuscript completion.

### R3. Sparse tails and individual-level uncertainty

- **Argument:** low tail frequency reduces precision of tail RT estimates.
  Zero observed tails provides no empirical conditional tail RT. Equal-mass
  bins stabilize counts but have different angular widths across cells.
- **Action (diagnostic coding):** export trial/bin counts, tail proportions,
  regional quantiles, and uncertainty for all 45 cells. Bootstrap trials within
  cells; use blocks/sessions when dependence is relevant and recorded.
  Recompute empirical equal-mass edges within bootstrap samples.
- Predefine and report a reliability flag for sparse tail cells; do not select
  only cells showing large slow-error effects. Include point estimates with
  their count/uncertainty, and leave empty-cell RT undefined.
- **Decision:** primary interpretation stays within participant and condition.
  Pooled plots are supplemental. There is no refit requirement for this step.

### R4. Comparable likelihoods, fits, and predictions

- **Argument:** historical open versus periodic angular interpolation gave some
  near-pi responses different likelihood treatment. Shared file names, parameter
  counts, or optimizer exit flags do not establish numerical comparability.
- **Action (validation coding):** create one manifest recording retained trial
  IDs/order, radians/seconds, 300-3000 ms inclusion, condition order, source/MEX
  hashes, resolved MEX paths, grids, floors, RT convolution, normalization,
  parameter names/bounds, penalty, seeds, starts, and optimizer settings.
- Re-evaluate saved parameter vectors without optimization first. Compare
  raw NLL, penalty, joint density, and all derived predictions separately.
  Current runner stores Pvar, Pfit, Sel, paramNames, bestNLL/bestObj, ll2,
  qaic/qbic; participant keys are e.g. AQ_cauchy. Pfit is the full reconstructed
  vector; Pvar contains only free entries. Earlier extraction examples that
  guessed AQ.Pest or AQ.parameterNames should not be reused.
- Current wrapper uses abs(llRaw); raw continuous-density NLL can be negative.
  Verify whether this ever activates, then use signed NLL in a validated future
  likelihood. AIC = 2*NLL + 2*k; BIC = 2*NLL + k*log(n), excluding penalties.
  Saved CSV NLL currently labels the optimization objective; verify equality
  with ll2/2 and record penalty explicitly.
- Audit soft bounds as well as hard bounds, especially after parameter
  transformations: penalties can defeat apparent nesting/equivalence.
- **Decision:** display-only fixes require prediction regeneration; changes to
  the fitted density/support/objective require reevaluation and affected refits.
  No blanket refit until impact is measured.

### R5. Parameterization and scaling theory

- **Established algebra:** team-Cauchy dispersion gamma = kappa_mu > 0;
  rho = exp(-gamma); circular SD = sqrt(2*gamma). JP at psi = -1 has
  rho = tanh(K/2), where K is its concentration. Different numeric kappas can
  therefore describe exactly the same distribution.
- If gamma(C) = gamma_2*(C/2)^beta, beta > 0, then
  rho(C) = rho_2^((C/2)^beta), and rho_1 = rho_2^(2^(-beta)) < 1.
  A direct power law rho_2*(C/2)^(-beta) is a different hypothesis.
  Its impossible extrapolated C1 does not prove invalid free-kappa estimates.
- An exponent beta on gamma implies beta/2 on circular SD. Specify which
  quantity has the theoretical inverse-square-root precision relationship.
- **External source-clarification question [D1]:** p.19 gives gamma_a = gamma/c_a and
  gamma_u = gamma/c_u, whereas Appendix A, p.27, derives
  gamma_m = sqrt(m)*gamma_1 by averaging Brownian processes before subordination.
  Equal allocation c = 1/m gives gamma_m = m*gamma_1 under p.19.
  These differ by a square root and imply different circular-SD exponents.
  The p.27 sentence identifying kappa_mu with circular SD also appears
  inconsistent with Eqs.9-11. Clarify the intended definitions with the authors
  if adopting this derivation. These observations concern an incomplete,
  separate manuscript; resolving or editing it is outside this project's
  work plan and does not establish an error in the free-cell Re2024 fits.
- Infinite divisibility alone does not imply square-root precision scaling.
  Averaging independent completed Cauchy variables differs from averaging
  Brownian evidence processes before applying the random consolidation time.
- **Action (theory before coding):** agree the dispersion/SD/resource mapping;
  then specify allocation by S, C, and multiplicity. Preserve normalized
  resources if R gains evidence at NR's expense. Derive the C law from the
  redundancy task, not simply from substituting C for the draft's set size.
- **Action (then simulation/fitting):** compare fixed sample-size exponent,
  free positive beta, and an attention-weighted allocation model against free
  cellwise gamma. Fit decision parameters jointly. Estimate the C1 intercept
  from all cells rather than treating the observed C2 estimate as error-free.
- **Decision:** begin constrained fits once this project's chosen law and
  parameter definitions are explicit and justified. Do not make completion
  or revision of the separate draft a general dependency. Use matched
  transformed bounds and Cauchy-to-JP warm starts.

### R6. POP selection rule and amplitude versus Xi

- **Code finding:** old popcdm2.m forms alpha*VM(theta;k)+c0 with
  c0 = 0.5772156649, then divides by the sum across directions. The team
  vpop300rot.c forms VM(theta;k)+c0*xi and normalizes the same way.
  The floor is the named Gumbel mean; adding it is not equivalent to integrating
  random Gumbel perturbations through an argmax.
- **Algebra for matched grids and k:** dividing the old weights by alpha gives
  VM+c0/alpha. Thus xi = 1/alpha gives identical normalized front-end weights.
  Large alpha and small xi can describe the same family. In continuous form,
  normalized alpha*VM+c0 is a VM/uniform mixture with uniform weight
  2*pi*c0/(alpha+2*pi*c0).
- Historical cores use different angular mixing implementations/grids, so this
  front-end identity does not yet establish identity of their complete CDMs.
  Priors, soft penalties, bounds, and constrained scaling also need mapping.
- **Selection distinction:** linear Luce uses w_j/sum(w). Independent additive
  Gumbel noise of scale s on raw activation A_j with max decoding gives
  exp(A_j/s)/sum(exp(A/s)). Linear Luce is representable with Gumbel noise on
  log weights, which changes the assumed activation scale. Oberauer [L5]
  explicitly distinguishes the response rules; our POP label must identify ours.
- **Action (algebra/unit tests):** compare normalized alpha/Xi weights on the
  same grids; compare complete predictions with one common CDM implementation;
  transform all bounds and penalties; map saved Xi estimates to amplitude as a
  reproducibility check. This test requires no optimization.
- **Action (team clarification):** supply the exact implemented equations and
  ask whether the intended comparator is linear Luce over positive tuning plus
  floor, or raw-activation Gumbel-max/softmax. Keep these as named alternatives
  if both are scientifically relevant; do not silently replace one with another.
- **Action (matched fits):** implement the requested amplitude route using the
  agreed rule and common decision structure. Use mapped Xi and historical
  amplitude solutions as starts. Compare scaling constraints and a profile of
  amplitude/floor trade-offs. Do not freely estimate amplitude and floor scale
  together when only their ratio is identified.
- **Decision:** an unconstrained amplitude fit should match its Xi equivalent
  under identical numerics/bounds/objective. Failure points to optimization or
  implementation differences. Large alpha alone is not evidence against POP;
  the evidence must be failure of a specified theory constraint, poorer
  predictive fit, or unresolved stage identification. General criticism of all
  neural population codes would be unsupported.

### R7. C-core and diagnostic numerical validity

#### R7a. Total-mass stride and its propagation

- **Code finding in all three C files:** Gt has 51 stored angle rows per time
  column, is written at (nw+1)*k+i, and totalmass reads nw*k+i.
  Excluding the duplicate endpoint with i<nw does not change the stored
  column stride. The indexing inconsistency is clear; its numerical impact
  on fits is a separate question.
- In the inspected grtrot300, totalmass divides Ptheta; it does not divide Gt.
  For one component, Mt's totalmass factors cancel algebraically through its
  Ptheta denominator. In the outer mixture, altered component Ptheta weights
  can still affect mixed Ptheta and Mt. Do not claim all outputs or the
  fitted likelihood necessarily change equally.
- test_ylcauchy normalizes Gt separately over retained RTs for likelihood, but
  exports C-returned Ptheta/Mt for some summaries. The marginal plotting
  helper reads that Ptheta. Thus angular PDF and likelihood may have different
  normalization/selection provenance.
- **Action:** in isolated diagnostic builds compare old/correct-stride mass,
  Gt, Ptheta, Mt, final conditioned PDFs, and per-cell/raw NLL at saved fitted
  parameters. Include rotated drifts, narrow/broad directions, and large eta.
  Use a separate name/path; preserve the production core and record hashes.
- **Team explanation:** "The wrap row closes interpolation; i<nw excludes
  its duplicate probability. Each stored column still has nw+1 entries.
  The audit will show which returned outputs depend on the mismatched stride."
- **Decision:** if joint likelihood is unchanged and only summaries differ,
  regenerate affected summaries/figures. Refit only routes whose fitted
  objective changes materially, after agreement on the core correction.

#### R7b. Other source findings to test before final figures/fits

- The outer mixtures close Ptheta and Mt, but do not explicitly copy the final
  Gt row from the first after mixing unique rows. The MEX output is zero
  initialized, and the wrapper floors Gt and interpolates all 51 rows.
  Verify the actual compiled output at +/-pi. This potential seam can affect
  likelihood, unlike a purely Ptheta-normalization defect.
- The while expression reads Gth[i] before checking i<sz. Comparing the tiny
  density threshold with the number of time bins does not establish safety.
  Test no-threshold-crossing input and change the check order in a separately
  validated correction when C edits are agreed.
- Saved median-by-angle code compares unnormalized angle-row cumulative mass
  with .5; a conditional median requires dividing by that row's retained mass.
- qvwm_ydl26 normalizes each row, but currently accumulates the full shifted
  time array, whereas empirical RTs are selected to 0.3-3 s. Mask the same
  interval for both. Preserve the conventional signed-error figure and add
  model bin-integrated quantiles for an exact like-for-like diagnostic.
- Ptheta and model RT means must be derived from the same convolved,
  RT-conditioned joint density as likelihood. Test mass=1, marginals,
  conditional moments, periodic endpoints, and density-unit consistency.
- Audit Ter/st with a known input density: shifting time by Ter+st/2 and then
  applying a causal boxcar also adds the boxcar's mean delay. Establish the
  intended Ter convention and account for discrete convolution rounding and
  truncation. Shared st cannot itself explain condition contrasts, but it
  affects interpretation of absolute Ter and predictive summaries.
- **Decision:** report source findings as unvalidated impact until compiled
  comparisons run. Existing fit rankings remain recorded historical outputs,
  with final manuscript diagnostics pending this audit.

#### R7c. Latent-angle quadrature

- The 21 latent directions are deterministic mixture points, separate from
  50 response-angle bins and 300 time samples. Their spacing is about 0.299 rad.
  Narrow fitted front ends can be poorly resolved; forcing weights to sum
  to one does not prove accurate quadrature.
- **Action:** compare target-centred 21, 51, 101, then 201/higher if needed at
  saved estimates and relevant parameter boundaries. Keep odd grids so zero
  remains represented. Check likelihood, peak/shoulder/tail mass, RT quantiles,
  and parameter sensitivity; assess response/time-grid convergence separately.
- Prefer an adaptive or analytic-bin integration reference if uniform-grid
  convergence is slow. Compare equal numerical accuracy across front ends,
  not just equal node counts.
- **Proposed acceptance targets (set before refitting):** successive validated
  resolutions change participant raw NLL by <0.1, regional probabilities by
  <.001 absolute, and well-supported RT quantiles by <1 ms, with no ranking
  change. These are project tolerances, not universal guarantees; refine them
  if inference depends on smaller differences.
- Benchmark runtime at fixed vectors first. If accuracy requires a new grid,
  refit affected routes from old estimates under the verified scheme.
  Bessel-root caching remains optional and deferred.

## 5. Ordered work plan

No new fits are required merely by updating this note. Proposed outputs below
are future deliverables, not files already produced.

| Step | Work and dependency | Deliverable / completion criterion |
|---|---|---|
| M0 | Freeze current fits and source provenance; verify saved vectors and objective components (R4). | Canonical manifest and reproduction table for all participants/routes. |
| M1 | Audit stride propagation, circular endpoints, RT selection/convolution, and quadrature (R7). | Numerical audit, isolated variants, measured impact; team resolves core decisions. |
| M2 | Recompute marginal/regional/equal-mass diagnostics with counts and uncertainty (R1-R3). Depends on M1. | One consistent diagnostic export and refreshed figures; distinguish plot-only corrections from refit triggers. |
| M3 | Validate the H2 timing interpretation after any necessary numerical refits. | Parameter contrasts, interval estimates, factor ablations, and simulation/recovery evidence. |
| M4 | Agree POP rule and amplitude/Xi equivalence; harmonize POP/JP/Cauchy (R4/R6). | Matched baseline and final-decision comparisons with raw NLL/AIC/BIC and diagnostics. |
| M5 | Specify and justify the Re2024 allocation-to-dispersion law; clarify external derivations only as needed, then simulate and fit (R5). | Free-cell versus sample-size, free-beta, and attention-weighted comparison; recovered parameters and predictive checks. |
| M6 | Validate generalization and remaining slow-error/strategy interpretations. | Independent dataset and/or held-out sessions; residual report; justified decision on further coupling. |
| M7 | Assemble manuscript evidence and reproducibility package. | Final tables/figures linked to exact data, code, results, and supported claims. |

### M3: specific RT models and inference

- Treat H2_tsensitive as the leading candidate pending audit; retain ES's
  H1_vnorm advantage as evidence to explain.
- Suggested nested ablations of H2: shared Ter (16 parameters); C-specific
  Ter with zero cue offsets (18); Base/R/NR Ter with shared eta (18);
  full H2_tsensitive (20). Existing H2_factorial remains an equal-complexity
  competing allocation. These proposed routes are not yet implemented.
- Test a different allocation of vnorm only if residual contrasts and task
  rationale motivate it. All candidates use the same nine memory dispersions.
- H2 was chosen after inspecting the data. Its BIC gain is useful but does not
  remove exploratory selection; use session/block validation or an independent
  dataset for stronger claims.
- Simulate recovery using actual condition counts and parameter ranges.
  Ask whether vnorm and Ter effects can be distinguished, and whether memory
  gamma is stable across plausible decision structures.
- A known individual strategy can motivate a common candidate variant.
  Estimate values separately per person; do not equate different BIC winners
  with proof that each person has a different psychological architecture.

### M4-M6: fit discipline and stopping decisions

- Preserve a common decision architecture for final front-end comparisons;
  selecting a different structure for each front end confounds the comparison.
  Examine a small common set of architectures if rankings are sensitive.
- For every truly nested model, include exact smaller-model seeds, keep the
  seed if optimization worsens, and report reproduced initial NLL. Include
  mapped Cauchy seeds in JP at psi=-1 after testing identity and bounds.
- Use multiple local perturbations plus broad starts and report basin recovery,
  convergence, boundaries, and function counts. More starts do not fix an
  incorrect density, nondifferentiable numerical step, or parameter mapping.
- Bounds define admissible models; widening them merely to remove flags is
  not a goal. Profile plausible boundary solutions and test identifiable ranges.
- If an audit changes likelihood, evaluate every canonical vector first, then
  refit affected routes using a versioned output folder. Preserve old results.
- Keep scaling intercepts and decision parameters free during constrained
  fits. If a theoretical restriction fails, report that outcome rather than
  transform parameters post hoc until plots resemble the expected curve.
- Define a minimum completion path: validated numerics, matched front ends,
  interpretable RT comparison, a clearly specified scaling test, uncertainty/
  recovery evidence, and honest residuals. Direction-strength coupling and
  explicit swap models are conditional extensions, not automatic prerequisites.
- To claim broad applicability across VWM paradigms, include another dataset.
  Otherwise scope conclusions to these five intensively measured participants.
  Prefer independent validation; post hoc splits cannot undo all prior exposure.

## 6. Manuscript evidence map and open decisions

| Claim or question | Required evidence | Planned exhibit |
|---|---|---|
| Why joint RT and angle matter | Same angle fit can conceal conditional RT residuals | Architecture figure and empirical/predicted RT-by-error panels |
| Cauchy is competitive with POP/JP | Matched architecture, likelihood, numerical accuracy, complexity | Participant model-comparison table plus angle-region residuals |
| Context affects timing | H2 versus H1/ablations; recoverable Ter contrasts | Ter by C with cue offsets; vnorm by S; uncertainty |
| Individuals express effects differently | Independent strategy records and conditional predictions | ES case study alongside all participant results |
| Memory follows allocation theory | Agreed equation, constrained joint fits, predictive validation | Dispersion/resource curves and free-versus-constrained table |
| Remaining slow errors are meaningful | Matched density diagnostics with counts and uncertainty | Residual panel, including sparse/empty-tail flags |
| Implementation is reproducible | Saved-vector checks, core/grid tests, source manifest | Supplementary audit and numerical convergence tables |

Project decisions and targeted source clarifications:

- Which POP selection equation is the intended theoretical comparator?
- Which resource-to-kappa/CSD law will this project test, and on what
  theoretical basis? If relying on D1, ask its authors which formulation
  is intended; revising their manuscript remains their separate work.
- Does the team accept the stored-column stride correction after the isolated
  output audit, and what is the intended Ter/st support convention?
- Which independent dataset or unused sessions support validation?

Do not claim yet: unique memory/decision stage identification; proof of swaps;
proof of consolidation from gamma or Ter alone; Cauchy superiority across
datasets; a new four-item threshold; or a complete solution to slow errors.

## 7. Literature and theoretical sources

Primary-source references checked online on 23 September 2026; descriptions
state their role in this project, not a claim that they establish our results.

- **L1:** Zhang, W., & Luck, S. J. (2008). Discrete fixed-resolution
  representations in visual working memory. Nature, 453, 233-235.
  [Paper](https://doi.org/10.1038/nature06860). Slot/mixture-model background.
- **L2:** Bays, P. M., Catalao, R. F. G., & Husain, M. (2009). The precision
  of visual working memory is set by allocation of a shared resource.
  Journal of Vision, 9(10), 7. [Paper](https://pmc.ncbi.nlm.nih.gov/articles/PMC3118422/).
  Resource and nontarget-error alternative.
- **L3:** van den Berg, R., Shin, H., Chou, W.-C., George, R., & Ma, W. J.
  (2012). Variability in encoding precision accounts for visual short-term
  memory limitations. PNAS, 109, 8780-8785.
  [Paper](https://pmc.ncbi.nlm.nih.gov/articles/PMC3365149/).
  Across-item/trial variability as an alternative origin of heavy errors.
- **L4:** Bays, P. M. (2014). Noise in neural populations accounts for errors
  in working memory. Journal of Neuroscience, 34, 3632-3645.
  [Paper](https://pmc.ncbi.nlm.nih.gov/articles/PMC3942580/).
  Population coding theory; not identical to our linear-Luce POP.
- **L5:** Oberauer, K. (2023; online 2021). Measurement models for visual
  working memory: A factorial model comparison. Psychological Review, 130,
  841-852. [Author PDF](https://www.psychologie.uzh.ch/dam/jcr:667a12fd-7a78-4163-911d-05ebd7c2c8a9/Oberauer.PsychReview.2023.pdf).
  Activation versus selection assumptions, including linear Luce and
  signal-detection response rules; useful for defining the comparator correctly.
- **L6:** Smith, P. L. (2016). Diffusion theory of decision making in continuous
  report. Psychological Review, 123, 425-451.
  [Paper record](https://pubmed.ncbi.nlm.nih.gov/26949831/).
  Foundational joint circular-outcome/decision-time theory.
- **L7:** Fennell, A., & Ratcliff, R. (2023). A spatially continuous diffusion
  model of visual working memory. Cognitive Psychology, 145, 101595.
  [Paper](https://pmc.ncbi.nlm.nih.gov/articles/PMC10546276/).
  Existing joint VWM RT/error account; relevant context for novelty.
- **L8:** Jones, M. C., & Pewsey, A. (2005). A family of symmetric distributions
  on the circle. JASA, 100, 1422-1428.
  [Publisher](https://www.tandfonline.com/doi/abs/10.1198/016214505000000286).
  Directional family and wrapped-Cauchy special case; no independent VWM theory.
- **L9:** Sewell, D. K., Lilburn, S. D., & Smith, P. L. (2014). An information
  capacity limitation of visual short-term memory. JEP: Human Perception and
  Performance, 40, 2214-2242. [Paper record](https://pubmed.ncbi.nlm.nih.gov/25222469/).
  Sample-size evidence in VSTM.
- **L10:** Smith, P. L., Lilburn, S. D., Corbett, E. A., Sewell, D. K., &
  Kyllingsbaek, S. (2016). The attention-weighted sample-size model of visual
  short-term memory: Attention capture predicts resource allocation and memory
  load. Cognitive Psychology, 89, 71-105.
  [Publisher](https://www.sciencedirect.com/science/article/pii/S0010028516300809).
  Attention-based resource allocation and diffusion predictions.
- **L11:** Smith, P. L., Corbett, E. A., Lilburn, S. D., & Kyllingsbaek, S.
  (2018). The power law of visual working memory characterizes attention
  engagement. Psychological Review, 125, 435-451.
  [DOI](https://doi.org/10.1037/rev0000098).
  Supports investigating a psychologically motivated exponent; does not
  determine which transformed Cauchy parameter should follow that law.
- **D1 (private incomplete draft):** Smith, Garrett, Saber, Qian, and
  Surette-Ferguson, cau26.pdf. [Local manuscript](/Users/prefabteam_ysl/Downloads/cau26.pdf).
  Separate theory-publication project; cited here as background and a source
  of candidate predictions, not as a Re2024 result or manuscript deliverable.
  Record the final title/date/status with the team before formal citation.
  Relevant pages: 12-14 parameterization; 14-16 consolidation; 17-19
  allocation; 26-27 derivation. R5 records unresolved internal equations.
  Do not treat unpublished draft results as results from Re2024.

## 8. Reproducibility and maintenance

- Active root: POPvJPvCauchy. Active specification:
  re2024_cauchy_hypothesis_spec.m; runner: test_fit_re2024.m; wrapper:
  test_ylcauchy.m. Current conditions and result paths are in the stage note.
- Prepared data: Re2024_POPvJPvCauchy_prepared.mat; participant-by-condition
  cells, response errors in radians, RT in seconds, five named participants.
- Current result key example: allResults.AQ_cauchy. Export parameters by saved
  paramNames, reconstruct full Pfit using Sel/Pfix when required, and expand
  groupings only for presentation.
- Exact H2 source files:
  TestFits/H2_tsensitive/H2_tsensitive_20260922_152336.mat and
  TestFits/H2_factorial/H2_factorial_20260922_143302.mat.
- Current QVWM and best-H1/H2 marginal figures are exploratory until R7
  validates prediction provenance; retain them as the development record.
- Future updates: update the relevant issue/step with dated evidence, output
  path, decision, and next action. Archive lengthy run logs rather than append
  conflicting current-state narratives to this master.
