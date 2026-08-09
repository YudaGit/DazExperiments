# Experiment 1: participant-level regression ML circular mixture models
# Components: target von Mises + colour swap + uniform guess
# Predictors: CueType * DurationF * Session_z  (parallel to AbsErr primary)

suppressPackageStartupMessages({
  library(tidyverse)
})

setwd("/Users/prefabteam_ysl/Documents/GitHub/DazExperiments/Data/Encoding 2025-26/Encoding Small-N/AnalysesR")
dir.create("mixture_regression", showWarnings = FALSE, recursive = TRUE)
set.seed(1234)

# ---------------------------------------------------------------------------
# Circular helpers
# ---------------------------------------------------------------------------

wrap_pi <- function(x) atan2(sin(x), cos(x))
deg2rad <- function(x) x * pi / 180
rad2deg <- function(x) x * 180 / pi

log_sum_exp <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) == 0) return(-Inf)
  m <- max(x)
  m + log(sum(exp(x - m)))
}

# Stable log von Mises density on (-pi, pi]. Vectorised over x / mu / kappa.
log_dvm <- function(x, mu, kappa) {
  # besselI(..., expon.scaled=TRUE) returns I0(k)*exp(-k)
  log_i0 <- log(pmax(besselI(kappa, 0, expon.scaled = TRUE), .Machine$double.xmin)) + kappa
  kappa * cos(x - mu) - log(2 * pi) - log_i0
}

# Circular SD (radians) from kappa: sqrt(-2 log(I1/I0))
circ_sd_from_kappa <- function(kappa) {
  a <- pmax(
    besselI(kappa, 1, expon.scaled = TRUE) /
      pmax(besselI(kappa, 0, expon.scaled = TRUE), .Machine$double.xmin),
    1e-12
  )
  a <- pmin(a, 1 - 1e-12)
  sqrt(-2 * log(a))
}

# Unique non-target colour centres as expected SignedErr if that colour were reported.
# SignedErr convention in this dataset: TargetHue - ResponseHue (wrapped).
swap_centers_rad <- function(target_hue_deg, item_hues_deg) {
  unique_hues <- unique(as.numeric(item_hues_deg))
  nt <- unique_hues[abs(wrap_pi(deg2rad(unique_hues - target_hue_deg))) > 1e-8]
  if (length(nt) == 0) return(numeric(0))
  wrap_pi(deg2rad(target_hue_deg - nt))
}

# ---------------------------------------------------------------------------
# Trial-level mixture log-likelihood
# ---------------------------------------------------------------------------

trial_mixture_ll <- function(theta, gamma, beta, kappa, swap_mus) {
  gamma <- min(max(gamma, 1e-10), 1 - 1e-10)
  beta <- min(max(beta, 1e-10), 1 - gamma - 1e-10)
  p_target <- 1 - gamma - beta
  kappa <- max(kappa, 1e-6)

  terms <- c(
    log(p_target) + log_dvm(theta, 0, kappa),
    log(gamma) - log(2 * pi)
  )

  if (length(swap_mus) > 0 && beta > 1e-12) {
    swap_term <- log(beta) +
      log_sum_exp(vapply(swap_mus, function(mu) log_dvm(theta, mu, kappa), numeric(1))) -
      log(length(swap_mus))
    terms <- c(terms, swap_term)
  }

  log_sum_exp(terms)
}

# ---------------------------------------------------------------------------
# Design / parameter mapping
# ---------------------------------------------------------------------------

mixture_formula <- ~ CueType * DurationF * Session_z

pack_coef <- function(b_kappa, b_gamma, b_beta) {
  c(b_kappa, b_gamma, b_beta)
}

unpack_coef <- function(par, n_coef) {
  list(
    b_kappa = par[seq_len(n_coef)],
    b_gamma = par[n_coef + seq_len(n_coef)],
    b_beta = par[2 * n_coef + seq_len(n_coef)]
  )
}

