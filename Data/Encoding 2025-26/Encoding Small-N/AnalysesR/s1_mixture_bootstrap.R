# Bootstrap CIs for mixture-regression contrasts + linear duration trends
# Warm-start nonparametric case bootstrap within participant.

S1_MIXTURE_SOURCE_ONLY <- TRUE
suppressPackageStartupMessages({
  library(tidyverse)
  library(parallel)
})

setwd("/Users/prefabteam_ysl/Documents/GitHub/DazExperiments/Data/Encoding 2025-26/Encoding Small-N/AnalysesR")
source("s1_mixture_regression.R")
dir.create("mixture_regression", showWarnings = FALSE)
set.seed(20260722)

linear_duration_weights <- c(-3, -2, -1, 0, 1, 2, 3)
duration_levels <- c(
  "50ms", "100ms", "150ms", "200ms", "250ms", "300ms", "350ms"
)

# ---------------------------------------------------------------------------
# Contrast extractor (point estimate from a fitted object)
# ---------------------------------------------------------------------------

extract_contrast_vector <- function(fit) {
  early_z <- fit$prep_meta$early_z
  late_z <- fit$prep_meta$late_z

  getp <- function(cue, dur, sz, wh) {
    param_at(fit, cue, dur, sz, wh)(fit$par)
  }

  linear_trend <- function(cue, wh, sz = 0) {
    vals <- vapply(
      duration_levels,
      function(d) getp(cue, d, sz, wh),
      numeric(1)
    )
    sum(linear_duration_weights * vals)
  }

  out <- list()

  for (wh in c("kappa", "gamma", "beta")) {
    out[[paste0("gain50_", wh, "_NR_minus_R")]] <-
      getp("NR", "50ms", 0, wh) - getp("R", "50ms", 0, wh)
  }

  for (cue in c("NR", "R")) {
    for (wh in c("kappa", "gamma", "beta")) {
      out[[paste0(cue, "_350_minus_50_", wh)]] <-
        getp(cue, "350ms", 0, wh) - getp(cue, "50ms", 0, wh)
      out[[paste0(cue, "_linear_trend_", wh)]] <- linear_trend(cue, wh, 0)
    }
  }

  # Catch-up average: kappa = NRΔ - RΔ; gamma/beta = RΔ - NRΔ
  # (positive gamma/beta catch-up = NR failure rate fell more)
  for (wh in c("kappa")) {
    out[[paste0("catchup_average_", wh)]] <-
      (getp("NR", "350ms", 0, wh) - getp("NR", "50ms", 0, wh)) -
      (getp("R", "350ms", 0, wh) - getp("R", "50ms", 0, wh))
  }
  for (wh in c("gamma", "beta")) {
    out[[paste0("catchup_average_", wh)]] <-
      (getp("R", "350ms", 0, wh) - getp("R", "50ms", 0, wh)) -
      (getp("NR", "350ms", 0, wh) - getp("NR", "50ms", 0, wh))
  }

  for (slice in c("early", "late")) {
    sz <- if (slice == "early") early_z else late_z
    out[[paste0("catchup_", slice, "_kappa")]] <-
      (getp("NR", "350ms", sz, "kappa") - getp("NR", "50ms", sz, "kappa")) -
      (getp("R", "350ms", sz, "kappa") - getp("R", "50ms", sz, "kappa"))
    for (wh in c("gamma", "beta")) {
      out[[paste0("catchup_", slice, "_", wh)]] <-
        (getp("R", "350ms", sz, wh) - getp("R", "50ms", sz, wh)) -
        (getp("NR", "350ms", sz, wh) - getp("NR", "50ms", sz, wh))
    }
  }

  for (cue in c("NR", "R")) {
    for (wh in c("kappa", "gamma", "beta")) {
      early_eff <- getp(cue, "350ms", early_z, wh) - getp(cue, "50ms", early_z, wh)
      late_eff <- getp(cue, "350ms", late_z, wh) - getp(cue, "50ms", late_z, wh)
      out[[paste0(cue, "_practice_durEffect_", wh)]] <- late_eff - early_eff
    }
  }

  # Duration-series at average session (for trend diagnostics)
  for (cue in c("NR", "R")) {
    for (wh in c("kappa", "gamma", "beta")) {
      for (d in duration_levels) {
        out[[paste0(cue, "_", d, "_", wh)]] <- getp(cue, d, 0, wh)
      }
    }
  }

  unlist(out)
}

# ---------------------------------------------------------------------------
# One bootstrap replicate: resample trials, warm-start optimise, extract
# ---------------------------------------------------------------------------

bootstrap_one <- function(d_sub, fit_mle, maxit = 80) {
  n <- nrow(d_sub)
  boot_idx <- sample.int(n, n, replace = TRUE)
  d_boot <- d_sub[boot_idx, , drop = FALSE]

  prep <- prepare_participant_data(d_boot)
  # Align design columns with MLE (rare missing cols if a level drops out)
  X <- prep$X
  missing <- setdiff(fit_mle$coef_names, colnames(X))
  if (length(missing) > 0) {
    # A duration/cue level vanished in the bootstrap sample — skip replicate
    return(NULL)
  }
  X <- X[, fit_mle$coef_names, drop = FALSE]
  prep$X <- X

  fit_boot <- tryCatch(
    optim(
      par = fit_mle$par,
      fn = negloglik_participant_fast,
      prep = prep,
      method = "BFGS",
      control = list(maxit = maxit, reltol = 1e-7)
    ),
    error = function(e) NULL
  )
  if (is.null(fit_boot) || !is.finite(fit_boot$value)) return(NULL)

  fit_tmp <- fit_mle
  fit_tmp$par <- fit_boot$par
  tryCatch(extract_contrast_vector(fit_tmp), error = function(e) NULL)
}

