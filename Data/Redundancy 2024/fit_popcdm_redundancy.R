# =============================================================================
# fit_popcdm_redundancy.R - Redundancy 2024 POPCDM (likelihood + fit helpers)
# =============================================================================
#
# Sourcing defines functions and POPCDM_R_DIR only. Use load_popcdm_sources()
# then call fit helpers from your Rmd with your own starts/bounds.
#
# POPCDM_R: besselFPT.R, popcode.R, popcdm300.R (Sys.setenv(POPCDM_R_DIR = "...") to override)
#
# Trial alpha: computed in redundancy_nll() as alphaEst * m (branch m from design).
# P_var (length 7): alphaEst, vnorm_R, vnorm_NR, beta1, beta2, kappa, a.
# Fixed tail: eta1, eta2, ter, st via redundancy_default_pfix(); slot a in P_fix is 0 when a is free.
#
# =============================================================================

# --- Load POPCDM --------------------------------------------------------------

POPCDM_R_DIR <- Sys.getenv(
  "POPCDM_R_DIR",
  "/Users/prefabteam_ysl/Documents/GitHub/DazExperiments/Models/CDM/POPCDM_R"
)

load_popcdm_sources <- function(dir = POPCDM_R_DIR) {
  if (!dir.exists(dir)) {
    stop("POPCDM_R_DIR not found: ", dir, call. = FALSE)
  }
  owd <- getwd()
  on.exit(setwd(owd), add = TRUE)
  setwd(dir)
  source("besselFPT.R", local = FALSE)
  source("popcode.R", local = FALSE)
  source("popcdm300.R", local = FALSE)
}


# --- Geometry (joint log-density on popcdm300 grid) -----------------------------

interp_joint_linear <- function(Theta, Tvec, Z, ang, rt, log_floor = log(1e-300)) {
  if (length(ang) != 1L || length(rt) != 1L) {
    stop("scalar ang, rt only", call. = FALSE)
  }
  if (ang <= Theta[1L] || ang >= Theta[length(Theta)]) {
    return(log_floor)
  }
  if (rt <= Tvec[1L] || rt >= Tvec[length(Tvec)]) {
    return(log_floor)
  }
  i <- findInterval(ang, Theta, all.inside = TRUE)
  j <- findInterval(rt, Tvec, all.inside = TRUE)
  x1 <- Theta[i]; x2 <- Theta[i + 1L]
  y1 <- Tvec[j]; y2 <- Tvec[j + 1L]
  q11 <- Z[i, j]; q21 <- Z[i + 1L, j]
  q12 <- Z[i, j + 1L]; q22 <- Z[i + 1L, j + 1L]
  wx <- (ang - x1) / (x2 - x1)
  wy <- (rt - y1) / (y2 - y1)
  v <- (1 - wx) * (1 - wy) * q11 + wx * (1 - wy) * q21 +
    (1 - wx) * wy * q12 + wx * wy * q22
  if (!is.finite(v) || v <= 0) {
    return(log_floor)
  }
  log(v)
}


# --- Experimental design (nine cells) -----------------------------------------

COND_LEVELS <- c(
  "set2_baseline",
  "set4_baseline",
  "set4_R_cue",
  "set4_NR_cue",
  "set6_baseline",
  "set6_R_cue_ci2",
  "set6_NR_cue_ci2",
  "set6_R_cue_ci4",
  "set6_NR_cue_ci4"
)

redundancy_condition_label <- function(num_itemsi, ColorNi, redundancy) {
  ni <- as.integer(num_itemsi)
  ci <- as.integer(ColorNi)
  if (length(ni) != 1L || length(ci) != 1L || length(redundancy) != 1L) {
    stop("scalar num_itemsi, ColorNi, redundancy only", call. = FALSE)
  }
  if (ni == 2L) {
    return("set2_baseline")
  }
  if (ni == 4L && ni == ci) {
    return("set4_baseline")
  }
  if (ni == 4L && ci == 2L) {
    if (identical(redundancy, "Redundant Cued")) {
      return("set4_R_cue")
    }
    if (identical(redundancy, "Non-Redundant Cued")) {
      return("set4_NR_cue")
    }
    return(NA_character_)
  }
  if (ni == 6L && ni == ci) {
    return("set6_baseline")
  }
  if (ni == 6L && ci %in% c(2L, 4L)) {
    if (identical(redundancy, "Redundant Cued")) {
      return(paste0("set6_R_cue_ci", ci))
    }
    if (identical(redundancy, "Non-Redundant Cued")) {
      return(paste0("set6_NR_cue_ci", ci))
    }
    return(NA_character_)
  }
  NA_character_
}

