# =============================================================================
# Hierarchical von Mises mixture ladder (L0 / L1 / L2 × 2κ / 14κ)
# =============================================================================
# Outcome: SignedErr (degrees, wrapped to radians).
# Session nested in Cue×Duration for κ (L0), γ (L1), γ and β (L2).
# L0: VM only (indicative κ structure).
# L1: VM + uniform guess.
# L2: VM + uniform + swap (trial-specific non-target centres; κ by cue).
# Model comparison: WAIC / LOO from trial-level log-likelihoods.
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(loo)
})

# ---- circular helpers (aligned with s1_mixture_cells.R) ----

wrap_rad_from_deg <- function(deg) {
  atan2(sin(deg * pi / 180), cos(deg * pi / 180))
}

log_vonmises <- function(x, mu, kappa) {
  log_i0 <- log(max(besselI(kappa, 0, expon.scaled = TRUE), .Machine$double.xmin)) + kappa
  kappa * cos(x - mu) - log(2 * pi) - log_i0
}

circ_sd_from_kappa <- function(kappa) {
  a <- pmax(
    besselI(kappa, 1, expon.scaled = TRUE) /
      pmax(besselI(kappa, 0, expon.scaled = TRUE), .Machine$double.xmin),
    1e-12
  )
  a <- pmin(a, 1 - 1e-12)
  sqrt(-2 * log(a)) * (180 / pi)
}

# ---- trial table with design indices ----

prep_vm_trials <- function(d_sub) {
  stopifnot(nrow(d_sub) > 0)
  cues <- levels(d_sub$CueType)
  durs <- levels(d_sub$DurationF)
  sess <- levels(d_sub$SessionF)

  d_sub <- d_sub %>%
    mutate(
      theta = wrap_rad_from_deg(SignedErr),
      idx_cue = as.integer(CueType),
      idx_dur = as.integer(DurationF),
      idx_cd = (idx_cue - 1L) * length(durs) + idx_dur,
      idx_sess = as.integer(SessionF)
    )

  n <- nrow(d_sub)
  mu1 <- mu2 <- mu3 <- numeric(n)
  item_mat <- as.matrix(d_sub[, paste0("ItemHue", 1:6)])

  for (t in seq_len(n)) {
    target <- d_sub$TargetHue[t]
    hues <- unique(as.numeric(item_mat[t, ]))
    nontarget <- hues[abs(wrap_rad_from_deg(hues - target)) > 1e-8]
    stopifnot(length(nontarget) == 3)
    mu <- wrap_rad_from_deg(target - nontarget)
    mu1[t] <- mu[1]
    mu2[t] <- mu[2]
    mu3[t] <- mu[3]
  }

  list(
    data = d_sub,
    theta = d_sub$theta,
    mu1 = mu1,
    mu2 = mu2,
    mu3 = mu3,
    idx_cue = d_sub$idx_cue,
    idx_cd = d_sub$idx_cd,
    idx_sess = d_sub$idx_sess,
    n = n,
    n_cd = length(cues) * length(durs),
    n_sess = length(sess),
    n_cue = length(cues)
  )
}

# Session 1 = reference (offset 0); sessions 2..S have free offsets.
sess_offset <- function(idx_sess, par_sess, n_sess) {
  c(0, par_sess)[idx_sess]
}

log_kappa_i <- function(idx_cue, idx_cd, idx_sess, kappa_struct, par) {
  base <- if (kappa_struct == "2k") {
    par$log_kappa_cue[idx_cue]
  } else {
    par$log_kappa_cd[idx_cd]
  }
  base + sess_offset(idx_sess, par$log_kappa_sess, par$n_sess)
}

# ---- trial log-likelihoods ----

trial_ll_L0 <- function(theta, idx_cue, idx_cd, idx_sess, kappa_struct, par) {
  lk <- exp(log_kappa_i(idx_cue, idx_cd, idx_sess, kappa_struct, par))
  log_vonmises(theta, 0, lk)
}