bootstrap_participant <- function(d_sub, fit_mle, B = 80, maxit = 80, n_cores = 4) {
  message(
    "Bootstrap ", fit_mle$ID, ": B = ", B,
    ", maxit = ", maxit, ", cores = ", n_cores
  )

  point <- extract_contrast_vector(fit_mle)

  boot_list <- mclapply(seq_len(B), function(b) {
    set.seed(20260722 + b * 1009 + sum(utf8ToInt(fit_mle$ID)))
    if (b %% 10 == 0) message("  ", fit_mle$ID, " boot ", b, "/", B)
    bootstrap_one(d_sub, fit_mle, maxit = maxit)
  }, mc.cores = n_cores)

  ok <- Filter(Negate(is.null), boot_list)
  message("  kept ", length(ok), "/", B, " replicates")
  if (length(ok) < 20) {
    warning("Few successful bootstrap replicates for ", fit_mle$ID)
  }

  boot_mat <- do.call(rbind, ok)
  # Align columns
  common <- Reduce(intersect, list(names(point), colnames(boot_mat)))
  boot_mat <- boot_mat[, common, drop = FALSE]
  point <- point[common]

  tibble(
    ID = fit_mle$ID,
    effect = common,
    estimate = as.numeric(point),
    boot_mean = colMeans(boot_mat, na.rm = TRUE),
    boot_se = apply(boot_mat, 2, sd, na.rm = TRUE),
    lower = apply(boot_mat, 2, quantile, probs = 0.025, na.rm = TRUE),
    upper = apply(boot_mat, 2, quantile, probs = 0.975, na.rm = TRUE),
    n_boot = nrow(boot_mat)
  )
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

d <- read_csv("S1_smallN_model_ready.csv", show_col_types = FALSE)
fits <- readRDS("mixture_regression/all_fits.rds")
participants <- c("AQ", "HC", "YILIU")

n_cores_detected <- suppressWarnings(parallel::detectCores())
if (is.na(n_cores_detected) || n_cores_detected < 1) n_cores_detected <- 4
n_cores <- max(1, min(4, as.integer(n_cores_detected)))
B <- 60
maxit <- 45
message("Using n_cores = ", n_cores)

boot_tbl <- bind_rows(lapply(participants, function(pid) {
  out_file <- file.path("mixture_regression", paste0("boot_", pid, ".rds"))
  if (file.exists(out_file)) {
    message("Loading existing bootstrap: ", out_file)
    return(readRDS(out_file))
  }
  d_sub <- d %>% filter(ID == pid)
  res <- bootstrap_participant(
    d_sub, fits[[pid]],
    B = B, maxit = maxit, n_cores = n_cores
  )
  saveRDS(res, out_file)
  res
}))

write_csv(boot_tbl, "mixture_regression/bootstrap_contrasts.csv")

# Focus tables
theory_boot <- boot_tbl %>%
  filter(
    grepl(
      "gain50_|350_minus_50_|linear_trend_|catchup_average_|catchup_early_|catchup_late_|practice_durEffect_",
      effect
    )
  ) %>%
  mutate(
    parameter = case_when(
      grepl("_kappa", effect) ~ "kappa",
      grepl("_gamma", effect) ~ "gamma",
      grepl("_beta", effect) ~ "beta",
      TRUE ~ "other"
    ),
    excludes_0 = (lower > 0 & upper > 0) | (lower < 0 & upper < 0)
  )

write_csv(theory_boot, "mixture_regression/bootstrap_theory_focus.csv")

# Duration series with bootstrap CIs for kappa/gamma/beta
series_boot <- boot_tbl %>%
  filter(grepl("_(50|100|150|200|250|300|350)ms_(kappa|gamma|beta)$", effect)) %>%
  tidyr::extract(
    effect,
    into = c("CueType", "DurationF", "parameter"),
    regex = "^(NR|R)_(.+)_(kappa|gamma|beta)$",
    remove = FALSE
  ) %>%
  mutate(
    Duration_ms = as.numeric(gsub("ms", "", DurationF))
  )

write_csv(series_boot, "mixture_regression/bootstrap_duration_series.csv")

cat("\n===== Linear duration trends (average session) =====\n")
print(as.data.frame(
  theory_boot %>%
    filter(grepl("linear_trend_", effect)) %>%
    select(ID, effect, estimate, lower, upper, excludes_0) %>%
    arrange(effect, ID)
), digits = 3)

cat("\n===== 350-50 contrasts =====\n")
print(as.data.frame(
  theory_boot %>%
    filter(grepl("350_minus_50_", effect)) %>%
    select(ID, effect, estimate, lower, upper, excludes_0) %>%
    arrange(effect, ID)
), digits = 3)

cat("\n===== Gain / catch-up / practice =====\n")
print(as.data.frame(
  theory_boot %>%
    filter(grepl("gain50_|catchup_average_|practice_durEffect_", effect)) %>%
    select(ID, effect, estimate, lower, upper, excludes_0) %>%
    arrange(effect, ID)
), digits = 3)

cat("\nDONE\n")