predict_mixture_params <- function(X, par) {
  n_coef <- ncol(X)
  coefs <- unpack_coef(par, n_coef)
  log_kappa <- as.numeric(X %*% coefs$b_kappa)
  eta_gamma <- as.numeric(X %*% coefs$b_gamma)
  eta_beta <- as.numeric(X %*% coefs$b_beta)

  gamma <- plogis(eta_gamma)
  beta <- plogis(eta_beta) * (1 - gamma)
  kappa <- exp(pmin(pmax(log_kappa, -2), 8)) # keep kappa in ~[0.14, 2980]

  tibble(
    kappa = kappa,
    gamma = gamma,
    beta = beta,
    p_target = 1 - gamma - beta,
    log_kappa = log(kappa),
    circSD_deg = rad2deg(circ_sd_from_kappa(kappa))
  )
}

# ---------------------------------------------------------------------------
# Negative log-likelihood for one participant
# ---------------------------------------------------------------------------

prepare_participant_data <- function(d_sub) {
  item_mat <- as.matrix(d_sub[, paste0("ItemHue", 1:6)])
  n <- nrow(d_sub)
  # Store up to 3 unique non-target centres (design always has 4 unique hues).
  swap_mat <- matrix(NA_real_, nrow = n, ncol = 3)
  n_swap <- integer(n)

  for (i in seq_len(n)) {
    mus <- swap_centers_rad(d_sub$TargetHue[i], item_mat[i, ])
    n_swap[i] <- length(mus)
    if (length(mus) > 0) {
      swap_mat[i, seq_along(mus)] <- mus
    }
  }

  d_sub <- d_sub %>%
    mutate(
      CueType = factor(CueType, levels = c("NR", "R")),
      DurationF = factor(Duration, levels = c(
        "50ms", "100ms", "150ms", "200ms", "250ms", "300ms", "350ms"
      )),
      theta = wrap_pi(deg2rad(SignedErr))
    )

  X <- model.matrix(mixture_formula, data = d_sub)
  list(
    d = d_sub,
    X = X,
    swap_mat = swap_mat,
    n_swap = n_swap,
    theta = d_sub$theta
  )
}

negloglik_participant <- function(par, prep) {
  params <- predict_mixture_params(prep$X, par)
  if (any(!is.finite(params$kappa)) ||
      any(params$gamma < 0 | params$gamma > 1) ||
      any(params$beta < 0) ||
      any(params$p_target < 0)) {
    return(1e12)
  }

  ll <- 0
  for (i in seq_along(prep$theta)) {
    ll_i <- trial_mixture_ll(
      prep$theta[i],
      params$gamma[i],
      params$beta[i],
      params$kappa[i],
      prep$swap_list[[i]]
    )
    if (!is.finite(ll_i)) return(1e12)
    ll <- ll + ll_i
  }
  -ll
}

# NLL with vectorised target/guess terms; swap uses precomputed centre matrix.
negloglik_participant_fast <- function(par, prep) {
  params <- predict_mixture_params(prep$X, par)
  kappa <- params$kappa
  gamma <- pmin(pmax(params$gamma, 1e-10), 1 - 1e-10)
  beta <- pmin(pmax(params$beta, 1e-10), 1 - gamma - 1e-10)
  p_target <- 1 - gamma - beta
  theta <- prep$theta
  n <- length(theta)

  if (any(!is.finite(kappa)) || any(p_target <= 0)) {
    return(1e12)
  }

  log_target <- log(p_target) + log_dvm(theta, 0, kappa)
  log_guess <- log(gamma) - log(2 * pi)

  # Swap: average VM density over available non-target centres
  log_swap <- rep(-Inf, n)
  for (j in seq_len(ncol(prep$swap_mat))) {
    mu_j <- prep$swap_mat[, j]
    ok <- is.finite(mu_j)
    if (!any(ok)) next
    # contribution for trials that have this centre slot filled
    log_swap_j <- log_dvm(theta[ok], mu_j[ok], kappa[ok])
    # accumulate in linear space via running log-sum-exp across j
    # initialise / update only for ok trials
    idx <- which(ok)
    fresh <- !is.finite(log_swap[idx])
    if (any(fresh)) {
      log_swap[idx[fresh]] <- log_swap_j[fresh]
    }
    if (any(!fresh)) {
      old <- log_swap[idx[!fresh]]
      new <- log_swap_j[!fresh]
      m <- pmax(old, new)
      log_swap[idx[!fresh]] <- m + log(exp(old - m) + exp(new - m))
    }
  }
  has_swap <- prep$n_swap > 0
  log_swap[has_swap] <- log(beta[has_swap]) + log_swap[has_swap] - log(prep$n_swap[has_swap])

  m <- pmax(log_target, log_guess, log_swap)
  # For trials with no swap centres, ignore -Inf swap term
  exp_swap <- ifelse(is.finite(log_swap), exp(log_swap - m), 0)
  ll <- m + log(exp(log_target - m) + exp(log_guess - m) + exp_swap)
  if (any(!is.finite(ll))) return(1e12)
  -sum(ll)
}

