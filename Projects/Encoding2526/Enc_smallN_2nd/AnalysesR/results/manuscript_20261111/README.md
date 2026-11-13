# Experiment 3 complete-data manuscript pass

Participants: YL and FP only, ten completed sessions each, 4900 main trials each. Raw data and historical analysis files were not modified. Checkpoint files were excluded.

## Model comparisons

Both families use unique-colour load, three-copy R strengthening, better/worse quality states, ten display-duration W groups, and the same capacity-preserving R-bias transformation. Cauchy dispersion scales sqrt(N/r); MaxGumbel signal amplitude scales sqrt(r/N). The constrained quantities differ.

Cauchy uses the direct Gaussian circular mapping kernel. MaxGumbel uses independent unit-scale Gumbel noise with max selection; its shared signal-shape parameter is not a response SD. Both primary fits estimate their response/shape parameter freely. They do not have identical memory/report decompositions.

The full shared-quality and no-bias variants have 15 and 13 parameters; the duration-specific-quality variant has 17, retaining two duration-specific bias values. No-bias removes only preferential membership, not repetition strengthening. All likelihoods use individual errors at the same one-degree grid, and each fit used 20 starts.

Use fitrows.csv for NLL/AIC/BIC and optimizer summaries; comparisons.csv for nested comparisons; states.csv and weights.csv for parameter estimates; data/ for complete-session exports and refreshed original descriptive figures; figures/ for fitted distributions and expected capacity. Estimates are maximum-likelihood point estimates, not Bayesian posterior estimates or confidence intervals.

The YL mapping session is the same participant as YL memory data (and YDL in Experiment 1). The historical fixed-9.5-degree report incorrectly calls the donor a different participant. These new primary fits do not fix that rounded width. FP independent calibration is not present.

## Scope

This is a dated, reproducible analysis pass, not the final project cleanup. The input manifest records source/data hashes; scripts/ contains this pass scripts; R_session_info.txt records the R environment. Historical results, the master note, and experiment scripts may describe earlier datasets. No fitted differences were assumed in advance.

## Interpretation of refreshed results

The shared-quality bias comparison supports bias by BIC in both Cauchy fits and YL MaxGumbel, but favours no bias for FP MaxGumbel. The duration-specific-quality comparison favours shared quality for YL Cauchy and duration-specific quality for the other three fits.

Capacity increases with duration in the shared-quality fits except ceiling-level S2C2. This conclusion is conditional on shared quality: freeing state quality reverses the direction of FP capacity estimates in the larger arrays. Use capacity_quality_comparison.png and capacity_duration_changes_all_quality_structures.csv alongside expected_capacity_both.png; do not report a general increase in capacity as a model-invariant result.

The no-bias comparison is matched within the shared-quality structure. A duration-specific no-bias variant was not included in this pass. Sample-size and repetition exponents were fixed in every fitted variant, so these comparisons assess fit under those constraints rather than testing those exponents against free alternatives.
