# FP: matched AWSS + R-selection fits, with the two Cauchy response rules.
# Run from the Encoding2526 project root.
source("Enc_smallN_2nd/AnalysesR/cauchy_model.R")
source("Enc_smallN_2nd/AnalysesR/MaxGumbelModel.R")
source("Enc_smallN_2nd/AnalysesR/awss_runner.R")

out <- "Enc_smallN_2nd/AnalysesR/results/FP"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
yl_out <- "Enc_smallN_2nd/AnalysesR/results/YL"
trials <- read.csv(
  "Enc_smallN_2nd/Daz25EncodingData/PreliminaryReview/FP_model_trials.csv")

specs <- list(
  cauchy_cosine = list(model = "cauchy", decision_signal = "cosine",
                        warm = "cauchy_awss_shared_quality_fit.rds"),
  cauchy_gaussian = list(model = "cauchy",
                          decision_signal = "gaussian_kernel",
                          warm = "cauchy_awss_gaussian_decision_20starts.rds"),
  maxgumbel = list(model = "maxgumbel", decision_signal = "cosine",
                   warm = "maxgumbel_awss_shared_quality_fit.rds")
)
fits <- lapply(seq_along(specs), function(i) {
  spec <- specs[[i]]
  fit <- fit_awss_cells(
    trials, model = spec$model, decision_signal = spec$decision_signal,
    n = 360L, n_starts = 50L, seed = 20261028L + i,
    maxit = 3000L, factr = 1e5, pgtol = 1e-7, ndeps = 1e-5,
    selection = "prefer_R", state_by_duration = FALSE,
    selection_by_duration = TRUE,
    previous_fit = readRDS(file.path(yl_out, spec$warm))
  )
  saveRDS(fit, file.path(out, paste0(names(specs)[i], "_awss_fit.rds")))
  cat(names(specs)[i], "NLL:", fit$total_negative_ll,
      "converged:", sum(fit$starts$convergence == 0L), "/ 50",
      "near best:",
      sum(abs(fit$starts$negative_ll - fit$total_negative_ll) < .01),
      "/ 50\n")
  fit
})
names(fits) <- names(specs)
comparison <- data.frame(
  model = names(fits),
  negative_ll = vapply(fits, `[[`, numeric(1), "total_negative_ll"),
  parameters = vapply(fits, `[[`, integer(1), "parameter_count"),
  trials = vapply(fits, `[[`, integer(1), "trial_count"),
  elapsed_seconds = vapply(fits, `[[`, numeric(1), "elapsed_seconds")
)
comparison$BIC <- with(comparison,
                       2 * negative_ll + parameters * log(trials))
write.csv(comparison, file.path(out, "awss_model_comparison_FP.csv"),
          row.names = FALSE)
print(comparison, row.names = FALSE)