redundancy_cond_design_table <- function() {
  data.frame(
    cond_label = COND_LEVELS,
    num_itemsi = c(2L, 4L, 4L, 4L, 6L, 6L, 6L, 6L, 6L),
    ColorNi = c(2L, 4L, 2L, 2L, 6L, 2L, 2L, 4L, 4L),
    redundancy = c(
      "Non-Redundant Cued",
      "Non-Redundant Cued",
      "Redundant Cued",
      "Non-Redundant Cued",
      "Non-Redundant Cued",
      "Redundant Cued",
      "Non-Redundant Cued",
      "Redundant Cued",
      "Non-Redundant Cued"
    ),
    stringsAsFactors = FALSE
  )
}

cue_branch_from_cond <- function(cond_label) {
  if (grepl("_R_cue", cond_label, fixed = TRUE)) {
    "R"
  } else {
    "NR"
  }
}


# --- Full 11-vector (seven free + fixed eta/ter/st) -----------------------------

redundancy_param_names <- function() {
  c(
    "alphaEst", "vnorm_R", "vnorm_NR", "beta1", "beta2",
    "eta1", "eta2", "a", "kappa", "ter", "st"
  )
}

#' Names and order of the optimised `P_var` vector (length 7).
redundancy_Pvar_free_names <- function() {
  c("alphaEst", "vnorm_R", "vnorm_NR", "beta1", "beta2", "kappa", "a")
}

REDUNDANCY_N_PVAR <- 7L

#' Build `P_fix` (length 11) for eta1, eta2, ter, st only; slot `a` is 0 (filled from `P_var[7]`).
redundancy_default_pfix <- function(
    eta1 = 1,
    eta2 = 1e-6,
    ter = 0.2,
    st = 0.1) {
  c(0, 0, 0, 0, 0, eta1, eta2, 0, 0, ter, st)
}

#' Pack starts / bounds / `P_fix` from named vectors (edit in Rmd).
#'
#' All names in [redundancy_Pvar_free_names] must appear in `starts`, `lower`, `upper`.
redundancy_fit_inputs_seven <- function(
    starts,
    lower,
    upper,
    fixed_eta_ter = list(eta1 = 1, eta2 = 1e-6, ter = 0.2, st = 0.1)) {
  nm <- redundancy_Pvar_free_names()
  if (!setequal(names(starts), nm)) {
    stop("starts must be a named vector with exactly: ", paste(nm, collapse = ", "), call. = FALSE)
  }
  if (!setequal(names(lower), nm) || !setequal(names(upper), nm)) {
    stop("lower and upper must use the same seven names as starts", call. = FALSE)
  }
  starts <- starts[nm]
  lower <- lower[nm]
  upper <- upper[nm]
  P_fix <- redundancy_default_pfix(
    eta1 = fixed_eta_ter$eta1,
    eta2 = fixed_eta_ter$eta2,
    ter = fixed_eta_ter$ter,
    st = fixed_eta_ter$st
  )
  list(
    P_var_start = unname(as.numeric(starts)),
    lower = unname(as.numeric(lower)),
    upper = unname(as.numeric(upper)),
    P_fix = P_fix
  )
}

#' Assemble full named `P` (length 11) from seven-vector `P_var` and fixed tail.
#'
#' `P_var`: alphaEst, vnorm_R, vnorm_NR, beta1, beta2, kappa, a (indices 1–7).
#' Uses `P_fix` slots 6, 7, 10, 11 for eta1, eta2, ter, st.
redundancy_full_P_from_var <- function(P_var, P_fix = redundancy_default_pfix()) {
  if (length(P_var) != REDUNDANCY_N_PVAR) {
    stop(
      "P_var must have length 7 (alphaEst, vnorm_R, vnorm_NR, beta1, beta2, kappa, a)",
      call. = FALSE
    )
  }
  if (length(P_fix) != 11L) {
    stop("P_fix must have length 11", call. = FALSE)
  }
  P <- c(
    P_var[1L], P_var[2L], P_var[3L], P_var[4L], P_var[5L],
    P_fix[6L], P_fix[7L], P_var[7L], P_var[6L], P_fix[10L], P_fix[11L]
  )
  names(P) <- redundancy_param_names()
  P
}

