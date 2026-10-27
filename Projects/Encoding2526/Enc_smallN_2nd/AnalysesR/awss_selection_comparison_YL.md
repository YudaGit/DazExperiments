---
title: "YL Study 2: AWSS with redundant-target selection"
output: html_document
---


``` r
source("cauchy_model.R")
source("MaxGumbelModel.R")
library(ggplot2)
ca0 <- readRDS("results/YL/cauchy_awss_fit.rds")
mg0 <- readRDS("results/YL/maxgumbel_awss_fit.rds")
ca <- readRDS("results/YL/cauchy_awss_prefer_R_fit.rds")
mg <- readRDS("results/YL/maxgumbel_awss_prefer_R_fit.rds")
stopifnot(identical(ca$cells$cell, mg$cells$cell),
          ca$parameter_count == mg$parameter_count)
trials <- read.csv("../Daz25EncodingData/PreliminaryReview/YL_model_trials.csv")
trials <- subset(trials, IsUsable == 1 & is.finite(Precision))
trials$ColorN <- ifelse(trials$RedundantN > 0,
                         trials$ItemN - trials$RedundantN + 1,
                         trials$ItemN)
trials$cell <- sprintf("S%dC%d_%s_%dms", trials$ItemN, trials$ColorN,
                       trials$ConditionType, round(1000 * trials$PresDur))
```

## Overall comparison

The new model fits a display-level better-state fraction `W` and one shared
selection-bias strength. For a display containing one redundant color and
`N - 1` other colors, the model derives group-specific `delta` and then
`W_R = W + (N - 1) * delta` and `W_NR = W - delta`. This preserves
`Kn_est = N * W`. The quality boost within each state remains in both models.


``` r
comparison <- data.frame(
  model = c("Cauchy quality only", "Cauchy with selection",
            "MaxGumbel quality only", "MaxGumbel with selection"),
  negative_ll = c(ca0$total_negative_ll, ca$total_negative_ll,
                  mg0$total_negative_ll, mg$total_negative_ll),
  parameters = c(ca0$parameter_count, ca$parameter_count,
                 mg0$parameter_count, mg$parameter_count))
comparison$AIC <- 2 * comparison$negative_ll + 2 * comparison$parameters
comparison$BIC <- 2 * comparison$negative_ll +
  log(ca$trial_count) * comparison$parameters
knitr::kable(comparison, digits = 3)
```



|model                    | negative_ll| parameters|      AIC|      BIC|
|:------------------------|-----------:|----------:|--------:|--------:|
|Cauchy quality only      |    4829.701|         15| 9689.401| 9786.834|
|Cauchy with selection    |    4706.098|         16| 9444.196| 9548.125|
|MaxGumbel quality only   |    4740.827|         15| 9511.655| 9609.088|
|MaxGumbel with selection |    4680.824|         16| 9393.648| 9497.577|

The selection parameter improves Cauchy by
123.60 negative
log-likelihood units and MaxGumbel by
60.00.
The new MaxGumbel advantage over Cauchy is
25.27 units.
These are in-sample fits; the extra parameter is included in AIC and BIC.

## Subset estimates and selection probabilities

The shared selection-bias strength is
0.840 for Cauchy and
0.695 for MaxGumbel. It is a fraction of the
maximum feasible shift for each display, so each display has a different
derived `delta`.


``` r
w <- data.frame(
  W_group = ca$weights$W_group, ColorN = ca$weights$ColorN,
  Cauchy_Kn = ca$weights$Kn_est,
  Cauchy_W_R = ca$weights$W_R,
  Cauchy_W_NR = ca$weights$W_NR,
  MaxGumbel_Kn = mg$weights$Kn_est,
  MaxGumbel_W_R = mg$weights$W_R,
  MaxGumbel_W_NR = mg$weights$W_NR)
knitr::kable(w, digits = 3)
```



|W_group    | ColorN| Cauchy_Kn| Cauchy_W_R| Cauchy_W_NR| MaxGumbel_Kn| MaxGumbel_W_R| MaxGumbel_W_NR|
|:----------|------:|---------:|----------:|-----------:|------------:|-------------:|--------------:|
|S2C2_250ms |      2|     1.990|         NA|          NA|        1.932|            NA|             NA|
|S2C2_50ms  |      2|     1.990|         NA|          NA|        1.990|            NA|             NA|
|S4C2_250ms |      2|     1.856|      0.988|       0.868|        1.800|         0.970|          0.831|
|S4C2_50ms  |      2|     1.604|      0.968|       0.636|        1.641|         0.945|          0.696|
|S4C4_250ms |      4|     2.132|         NA|          NA|        2.409|            NA|             NA|
|S4C4_50ms  |      4|     1.662|         NA|          NA|        2.034|            NA|             NA|
|S6C4_250ms |      4|     1.606|      0.904|       0.234|        1.708|         0.825|          0.294|
|S6C4_50ms  |      4|     0.842|      0.741|       0.034|        0.945|         0.729|          0.072|
|S6C6_250ms |      6|     2.059|         NA|          NA|        2.256|            NA|             NA|
|S6C6_50ms  |      6|     1.036|         NA|          NA|        1.481|            NA|             NA|

