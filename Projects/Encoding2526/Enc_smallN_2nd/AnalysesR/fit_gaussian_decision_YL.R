# Direct centre-concentrated decision-error kernel, with one shared width.
# Run from the Encoding2526 project root.
source("Enc_smallN_2nd/AnalysesR/cauchy_model.R")
source("Enc_smallN_2nd/AnalysesR/awss_runner.R")
out <- "Enc_smallN_2nd/AnalysesR/results/YL"
trials <- read.csv("Enc_smallN_2nd/Daz25EncodingData/PreliminaryReview/YL_model_trials.csv")
baseline <- readRDS(file.path(out, "cauchy_awss_cosine_decision_20starts.rds"))
fit <- fit_awss_cells(
  trials, model = "cauchy", decision_signal = "gaussian_kernel",
  n = 360L, n_starts = 20L, seed = 20261014L,
  maxit = 3000L, factr = 1e5, pgtol = 1e-7, ndeps = 1e-5,
  selection = "prefer_R", state_by_duration = FALSE,
  selection_by_duration = TRUE, previous_fit = baseline
)
saveRDS(fit, file.path(out, "cauchy_awss_gaussian_decision_20starts.rds"))
comparison <- data.frame(
  decision = c("cosine_gumbel", "gaussian_direct"),
  negative_ll = c(baseline$total_negative_ll, fit$total_negative_ll),
  parameters = c(baseline$parameter_count, fit$parameter_count),
  decision_parameter = c(baseline$shared_value,
                         fit$shared_value * 180 / pi)
)
comparison$BIC <- with(comparison,
                       2 * negative_ll + parameters * log(fit$trial_count))
write.csv(comparison, file.path(out, "cauchy_gaussian_decision_comparison_YL.csv"),
          row.names = FALSE)
print(comparison, row.names = FALSE)
cat("Converged starts:", sum(fit$starts$convergence == 0L), "of 20\n")
cat("Near best:",
    sum(abs(fit$starts$negative_ll - fit$total_negative_ll) < .01), "of 20\n")