redundancy_parse_merged <- function(P) {
  nm <- redundancy_param_names()
  if (length(P) != length(nm)) {
    stop("P must have length ", length(nm), call. = FALSE)
  }
  list(
    alphaEst = unname(P["alphaEst"]),
    vnorm_R = unname(P["vnorm_R"]),
    vnorm_NR = unname(P["vnorm_NR"]),
    beta1 = unname(P["beta1"]),
    beta2 = unname(P["beta2"]),
    eta1 = unname(P["eta1"]),
    eta2 = unname(P["eta2"]),
    a = unname(P["a"]),
    kappa = unname(P["kappa"]),
    ter = unname(P["ter"]),
    st = unname(P["st"])
  )
}

redundancy_popcdm_P8 <- function(vnorm, alpha, pr) {
  c(vnorm, pr$eta1, pr$eta2, pr$a, alpha, pr$kappa, pr$ter, pr$st)
}


# --- Grid / RT audit (step 1: tmax, nw, h) ------------------------------------

#' Time grid used by `popcdm300` (same construction as in engine).
redundancy_time_grid_length <- function(tmax, h) {
  length(seq(0, tmax, by = h))
}

#' Summarise RTs vs `tmax` and discrete grid size. Use before locking `tmax`/`h`/`nw`.
#'
#' If many trials have `rt_sec >= tmax`, joint density is evaluated on the
#' interpolation floor and the NLL is distorted. Prefer `tmax` above high RT
#' quantiles, then refine `h` / raise `nw` for accuracy (costly).
redundancy_rt_grid_audit <- function(fit_df, tmax, h, nw = NA_integer_) {
  if (!"rt_sec" %in% names(fit_df)) {
    stop("fit_df must contain rt_sec (from prepare_redundancy_fit_frame)", call. = FALSE)
  }
  rt <- as.numeric(fit_df$rt_sec)
  rt <- rt[is.finite(rt)]
  n <- length(rt)
  if (!n) {
    stop("no finite rt_sec", call. = FALSE)
  }
  qs <- stats::quantile(rt, probs = c(0.5, 0.9, 0.95, 0.99, 0.999), names = TRUE)
  ge_tmax <- mean(rt >= tmax)
  ge_tmax_mh <- mean(rt >= (tmax - h))
  nT <- redundancy_time_grid_length(tmax, h)
  data.frame(
    n_trials = n,
    rt_min = min(rt),
    rt_median = unname(qs["50%"]),
    rt_p90 = unname(qs["90%"]),
    rt_p95 = unname(qs["95%"]),
    rt_p99 = unname(qs["99%"]),
    rt_p999 = unname(qs["99.9%"]),
    rt_max = max(rt),
    tmax = tmax,
    h = h,
    n_time_bins = nT,
    nw = nw,
    frac_rt_ge_tmax = ge_tmax,
    frac_rt_ge_tmax_minus_h = ge_tmax_mh,
    stringsAsFactors = FALSE
  )
}


# --- Beta reparameterisation (logit on physical interval) ---------------------

redundancy_beta_phys_from_latent <- function(u, lo, hi) {
  if (!(is.finite(lo) && is.finite(hi) && hi > lo)) {
    stop("need finite beta bounds with hi > lo", call. = FALSE)
  }
  lo + (hi - lo) * stats::plogis(u)
}

redundancy_beta_latent_from_phys <- function(beta, lo, hi) {
  if (!(is.finite(lo) && is.finite(hi) && hi > lo)) {
    stop("need finite beta bounds with hi > lo", call. = FALSE)
  }
  p <- (beta - lo) / (hi - lo)
  p <- pmin(pmax(p, .Machine$double.eps), 1 - .Machine$double.eps)
  stats::qlogis(p)
}

