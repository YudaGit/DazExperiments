# Manuscript foundation and sources

Preserved theory/Introduction plan from the previous master. This is a drafting resource, not the current results summary. Use the [overview](../README.md) and [evidence map](../manuscript/evidence_map.md) for current status. The planned Results sequence must now include H3. Private draft version and resource-law clarifications remain open; the old Downloads link below is historical.

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
  Surette-Ferguson, cau26.pdf. [Local manuscript](../../../Encoding2526/cau26.pdf).
  Separate theory-publication project; cited here as background and a source
  of candidate predictions, not as a Re2024 result or manuscript deliverable.
  Record the final title/date/status with the team before formal citation.
  Relevant pages: 12-14 parameterization; 14-16 consolidation; 17-19
  allocation; 26-27 derivation. R5 records unresolved internal equations.
  Do not treat unpublished draft results as results from Re2024.