trial_ll_L1 <- function(theta, idx_cue, idx_cd, idx_sess, kappa_struct, par) {
  lk <- exp(log_kappa_i(idx_cue, idx_cd, idx_sess, kappa_struct, par))
  g <- plogis(par$gamma_cd[idx_cd] + sess_offset(idx_sess, par$gamma_sess, par$n_sess))
  g <- pmin(pmax(g, 1e-8), 1 - 1e-8)
  pt <- 1 - g
  log_target <- log(pt) + log_vonmises(theta, 0, lk)
  log_guess <- log(g) - log(2 * pi)
  m <- pmax(log_target, log_guess)
  m + log(exp(log_target - m) + exp(log_guess - m))
}

trial_ll_L2 <- function(theta, mu1, mu2, mu3, idx_cue, idx_cd, idx_sess, kappa_struct, par) {
  lk <- exp(log_kappa_i(idx_cue, idx_cd, idx_sess, kappa_struct, par))
  b <- plogis(par$beta_cd[idx_cd] + sess_offset(idx_sess, par$beta_sess, par$n_sess))
  gf <- plogis(par$gfrac_cd[idx_cd] + sess_offset(idx_sess, par$gfrac_sess, par$n_sess))
  g <- pmin(pmax((1 - b) * gf, 1e-8), 1 - 1e-8)
  b <- pmin(pmax(b, 1e-8), 1 - g - 1e-8)
  pt <- 1 - b - g

  log_target <- log(pt) + log_vonmises(theta, 0, lk)
  log_s1 <- log(b / 3) + log_vonmises(theta, mu1, lk)
  log_s2 <- log(b / 3) + log_vonmises(theta, mu2, lk)
  log_s3 <- log(b / 3) + log_vonmises(theta, mu3, lk)
  m_sw <- pmax(log_s1, log_s2, log_s3)
  log_swap <- m_sw + log(exp(log_s1 - m_sw) + exp(log_s2 - m_sw) + exp(log_s3 - m_sw))
  log_guess <- log(g) - log(2 * pi)

  m <- pmax(log_target, log_swap, log_guess)
  m + log(exp(log_target - m) + exp(log_swap - m) + exp(log_guess - m))
}

# ---- pack / unpack parameters ----

vm_par_layout <- function(prep, level, kappa_struct) {
  n_cd <- prep$n_cd
  n_sess <- prep$n_sess
  n_cue <- prep$n_cue
  n_kappa <- if (kappa_struct == "2k") n_cue else n_cd
  n_sess_off <- max(n_sess - 1L, 0L)

  layout <- list(
    level = level,
    kappa_struct = kappa_struct,
    n_cd = n_cd,
    n_sess = n_sess,
    n_kappa = n_kappa,
    idx = list(
      log_kappa_base = 1:n_kappa,
      log_kappa_sess = if (n_sess_off > 0) (n_kappa + 1):(n_kappa + n_sess_off) else integer(0)
    )
  )
  pos <- n_kappa + n_sess_off

  if (level %in% c("L1", "L2")) {
    layout$idx$gamma_cd <- (pos + 1):(pos + n_cd)
    pos <- pos + n_cd
    layout$idx$gamma_sess <- if (n_sess_off > 0) (pos + 1):(pos + n_sess_off) else integer(0)
    pos <- pos + n_sess_off
  }
  if (level == "L2") {
    layout$idx$beta_cd <- (pos + 1):(pos + n_cd)
    pos <- pos + n_cd
    layout$idx$beta_sess <- if (n_sess_off > 0) (pos + 1):(pos + n_sess_off) else integer(0)
    pos <- pos + n_sess_off
    layout$idx$gfrac_cd <- (pos + 1):(pos + n_cd)
    pos <- pos + n_cd
    layout$idx$gfrac_sess <- if (n_sess_off > 0) (pos + 1):(pos + n_sess_off) else integer(0)
    pos <- pos + n_sess_off
  }
  layout$n_par <- pos
  layout
}

