# Numerical audit: pending measured validation

Current issue register, 13 November 2026. [Project overview](../README.md).

The source findings below were already documented before reorganization. No isolated core builds, numerical corrections or refits were performed during cleanup. Production C and MEX files remain unchanged. Current fit/source hashes are snapshots; they do not prove fit-time provenance or source/MEX agreement.

## Order and decision gates

1. Resolve exact MEX paths and record hashes/compiler/platform; reproduce each saved vector and separate signed raw NLL, penalty, and information criteria.
2. Compare isolated old/corrected variants at fixed parameters, measuring joint density and returned summaries independently.
3. Test periodic closure, RT conditioning/convolution, latent-angle and response/time-grid convergence.
4. Classify effects: summary-only changes regenerate diagnostics; objective changes require evaluation of every affected canonical vector before deciding refits.
5. Regenerate final diagnostics from one convolved, RT-selected joint density, with regional counts and uncertainty. Do not treat existing manuscript candidates as validated predictions.

## Retained technical findings and proposed tolerances

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


## Audit log

- 13 November 2026: 55 CSV/MAT scalar records checked for agreement; this is saved-file consistency only. HC H0 has objective penalty approximately 0.0013714; other checked penalties are negligible at 1e-7 tolerance. No forward evaluation performed.
- Next: exact saved-vector replay with current production binaries, followed by isolated variants. Record date, build hashes, parameter/data snapshots, per-cell and participant effects, decision and outputs here.
