# Compare cosine and Cauchy-shaped conditional decision signals in the same
# 15-parameter AWSS latent-Cauchy model. Run from the Encoding2526 root.
source("Enc_smallN_2nd/AnalysesR/cauchy_model.R")
source("Enc_smallN_2nd/AnalysesR/awss_runner.R")

out <- "Enc_smallN_2nd/AnalysesR/results/YL"
trials <- read.csv("Enc_smallN_2nd/Daz25EncodingData/PreliminaryReview/YL_model_trials.csv")
previous <- readRDS(file.path(out, "cauchy_awss_shared_quality_fit.rds"))

fits <- lapply(c("cosine", "cauchy"), function(signal) {
  cat("Fitting", signal, "decision signal...\n")
  fit_awss_cells(trials, model = "cauchy", decision_signal = signal,
                 n = 360L, n_starts = 20L, seed = 20261013L,
                 maxit = 3000L, factr = 1e5, pgtol = 1e-7,
                 ndeps = 1e-5, selection = "prefer_R",
                 state_by_duration = FALSE, selection_by_duration = TRUE,
                 previous_fit = previous)
})
names(fits) <- c("cosine", "cauchy")

saveRDS(fits$cosine,file.path(out,"cauchy_awss_cosine_decision_20starts.rds"))
saveRDS(fits$cauchy,file.path(out,"cauchy_awss_cauchy_decision_20starts.rds"))

summary <- do.call(rbind,lapply(names(fits),function(signal) {
  f <- fits[[signal]]
  data.frame(signal=signal,negative_ll=f$total_negative_ll,
             BIC=2*f$total_negative_ll+f$parameter_count*log(f$trial_count),
             parameter_count=f$parameter_count,trial_count=f$trial_count,
             sensitivity=f$shared_value,elapsed_seconds=f$elapsed_seconds,
             starts=f$optimizer_settings$n_starts,
             converged_starts=sum(f$starts$convergence==0),
             best_start=f$best_start,
             boundary_starts=sum(f$starts$boundary_hit))
}))
write.csv(summary,file.path(out,"cauchy_decision_signal_comparison.csv"),row.names=FALSE)

cell <- merge(fits$cosine$cells[c("cell","negative_ll")],
              fits$cauchy$cells[c("cell","negative_ll")],by="cell",
              suffixes=c("_cosine","_cauchy"))
cell$delta_nll_cauchy_minus_cosine <- cell$negative_ll_cauchy-cell$negative_ll_cosine
write.csv(cell,file.path(out,"cauchy_decision_signal_cell_comparison.csv"),row.names=FALSE)
print(summary)
print(cell[order(-abs(cell$delta_nll_cauchy_minus_cosine)),])
