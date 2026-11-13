# YL Study 2: fixed 9.5-degree response mapping

This exploratory comparison applies a circular Gaussian report-mapping kernel
with SD fixed at 9.5 degrees to both AWSS models. The width comes from a
pilot mapping session by a different participant, so its transfer to YL is an
assumption. The same 4,893 usable YL trials, 14 conditions, one-degree grid,
nearest-grid likelihood, colour-count and redundancy scaling, ten display-
duration W values, shared attended/unattended quality across durations, and
duration-specific R-selection biases are used in both fits.

For Cauchy, the kernel is the conditional response distribution around the
latent consolidated angle; the former free mapping width is removed. For
MaxGumbel, the same kernel is convolved with the result of Gumbel/max choice.
Consequently MaxGumbel still includes an internal choice-noise stage. The
fixed external mapping stage does not make the models mechanistically
identical. Cauchy has 14 fitted parameters and MaxGumbel has 15; BIC includes
this difference.

## Fit

| Model | NLL | Fitted parameters | BIC | Starts within 0.01 NLL of best |
|---|---:|---:|---:|---:|
| Cauchy + fixed mapping | 4750.006 | 14 | 9618.950 | 50/50 |
| MaxGumbel + fixed mapping | 4700.120 | 15 | 9527.674 | 49/50 |

MaxGumbel wins by 49.886 negative-log-likelihood units and 91.276 BIC units.
The earlier free-width Cauchy Gaussian fit had NLL 4711.270 and estimated SD
14.65 degrees. Fixing it at 9.5 degrees raises its NLL by 38.736. The prior
MaxGumbel fit without an external mapping kernel had NLL 4696.425; adding
and refitting with fixed mapping raises its NLL by 3.695. These historical
comparisons are diagnostic rather than matched model comparisons.

## Shared fitted values

| Parameter | Cauchy | MaxGumbel |
|---|---:|---:|
| Better-state single-colour dispersion / signal amplitude | 0.096834 | 71.932088 |
| Worse-state single-colour dispersion / signal amplitude | 0.524613 | 8.619229 |
| Shared signal-shape kappa | — | 0.884993 |
| R-selection bias at 50 ms | 1.000000 | 0.669330 |
| R-selection bias at 250 ms | 0.997457 | 0.696103 |
| Report-mapping SD | 9.5 degrees, fixed | 9.5 degrees, fixed |

The Cauchy attended dispersion rose from 0.0380 under the free-width Gaussian
fit to 0.0968, broadening the latent representation to compensate for the
narrower response kernel. Both Cauchy bias values lie at or near their upper
bound, so their precise magnitude is not resolved. MaxGumbel's amplitudes
and shared tuning parameter changed substantially to offset the added kernel.

## Fitted display weights

| Display | Duration | Cauchy W | Cauchy Kn | MaxGumbel W | MaxGumbel Kn |
|---|---:|---:|---:|---:|---:|
| S2C2 | 50 ms | 0.995 | 1.99 | 0.929 | 1.86 |
| S2C2 | 250 ms | 0.995 | 1.99 | 0.953 | 1.91 |
| S4C2 | 50 ms | 0.816 | 1.63 | 0.720 | 1.44 |
| S4C2 | 250 ms | 0.995 | 1.99 | 0.886 | 1.77 |
| S4C4 | 50 ms | 0.438 | 1.75 | 0.381 | 1.52 |
| S4C4 | 250 ms | 0.650 | 2.60 | 0.537 | 2.15 |
| S6C4 | 50 ms | 0.188 | 0.75 | 0.211 | 0.84 |
| S6C4 | 250 ms | 0.445 | 1.78 | 0.371 | 1.48 |
| S6C6 | 50 ms | 0.186 | 1.12 | 0.148 | 0.89 |
| S6C6 | 250 ms | 0.412 | 2.47 | 0.318 | 1.91 |

W rises from 50 to 250 ms in all non-ceiling displays in both models. The
model-predicted R/NR weights are in the accompanying weights CSV. W_R and W_NR
are derived from W and the duration-specific bias; they are not separately
estimated.

## Where the models differ

The two S2C2 baseline conditions account for 30.476 of the total 49.886 NLL
advantage for MaxGumbel. With the 9.5-degree mapping kernel, Cauchy predicts
too much central peak mass in these easy conditions while retaining broad
shoulder/tail mass. MaxGumbel also does better in S4C2 R conditions. The
figure `fixed_mapping_9p5deg_predictions_YL.png` and the cell-level CSV show
all 14 conditions. This result does not show that the pilot SD is YL's true
mapping SD. It shows the consequence of imposing that measured value on YL.