unpack_par <- function(vec, layout) {
  g <- function(name) {
    idx <- layout$idx[[name]]
    if (length(idx) == 0) numeric(0) else vec[idx]
  }
  list(
    log_kappa_cue = if (layout$kappa_struct == "2k") g("log_kappa_base") else NULL,
    log_kappa_cd = if (layout$kappa_struct == "14k") g("log_kappa_base") else NULL,
    log_kappa_sess = g("log_kappa_sess"),
    gamma_cd = g("gamma_cd"),
    gamma_sess = g("gamma_sess"),
    beta_cd = g("beta_cd"),
    beta_sess = g("beta_sess"),
    gfrac_cd = g("gfrac_cd"),
    gfrac_sess = g("gfrac_sess"),
    n_sess = layout$n_sess
  )
}

init_par <- function(prep, layout) {
  vec <- rep(0, layout$n_par)
  n_k <- layout$n_kappa
  vec[layout$idx$log_kappa_base] <- log(8)
  if (length(layout$idx$log_kappa_sess) > 0) {
    vec[layout$idx$log_kappa_sess] <- 0
  }
  if (layout$level %in% c("L1", "L2")) {
    vec[layout$idx$gamma_cd] <- qlogis(0.05)
    if (length(layout$idx$gamma_sess) > 0) vec[layout$idx$gamma_sess] <- 0
  }
  if (layout$level == "L2") {
    vec[layout$idx$beta_cd] <- qlogis(0.10)
    if (length(layout$idx$beta_sess) > 0) vec[layout$idx$beta_sess] <- 0
    vec[layout$idx$gfrac_cd] <- qlogis(0.15)
    if (length(layout$idx$gfrac_sess) > 0) vec[layout$idx$gfrac_sess] <- 0
  }
  vec
}

random_starts <- function(prep, layout, n = 12) {
  starts <- list(init_par(prep, layout))
  for (i in seq_len(n - 1)) {
    v <- init_par(prep, layout)
    v[layout$idx$log_kappa_base] <- log(runif(layout$n_kappa, 2, 30))
    if (layout$level %in% c("L1", "L2")) {
      v[layout$idx$gamma_cd] <- qlogis(runif(layout$n_cd, 0.01, 0.25))
    }
    if (layout$level == "L2") {
      v[layout$idx$beta_cd] <- qlogis(runif(layout$n_cd, 0.02, 0.35))
      v[layout$idx$gfrac_cd] <- qlogis(runif(layout$n_cd, 0.05, 0.40))
    }
    starts[[length(starts) + 1]] <- v
  }
  starts
}

nll_vm_ladder <- function(vec, prep, layout) {
  par <- unpack_par(vec, layout)
  lk <- exp(log_kappa_i(prep$idx_cue, prep$idx_cd, prep$idx_sess, layout$kappa_struct, par))
  if (any(!is.finite(lk)) || any(lk < 0.05) || any(lk > 800)) return(1e12)

  if (layout$level == "L0") {
    ll <- trial_ll_L0(
      prep$theta, prep$idx_cue, prep$idx_cd, prep$idx_sess,
      layout$kappa_struct, par
    )
  } else if (layout$level == "L1") {
    ll <- trial_ll_L1(
      prep$theta, prep$idx_cue, prep$idx_cd, prep$idx_sess,
      layout$kappa_struct, par
    )
  } else {
    ll <- trial_ll_L2(
      prep$theta, prep$mu1, prep$mu2, prep$mu3,
      prep$idx_cue, prep$idx_cd, prep$idx_sess,
      layout$kappa_struct, par
    )
  }
  if (any(!is.finite(ll)) || any(ll > 12)) return(1e12)
  nll <- -sum(ll)
  if (!is.finite(nll) || nll < -prep$n * 3) return(1e12)
  nll
}

trial_loglik <- function(vec, prep, layout) {
  par <- unpack_par(vec, layout)
  if (layout$level == "L0") {
    trial_ll_L0(prep$theta, prep$idx_cue, prep$idx_cd, prep$idx_sess, layout$kappa_struct, par)
  } else if (layout$level == "L1") {
    trial_ll_L1(prep$theta, prep$idx_cue, prep$idx_cd, prep$idx_sess, layout$kappa_struct, par)
  } else {
    trial_ll_L2(
      prep$theta, prep$mu1, prep$mu2, prep$mu3,
      prep$idx_cue, prep$idx_cd, prep$idx_sess,
      layout$kappa_struct, par
    )
  }
}

# ---- fit one participant × model spec ----