# ---------------------------------------------------------------------------
# Starting values
# ---------------------------------------------------------------------------

start_from_moments <- function(prep) {
  n_coef <- ncol(prep$X)
  # Rough guess: mostly target-centered, modest guess/swap, moderate kappa
  b_kappa <- rep(0, n_coef)
  b_gamma <- rep(0, n_coef)
  b_beta <- rep(0, n_coef)
  names(b_kappa) <- colnames(prep$X)
  names(b_gamma) <- colnames(prep$X)
  names(b_beta) <- colnames(prep$X)

  # Intercept: kappa ~ 4, gamma ~ 0.15, beta|not-guess ~ 0.20
  b_kappa["(Intercept)"] <- log(4)
  b_gamma["(Intercept)"] <- qlogis(0.15)
  b_beta["(Intercept)"] <- qlogis(0.20)

  pack_coef(b_kappa, b_gamma, b_beta)
}

random_start <- function(prep, scale = 0.35) {
  par0 <- start_from_moments(prep)
  par0 + rnorm(length(par0), 0, scale)
}

# ---------------------------------------------------------------------------
# Fit one participant
# ---------------------------------------------------------------------------

fit_mixture_regression <- function(d_sub, participant,
                                   n_starts = 3,
                                   maxit = 400,
                                   force_refit = FALSE) {
  out_file <- file.path("mixture_regression", paste0("m_", participant, "_mixreg.rds"))
  if (!force_refit && file.exists(out_file)) {
    message("Loading saved fit: ", out_file)
    return(readRDS(out_file))
  }

  message("Preparing data for ", participant, " ...")
  prep <- prepare_participant_data(d_sub)
  n_coef <- ncol(prep$X)
  message(
    "  trials = ", nrow(prep$d),
    " ; coefs/param = ", n_coef,
    " ; total free = ", 3 * n_coef
  )

  # Stage 1: intercept-only warm start (fast)
  message("  stage 1: intercept-only warm start")
  par0 <- start_from_moments(prep)
  nll0 <- negloglik_participant_fast(par0, prep)
  message("    initial NLL = ", round(nll0, 2))

  intercept_cols <- which(colnames(prep$X) == "(Intercept)")
  free_idx <- c(
    intercept_cols,
    n_coef + intercept_cols,
    2 * n_coef + intercept_cols
  )

  stage1 <- optim(
    par = par0[free_idx],
    fn = function(p_free) {
      par <- par0
      par[free_idx] <- p_free
      negloglik_participant_fast(par, prep)
    },
    method = "BFGS",
    control = list(maxit = 150, reltol = 1e-8)
  )
  par0[free_idx] <- stage1$par
  message("    stage-1 NLL = ", round(stage1$value, 2))

  # Stage 2: full model from warm start + a couple of random starts
  starts <- list(par0)
  for (s in seq_len(max(0, n_starts - 1))) {
    starts[[s + 1]] <- par0 + rnorm(length(par0), 0, 0.15)
  }

  best <- NULL
  for (s in seq_along(starts)) {
    message("  stage 2 start ", s, "/", length(starts))
    fit <- tryCatch(
      optim(
        par = starts[[s]],
        fn = negloglik_participant_fast,
        prep = prep,
        method = "BFGS",
        control = list(maxit = maxit, reltol = 1e-9)
      ),
      error = function(e) {
        message("    optim error: ", conditionMessage(e))
        NULL
      }
    )
    if (is.null(fit)) next
    message("    NLL = ", round(fit$value, 2), " ; conv = ", fit$convergence)
    if (is.null(best) || fit$value < best$value) {
      best <- fit
      best$start_id <- s
    }
  }

  if (is.null(best)) {
    stop("All optim starts failed for ", participant)
  }

  # Full numerical Hessian is O(p^2) and slow for p=84; skip by default.
  # Contrasts still return point estimates; SEs are NA unless compute_vcov=TRUE.
  vcov_mat <- NULL
  if (isTRUE(getOption("s1.mixture_vcov", FALSE))) {
    message("  computing Hessian (slow) ...")
    hess <- tryCatch(
      optimHess(best$par, negloglik_participant_fast, prep = prep),
      error = function(e) NULL
    )
    if (!is.null(hess)) {
      vcov_mat <- tryCatch(solve(hess), error = function(e) NULL)
    }
  } else {
    message("  skipping Hessian (set options(s1.mixture_vcov=TRUE) for SEs)")
  }

  result <- list(
    ID = participant,
    par = best$par,
    nll = best$value,
    convergence = best$convergence,
    start_id = best$start_id,
    n_coef = n_coef,
    coef_names = colnames(prep$X),
    formula = mixture_formula,
    vcov = vcov_mat,
    n_trials = nrow(prep$d),
    prep_meta = list(
      early_z = mean(unique(prep$d$Session_z[prep$d$Session %in% c(1, 2)])),
      late_z = mean(unique(prep$d$Session_z[prep$d$Session %in% c(9, 10)]))
    )
  )
  class(result) <- c("s1_mixreg", class(result))
  saveRDS(result, out_file)
  message("Saved: ", out_file, " ; NLL = ", round(best$value, 2))
  result
}

