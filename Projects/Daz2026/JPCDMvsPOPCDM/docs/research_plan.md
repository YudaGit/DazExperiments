# Research and completion plan

Current priorities; [overview](../README.md) holds the current evidence. Historical proposals are preserved in the archived master. The cleanup implements organization and reliable saved-result selection; it does not start large fits.

## Scientific sequence

| Step | Work | Completion criterion |
|---|---|---|
| M0 | Freeze canonical files, explicit data and source/MEX provenance; reproduce saved vectors | Manifest and per-route reproduction table; distinguish objective/penalty and signed NLL |
| M1 | Isolated numerical checks | Measured stride/endpoint/conditioning/convolution/grid effects and justified refit decisions; see numerical audit |
| M2 | Consistent regional and conditional diagnostics | Same selected joint density for marginals, moments and quantiles; 45-cell counts and uncertainty |
| M3 | Assess timing/evidence interpretation using current H2 **and H3** | Exact nesting checks, parameter contrasts, recovery and ablations; retain near ties and individual differences |
| M4 | Clarify POP rule; matched front-end comparison | Common architectures, likelihood conventions, numerical accuracy and optimization quality across POP/JP/Cauchy |
| M5 | Derive and fit resource-to-dispersion constraints | Explicit law in gamma/rho/CSD, task allocation by S/C/multiplicity, constrained joint fits and recovery |
| M6 | Validate and assess remaining slow-error/strategy interpretations | Independent data or held-out sessions, honest residual account, decision on any extra mechanism |
| M7 | Assemble draft and reproducibility material | Every numerical claim/exhibit linked to exact evidence; draft can develop alongside M0–M3 |

## Retained scientific questions

- **R1, angle fit:** preserve any reproducible POP central/shoulder/tail advantage even if joint information criteria favour another model. Integrate fractional angular-bin overlaps; decompose angle and conditional-RT contributions consistently.
- **R2, slow errors:** distinguish global timing improvement from tail-minus-central slowing within a condition. Compute regional quantiles at matched empirical bins. Vary eta, drift and Ter separately in simulation before proposing a shared latent state linking direction dispersion and strength.
- **R3, uncertainty:** export counts, tail proportions and quantiles for every participant/condition. Bootstrap within cells or blocks/sessions as appropriate. Recompute empirical equal-mass edges. Empty-tail RT remains undefined; retain sparse-cell flags rather than selecting striking effects.
- **R4, comparability:** record trial identities/order, units, filters, grids, floors, bounds/penalties, seeds, starts, optimizer settings and exact binaries. Validate saved parameter mappings before optimizing. Use signed NLL once its impact is checked; information criteria exclude penalties.
- **R5, memory theory:** gamma is dispersion, rho=exp(-gamma), CSD=sqrt(2 gamma). A power law on one is not the same hypothesis on another. Distinguish averaging completed Cauchy variables from averaging evidence before stochastic consolidation. Derive the resource law for the redundancy design instead of substituting colour count for item count automatically. Questions in the separate theory draft require author clarification only if we adopt that derivation; revising that publication is not our deliverable.
- **R6, POP:** identify the implemented activation/selection rule and amplitude/floor ratio. Compare equivalent parameterizations under mapped bounds and penalties; do not infer theoretical failure from large amplitude alone. Keep the investigator's signal interpretation in the decision log pending detailed discussion.
- **R7, numerics:** follow the separate audit register. Source inspection is evidence of a code finding, not proof of fitted likelihood impact.

## Fit discipline and stopping boundary

Include exact smaller-model seeds in genuinely nested models, and keep a seed if optimization worsens. A larger model's worse unpenalized likelihood triggers an embedding/optimization investigation. Check boundaries and basin recovery rather than relying on successful exit flags alone.

Use a small common set of decision architectures for final front-end comparison. Selecting bespoke architectures for each front end or participant confounds comparisons. H2/H3 development is exploratory; BIC does not erase that history. Independently reported strategies can motivate variants but do not follow directly from Ter.

Minimum empirical completion: validated numerics, matched front ends, interpretable timing/evidence comparison, a specified allocation test, uncertainty/recovery evidence and reported residuals. Direction–strength coupling or swap extensions remain conditional. Scope conclusions to these five participants unless additional data establish broader applicability.

## Drafting

Use the [manuscript foundation](manuscript_foundation.md) for the Introduction and source list, and the [evidence map](../manuscript/evidence_map.md) to separate completed, provisional and planned findings. Keep full route history in supporting material. The investigator's core argument is that an adequate memory front end enables interpretable assessment of decision variability, not simply that adding timing parameters improves fit.
