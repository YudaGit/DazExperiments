# Exploratory fixed-shape decision-similarity fits for YL.
# Run from the Encoding2526 project root.
source("Enc_smallN_2nd/AnalysesR/cauchy_model.R")
source("Enc_smallN_2nd/AnalysesR/awss_runner.R")
out <- "Enc_smallN_2nd/AnalysesR/results/YL"
trials <- read.csv("Enc_smallN_2nd/Daz25EncodingData/PreliminaryReview/YL_model_trials.csv")
baseline <- readRDS(file.path(out, "cauchy_awss_cosine_decision_20starts.rds"))

fits <- lapply(c(15, 45, 90), function(efold_degrees) {
  fit <- fit_awss_cells(
    trials, model = "cauchy", decision_signal = "exponential",
    fixed_similarity_decay = 180 / (pi * efold_degrees),
    n = 360L, n_starts = 4L, seed = 20261014L,
    maxit = 3000L, factr = 1e5, pgtol = 1e-7, ndeps = 1e-5,
    selection = "prefer_R", state_by_duration = FALSE,
    selection_by_duration = TRUE, previous_fit = baseline
  )
  saveRDS(fit, file.path(out, sprintf("cauchy_fixed_similarity_%ddeg_YL.rds",
                                      efold_degrees)))
  data.frame(shape = sprintf("exponential_%ddeg", efold_degrees),
             efold_degrees = efold_degrees,
             negative_ll = fit$total_negative_ll,
             parameters = fit$parameter_count,
             sensitivity = fit$shared_value,
             converged_starts = sum(fit$starts$convergence == 0L))
})
comparison <- rbind(
  data.frame(shape = "cosine", efold_degrees = NA_real_,
             negative_ll = baseline$total_negative_ll,
             parameters = baseline$parameter_count,
             sensitivity = baseline$shared_value,
             converged_starts = sum(baseline$starts$convergence == 0L)),
  do.call(rbind, fits)
)
comparison$BIC <- with(comparison,
                       2 * negative_ll + parameters * log(baseline$trial_count))
write.csv(comparison, file.path(out, "cauchy_fixed_similarity_comparison_YL.csv"),
          row.names = FALSE)
print(comparison, row.names = FALSE)
