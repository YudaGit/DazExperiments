# Model dictionary

Current specification reference, 13 November 2026. [Project overview](../README.md) · [canonical results](../POPvJPvCauchy/results_manifest.csv).

## Shared interpretation and units

The latent memory direction defines the centre of the drift distribution entering circular diffusion. The diffusion process jointly generates report angle and decision time, followed by the implemented nondecision-time transformation. Interpretations are conditional on this architecture; a named parameter does not uniquely identify a psychological stage.

| Symbol / code | Meaning and scale | Interpretation boundary |
|---|---|---|
| gamma = `kappa_mu` / Cauchy `kappa` | Positive wrapped-Cauchy dispersion; larger is broader | Memory-direction variability; not drift strength |
| rho | exp(-gamma), circular resultant length | Larger is more concentrated |
| circular SD | sqrt(2 gamma), radians | A power-law exponent on gamma becomes half that exponent on circular SD |
| JP K / `kappa` | JP concentration; at psi=-1, rho=tanh(K/2) | Different numeric scale from team-Cauchy kappa |
| JP psi | Directional shape; psi=-1 is wrapped Cauchy | Extra descriptive flexibility needs theoretical justification |
| `vnorm` | Mean drift-vector norm | Evidence strength within the assumed CDM |
| `eta` | Across-trial radial drift variability | May reflect fluctuating memory/attention/input; not within-trial diffusion |
| tangential eta | Fixed internally at 0.01 in active team cores | Distinguish from older implementations using exp(-6) |
| sigma | Fixed diffusion scale 1 | Sets the scale of other diffusion parameters |
| `a` | Circular boundary radius, shared across conditions | Response criterion under the model |
| `Ter` | Nondecision timing parameter, seconds | Does not alone distinguish retrieval, mapping, motor execution or consolidation |
| `st` | Nondecision-time range, seconds; shared | Absolute Ter interpretation awaits convolution/support audit |
| POP xi | Floor coefficient in the active normalized tuning-plus-floor weights | Calling it Gumbel scale does not establish raw-activation Gumbel-max equivalence |
| POP alpha | Tuning amplitude in older fixed-floor implementation | Only amplitude/floor ratio determines normalized front-end weights at fixed tuning |

## Candidate front ends

**JP** is a symmetric directional family. **Wrapped Cauchy** is its psi=-1 special case. Under the active team convention gamma=-log[tanh(K/2)] maps JP concentration to Cauchy dispersion. Identity of mathematical distributions must be accompanied by matched numerical integration, bounds and likelihood before treating saved fits as nested.

**Implemented POP** uses positive weights w(theta)=VM(theta;kappa)+xi*gamma_E with alpha fixed at one, then divides by their sum over latent nodes. Older MATLAB POP uses alpha*VM+gamma_E. This is linear Luce normalization. Gumbel-max with independent scale-one noise is equivalent for deterministic utility log(w). Oberauer's SDT uses exp(S)/sum(exp(S)) for activation S. Whether the project's intended psychological signal is S or log(w) remains an explicit discussion item; no equation was changed during cleanup. See [decision log](decisions.md).

## Conditions

| Stored label | S | C | Repeated-colour multiplicity m=S-C+1 | Grouped-model cue state |
|---|---:|---:|---:|---|
| S2C2NR | 2 | 2 | 1 | Base |
| S4C2NR | 4 | 2 | 3 | NR |
| S4C2R | 4 | 2 | 3 | R |
| S4C4NR | 4 | 4 | 1 | Base |
| S6C2NR | 6 | 2 | 5 | NR |
| S6C2R | 6 | 2 | 5 | R |
| S6C4NR | 6 | 4 | 3 | NR |
| S6C4R | 6 | 4 | 3 | R |
| S6C6NR | 6 | 6 | 1 | Base |

The design provides matched R/NR comparisons at identical S/C. Increasing S at fixed C also changes multiplicity/configuration; it is not a complete independent factorial crossing.

## Active Cauchy architectures

Every route retains nine cellwise gamma values and shared a/st. “Cellwise” means nine separately fitted condition values. Cue offsets apply only in redundant arrays, not S=C baseline cells. IDs below are the stable descriptive IDs used in the manifest; H labels remain valid code aliases.

| Existing alias | Descriptive reading label | Free k | Drift / eta / timing allocation |
|---|---|---:|---|
| H0 | Shared decision baseline | 14 | Shared vnorm, eta and Ter |
| H1_eta | Cellwise radial drift variability | 22 | Cellwise eta; shared vnorm/Ter |
| H1_vnorm | Cellwise drift strength | 22 | Cellwise vnorm; shared eta/Ter |
| H1_ter | Cellwise nondecision timing | 22 | Cellwise Ter; shared vnorm/eta |
| H_satDecision | Saturated decision diagnostic | 38 | Cellwise vnorm, eta, Ter; descriptive headroom only |
| H2_factorial | Factorized drift variability and timing | 20 | vnorm by S; eta by C; Ter by Base/R/NR |
| H2_tsensitive | Set-size drift with colour/cue timing | 20 | vnorm by S; shared eta; Ter by C plus signed R/NR offsets |
| H3_1v_tcolor | Shared drift with colour/cue timing | 18 | Shared vnorm/eta; Ter by C plus signed R/NR offsets |
| H3_1t_vset | Set-size/cue drift with shared timing | 18 | vnorm by S plus signed R/NR offsets; shared eta/Ter |
| H3_1t_vcolor | Colour/cue drift with shared timing | 18 | vnorm by C plus signed R/NR offsets; shared eta/Ter |
| H3_1v_tset | Shared drift with set-size/cue timing | 18 | Shared vnorm/eta; Ter by S plus signed R/NR offsets |

Timing law: Ter(c)=Ter_group(c)+delta_R*I_R(c)+delta_NR*I_NR(c). Drift-offset routes use the analogous vnorm law. Group values are categorical, not a fitted smooth load function. Linear constraints bound derived cell Ter in [0,1] s and vnorm in [2,12]. Consult `re2024_cauchy_hypothesis_spec.m` for exact hard/soft bounds, ordering and layout versions.

Useful nesting checks: H0 embeds in each release; H3 colour/cue Ter embeds in H1_ter and H2_tsensitive; H3 colour/cue drift embeds in H1_vnorm. Exact embeddings must reproduce likelihood and account for soft penalties. H2 and H1 are not generally nested in each other.

Descriptive IDs separate memory, drift, eta and timing allocation (for example `memory_cellwise_drift_shared_timing_colour_cue`). They improve exposition without renaming historical directories, vector fields or specification switches. The manifest carries the complete alias-to-ID mapping.

## Saved quantities and versioning

Current result keys are `allResults.AQ_cauchy` etc. `Pfit` is the full vector, `Pvar` its free entries, `Sel` the selection mask, and `paramNames` the saved order. Match names and layout versions rather than guessing vector positions.

`bestNLL` / CSV `NLL` is the optimization objective. `ll2/2` is the saved absolute unpenalized NLL because wrappers currently use abs(llRaw). AIC/BIC exclude penalties. The comparison export separates objective and penalty; signed raw NLL still requires forward evaluation. The current source hash is a snapshot, not evidence that saved fits used that exact source or binary.
