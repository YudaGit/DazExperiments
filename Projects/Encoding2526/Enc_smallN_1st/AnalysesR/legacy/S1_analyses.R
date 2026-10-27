# First laboratory study: reproducible analysis tables from the cleaned trials.
# Usage: Rscript Enc_smallN_1st/AnalysesR/S1_analyses.R [--skip-descriptives]
# Run from the project root or AnalysesR. Existing Stan fits are read, never
# silently refitted. Model specification and confirmatory contrasts remain open.

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

locate_analysis_dir <- function() {
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  script_dir <- if (length(file_arg)) dirname(sub("^--file=", "", file_arg[1])) else character()
  candidates <- unique(c(script_dir, getwd(),
                         file.path(getwd(), "Enc_smallN_1st", "AnalysesR")))
  candidates <- candidates[file.exists(file.path(candidates, "S1_smallN_model_ready.csv"))]
  if (!length(candidates)) stop("Cannot locate S1_smallN_model_ready.csv")
  normalizePath(candidates[1], mustWork = TRUE)
}

validate_trials <- function(d) {
  required <- c("ID", "Session", "CueType", "Duration_ms", "SignedErr", "RT")
  if (!all(required %in% names(d)) || anyNA(d[, required]))
    stop("Missing required columns or values in model-ready trials")
  if (!setequal(unique(d$ID), c("AQ", "HC", "YILIU", "YDL")) ||
      !setequal(unique(d$Session), 1:10) ||
      !setequal(unique(d$CueType), c("NR", "R")) ||
      !setequal(unique(d$Duration_ms), seq(50, 350, 50)))
    stop("Participant or design levels differ from the expected Study 1 design")
  if (any(d$RT < 300 | d$RT > 3000) || any(!is.finite(d$SignedErr)))
    stop("Preplanned RT filter or finite signed-error check failed")
  counts <- d %>% count(ID, Session, CueType, Duration_ms)
  if (nrow(counts) != 4 * 10 * 2 * 7 || any(counts$n == 0))
    stop("One or more participant-session-condition cells are absent")
  invisible(counts)
}

log_vm0 <- function(theta, kappa) {
  log_i0 <- log(max(besselI(kappa, 0, expon.scaled = TRUE),
                    .Machine$double.xmin)) + kappa
  kappa * cos(theta) - log(2 * pi) - log_i0
}

fit_kappa_vm <- function(theta) {
  if (length(theta) <= 20 || any(!is.finite(theta)))
    stop("Von Mises cell has insufficient or nonfinite observations")
  nll <- function(log_k) {
    k <- exp(log_k)
    if (!is.finite(k) || k < 1e-6 || k > 5000) return(1e12)
    -sum(log_vm0(theta, k))
  }
  fits <- lapply(log(c(1, 2, 4, 8, 16, 32)), function(start) {
    tryCatch(optim(start, nll, method = "BFGS",
                   control = list(maxit = 1000, reltol = 1e-12)),
             error = function(e) NULL)
  })
  fits <- Filter(function(x) !is.null(x) && x$convergence == 0 &&
                   is.finite(x$value), fits)
  if (!length(fits)) stop("Von Mises optimization failed")
  best <- fits[[which.min(vapply(fits, `[[`, numeric(1), "value"))]]
  list(kappa = exp(best$par), logLik = -best$value, n = length(theta))
}

simple_vm_tables <- function(d) {
  d$theta <- atan2(sin(d$SignedErr * pi / 180),
                   cos(d$SignedErr * pi / 180))
  param_rows <- list()
  comparison_rows <- list()
  for (raw in c("AQ", "HC", "YILIU", "YDL")) {
    sub <- d[d$ID == raw, ]
    log_lik <- c(`14k` = 0, `2k` = 0)
    for (cue in c("NR", "R")) {
      for (dur in seq(50, 350, 50)) {
        fit <- fit_kappa_vm(sub$theta[sub$CueType == cue & sub$Duration_ms == dur])
        log_lik["14k"] <- log_lik["14k"] + fit$logLik
        param_rows[[length(param_rows) + 1L]] <- tibble(
          ID = raw, model = "14k", CueType = cue, Duration_ms = dur,
          n_trials = fit$n, kappa = fit$kappa, logLik_cell = fit$logLik)
      }
      fit <- fit_kappa_vm(sub$theta[sub$CueType == cue])
      log_lik["2k"] <- log_lik["2k"] + fit$logLik
      param_rows[[length(param_rows) + 1L]] <- tibble(
        ID = raw, model = "2k", CueType = cue, Duration_ms = NA_real_,
        n_trials = fit$n, kappa = fit$kappa, logLik_cell = fit$logLik)
    }
    bic_14 <- -2 * log_lik["14k"] + 14 * log(nrow(sub))
    bic_2 <- -2 * log_lik["2k"] + 2 * log(nrow(sub))
    comparison_rows[[length(comparison_rows) + 1L]] <- tibble(
      ID = raw, n_trials = nrow(sub), logLik_14k = unname(log_lik["14k"]),
      logLik_2k = unname(log_lik["2k"]), BIC_14k = unname(bic_14),
      BIC_2k = unname(bic_2), delta_BIC_14_minus_2 = unname(bic_14 - bic_2),
      BIC_winner = if (bic_14 < bic_2) "14k" else "2k")
  }
  list(parameters = bind_rows(param_rows), comparison = bind_rows(comparison_rows))
}