# ---------------------------------------------------------------------------
# Predict / contrasts
# ---------------------------------------------------------------------------

newdata_grid <- function(session_z_vals = 0) {
  expand_grid(
    CueType = factor(c("NR", "R"), levels = c("NR", "R")),
    DurationF = factor(
      c("50ms", "100ms", "150ms", "200ms", "250ms", "300ms", "350ms"),
      levels = c("50ms", "100ms", "150ms", "200ms", "250ms", "300ms", "350ms")
    ),
    Session_z = session_z_vals
  )
}

predict_mixreg <- function(fit, newdata = NULL, session_z = 0) {
  if (is.null(newdata)) {
    newdata <- newdata_grid(session_z)
  }
  X <- model.matrix(fit$formula, data = newdata)
  # align columns if needed
  missing <- setdiff(fit$coef_names, colnames(X))
  if (length(missing)) {
    for (m in missing) X <- cbind(X, setNames(rep(0, nrow(X)), m))
  }
  X <- X[, fit$coef_names, drop = FALSE]
  params <- predict_mixture_params(X, fit$par)
  bind_cols(newdata, params)
}

# Delta-method SE for a scalar function of parameters via numerical gradient
contrast_estimate <- function(fit, fun) {
  est <- fun(fit$par)
  se <- NA_real_
  if (!is.null(fit$vcov)) {
    g <- tryCatch({
      eps <- 1e-5
      v <- numeric(length(fit$par))
      for (j in seq_along(fit$par)) {
        p1 <- fit$par
        p2 <- fit$par
        p1[j] <- p1[j] + eps
        p2[j] <- p2[j] - eps
        v[j] <- (fun(p1) - fun(p2)) / (2 * eps)
      }
      v
    }, error = function(e) rep(NA_real_, length(fit$par)))
    if (all(is.finite(g))) {
      se <- sqrt(max(0, as.numeric(t(g) %*% fit$vcov %*% g)))
    }
  }
  tibble(
    estimate = est,
    se = se,
    lower = est - 1.96 * se,
    upper = est + 1.96 * se
  )
}