#' Map optim working vector -> physical `P_var` (default: beta slots 4–5).
redundancy_Pvar_phys_from_working <- function(
    par_working,
    lower_phys,
    upper_phys,
    beta_link = c("identity", "logit"),
    beta_idx = c(4L, 5L)) {
  beta_link <- match.arg(beta_link)
  out <- par_working
  if (identical(beta_link, "logit")) {
    for (k in beta_idx) {
      out[k] <- redundancy_beta_phys_from_latent(
        par_working[k],
        lower_phys[k],
        upper_phys[k]
      )
    }
  }
  out
}

redundancy_Pvar_working_from_phys <- function(
    P_var_phys,
    lower_phys,
    upper_phys,
    beta_link = c("identity", "logit"),
    beta_idx = c(4L, 5L)) {
  beta_link <- match.arg(beta_link)
  out <- P_var_phys
  if (identical(beta_link, "logit")) {
    for (k in beta_idx) {
      out[k] <- redundancy_beta_latent_from_phys(
        P_var_phys[k],
        lower_phys[k],
        upper_phys[k]
      )
    }
  }
  out
}

redundancy_optim_bounds_from_phys <- function(
    lower_phys,
    upper_phys,
    beta_link = c("identity", "logit"),
    beta_idx = c(4L, 5L),
    beta_latent_limit = 15) {
  beta_link <- match.arg(beta_link)
  lo <- lower_phys
  hi <- upper_phys
  if (identical(beta_link, "logit")) {
    L <- as.numeric(beta_latent_limit)
    for (k in beta_idx) {
      lo[k] <- -L
      hi[k] <- L
    }
  }
  list(lower = lo, upper = hi)
}


# --- CSV → trials, NLL, fit ---------------------------------------------------

prepare_redundancy_fit_frame <- function(
    path,
    uid_filter = NULL,
    drop_na_cond = TRUE) {
  d <- utils::read.csv(path, stringsAsFactors = FALSE)
  ex <- d$too_fast_trigger | d$too_slow_trigger
  if ("started_outof_center" %in% names(d)) {
    ex <- ex | d$started_outof_center
  }
  d <- d[!ex & is.finite(d$response_RT) & is.finite(d$response_error), , drop = FALSE]
  if (!is.null(uid_filter)) {
    d <- d[d$uid %in% uid_filter, , drop = FALSE]
  }
  if (!all(c("num_itemsi", "ColorNi", "redundancy") %in% names(d))) {
    stop("CSV must contain num_itemsi, ColorNi, redundancy", call. = FALSE)
  }
  d$cond_label <- mapply(
    redundancy_condition_label,
    d$num_itemsi,
    d$ColorNi,
    d$redundancy,
    SIMPLIFY = TRUE,
    USE.NAMES = FALSE
  )
  if (drop_na_cond) {
    d <- d[!is.na(d$cond_label), , drop = FALSE]
  }
  d$angle_rad <- ((d$response_error + 180) %% 360 - 180) * (pi / 180)
  d$rt_sec <- d$response_RT / 1000
  d
}

#' Subsample trials per `cond_label` (pilots only; NLL not comparable to full data).
redundancy_thin_trials_by_cond <- function(fit_df, max_per_cond = 200L, seed = NULL) {
  if (!"cond_label" %in% names(fit_df)) {
    stop("fit_df must contain cond_label (from prepare_redundancy_fit_frame)", call. = FALSE)
  }
  if (!is.null(seed)) {
    set.seed(seed)
  }
  max_per_cond <- as.integer(max_per_cond)
  if (max_per_cond < 1L) {
    stop("max_per_cond must be >= 1", call. = FALSE)
  }
  labels <- unique(fit_df$cond_label)
  labels <- labels[!is.na(labels)]
  parts <- vector("list", length(labels))
  for (i in seq_along(labels)) {
    rows <- fit_df[fit_df$cond_label == labels[i], , drop = FALSE]
    n <- nrow(rows)
    if (n <= max_per_cond) {
      parts[[i]] <- rows
    } else {
      ix <- sample.int(n, max_per_cond)
      parts[[i]] <- rows[ix, , drop = FALSE]
    }
  }
  out <- do.call(rbind, parts)
  rownames(out) <- NULL
  out
}

# --- NLL: redundancy branch multiplier m, alpha_trial = alphaEst * m, popcdm300 ---