cached_stan_table <- function(cache_dir, d) {
  rows <- list()
  for (raw in c("AQ", "HC", "YILIU", "YDL")) {
    for (level in c("L0", "L1", "L2")) {
      for (ks in c("2k", "14k")) {
        path <- file.path(cache_dir, "vm_stan",
                          paste0(raw, "_", level, "_", ks), "fit_meta.rds")
        if (!file.exists(path)) stop("Missing Stan cache: ", path)
        fit <- readRDS(path)
        if (fit$raw_id != raw || fit$level != level || fit$kappa_struct != ks)
          stop("Stan cache metadata mismatch: ", path)
        if (is.null(fit$loo) || is.null(fit$summary))
          stop("Stan cache lacks LOO or summary: ", path)
        if (length(fit$loo$diagnostics$pareto_k) != sum(d$ID == raw))
          stop("Stan log-likelihood trial count differs from current CSV: ", path)
        k <- fit$loo$diagnostics$pareto_k
        rhats <- fit$summary$rhat
        rows[[length(rows) + 1L]] <- tibble(
          ID = raw, level = level, kappa_struct = ks,
          model_id = paste0(level, "_", ks), n_trials = sum(d$ID == raw),
          elpd_loo = fit$loo$estimates["elpd_loo", "Estimate"],
          se_elpd_loo = fit$loo$estimates["elpd_loo", "SE"],
          p_loo = fit$loo$estimates["p_loo", "Estimate"],
          pareto_k_gt_0_7 = sum(k > 0.7, na.rm = TRUE),
          pareto_k_gt_1 = sum(k > 1, na.rm = TRUE),
          max_pareto_k = max(k, na.rm = TRUE),
          max_rhat = max(rhats, na.rm = TRUE),
          min_ess_bulk = min(fit$summary$ess_bulk, na.rm = TRUE))
      }
    }
  }
  bind_rows(rows) %>% group_by(ID) %>%
    mutate(delta_elpd_from_best = max(elpd_loo) - elpd_loo) %>% ungroup()
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  if (any(!args %in% "--skip-descriptives"))
    stop("Only supported option: --skip-descriptives")
  analysis_dir <- locate_analysis_dir()
  old_dir <- getwd()
  on.exit(setwd(old_dir), add = TRUE)
  setwd(analysis_dir)
  if (!"--skip-descriptives" %in% args)
    source("s1_descriptives.R", local = new.env(parent = globalenv()))
  d <- read_csv("S1_smallN_model_ready.csv", show_col_types = FALSE)
  validate_trials(d)
  out_dir <- file.path("bayes_primary_discrete", "current_review")
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  vm <- simple_vm_tables(d)
  write_csv(vm$parameters, file.path(out_dir, "simple_vm_parameters.csv"))
  write_csv(vm$comparison, file.path(out_dir, "simple_vm_bic.csv"))
  stan <- cached_stan_table("bayes_primary_discrete", d)
  write_csv(stan, file.path(out_dir, "stan_cache_comparison_diagnostics.csv"))
  cat("Validated", nrow(d), "trials; reviewed", nrow(stan), "Stan caches.\n")
  cat("Analysis review tables:", normalizePath(out_dir), "\n")
  if (any(stan$pareto_k_gt_0_7 > 0 | stan$max_rhat > 1.01))
    cat("Some cached fits need diagnostic review before publication claims.\n")
}

if (sys.nframe() == 0L) main()
