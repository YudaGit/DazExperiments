# FP nested comparison: quality boost only, no R-selection bias.
source("Enc_smallN_2nd/AnalysesR/cauchy_model.R")
source("Enc_smallN_2nd/AnalysesR/MaxGumbelModel.R")
source("Enc_smallN_2nd/AnalysesR/awss_runner.R")
out <- "Enc_smallN_2nd/AnalysesR/results/FP"
trials <- read.csv(
  "Enc_smallN_2nd/Daz25EncodingData/PreliminaryReview/FP_model_trials.csv")
specs <- list(cauchy_cosine = "cauchy", maxgumbel = "maxgumbel")
fits <- lapply(seq_along(specs), function(i) {
  name <- names(specs)[i]
  fit <- fit_awss_cells(
    trials, model = specs[[i]], n = 360L, n_starts = 20L,
    seed = 20261028L + 100L + i,
    maxit = 3000L, factr = 1e5, pgtol = 1e-7, ndeps = 1e-5,
    selection = "quality_only", state_by_duration = FALSE,
    selection_by_duration = FALSE,
    previous_fit = readRDS(file.path(out, paste0(name, "_awss_fit.rds")))
  )
  saveRDS(fit, file.path(out, paste0(name, "_quality_only_fit.rds")))
  cat(name, "quality-only NLL:", fit$total_negative_ll,
      "near best:",
      sum(abs(fit$starts$negative_ll - fit$total_negative_ll) < .01),
      "/ 20\n")
  fit
})
names(fits) <- names(specs)
comparison <- do.call(rbind, lapply(names(fits), function(name) {
  full <- readRDS(file.path(out, paste0(name, "_awss_fit.rds")))
  reduced <- fits[[name]]
  data.frame(model = name,
             full_nll = full$total_negative_ll,
             reduced_nll = reduced$total_negative_ll,
             improvement_nll = reduced$total_negative_ll -
               full$total_negative_ll,
             full_BIC = 2 * full$total_negative_ll +
               full$parameter_count * log(full$trial_count),
             reduced_BIC = 2 * reduced$total_negative_ll +
               reduced$parameter_count * log(reduced$trial_count))
}))
write.csv(comparison, file.path(out, "awss_bias_ablation_FP.csv"),
          row.names = FALSE)
print(comparison, row.names = FALSE)