# NR / Non-Redundant Cued: m = ColorNi^(-beta1). R / Redundant Cued:
#   m = ColorNi^(-beta2) * n_redundant^beta2,  n_redundant = num_itemsi - ColorNi + 1.
redundancy_branch_m <- function(num_itemsi, ColorNi, redundancy, beta1, beta2) {
  ni <- as.integer(num_itemsi)
  ci <- as.integer(ColorNi)
  if (length(ni) != 1L || length(ci) != 1L || length(redundancy) != 1L) {
    stop("scalar num_itemsi, ColorNi, redundancy only", call. = FALSE)
  }
  if (identical(redundancy, "Redundant Cued")) {
    n_redundant <- as.integer(ni - ci + 1L)
    if (!is.finite(n_redundant) || n_redundant < 1L) {
      stop("n_redundant = num_itemsi - ColorNi + 1 must be >= 1", call. = FALSE)
    }
    m <- as.numeric(ci)^(-as.numeric(beta2)) * as.numeric(n_redundant)^as.numeric(beta2)
  } else if (identical(redundancy, "Non-Redundant Cued")) {
    m <- as.numeric(ci)^(-as.numeric(beta1))
  } else {
    stop("redundancy must be 'Redundant Cued' or 'Non-Redundant Cued'", call. = FALSE)
  }
  if (!is.finite(m) || m <= 0) {
    stop("alpha branch multiplier invalid", call. = FALSE)
  }
  m
}

#' Negative log-likelihood (minimise). One `popcdm300` surface per `cond_label`.
redundancy_nll <- function(
    P_var,
    fit_df,
    P_fix = redundancy_default_pfix(),
    nw = 56L,
    h = 0.0025,
    tmax = 5.0,
    log_floor = log(1e-300),
    trace = FALSE) {
  P_full <- redundancy_full_P_from_var(P_var, P_fix)
  pr <- redundancy_parse_merged(P_full)
  if (trace) {
    print(P_full)
  }
  fit_df <- fit_df[!is.na(fit_df$cond_label), , drop = FALSE]
  if (!nrow(fit_df)) {
    stop("no trials after condition filter", call. = FALSE)
  }
  tab <- redundancy_cond_design_table()
  ll_total <- 0
  for (cl in unique(fit_df$cond_label)) {
    rows <- fit_df[fit_df$cond_label == cl, , drop = FALSE]
    if (!nrow(rows)) {
      next
    }
    row_design <- tab[tab$cond_label == cl, , drop = FALSE]
    if (nrow(row_design) != 1L) {
      stop("unknown cond_label in NLL: ", cl, call. = FALSE)
    }
    m <- redundancy_branch_m(
      row_design$num_itemsi,
      row_design$ColorNi,
      row_design$redundancy,
      pr$beta1,
      pr$beta2
    )
    alpha_trial <- pr$alphaEst * m
    cb <- cue_branch_from_cond(cl)
    vnorm <- if (identical(cb, "R")) pr$vnorm_R else pr$vnorm_NR
    P8 <- redundancy_popcdm_P8(vnorm, alpha_trial, pr)
    out <- popcdm300(P8, nw = nw, h = h, tmax = tmax, return_components = FALSE)
    for (r in seq_len(nrow(rows))) {
      ll_total <- ll_total + interp_joint_linear(
        out$Theta,
        out$T,
        out$Gt,
        rows$angle_rad[r],
        rows$rt_sec[r],
        log_floor = log_floor
      )
    }
  }
  -ll_total
}