param_at <- function(fit, cue, duration, session_z, which = c("kappa", "gamma", "beta", "log_kappa")) {
  which <- match.arg(which)
  nd <- tibble(
    CueType = factor(cue, levels = c("NR", "R")),
    DurationF = factor(
      duration,
      levels = c("50ms", "100ms", "150ms", "200ms", "250ms", "300ms", "350ms")
    ),
    Session_z = session_z
  )
  X <- model.matrix(fit$formula, data = nd)
  missing <- setdiff(fit$coef_names, colnames(X))
  if (length(missing)) {
    for (m in missing) X <- cbind(X, setNames(rep(0, nrow(X)), m))
  }
  X <- X[, fit$coef_names, drop = FALSE]
  function(par) {
    p <- predict_mixture_params(X, par)
    as.numeric(p[[which]][1])
  }
}

participant_mixture_contrasts <- function(fit) {
  early_z <- fit$prep_meta$early_z
  late_z <- fit$prep_meta$late_z
  pid <- fit$ID

  make_row <- function(effect, which, fun) {
    contrast_estimate(fit, fun) %>%
      mutate(ID = pid, effect = effect, parameter = which)
  }

  rows <- list()

  # Redundancy advantage at 50 ms (average session): NR - R on each param
  for (wh in c("kappa", "gamma", "beta")) {
    f_nr <- param_at(fit, "NR", "50ms", 0, wh)
    f_r <- param_at(fit, "R", "50ms", 0, wh)
    rows[[length(rows) + 1]] <- make_row(
      paste0("gain50_", wh, "_NR_minus_R"),
      wh,
      function(par) f_nr(par) - f_r(par)
    )
  }

  # Duration change 350 - 50 by cue at average session
  for (cue in c("NR", "R")) {
    for (wh in c("kappa", "gamma", "beta", "log_kappa")) {
      f50 <- param_at(fit, cue, "50ms", 0, wh)
      f350 <- param_at(fit, cue, "350ms", 0, wh)
      rows[[length(rows) + 1]] <- make_row(
        paste0(cue, "_350_minus_50_", wh),
        wh,
        function(par) f350(par) - f50(par)
      )
    }
  }

  # Catch-up on each parameter: (NR change) - (R change) for 50->350
  # Positive catch-up for kappa = NR improved more (larger kappa increase)
  # Positive catch-up for gamma/beta = NR decreased less / increased more (bad)
  # For error-like params, define catchup as (R_change) - (NR_change) for gamma/beta
  # so positive = NR improved more (larger decrease), matching AbsErr convention.
  for (wh in c("kappa", "log_kappa")) {
    f_nr50 <- param_at(fit, "NR", "50ms", 0, wh)
    f_nr350 <- param_at(fit, "NR", "350ms", 0, wh)
    f_r50 <- param_at(fit, "R", "50ms", 0, wh)
    f_r350 <- param_at(fit, "R", "350ms", 0, wh)
    rows[[length(rows) + 1]] <- make_row(
      paste0("catchup_average_", wh),
      wh,
      function(par) (f_nr350(par) - f_nr50(par)) - (f_r350(par) - f_r50(par))
    )
  }
  for (wh in c("gamma", "beta")) {
    f_nr50 <- param_at(fit, "NR", "50ms", 0, wh)
    f_nr350 <- param_at(fit, "NR", "350ms", 0, wh)
    f_r50 <- param_at(fit, "R", "50ms", 0, wh)
    f_r350 <- param_at(fit, "R", "350ms", 0, wh)
    # Positive = NR decreased more than R (NR improved more)
    rows[[length(rows) + 1]] <- make_row(
      paste0("catchup_average_", wh),
      wh,
      function(par) (f_r350(par) - f_r50(par)) - (f_nr350(par) - f_nr50(par))
    )
  }

  # Catch-up early / late
  for (slice_name in c("early", "late")) {
    sz <- if (slice_name == "early") early_z else late_z
    for (wh in c("kappa", "gamma", "beta")) {
      f_nr50 <- param_at(fit, "NR", "50ms", sz, wh)
      f_nr350 <- param_at(fit, "NR", "350ms", sz, wh)
      f_r50 <- param_at(fit, "R", "50ms", sz, wh)
      f_r350 <- param_at(fit, "R", "350ms", sz, wh)
      if (wh == "kappa") {
        rows[[length(rows) + 1]] <- make_row(
          paste0("catchup_", slice_name, "_", wh),
          wh,
          function(par) (f_nr350(par) - f_nr50(par)) - (f_r350(par) - f_r50(par))
        )
      } else {
        rows[[length(rows) + 1]] <- make_row(
          paste0("catchup_", slice_name, "_", wh),
          wh,
          function(par) (f_r350(par) - f_r50(par)) - (f_nr350(par) - f_nr50(par))
        )
      }
    }
  }

  # Practice: late - early duration effect (350-50) by cue
  for (cue in c("NR", "R")) {
    for (wh in c("kappa", "gamma", "beta")) {
      f50e <- param_at(fit, cue, "50ms", early_z, wh)
      f350e <- param_at(fit, cue, "350ms", early_z, wh)
      f50l <- param_at(fit, cue, "50ms", late_z, wh)
      f350l <- param_at(fit, cue, "350ms", late_z, wh)
      rows[[length(rows) + 1]] <- make_row(
        paste0(cue, "_practice_durEffect_", wh),
        wh,
        function(par) (f350l(par) - f50l(par)) - (f350e(par) - f50e(par))
      )
    }
  }

  bind_rows(rows)
}