fit_vm_ladder <- function(d_sub, level, kappa_struct, label = NULL, verbose = TRUE) {
  if (is.null(label)) label <- paste(level, kappa_struct, sep = "_")
  if (verbose) message("  Fitting ", label, " (n = ", nrow(d_sub), " trials) ...")

  prep <- prep_vm_trials(d_sub)
  layout <- vm_par_layout(prep, level, kappa_struct)
  starts <- random_starts(prep, layout, n = 20)

  best <- list(value = Inf, par = NULL, convergence = 1L)
  for (s in seq_along(starts)) {
    fit <- tryCatch(
      optim(
        par = starts[[s]],
        fn = nll_vm_ladder,
        prep = prep,
        layout = layout,
        method = "L-BFGS-B",
        lower = rep(-8, layout$n_par),
        upper = rep(8, layout$n_par),
        control = list(maxit = 3000, factr = 1e7)
      ),
      error = function(e) NULL
    )
    if (is.null(fit)) next
    if (!is.finite(fit$value) || fit$value >= 1e11) next
    if (fit$value < best$value) best <- fit
  }
  if (!is.finite(best$value) || is.null(best$par)) {
    stop("Optimization failed for ", label)
  }
  if (verbose) message("    done: NLL = ", round(best$value, 1), ", n_par = ", layout$n_par)

  ll <- trial_loglik(best$par, prep, layout)
  n <- length(ll)
  npar <- layout$n_par

  waic_res <- tryCatch(waic(ll), error = function(e) NULL)
  loo_res <- tryCatch(loo(ll), error = function(e) NULL)

  cell_params <- extract_vm_cell_params(best$par, prep, layout)

  list(
    label = label,
    level = level,
    kappa_struct = kappa_struct,
    par = best$par,
    layout = layout,
    nll = best$value,
    log_lik = ll,
    n = n,
    npar = npar,
    aic = 2 * npar + 2 * best$value,
    bic = log(n) * npar + 2 * best$value,
    waic = if (!is.null(waic_res)) waic_res$estimates["waic", "Estimate"] else NA_real_,
    waic_se = if (!is.null(waic_res)) waic_res$estimates["waic", "SE"] else NA_real_,
    elpd_waic = if (!is.null(waic_res)) waic_res$estimates["elpd_waic", "Estimate"] else NA_real_,
    looic = if (!is.null(loo_res)) loo_res$estimates["looic", "Estimate"] else NA_real_,
    looic_se = if (!is.null(loo_res)) loo_res$estimates["looic", "SE"] else NA_real_,
    elpd_loo = if (!is.null(loo_res)) loo_res$estimates["elpd_loo", "Estimate"] else NA_real_,
    cell_params = cell_params,
    prep = prep
  )
}

extract_vm_cell_params <- function(vec, prep, layout) {
  par <- unpack_par(vec, layout)
  dd <- prep$data
  cues <- levels(dd$CueType)
  durs <- levels(dd$DurationF)
  sess <- levels(dd$SessionF)

  grid <- expand_grid(
    CueType = factor(cues, levels = cues),
    DurationF = factor(durs, levels = durs),
    SessionF = factor(sess, levels = sess)
  ) %>%
    mutate(
      idx_cue = as.integer(CueType),
      idx_dur = as.integer(DurationF),
      idx_cd = (idx_cue - 1L) * length(durs) + idx_dur,
      idx_sess = as.integer(SessionF)
    )

  grid$kappa <- exp(log_kappa_i(
    grid$idx_cue, grid$idx_cd, grid$idx_sess, layout$kappa_struct, par
  ))
  grid$circSD_deg <- circ_sd_from_kappa(grid$kappa)

  if (layout$level %in% c("L1", "L2")) {
    if (layout$level == "L1") {
      grid$gamma <- plogis(par$gamma_cd[grid$idx_cd] +
        sess_offset(grid$idx_sess, par$gamma_sess, par$n_sess))
      grid$beta <- 0
      grid$p_target <- 1 - grid$gamma
    } else {
      grid$beta <- plogis(par$beta_cd[grid$idx_cd] +
        sess_offset(grid$idx_sess, par$beta_sess, par$n_sess))
      gf <- plogis(par$gfrac_cd[grid$idx_cd] +
        sess_offset(grid$idx_sess, par$gfrac_sess, par$n_sess))
      grid$gamma <- (1 - grid$beta) * gf
      grid$p_target <- 1 - grid$beta - grid$gamma
    }
  } else {
    grid$gamma <- 0
    grid$beta <- 0
    grid$p_target <- 1
  }

  grid %>%
    select(CueType, DurationF, SessionF, kappa, circSD_deg, p_target, beta, gamma)
}