#' Mesh-edge and floor diagnostics for one `P_var`.
#'
#' For each trial, checks whether `(angle_rad, rt_sec)` lies strictly inside the
#' `Theta` and `T` meshes returned by `popcdm300` for that trial's condition.
#' If many trials sit on RT or angle **edges**, the summed log likelihood is
#' driven by the **interpolation floor** and optima can be pulled toward extreme
#' `alphaEst`, `kappa`, or `beta` values.
redundancy_mesh_hit_rates <- function(
    P_var,
    fit_df,
    P_fix = redundancy_default_pfix(),
    nw = 56L,
    h = 0.0025,
    tmax = 5.0,
    log_floor = log(1e-300),
    eps_floor = 1e-6) {
  fit_df <- fit_df[!is.na(fit_df$cond_label), , drop = FALSE]
  if (!nrow(fit_df)) {
    stop("no trials", call. = FALSE)
  }
  P_full <- redundancy_full_P_from_var(P_var, P_fix)
  pr <- redundancy_parse_merged(P_full)
  tab <- redundancy_cond_design_table()
  n_eval <- 0L
  n_edge_mesh <- 0L
  n_floor_ll <- 0L
  for (cl in unique(fit_df$cond_label)) {
    rows <- fit_df[fit_df$cond_label == cl, , drop = FALSE]
    if (!nrow(rows)) {
      next
    }
    row_design <- tab[tab$cond_label == cl, , drop = FALSE]
    if (nrow(row_design) != 1L) {
      stop("unknown cond_label: ", cl, call. = FALSE)
    }
    m <- redundancy_branch_m(
      row_design$num_itemsi,
      row_design$ColorNi,
      row_design$redundancy,
      pr$beta1,
      pr$beta2
    )
    alpha_trial <- pr$alphaEst * m
    cb <- cue_branch_from_cond(cl)
    vnorm <- if (identical(cb, "R")) pr$vnorm_R else pr$vnorm_NR
    P8 <- redundancy_popcdm_P8(vnorm, alpha_trial, pr)
    out <- popcdm300(P8, nw = nw, h = h, tmax = tmax, return_components = FALSE)
    Th <- out$Theta
    Tv <- out$T
    nTh <- length(Th)
    nTv <- length(Tv)
    for (r in seq_len(nrow(rows))) {
      n_eval <- n_eval + 1L
      ang <- rows$angle_rad[r]
      rt <- rows$rt_sec[r]
      edge <- (ang <= Th[1L] || ang >= Th[nTh] || rt <= Tv[1L] || rt >= Tv[nTv])
      if (edge) {
        n_edge_mesh <- n_edge_mesh + 1L
      }
      ll <- interp_joint_linear(Th, Tv, out$Gt, ang, rt, log_floor = log_floor)
      if (ll <= log_floor + eps_floor) {
        n_floor_ll <- n_floor_ll + 1L
      }
    }
  }
  data.frame(
    n_eval = n_eval,
    frac_on_mesh_edge = n_edge_mesh / n_eval,
    frac_ll_at_floor = n_floor_ll / n_eval,
    stringsAsFactors = FALSE
  )
}

#' 1D slices of NLL: vary `P_var[par_index]` over `par_values`, other coordinates
#' fixed at `P_var_ref`. Use to see ridges (e.g. `alphaEst` vs `kappa`) or
#' multimodality. `par_values` are on the **physical** scale (same as `P_var`).
redundancy_curve_nll_1d <- function(
    par_index,
    par_values,
    P_var_ref,
    fit_df,
    P_fix = redundancy_default_pfix(),
    ...) {
  ni <- as.integer(par_index)
  if (length(ni) != 1L || ni < 1L || ni > length(P_var_ref)) {
    stop("par_index must be one integer in 1:length(P_var_ref)", call. = FALSE)
  }
  vals <- as.numeric(par_values)
  nlls <- vapply(vals, function(v) {
    P <- P_var_ref
    P[ni] <- v
    redundancy_nll(P, fit_df = fit_df, P_fix = P_fix, ...)
  }, numeric(1))
  data.frame(value = vals, nll = nlls, par_index = ni, stringsAsFactors = FALSE)
}

