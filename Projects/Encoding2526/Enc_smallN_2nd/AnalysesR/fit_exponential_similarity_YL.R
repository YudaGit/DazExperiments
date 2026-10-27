# Exploratory test of an exponential decision-similarity signal. Its falloff
# is estimated from YL data because the published curve used a different wheel.
# Run from the Encoding2526 root.
source("Enc_smallN_2nd/AnalysesR/cauchy_model.R")
source("Enc_smallN_2nd/AnalysesR/awss_runner.R")
out <- "Enc_smallN_2nd/AnalysesR/results/YL"
trials <- read.csv("Enc_smallN_2nd/Daz25EncodingData/PreliminaryReview/YL_model_trials.csv")
previous <- readRDS(file.path(out,"cauchy_awss_cosine_decision_20starts.rds"))

fit <- fit_awss_cells(trials,model="cauchy",decision_signal="exponential",
                      n=360L,n_starts=20L,seed=20261013L,
                      maxit=3000L,factr=1e5,pgtol=1e-7,ndeps=1e-5,
                      selection="prefer_R",state_by_duration=FALSE,
                      selection_by_duration=TRUE,previous_fit=previous)
saveRDS(fit,file.path(out,"cauchy_awss_exponential_decision_20starts.rds"))

baseline <- previous
comparison <- data.frame(
  signal=c("cosine","exponential"),
  negative_ll=c(baseline$total_negative_ll,fit$total_negative_ll),
  parameter_count=c(baseline$parameter_count,fit$parameter_count),
  trial_count=c(baseline$trial_count,fit$trial_count),
  sensitivity=c(baseline$shared_value,fit$shared_value),
  similarity_decay_per_radian=c(NA_real_,fit$similarity_decay))
comparison$BIC <- with(comparison,
                       2*negative_ll+parameter_count*log(trial_count))
write.csv(comparison,file.path(out,"cauchy_exponential_similarity_comparison.csv"),
          row.names=FALSE)
print(comparison)
cat("Converged starts:",sum(fit$starts$convergence==0),"of 20\n")
cat("Best within 0.01 NLL:",
    sum(abs(fit$starts$negative_ll-fit$total_negative_ll)<.01),"of 20\n")
print(fit$state_parameters)