Baseline groups have no R or NR target, so their R/NR columns are blank.
S2C2 remains near two better-consolidated colors in both models. The
display-level `Kn` values are substantially closer across models than in the
quality-only fits, but they are still model-dependent estimates.

## Cell likelihoods and far errors


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
|S2C2_B_50ms   |            167.548|               160.417|                  7.131|
|S4C4_B_250ms  |            438.499|               433.734|                  4.765|
|S4C2_NR_50ms  |            357.957|               353.829|                  4.129|
|S4C4_B_50ms   |            500.017|               496.699|                  3.318|
|S4C2_R_50ms   |            103.005|               100.448|                  2.557|
|S4C2_R_250ms  |             45.829|                43.439|                  2.390|
|S6C4_NR_50ms  |            617.541|               615.625|                  1.916|
|S6C4_R_250ms  |            183.815|               182.490|                  1.324|
|S6C6_B_50ms   |            587.082|               585.989|                  1.093|
|S6C4_NR_250ms |            553.331|               552.742|                  0.589|
|S6C6_B_250ms  |            545.074|               545.424|                 -0.350|
|S2C2_B_250ms  |            110.048|               110.783|                 -0.735|
|S6C4_R_50ms   |            284.891|               286.317|                 -1.426|
|S4C2_NR_250ms |            211.461|               212.888|                 -1.427|


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
knitr::kable(far[grepl("^S6C4", far$cell), ],
             digits = 3, row.names = FALSE)
```



|cell          | observed| cauchy| maxgumbel|
|:-------------|--------:|------:|---------:|
|S6C4_NR_250ms |    0.253|  0.244|     0.247|
|S6C4_NR_50ms  |    0.340|  0.284|     0.304|
|S6C4_R_250ms  |    0.046|  0.029|     0.043|
|S6C4_R_50ms   |    0.049|  0.064|     0.059|

The selection mechanism substantially improves the S6C4 R/NR contrast.
At 50 ms, both models still underpredict the NR far-error fraction, while
the corresponding R predictions are much closer. The S6C6 baseline at
250 ms remains a tail mismatch that R-target selection cannot directly fix.
The threshold is descriptive; the fits use individual signed errors.

## Observed and predicted distributions


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
               model = "Cauchy AWSS + selection"),
    data.frame(cell = b$cell, error_deg = bp$theta * 180 / pi,
               density_deg = bp$ptheta * pi / 180,
               model = "MaxGumbel AWSS + selection")
  )
}))
curves$cell <- factor(curves$cell, levels = cell_levels)
plot_selection <- ggplot(trials, aes(x = Precision)) +
  geom_histogram(aes(y = after_stat(density)), binwidth = 10,
                 boundary = -180, fill = "grey75", colour = "white") +
  geom_line(data = curves,
            aes(x = error_deg, y = density_deg, colour = model),
            linewidth = 0.8) +
  facet_wrap(~ cell, ncol = 4) +
  coord_cartesian(xlim = c(-180, 180)) +
  scale_x_continuous(breaks = c(-180, -90, 0, 90, 180)) +
  scale_colour_manual(values = c("Cauchy AWSS + selection" = "#C13C32",
                                 "MaxGumbel AWSS + selection" = "#2C7FB8")) +
  labs(x = "Signed response error (degrees)", y = "Density per degree",
       title = "YL: observed errors and AWSS selection predictions") +
  theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank(),
        strip.text = element_text(face = "bold"))
print(plot_selection)
```

![plot of chunk selection-predictions](figure/selection-predictions-1.png)

``` r
ggsave("results/YL/awss_selection_predictions_YL.png", plot_selection,
       width = 14, height = 11, dpi = 150)
```

## Optimization


``` r
audit <- do.call(rbind, lapply(list(ca, mg), function(f) {
  data.frame(model = f$model, starts = nrow(f$starts),
             converged = sum(f$starts$convergence == 0),
             near_best = sum(abs(f$starts$negative_ll -
                                 f$total_negative_ll) < 1e-4),
             elapsed_seconds = f$elapsed_seconds)
}))
knitr::kable(audit, digits = 3)
```



|model                   | starts| converged| near_best| elapsed_seconds|
|:-----------------------|------:|---------:|---------:|---------------:|
|cauchy_awss_prefer_R    |     12|        12|         6|          45.184|
|maxgumbel_awss_prefer_R |     12|        12|        12|         106.084|

Six Cauchy starts recover the best solution; the other six converge to a
solution about 4.48 negative-log-likelihood units worse. All twelve
MaxGumbel starts recover the same best result to within 0.0001. Both fitted
solutions include `W` values at their imposed upper bound, so `Kn` near two
in S2C2 is best read as "approximately both colors."
