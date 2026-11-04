# FP Study 2: AWSS model comparison

FP has 1,960 trials in 14 conditions (140 per condition); one trial is flagged
unusable, leaving 1,959 likelihood observations. The fits use the same
condition mapping, one-degree response grid, nearest-grid likelihood, colour
count scaling, redundant-copy boost, and AWSS selection parameterization as
the YL shared-quality comparison. Each full model has 15 parameters: two
single-colour state qualities shared across durations, ten display-duration
weights W, two duration-specific R-selection biases, and one shared response
or tuning parameter. Fifty optimizer starts were used for each full fit.

## Fit

| Model | Negative log likelihood | BIC | Starts near best |
|---|---:|---:|---:|
| MaxGumbel AWSS + R bias | 1487.088 | 3087.878 | 47/50 |
| Cauchy AWSS + R bias, cosine/Gumbel response | 1496.912 | 3107.527 | 49/50 |
| Cauchy AWSS + R bias, direct Gaussian response | 1498.022 | 3109.747 | 48/50 |

Among matched 15-parameter fits, MaxGumbel has a 9.824-unit negative-log-
likelihood advantage over the historical Cauchy comparison, equivalent to
19.649 BIC units. The direct Gaussian response variant is within 1.110
negative-log-likelihood units of Cauchy cosine, so the Cauchy result is robust
to that change in response rule. This is an in-sample fit comparison.

## Parameters and participant comparison

| Quantity | FP Cauchy cosine | YL Cauchy cosine | FP MaxGumbel | YL MaxGumbel |
|---|---:|---:|---:|---:|
| Better-state single-colour dispersion / amplitude | 0.0403 | 0.0360 | 26.3950 | 20.1564 |
| Worse-state single-colour dispersion / amplitude | 0.5013 | 0.5174 | 6.4825 | 4.3805 |
| Response sensitivity / tuning kappa | 15.6973 | 15.4074 | 1.7059 | 1.3283 |
| R-selection bias, 50 ms | 0.5876 | 1.0000 | 0.0555 | 0.6291 |
| R-selection bias, 250 ms | 1.0000 | 0.8388 | 0.3406 | 0.7011 |

The two Cauchy dispersions and the response sensitivity are close between FP
and YL. For the direct Gaussian response, the estimated response width is
14.05 degrees for FP and 14.65 degrees for YL. FP's MaxGumbel amplitudes and
tuning are larger than YL's, so MaxGumbel W values need to be interpreted
jointly with these state-quality differences.

| Display | FP Cauchy W: 50 -> 250 ms | YL Cauchy W: 50 -> 250 ms | FP MaxGumbel W: 50 -> 250 ms | YL MaxGumbel W: 50 -> 250 ms |
|---|---:|---:|---:|---:|
| S2C2 | 0.974 -> 0.995 | 0.995 -> 0.995 | 0.505 -> 0.701 | 0.987 -> 0.983 |
| S4C2 | 0.934 -> 0.963 | 0.787 -> 0.943 | 0.268 -> 0.296 | 0.752 -> 0.914 |
| S4C4 | 0.774 -> 0.892 | 0.375 -> 0.542 | 0.384 -> 0.604 | 0.453 -> 0.627 |
| S6C4 | 0.561 -> 0.692 | 0.175 -> 0.392 | 0.192 -> 0.321 | 0.229 -> 0.406 |
| S6C6 | 0.319 -> 0.523 | 0.150 -> 0.339 | 0.005 -> 0.174 | 0.202 -> 0.377 |

Within FP, every fitted W increases with duration in both models. This
matches the main YL pattern outside S2C2, where YL is already near the
upper W bound. FP's Cauchy W values are higher than YL's in most displays,
which is consistent with FP's generally better raw recall in the harder
conditions. The MaxGumbel model does not produce the same participant ordering
for every display: notably, FP's S4C2 W is much lower than YL's despite
stronger FP quality parameters. Thus the *direction of the duration effect*
replicates, whereas the numerical estimated subset size Kn = NW is model
dependent. FP's MaxGumbel S6C6 50 ms W reaches the imposed lower bound 0.005.

## Does the R-selection mechanism help?

The reduced models keep the redundant-copy quality boost but set selection
bias to zero. They have 13 rather than 15 parameters; each was fit from 20
starts, all ending within 0.01 negative-log-likelihood units of the best.

| Model | Full NLL | No-bias NLL | Full BIC | No-bias BIC |
|---|---:|---:|---:|---:|
| Cauchy cosine | 1496.912 | 1512.936 | 3107.527 | 3124.414 |
| MaxGumbel | 1487.088 | 1490.702 | 3087.878 | 3079.947 |

For FP, the Cauchy account benefits materially from R-selection bias even
after BIC's penalty. The MaxGumbel account improves by only 3.615 NLL units;
its no-bias version has the better BIC by 7.931. The FP MaxGumbel 50 ms bias
estimate is only 0.055. Accordingly, a redundancy-related representation-
quality boost is common to both model implementations, but an additional
selection bias is not equally supported by both. The Cauchy 250 ms bias is at
its upper bound, so its exact magnitude is unresolved.

The full-fit curves against data are in `awss_predictions_FP.png`, and the
cell-level likelihood differences are in `awss_cell_comparison_FP.csv`.