# ---- fit full ladder for one participant ----

vm_ladder_specs <- function() {
  expand_grid(
    level = c("L0", "L1", "L2"),
    kappa_struct = c("2k", "14k")
  ) %>%
    mutate(
      model_id = paste0(level, "_", kappa_struct),
      description = case_when(
        level == "L0" & kappa_struct == "2k" ~ "VM; κ ~ Cue + Session",
        level == "L0" & kappa_struct == "14k" ~ "VM; κ ~ Cue×Duration + Session",
        level == "L1" & kappa_struct == "2k" ~ "VM+guess; κ ~ Cue; γ ~ Cue×Duration + Session",
        level == "L1" & kappa_struct == "14k" ~ "VM+guess; κ ~ Cue×Duration; γ ~ Cue×Duration + Session",
        level == "L2" & kappa_struct == "2k" ~ "VM+guess+swap; κ ~ Cue; γ,β ~ Cue×Duration + Session",
        level == "L2" & kappa_struct == "14k" ~ "VM+guess+swap; κ ~ Cue×Duration; γ,β ~ Cue×Duration + Session"
      )
    )
}

fit_vm_ladder_all <- function(d_sub, pid = NA_character_, verbose = TRUE) {
  if (verbose) message("=== VM ladder: ", pid, " ===")
  specs <- vm_ladder_specs()
  fits <- vector("list", nrow(specs))
  names(fits) <- specs$model_id

  for (i in seq_len(nrow(specs))) {
    fits[[i]] <- fit_vm_ladder(
      d_sub,
      level = specs$level[i],
      kappa_struct = specs$kappa_struct[i],
      label = specs$model_id[i],
      verbose = verbose
    )
  }

  cmp <- tibble(
    model_id = names(fits),
    level = specs$level,
    kappa_struct = specs$kappa_struct,
    description = specs$description,
    npar = vapply(fits, function(x) x$npar, numeric(1)),
    nll = vapply(fits, function(x) x$nll, numeric(1)),
    aic = vapply(fits, function(x) x$aic, numeric(1)),
    bic = vapply(fits, function(x) x$bic, numeric(1)),
    waic = vapply(fits, function(x) x$waic, numeric(1)),
    elpd_loo = vapply(fits, function(x) x$elpd_loo, numeric(1))
  ) %>%
    group_by(level) %>%
    mutate(
      delta_waic = waic - min(waic, na.rm = TRUE),
      delta_loo = -elpd_loo + max(elpd_loo, na.rm = TRUE)
    ) %>%
    ungroup() %>%
    arrange(level, waic)

  list(fits = fits, compare = cmp, specs = specs)
}

summarize_ladder_winners <- function(all_results, id_pub) {
  pmap_dfr(names(all_results), function(raw) {
    cmp <- all_results[[raw]]$compare
    bind_rows(
      cmp %>%
        group_by(level) %>%
        slice_min(waic, n = 1, with_ties = FALSE) %>%
        ungroup() %>%
        mutate(winner_type = "best_waic_within_level"),
      cmp %>%
        slice_min(waic, n = 1, with_ties = FALSE) %>%
        mutate(winner_type = "best_waic_overall"),
      cmp %>%
        filter(kappa_struct == "2k") %>%
        group_by(level) %>%
        slice_min(waic, n = 1, with_ties = FALSE) %>%
        ungroup() %>%
        mutate(winner_type = "best_2k_within_level")
    ) %>%
      mutate(ID = id_pub[[raw]], raw_ID = raw) %>%
      select(ID, raw_ID, winner_type, model_id, level, kappa_struct, description, waic, elpd_loo, delta_waic)
  })
}
