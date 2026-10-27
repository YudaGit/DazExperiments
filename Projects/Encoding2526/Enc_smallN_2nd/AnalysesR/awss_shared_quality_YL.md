---
title: "YL Study 2: shared-quality AWSS models"
output: html_document
---

Both models have one attended and one unattended single-color quality value
shared across the 50 and 250 ms conditions. Each of the ten display-duration
groups has its own better-state fraction `W`. The redundancy selection-bias
strength is estimated separately at 50 and 250 ms. A single Cauchy report
sensitivity or MaxGumbel tuning parameter is shared across all cells. Thus
each model has 15 parameters: 2 state values + 10 weights + 2 selection
strengths + 1 report/tuning value. Sample-size and redundancy quality scaling
remain the same as in the previous AWSS fits.


``` r
source("cauchy_model.R")
source("MaxGumbelModel.R")
library(ggplot2)
ca <- readRDS("results/YL/cauchy_awss_shared_quality_fit.rds")
mg <- readRDS("results/YL/maxgumbel_awss_shared_quality_fit.rds")
ca_old <- readRDS("results/YL/cauchy_awss_prefer_R_fit.rds")
mg_old <- readRDS("results/YL/maxgumbel_awss_prefer_R_fit.rds")
stopifnot(ca$parameter_count == 15, mg$parameter_count == 15,
          identical(ca$cells$cell, mg$cells$cell))
trials <- read.csv("../Daz25EncodingData/PreliminaryReview/YL_model_trials.csv")
trials <- subset(trials, IsUsable == 1 & is.finite(Precision))
trials$ColorN <- ifelse(trials$RedundantN > 0,
                         trials$ItemN - trials$RedundantN + 1,
                         trials$ItemN)
trials$cell <- sprintf("S%dC%d_%s_%dms", trials$ItemN, trials$ColorN,
                       trials$ConditionType, round(1000 * trials$PresDur))
```

## Fit comparison


``` r
summary <- data.frame(
  model = c("Cauchy: duration-specific quality",
            "Cauchy: shared quality",
            "MaxGumbel: duration-specific quality",
            "MaxGumbel: shared quality"),
  negative_ll = c(ca_old$total_negative_ll, ca$total_negative_ll,
                  mg_old$total_negative_ll, mg$total_negative_ll),
  parameters = c(ca_old$parameter_count, ca$parameter_count,
                 mg_old$parameter_count, mg$parameter_count))
summary$AIC <- 2 * summary$negative_ll + 2 * summary$parameters
summary$BIC <- 2 * summary$negative_ll +
  log(ca$trial_count) * summary$parameters
knitr::kable(summary, digits = 3)
```



|model                                | negative_ll| parameters|      AIC|      BIC|
|:------------------------------------|-----------:|----------:|--------:|--------:|
|Cauchy: duration-specific quality    |    4706.098|         16| 9444.196| 9548.125|
|Cauchy: shared quality               |    4710.289|         15| 9450.578| 9548.012|
|MaxGumbel: duration-specific quality |    4680.824|         16| 9393.648| 9497.577|
|MaxGumbel: shared quality            |    4696.425|         15| 9422.850| 9520.284|

Sharing quality increases negative log likelihood by
4.19 for
Cauchy and 15.60
for MaxGumbel. The shared-quality models have the same parameter count;
MaxGumbel has an advantage of
13.86 negative
log-likelihood units. This is an in-sample comparison. Sharing quality is
a substantive restriction, not evidence that duration can only affect
subset membership.

## Fitted values


``` r
quality <- data.frame(
  model = c("Cauchy dispersion", "MaxGumbel amplitude"),
  attended_1 = c(ca$state_parameters$attended_1[1],
                 mg$state_parameters$attended_1[1]),
  unattended_1 = c(ca$state_parameters$unattended_1[1],
                   mg$state_parameters$unattended_1[1]),
  shared_report_or_tuning = c(ca$shared_value, mg$shared_value),
  bias_50ms = c(ca$selection_bias[1], mg$selection_bias[1]),
  bias_250ms = c(ca$selection_bias[2], mg$selection_bias[2]))
knitr::kable(quality, digits = 3)
```



|model               | attended_1| unattended_1| shared_report_or_tuning| bias_50ms| bias_250ms|
|:-------------------|----------:|------------:|-----------------------:|---------:|----------:|
|Cauchy dispersion   |      0.036|        0.517|                  15.407|     1.000|      0.839|
|MaxGumbel amplitude |     20.156|        4.380|                   1.328|     0.629|      0.701|