# ---------------------------------------------------------------------------
# Run fits (only when executed as a script, not when sourced)
# ---------------------------------------------------------------------------

.run_mixture_main <- !exists("S1_MIXTURE_SOURCE_ONLY") &&
  identical(sys.nframe(), 0L)

if (.run_mixture_main || isTRUE(getOption("s1.run_mixture", FALSE))) {
  d <- read_csv("S1_smallN_model_ready.csv", show_col_types = FALSE)

  participants <- c("AQ", "HC", "YILIU")
  fits <- list()

  for (pid in participants) {
    d_sub <- d %>% filter(ID == pid)
    fits[[pid]] <- fit_mixture_regression(
      d_sub, pid,
      n_starts = 3,
      maxit = 500
    )
  }

  pred_avg <- bind_rows(lapply(participants, function(pid) {
    predict_mixreg(fits[[pid]], session_z = 0) %>%
      mutate(ID = pid, SessionSlice = "average")
  }))

  pred_early <- bind_rows(lapply(participants, function(pid) {
    predict_mixreg(fits[[pid]], session_z = fits[[pid]]$prep_meta$early_z) %>%
      mutate(ID = pid, SessionSlice = "early")
  }))

  pred_late <- bind_rows(lapply(participants, function(pid) {
    predict_mixreg(fits[[pid]], session_z = fits[[pid]]$prep_meta$late_z) %>%
      mutate(ID = pid, SessionSlice = "late")
  }))

  pred_all <- bind_rows(pred_avg, pred_early, pred_late)
  write_csv(pred_all, "mixture_regression/predicted_params.csv")

  message("Computing contrasts ...")
  contrast_tbl <- bind_rows(lapply(fits, participant_mixture_contrasts))
  write_csv(contrast_tbl, "mixture_regression/theory_contrasts.csv")
  saveRDS(fits, "mixture_regression/all_fits.rds")

  cat("\n===== Fit summaries =====\n")
  for (pid in participants) {
    cat(
      pid, ": NLL =", round(fits[[pid]]$nll, 2),
      " convergence =", fits[[pid]]$convergence, "\n"
    )
  }

  cat("\n===== Predicted params (average session) =====\n")
  print(
    pred_avg %>%
      select(ID, CueType, DurationF, kappa, gamma, beta, circSD_deg) %>%
      arrange(ID, CueType, DurationF),
    n = 50
  )

  cat("\n===== Theory contrasts =====\n")
  print(as.data.frame(contrast_tbl), digits = 3)

  cat("\nDONE\n")
}