fit_redundancy_popcdm_participant <- function(
    fit_df,
    P_var_start,
    lower,
    upper,
    P_fix = redundancy_default_pfix(),
    method = "L-BFGS-B",
    beta_link = c("identity", "logit"),
    beta_latent_limit = 15,
    ...,
    control = list(maxit = 120L, factr = 1e7)) {
  beta_link <- match.arg(beta_link)
  if (length(P_var_start) != REDUNDANCY_N_PVAR) {
    stop("P_var_start must have length 7", call. = FALSE)
  }
  if (length(lower) != length(P_var_start) || length(upper) != length(P_var_start)) {
    stop("lower/upper same length as P_var_start", call. = FALSE)
  }
  lower_phys <- lower
  upper_phys <- upper
  bo <- redundancy_optim_bounds_from_phys(
    lower_phys,
    upper_phys,
    beta_link = beta_link,
    beta_latent_limit = beta_latent_limit
  )
  par0 <- redundancy_Pvar_working_from_phys(
    P_var_start,
    lower_phys,
    upper_phys,
    beta_link = beta_link
  )
  fn <- function(par_w) {
    pv <- redundancy_Pvar_phys_from_working(
      par_w,
      lower_phys,
      upper_phys,
      beta_link = beta_link
    )
    redundancy_nll(pv, fit_df = fit_df, P_fix = P_fix, ...)
  }
  fit <- stats::optim(
    par = par0,
    fn = fn,
    method = method,
    lower = bo$lower,
    upper = bo$upper,
    control = control
  )
  P_var_hat <- redundancy_Pvar_phys_from_working(
    fit$par,
    lower_phys,
    upper_phys,
    beta_link = beta_link
  )
  P_hat <- redundancy_full_P_from_var(P_var_hat, P_fix)
  list(
    optim = fit,
    P_hat = P_hat,
    P_var_hat = P_var_hat,
    optim_par_working = if (identical(beta_link, "logit")) fit$par else NULL,
    nll = fit$value,
    n_trials = nrow(fit_df),
    np_free = REDUNDANCY_N_PVAR,
    P_fix = P_fix,
    fit_meta = list(
      beta_link = beta_link,
      beta_latent_limit = beta_latent_limit,
      lower_phys = lower_phys,
      upper_phys = upper_phys,
      note = if (identical(beta_link, "logit")) {
        "optim$par is on the latent scale for beta1/beta2; use P_var_hat for physical betas."
      } else {
        "optim$par matches P_var_hat (physical scale)."
      }
    )
  )
}

#' Several `optim` runs from different starts; return **best** NLL in the same
#' shape as [fit_redundancy_popcdm_participant], plus `multistart_detail`.
fit_redundancy_popcdm_multistart <- function(
    fit_df,
    P_var_start,
    lower,
    upper,
    P_fix = redundancy_default_pfix(),
    n_starts = 8L,
    seed = NULL,
    method = "L-BFGS-B",
    beta_link = c("identity", "logit"),
    beta_latent_limit = 15,
    ...,
    control = list(maxit = 200L, factr = 1e7)) {
  beta_link <- match.arg(beta_link)
  if (length(P_var_start) != REDUNDANCY_N_PVAR) {
    stop("P_var_start must have length 7", call. = FALSE)
  }
  n_starts <- as.integer(n_starts)
  if (n_starts < 1L) {
    stop("n_starts must be >= 1", call. = FALSE)
  }
  if (!is.null(seed)) {
    set.seed(seed)
  }
  lower_phys <- lower
  upper_phys <- upper
  np <- length(P_var_start)
  beta_idx <- c(4L, 5L)
  eps <- 1e-5

  sample_start_phys <- function() {
    s <- numeric(np)
    for (j in seq_len(np)) {
      lo <- lower_phys[j]
      hi <- upper_phys[j]
      if (j %in% beta_idx) {
        u <- stats::runif(1, min = lo + eps * (hi - lo), max = hi - eps * (hi - lo))
        s[j] <- u
      } else {
        s[j] <- stats::runif(1, min = lo, max = hi)
      }
    }
    s
  }

  starts_mat <- matrix(NA_real_, nrow = n_starts, ncol = np)
  starts_mat[1L, ] <- P_var_start
  if (n_starts > 1L) {
    for (i in 2:n_starts) {
      starts_mat[i, ] <- sample_start_phys()
    }
  }

  results <- vector("list", n_starts)
  nlls <- rep(NA_real_, n_starts)
  for (i in seq_len(n_starts)) {
    results[[i]] <- fit_redundancy_popcdm_participant(
      fit_df,
      P_var_start = starts_mat[i, ],
      lower = lower_phys,
      upper = upper_phys,
      P_fix = P_fix,
      method = method,
      beta_link = beta_link,
      beta_latent_limit = beta_latent_limit,
      ...,
      control = control
    )
    nlls[i] <- results[[i]]$nll
  }
  ibest <- which.min(nlls)
  best <- results[[ibest]]
  best$multistart_detail <- list(
    n_starts = n_starts,
    seed = seed,
    best_index = ibest,
    nll_each = nlls,
    starts_Pvar_phys = starts_mat,
    all_fits = results
  )
  best
}