``` r
weights <- data.frame(
  W_group = ca$weights$W_group, ColorN = ca$weights$ColorN,
  Cauchy_Kn = ca$weights$Kn_est,
  Cauchy_W_R = ca$weights$W_R,
  Cauchy_W_NR = ca$weights$W_NR,
  MaxGumbel_Kn = mg$weights$Kn_est,
  MaxGumbel_W_R = mg$weights$W_R,
  MaxGumbel_W_NR = mg$weights$W_NR)
knitr::kable(weights, digits = 3)
```



|W_group    | ColorN| Cauchy_Kn| Cauchy_W_R| Cauchy_W_NR| MaxGumbel_Kn| MaxGumbel_W_R| MaxGumbel_W_NR|
|:----------|------:|---------:|----------:|-----------:|------------:|-------------:|--------------:|
|S2C2_250ms |      2|     1.990|         NA|          NA|        1.966|            NA|             NA|
|S2C2_50ms  |      2|     1.990|         NA|          NA|        1.975|            NA|             NA|
|S4C2_250ms |      2|     1.886|      0.991|       0.895|        1.827|         0.974|          0.853|
|S4C2_50ms  |      2|     1.574|      1.000|       0.574|        1.504|         0.908|          0.596|
|S4C4_250ms |      4|     2.168|         NA|          NA|        2.510|            NA|             NA|
|S4C4_50ms  |      4|     1.500|         NA|          NA|        1.814|            NA|             NA|
|S6C4_250ms |      4|     1.568|      0.902|       0.222|        1.624|         0.822|          0.267|
|S6C4_50ms  |      4|     0.700|      0.700|       0.000|        0.916|         0.661|          0.085|
|S6C6_250ms |      6|     2.033|         NA|          NA|        2.260|            NA|             NA|
|S6C6_50ms  |      6|     0.901|         NA|          NA|        1.210|            NA|             NA|

The bias values are fractions of the largest feasible probability shift for
each display. The Cauchy 50 ms bias reaches its upper bound, so its estimated
selection preference should be read as maximal under this parameterization.
The S2C2 `Kn` estimates remain close to two. Some 50 ms large-display
`Kn` estimates differ across the models; their psychological precision
requires a parameter-recovery check.

## Cell fit and far errors


``` r
cells <- data.frame(cell = ca$cells$cell,
                    cauchy_negative_ll = ca$cells$negative_ll,
                    maxgumbel_negative_ll = mg$cells$negative_ll)
cells$cauchy_minus_maxgumbel <- cells$cauchy_negative_ll -
  cells$maxgumbel_negative_ll
knitr::kable(cells[order(-cells$cauchy_minus_maxgumbel), ],
             digits = 3, row.names = FALSE)
```



|cell          | cauchy_negative_ll| maxgumbel_negative_ll| cauchy_minus_maxgumbel|
|:-------------|------------------:|---------------------:|----------------------:|
|S2C2_B_50ms   |            168.188|               161.212|                  6.976|
|S4C2_R_250ms  |             48.110|                42.814|                  5.295|
|S4C4_B_50ms   |            500.901|               497.114|                  3.787|
|S4C4_B_250ms  |            435.975|               432.373|                  3.601|
|S6C6_B_50ms   |            587.303|               586.231|                  1.072|
|S6C4_NR_250ms |            553.934|               553.251|                  0.683|
|S4C2_NR_50ms  |            359.033|               358.671|                  0.362|
|S6C4_NR_50ms  |            617.159|               617.111|                  0.048|
|S6C4_R_50ms   |            284.912|               285.514|                 -0.601|
|S6C4_R_250ms  |            184.511|               185.182|                 -0.671|
|S6C6_B_250ms  |            546.596|               547.328|                 -0.731|
|S4C2_R_50ms   |            101.476|               103.041|                 -1.565|
|S4C2_NR_250ms |            210.763|               212.682|                 -1.919|
|S2C2_B_250ms  |            111.428|               113.902|                 -2.474|


``` r
tail_mass <- function(pred) {
  h <- 2 * pi / length(pred$theta)
  sum(pred$ptheta[abs(pred$theta) >= pi / 2]) * h
}
far <- do.call(rbind, lapply(seq_len(nrow(ca$cells)), function(i) {
  a <- ca$cells[i, ]
  b <- mg$cells[i, ]
  ap <- cauAWSSreport(c(a$attended_1, a$unattended_1,
                        a$W, ca$shared_value),
                      N = a$ColorN, r = a$r)
  bp <- max_gumbel_awss_report(c(b$attended_1, b$unattended_1,
                                 b$W, mg$shared_value),
                               N = b$ColorN, r = b$r)
  data.frame(cell = a$cell,
             observed = mean(abs(trials$Precision[trials$cell == a$cell]) >= 90),
             cauchy = tail_mass(ap), maxgumbel = tail_mass(bp))
}))
knitr::kable(far[grepl("^S6C4|^S6C6", far$cell), ],
             digits = 3, row.names = FALSE)
```



|cell          | observed| cauchy| maxgumbel|
|:-------------|--------:|------:|---------:|
|S6C4_NR_250ms |    0.253|  0.231|     0.240|
|S6C4_NR_50ms  |    0.340|  0.290|     0.295|
|S6C4_R_250ms  |    0.046|  0.031|     0.037|
|S6C4_R_50ms   |    0.049|  0.066|     0.069|
|S6C6_B_250ms  |    0.289|  0.230|     0.235|
|S6C6_B_50ms   |    0.277|  0.287|     0.290|

The R/NR contrast is substantially closer to the data than under the
quality-only mixture. Both models still underpredict some NR far errors
at S6C4, 50 ms and baseline far errors at S6C6, 250 ms. This threshold is
descriptive; the likelihood uses individual signed errors.

## Predictions against YL data


``` r
cell_order <- with(ca$cells,
  order(ItemN, match(ConditionType, c("B", "R", "NR")), PresDur))
cell_levels <- ca$cells$cell[cell_order]
trials$cell <- factor(trials$cell, levels = cell_levels)
curves <- do.call(rbind, lapply(seq_len(nrow(ca$cells)), function(i) {
  a <- ca$cells[i, ]
  b <- mg$cells[i, ]
  ap <- cauAWSSreport(c(a$attended_1, a$unattended_1,
                        a$W, ca$shared_value),
                      N = a$ColorN, r = a$r)
  bp <- max_gumbel_awss_report(c(b$attended_1, b$unattended_1,
                                 b$W, mg$shared_value),
                               N = b$ColorN, r = b$r)
  rbind(
    data.frame(cell = a$cell, error_deg = ap$theta * 180 / pi,
               density_deg = ap$ptheta * pi / 180,
               model = "Cauchy AWSS"),
    data.frame(cell = b$cell, error_deg = bp$theta * 180 / pi,
               density_deg = bp$ptheta * pi / 180,
               model = "MaxGumbel AWSS")
  )
}))
curves$cell <- factor(curves$cell, levels = cell_levels)
plot_shared <- ggplot(trials, aes(x = Precision)) +
  geom_histogram(aes(y = after_stat(density)), binwidth = 10,
                 boundary = -180, fill = "grey75", colour = "white") +
  geom_line(data = curves,
            aes(x = error_deg, y = density_deg, colour = model),
            linewidth = 0.8) +
  facet_wrap(~ cell, ncol = 4) +
  coord_cartesian(xlim = c(-180, 180)) +
  scale_x_continuous(breaks = c(-180, -90, 0, 90, 180)) +
  scale_colour_manual(values = c("Cauchy AWSS" = "#C13C32",
                                 "MaxGumbel AWSS" = "#2C7FB8")) +
  labs(x = "Signed response error (degrees)", y = "Density per degree",
       title = "YL: shared-quality AWSS predictions") +
  theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank(),
        strip.text = element_text(face = "bold"))
print(plot_shared)
```

![plot of chunk shared-quality-predictions](figure/shared-quality-predictions-1.png)

``` r
ggsave("results/YL/awss_shared_quality_predictions_YL.png", plot_shared,
       width = 14, height = 11, dpi = 150)
```

## Optimizer check


``` r
audit <- do.call(rbind, lapply(list(ca, mg), function(f) {
  data.frame(model = f$model, starts = nrow(f$starts),
             converged = sum(f$starts$convergence == 0),
             near_best = sum(is.finite(f$starts$negative_ll) &
                             abs(f$starts$negative_ll -
                                 f$total_negative_ll) < 1e-4),
             failed = sum(!is.finite(f$starts$negative_ll)),
             elapsed_seconds = f$elapsed_seconds)
}))
knitr::kable(audit, digits = 3)
```



|model                                                | starts| converged| near_best| failed| elapsed_seconds|
|:----------------------------------------------------|------:|---------:|---------:|------:|---------------:|
|cauchy_awss_prefer_R_shared_quality_duration_bias    |     12|        12|        12|      0|          37.102|
|maxgumbel_awss_prefer_R_shared_quality_duration_bias |     12|        11|        11|      1|         422.618|

All twelve Cauchy starts recover the best solution. Eleven MaxGumbel starts
recover the best solution; one start fails. The repeated best result supports
the reported likelihood but does not prove a global optimum.
