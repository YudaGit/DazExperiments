# =============================================================================
# fit_popcdm_redundancy.R - Redundancy 2024 POPCDM (likelihood + fit helpers)
# =============================================================================
#
# Sourcing defines functions and POPCDM_R_DIR only. Use load_popcdm_sources()
# then call fit helpers from your Rmd with your own starts/bounds.
#
# POPCDM_R: besselFPT.R, popcode.R, popcdm300.R (Sys.setenv(POPCDM_R_DIR = "...") to override)
#
# Trial alpha: alpha_trial = alphaEst * m, with alphaEst = theoretical resource baseline B.
# Down-scaling uses (ColorNi / color_count_ref)^(-beta); default color_count_ref = 2 (smallest set).
# Full P uses a Jay-style P/Sel/Pvar/Pfix contract:
#   P    = maximal named parameter vector (50 or 51 entries; depends on beta_variant)
#   Sel  = TRUE/free, FALSE/fixed
#   Pvar = P[Sel], passed to optim()
#   Pfix = P[!Sel], held fixed
#
# =============================================================================

# --- Geometry (joint log-density on popcdm300 grid) -----------------------------

interp_joint_linear <- function(Theta, Tvec, Z, ang, rt, contam_density = 0.05) {
  if (length(ang) != 1L || length(rt) != 1L) {
    stop("scalar ang, rt only", call. = FALSE)
  }
  if (!is.finite(contam_density) || contam_density <= 0) {
    stop("contam_density must be a finite positive scalar", call. = FALSE)
  }
  log_contam <- log(contam_density)
  if (ang <= Theta[1L] || ang >= Theta[length(Theta)]) {
    return(log_contam)
  }
  if (rt <= Tvec[1L] || rt >= Tvec[length(Tvec)]) {
    return(log_contam)
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
    return(log_contam)
  }
  log(v)
}

interp_joint_linear_vec <- function(Theta, Tvec, Z, ang, rt, contam_density = 0.05) {
  if (length(ang) != length(rt)) {
    stop("ang and rt must have the same length", call. = FALSE)
  }
  if (!is.finite(contam_density) || contam_density <= 0) {
    stop("contam_density must be a finite positive scalar", call. = FALSE)
  }
  n <- length(ang)
  log_contam <- log(contam_density)
  ll <- rep(log_contam, n)
  inside <- is.finite(ang) & is.finite(rt) &
    ang > Theta[1L] & ang < Theta[length(Theta)] &
    rt > Tvec[1L] & rt < Tvec[length(Tvec)]
  if (!any(inside)) {
    return(ll)
  }

  ii <- findInterval(ang[inside], Theta, all.inside = TRUE)
  jj <- findInterval(rt[inside], Tvec, all.inside = TRUE)
  x1 <- Theta[ii]
  x2 <- Theta[ii + 1L]
  y1 <- Tvec[jj]
  y2 <- Tvec[jj + 1L]
  q11 <- Z[cbind(ii, jj)]
  q21 <- Z[cbind(ii + 1L, jj)]
  q12 <- Z[cbind(ii, jj + 1L)]
  q22 <- Z[cbind(ii + 1L, jj + 1L)]
  wx <- (ang[inside] - x1) / (x2 - x1)
  wy <- (rt[inside] - y1) / (y2 - y1)
  v <- (1 - wx) * (1 - wy) * q11 + wx * (1 - wy) * q21 +
    (1 - wx) * wy * q12 + wx * wy * q22
  ok <- is.finite(v) & v > 0
  inside_ix <- which(inside)
  ll[inside_ix[ok]] <- log(v[ok])
  ll
}


# --- Experimental design (nine cells) -----------------------------------------
#group trials by condition
#for each condition:
#  get design values
#compute condition-specific parameters
#run popcdm300 once
#interpolate all trials in that condition

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

BASELINE_COND_LEVELS <- c(
  "set2_baseline",
  "set4_baseline",
  "set6_baseline"
)

REDUNDANCY_BETA_VARIANTS <- c("down_up", "base_nr_r")

#' Smallest ColorNi in the design; alphaEst is baseline B with m = 1 at this reference.
DEFAULT_COLOR_COUNT_REF <- 2L

#' Beta parameter names for a variant (`down_up`: 2; `base_nr_r`: 3).
redundancy_beta_names <- function(variant = c("down_up", "base_nr_r")) {
  variant <- match.arg(variant, REDUNDANCY_BETA_VARIANTS)
  switch(variant,
    down_up = c("beta_down", "beta_up"),
    base_nr_r = c("beta_baseline", "beta_nr", "beta_r")
  )
}

redundancy_resolve_beta_variant <- function(model_spec = redundancy_model_spec()) {
  variant <- model_spec$beta_variant
  if (is.null(variant) || !nzchar(variant)) {
    return("down_up")
  }
  match.arg(variant, REDUNDANCY_BETA_VARIANTS)
}

redundancy_resolve_color_count_ref <- function(model_spec = redundancy_model_spec()) {
  n_ref <- model_spec$color_count_ref
  if (is.null(n_ref)) {
    return(DEFAULT_COLOR_COUNT_REF)
  }
  n_ref <- as.integer(n_ref)
  if (length(n_ref) != 1L || !is.finite(n_ref) || n_ref < 1L) {
    stop("color_count_ref must be a positive integer scalar", call. = FALSE)
  }
  n_ref
}

redundancy_infer_beta_variant_from_names <- function(nm) {
  if ("beta_baseline" %in% nm) {
    return("base_nr_r")
  }
  if ("beta_down" %in% nm) {
    return("down_up")
  }
  stop("cannot infer beta_variant from parameter names", call. = FALSE)
}

#' Classify trials for beta branching (baseline vs partial NR vs R).
redundancy_trial_kind <- function(cond_label) {
  if (!cond_label %in% COND_LEVELS) {
    stop("unknown cond_label: ", cond_label, call. = FALSE)
  }
  if (cond_label %in% BASELINE_COND_LEVELS) {
    "baseline"
  } else if (grepl("_R_cue", cond_label, fixed = TRUE)) {
    "R"
  } else {
    "NR"
  }
}

cue_branch_from_cond <- function(cond_label) {
  kind <- redundancy_trial_kind(cond_label)
  if (identical(kind, "R")) {
    "R"
  } else {
    "NR"
  }
}


# --- Full named parameter vector + P/Sel/Pvar/Pfix --------------------

#' Full parameter names for the maximal redundancy POPCDM.
#'
#' The full vector deliberately contains one condition-specific value for each
#' parameter family that we may later want to constrain: vnorm, kappa, a, ter,
#' and eta1. Simpler model versions are made by fixing/copying entries via `Sel`
#' and `model_spec$equal_groups`. Beta slots depend on `beta_variant`.
redundancy_param_names <- function(beta_variant = c("down_up", "base_nr_r")) {
  beta_variant <- match.arg(beta_variant, REDUNDANCY_BETA_VARIANTS)
  c(
    "alphaEst",
    paste0("vnorm_", COND_LEVELS),
    redundancy_beta_names(beta_variant),
    paste0("kappa_", COND_LEVELS),
    paste0("a_", COND_LEVELS),
    paste0("ter_", COND_LEVELS),
    paste0("eta1_", COND_LEVELS),
    "eta2", "st"
  )
}

redundancy_param_family_names <- function(family) {
  if (!family %in% c("vnorm", "kappa", "a", "ter", "eta1")) {
    stop("unknown condition-specific family: ", family, call. = FALSE)
  }
  paste0(family, "_", COND_LEVELS)
}

#' Default interior bounds for beta exponents (avoids exact 0/1 under logit).
redundancy_beta_bound_defaults <- function() {
  list(lower = 0.02, upper = 0.98, start = 0.4)
}

#' Starting values for the maximal full vector.
redundancy_default_P <- function(
    beta_variant = c("down_up", "base_nr_r"),
    alphaEst = 2.5,
    vnorm = 2.0,
    beta_down = NULL,
    beta_up = NULL,
    beta_baseline = NULL,
    beta_nr = NULL,
    beta_r = NULL,
    kappa = 5.0,
    a = 2.0,
    ter = 0.2,
    eta1 = 1,
    eta2 = 1e-6,
    st = 0.2) {
  beta_variant <- match.arg(beta_variant, REDUNDANCY_BETA_VARIANTS)
  bb <- redundancy_beta_bound_defaults()
  if (is.null(beta_down)) {
    beta_down <- bb$start
  }
  if (is.null(beta_up)) {
    beta_up <- bb$start
  }
  if (is.null(beta_baseline)) {
    beta_baseline <- bb$start
  }
  if (is.null(beta_nr)) {
    beta_nr <- bb$start
  }
  if (is.null(beta_r)) {
    beta_r <- bb$start
  }
  beta_block <- switch(
    beta_variant,
    down_up = c(beta_down = beta_down, beta_up = beta_up),
    base_nr_r = c(
      beta_baseline = beta_baseline,
      beta_nr = beta_nr,
      beta_r = beta_r
    )
  )
  P <- c(
    alphaEst = alphaEst,
    stats::setNames(rep(vnorm, length(COND_LEVELS)), redundancy_param_family_names("vnorm")),
    beta_block,
    stats::setNames(rep(kappa, length(COND_LEVELS)), redundancy_param_family_names("kappa")),
    stats::setNames(rep(a, length(COND_LEVELS)), redundancy_param_family_names("a")),
    stats::setNames(rep(ter, length(COND_LEVELS)), redundancy_param_family_names("ter")),
    stats::setNames(rep(eta1, length(COND_LEVELS)), redundancy_param_family_names("eta1")),
    eta2 = eta2,
    st = st
  )
  P[redundancy_param_names(beta_variant)]
}

# Broad default bounds for the maximal full vector.
redundancy_default_bounds <- function(beta_variant = c("down_up", "base_nr_r")) {
  beta_variant <- match.arg(beta_variant, REDUNDANCY_BETA_VARIANTS)
  bb <- redundancy_beta_bound_defaults()
  beta_lower <- stats::setNames(
    rep(bb$lower, length(redundancy_beta_names(beta_variant))),
    redundancy_beta_names(beta_variant)
  )
  beta_upper <- stats::setNames(
    rep(bb$upper, length(redundancy_beta_names(beta_variant))),
    redundancy_beta_names(beta_variant)
  )
  lower <- c(
    alphaEst = 1.0,
    stats::setNames(rep(1.0, length(COND_LEVELS)), redundancy_param_family_names("vnorm")),
    beta_lower,
    stats::setNames(rep(0.5, length(COND_LEVELS)), redundancy_param_family_names("kappa")),
    stats::setNames(rep(0.1, length(COND_LEVELS)), redundancy_param_family_names("a")),
    stats::setNames(rep(0.001, length(COND_LEVELS)), redundancy_param_family_names("ter")),
    stats::setNames(rep(0.01, length(COND_LEVELS)), redundancy_param_family_names("eta1")),
    eta2 = 1e-6,
    st = 0
  )
  upper <- c(
    alphaEst = 20.0,
    stats::setNames(rep(10.0, length(COND_LEVELS)), redundancy_param_family_names("vnorm")),
    beta_upper,
    stats::setNames(rep(20.0, length(COND_LEVELS)), redundancy_param_family_names("kappa")),
    stats::setNames(rep(8.0, length(COND_LEVELS)), redundancy_param_family_names("a")),
    stats::setNames(rep(1.0, length(COND_LEVELS)), redundancy_param_family_names("ter")),
    stats::setNames(rep(4.0, length(COND_LEVELS)), redundancy_param_family_names("eta1")),
    eta2 = 0.001,
    st = 0.4
  )
  nm <- redundancy_param_names(beta_variant)
  list(lower = lower[nm], upper = upper[nm])
}

#' Default selector: all exploratory parameters free, eta2 and st fixed.
redundancy_default_sel <- function(
    beta_variant = c("down_up", "base_nr_r"),
    free_eta2 = FALSE,
    free_st = FALSE) {
  beta_variant <- match.arg(beta_variant, REDUNDANCY_BETA_VARIANTS)
  nm <- redundancy_param_names(beta_variant)
  Sel <- stats::setNames(rep(TRUE, length(nm)), nm)
  Sel["eta2"] <- isTRUE(free_eta2)
  Sel["st"] <- isTRUE(free_st)
  Sel
}

redundancy_model_spec <- function(
    equal_groups = list(),
    label = "full_condition",
    beta_variant = c("down_up", "base_nr_r"),
    color_count_ref = DEFAULT_COLOR_COUNT_REF) {
  beta_variant <- match.arg(beta_variant, REDUNDANCY_BETA_VARIANTS)
  color_count_ref <- as.integer(color_count_ref)
  if (length(color_count_ref) != 1L || !is.finite(color_count_ref) || color_count_ref < 1L) {
    stop("color_count_ref must be a positive integer scalar", call. = FALSE)
  }
  list(
    label = label,
    equal_groups = redundancy_normalize_equal_groups(equal_groups),
    beta_variant = beta_variant,
    color_count_ref = color_count_ref
  )
}

#' Helper for readable equality constraints.
#'
#' Example:
#'   redundancy_equal_group("kappa", c("set4_baseline", "set4_R_cue", "set4_NR_cue"))
#' means the first listed condition is the representative and the other kappas
#' are copied from it inside every likelihood evaluation.
redundancy_equal_group <- function(family, cond_labels) {
  if (!all(cond_labels %in% COND_LEVELS)) {
    stop("all cond_labels must be in COND_LEVELS", call. = FALSE)
  }
  paste0(family, "_", cond_labels)
}

#' Drop NULL / empty entries (e.g. from a trailing comma in list(...)).
redundancy_normalize_equal_groups <- function(equal_groups = list()) {
  if (!length(equal_groups)) {
    return(list())
  }
  Filter(
    function(grp) {
      !is.null(grp) && length(grp) >= 1L && nzchar(grp[[1L]])
    },
    equal_groups
  )
}

redundancy_apply_equal_groups <- function(P, equal_groups = list()) {
  equal_groups <- redundancy_normalize_equal_groups(equal_groups)
  if (!length(equal_groups)) {
    return(P)
  }
  for (grp in equal_groups) {
    if (length(grp) < 2L) {
      next
    }
    if (!all(grp %in% names(P))) {
      stop("equal group contains unknown parameter(s): ", paste(setdiff(grp, names(P)), collapse = ", "), call. = FALSE)
    }
    P[grp[-1L]] <- P[grp[1L]]
  }
  P
}

redundancy_sel_for_equal_groups <- function(
    Sel,
    equal_groups = list(),
    beta_variant = NULL) {
  equal_groups <- redundancy_normalize_equal_groups(equal_groups)
  Sel <- redundancy_check_named_full_vector(Sel, "Sel", beta_variant = beta_variant)
  Sel <- stats::setNames(as.logical(Sel), names(Sel))
  for (grp in equal_groups) {
    if (length(grp) >= 2L) {
      Sel[grp[-1L]] <- FALSE
    }
  }
  Sel
}

redundancy_check_named_full_vector <- function(
    x,
    arg_name = "P",
    beta_variant = NULL) {
  if (is.null(beta_variant)) {
    if (is.null(names(x)) || !length(names(x))) {
      stop(arg_name, " must be named to infer beta_variant", call. = FALSE)
    }
    beta_variant <- redundancy_infer_beta_variant_from_names(names(x))
  } else {
    beta_variant <- match.arg(beta_variant, REDUNDANCY_BETA_VARIANTS)
  }
  nm <- redundancy_param_names(beta_variant)
  if (is.null(names(x)) || !setequal(names(x), nm)) {
    extra <- setdiff(names(x), nm)
    missing <- setdiff(nm, names(x))
    stop(
      arg_name,
      " must be a named vector with exactly the full redundancy parameter names for beta_variant='",
      beta_variant, "'.",
      if (length(extra)) paste0(" Unexpected: ", paste(extra, collapse = ", "), ".") else "",
      if (length(missing)) paste0(" Missing: ", paste(missing, collapse = ", "), ".") else "",
      call. = FALSE
    )
  }
  x[nm]
}

redundancy_split_P <- function(P, Sel) {
  beta_variant <- redundancy_infer_beta_variant_from_names(names(P))
  P <- redundancy_check_named_full_vector(P, "P", beta_variant = beta_variant)
  Sel <- redundancy_check_named_full_vector(Sel, "Sel", beta_variant = beta_variant)
  Sel <- stats::setNames(as.logical(Sel), names(Sel))
  list(
    P_var = P[Sel],
    P_fix = P[!Sel],
    Sel = Sel
  )
}

redundancy_full_P_from_var <- function(
    P_var,
    P_fix,
    Sel,
    model_spec = redundancy_model_spec()) {
  beta_variant <- redundancy_resolve_beta_variant(model_spec)
  Sel <- redundancy_check_named_full_vector(Sel, "Sel", beta_variant = beta_variant)
  Sel <- stats::setNames(as.logical(Sel), names(Sel))
  expected_var <- names(Sel)[Sel]
  expected_fix <- names(Sel)[!Sel]
  if (length(P_var) != sum(Sel)) {
    stop("P_var length must equal sum(Sel)", call. = FALSE)
  }
  if (length(P_fix) != sum(!Sel)) {
    stop("P_fix length must equal sum(!Sel)", call. = FALSE)
  }
  if (!is.null(names(P_var))) {
    if (!setequal(names(P_var), expected_var)) {
      stop("P_var names must match names(Sel)[Sel]", call. = FALSE)
    }
    P_var <- P_var[expected_var]
  }
  if (!is.null(names(P_fix))) {
    if (!setequal(names(P_fix), expected_fix)) {
      stop("P_fix names must match names(Sel)[!Sel]", call. = FALSE)
    }
    P_fix <- P_fix[expected_fix]
  }
  beta_variant <- redundancy_resolve_beta_variant(model_spec)
  nm <- redundancy_param_names(beta_variant)
  P <- stats::setNames(rep(NA_real_, length(nm)), nm)
  P[Sel] <- as.numeric(P_var)
  P[!Sel] <- as.numeric(P_fix)
  P <- P[nm]
  redundancy_apply_equal_groups(P, model_spec$equal_groups)
}

redundancy_sync_beta_variant <- function(model_spec, P_start = NULL, Sel = NULL) {
  beta_variant <- redundancy_resolve_beta_variant(model_spec)
  inferred <- NULL
  if (!is.null(P_start) && length(names(P_start))) {
    inferred <- redundancy_infer_beta_variant_from_names(names(P_start))
  } else if (!is.null(Sel) && length(names(Sel))) {
    inferred <- redundancy_infer_beta_variant_from_names(names(Sel))
  }
  if (!is.null(inferred) && !identical(inferred, beta_variant)) {
    warning(
      "model_spec$beta_variant='", beta_variant,
      "' does not match parameter names (inferred '", inferred,
      "'). Using inferred variant.",
      call. = FALSE
    )
    beta_variant <- inferred
    model_spec$beta_variant <- inferred
  }
  list(model_spec = model_spec, beta_variant = beta_variant)
}

redundancy_fit_inputs <- function(
    P_start = NULL,
    lower = NULL,
    upper = NULL,
    Sel = NULL,
    model_spec = redundancy_model_spec()) {
  synced <- redundancy_sync_beta_variant(model_spec, P_start = P_start, Sel = Sel)
  model_spec <- synced$model_spec
  beta_variant <- synced$beta_variant
  if (is.null(P_start)) {
    P_start <- redundancy_default_P(beta_variant = beta_variant)
  }
  if (is.null(lower) || is.null(upper)) {
    bb <- redundancy_default_bounds(beta_variant = beta_variant)
    if (is.null(lower)) {
      lower <- bb$lower
    }
    if (is.null(upper)) {
      upper <- bb$upper
    }
  }
  if (is.null(Sel)) {
    Sel <- redundancy_default_sel(beta_variant = beta_variant)
  }
  P_start <- redundancy_check_named_full_vector(P_start, "P_start", beta_variant = beta_variant)
  lower <- redundancy_check_named_full_vector(lower, "lower", beta_variant = beta_variant)
  upper <- redundancy_check_named_full_vector(upper, "upper", beta_variant = beta_variant)
  Sel <- redundancy_check_named_full_vector(Sel, "Sel", beta_variant = beta_variant)
  Sel <- redundancy_sel_for_equal_groups(
    Sel,
    model_spec$equal_groups,
    beta_variant = beta_variant
  )
  if (any(lower >= upper)) {
    stop("all lower bounds must be less than upper bounds", call. = FALSE)
  }
  split <- redundancy_split_P(P_start, Sel)
  list(
    P_var_start = split$P_var,
    P_fix = split$P_fix,
    Sel = split$Sel,
    lower = lower[split$Sel],
    upper = upper[split$Sel],
    model_spec = model_spec
  )
}

redundancy_condition_params <- function(
    P,
    cond_label,
    model_spec = redundancy_model_spec()) {
  if (!cond_label %in% COND_LEVELS) {
    stop("unknown cond_label: ", cond_label, call. = FALSE)
  }
  beta_variant <- redundancy_resolve_beta_variant(model_spec)
  beta_nm <- redundancy_beta_names(beta_variant)
  betas <- stats::setNames(
    as.numeric(P[beta_nm]),
    beta_nm
  )
  out <- list(
    alphaEst = unname(P["alphaEst"]),
    vnorm = unname(P[paste0("vnorm_", cond_label)]),
    betas = betas,
    beta_variant = beta_variant,
    kappa = unname(P[paste0("kappa_", cond_label)]),
    a = unname(P[paste0("a_", cond_label)]),
    ter = unname(P[paste0("ter_", cond_label)]),
    eta1 = unname(P[paste0("eta1_", cond_label)]),
    eta2 = unname(P["eta2"]),
    st = unname(P["st"])
  )
  for (bn in beta_nm) {
    out[[bn]] <- unname(P[bn])
  }
  out
}

#' Report beta parameters on or near box bounds (physical scale).
redundancy_beta_bound_report <- function(
    P_var_hat,
    lower,
    upper,
    model_spec = redundancy_model_spec(),
    tol_frac = 0.02) {
  if (is.null(names(P_var_hat))) {
    stop("P_var_hat must be named", call. = FALSE)
  }
  beta_nm <- redundancy_beta_names(redundancy_resolve_beta_variant(model_spec))
  beta_nm <- intersect(beta_nm, names(P_var_hat))
  if (!length(beta_nm)) {
    return(data.frame(parameter = character(), value = numeric(), bound = character(), stringsAsFactors = FALSE))
  }
  rows <- vector("list", length(beta_nm))
  for (bn in beta_nm) {
    v <- P_var_hat[bn]
    lo <- lower[bn]
    hi <- upper[bn]
    span <- hi - lo
    on_lo <- is.finite(v) && is.finite(lo) && v <= lo + tol_frac * span
    on_hi <- is.finite(v) && is.finite(hi) && v >= hi - tol_frac * span
    bound <- if (on_lo && on_hi) {
      "both"
    } else if (on_lo) {
      "lower"
    } else if (on_hi) {
      "upper"
    } else {
      NA_character_
    }
    if (!is.na(bound)) {
      rows[[bn]] <- data.frame(
        parameter = bn,
        value = v,
        bound = bound,
        stringsAsFactors = FALSE
      )
    }
  }
  if (!length(rows)) {
    return(data.frame(parameter = character(), value = numeric(), bound = character(), stringsAsFactors = FALSE))
  }
  do.call(rbind, rows)
}

redundancy_popcdm_P8 <- function(pr, alpha) {
  c(pr$vnorm, pr$eta1, pr$eta2, pr$a, alpha, pr$kappa, pr$ter, pr$st)
}


# --- Grid / RT audit (step 1: tmax, nw, h) ------------------------------------

#' Time grid used by `popcdm300` (same construction as in engine).
redundancy_time_grid_length <- function(tmax, h) {
  length(seq(0, tmax, by = h))
}

#' Summarise RTs vs `tmax` and discrete grid size. Use before locking `tmax`/`h`/`nw`.
#'
#' If many trials have `rt_sec >= tmax`, joint density is evaluated on the
#' contaminant fallback and the NLL is distorted. Prefer `tmax` above high RT
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
#
# alphaEst = theoretical resource baseline B (set-size-1 equivalent).
# Down-scaling: (ColorNi / color_count_ref)^(-beta), default color_count_ref = 2.
# R trials: down term uses cued ColorNi; up term uses n_redundant^beta (variant-specific).
#
# down_up:    m = (ci/n_ref)^(-beta_down) * n_red^beta_up  [R only for up term]
# base_nr_r:  baseline/NR/R betas on (ci/n_ref); R adds n_red^beta_r
redundancy_branch_m_invalid_reason <- function(
    m,
    log_m = NA_real_,
    cond_label = NA_character_,
    betas = NULL) {
  if (!is.null(betas) && any(!is.finite(betas))) {
    bad <- names(betas)[!is.finite(betas)]
    return(paste0("non-finite beta(s): ", paste(bad, collapse = ", ")))
  }
  if (!is.finite(log_m)) {
    return("log(m) not finite (overflow/underflow in power law)")
  }
  if (!is.finite(m)) {
    return("m not finite")
  }
  if (m <= 0) {
    return("m <= 0 (underflow)")
  }
  paste0("invalid m for cond_label=", cond_label)
}

redundancy_branch_m <- function(
    cond_label,
    num_itemsi,
    ColorNi,
    redundancy,
    betas,
    beta_variant = c("down_up", "base_nr_r"),
    color_count_ref = DEFAULT_COLOR_COUNT_REF,
    strict = FALSE) {
  beta_variant <- match.arg(beta_variant, REDUNDANCY_BETA_VARIANTS)
  ni <- as.integer(num_itemsi)
  ci <- as.integer(ColorNi)
  n_ref <- as.integer(color_count_ref)
  if (length(ni) != 1L || length(ci) != 1L || length(redundancy) != 1L) {
    msg <- "scalar num_itemsi, ColorNi, redundancy only"
    if (strict) stop(msg, call. = FALSE)
    return(NA_real_)
  }
  if (length(n_ref) != 1L || !is.finite(n_ref) || n_ref < 1L) {
    msg <- "color_count_ref must be a positive integer scalar"
    if (strict) stop(msg, call. = FALSE)
    return(NA_real_)
  }
  if (ci < 1L) {
    msg <- "ColorNi must be >= 1"
    if (strict) stop(msg, call. = FALSE)
    return(NA_real_)
  }
  if (is.null(names(betas))) {
    msg <- "betas must be a named vector"
    if (strict) stop(msg, call. = FALSE)
    return(NA_real_)
  }
  expected <- redundancy_beta_names(beta_variant)
  if (!all(expected %in% names(betas))) {
    msg <- paste0(
      "betas missing names for beta_variant='", beta_variant, "': ",
      paste(setdiff(expected, names(betas)), collapse = ", ")
    )
    if (strict) stop(msg, call. = FALSE)
    return(NA_real_)
  }
  betas <- stats::setNames(as.numeric(betas[expected]), expected)
  if (any(!is.finite(betas))) {
    msg <- redundancy_branch_m_invalid_reason(NA, betas = betas)
    if (strict) stop("alpha branch multiplier invalid: ", msg, call. = FALSE)
    return(NA_real_)
  }

  log_ci_over_ref <- log(as.numeric(ci)) - log(as.numeric(n_ref))
  log_m <- NA_real_

  if (identical(beta_variant, "down_up")) {
    beta_down <- betas["beta_down"]
    beta_up <- betas["beta_up"]
    log_m <- -beta_down * log_ci_over_ref
    if (identical(redundancy, "Redundant Cued")) {
      n_redundant <- as.integer(ni - ci + 1L)
      if (!is.finite(n_redundant) || n_redundant < 1L) {
        msg <- "n_redundant = num_itemsi - ColorNi + 1 must be >= 1"
        if (strict) stop(msg, call. = FALSE)
        return(NA_real_)
      }
      log_m <- log_m + beta_up * log(as.numeric(n_redundant))
    } else if (!identical(redundancy, "Non-Redundant Cued")) {
      msg <- "redundancy must be 'Redundant Cued' or 'Non-Redundant Cued'"
      if (strict) stop(msg, call. = FALSE)
      return(NA_real_)
    }
  } else {
    kind <- redundancy_trial_kind(cond_label)
    if (identical(kind, "baseline")) {
      log_m <- -betas["beta_baseline"] * log_ci_over_ref
    } else if (identical(kind, "NR")) {
      log_m <- -betas["beta_nr"] * log_ci_over_ref
    } else if (identical(kind, "R")) {
      n_redundant <- as.integer(ni - ci + 1L)
      if (!is.finite(n_redundant) || n_redundant < 1L) {
        msg <- "n_redundant = num_itemsi - ColorNi + 1 must be >= 1"
        if (strict) stop(msg, call. = FALSE)
        return(NA_real_)
      }
      beta_r <- betas["beta_r"]
      log_m <- -beta_r * log_ci_over_ref + beta_r * log(as.numeric(n_redundant))
    } else {
      msg <- paste0("unknown trial kind for cond_label: ", cond_label)
      if (strict) stop(msg, call. = FALSE)
      return(NA_real_)
    }
  }

  if (!is.finite(log_m) || log_m > 700 || log_m < -700) {
    msg <- redundancy_branch_m_invalid_reason(NA, log_m = log_m, cond_label = cond_label, betas = betas)
    if (strict) stop("alpha branch multiplier invalid: ", msg, call. = FALSE)
    return(NA_real_)
  }
  m <- exp(log_m)
  if (!is.finite(m) || m <= 0) {
    msg <- redundancy_branch_m_invalid_reason(m, log_m = log_m, cond_label = cond_label, betas = betas)
    if (strict) stop("alpha branch multiplier invalid: ", msg, call. = FALSE)
    return(NA_real_)
  }
  m
}

redundancy_branch_m_from_design <- function(
    cond_label,
    num_itemsi,
    ColorNi,
    redundancy,
    P,
    model_spec = redundancy_model_spec(),
    strict = FALSE) {
  pr <- tryCatch(
    redundancy_condition_params(P, cond_label, model_spec = model_spec),
    error = function(e) NULL
  )
  if (is.null(pr)) {
    if (strict) {
      stop("could not build condition params for ", cond_label, call. = FALSE)
    }
    return(NA_real_)
  }
  redundancy_branch_m(
    cond_label,
    num_itemsi,
    ColorNi,
    redundancy,
    betas = pr$betas,
    beta_variant = pr$beta_variant,
    color_count_ref = redundancy_resolve_color_count_ref(model_spec),
    strict = strict
  )
}

#' Pre-fit check: evaluate m for every design condition at a parameter vector.
redundancy_branch_m_audit <- function(
    P,
    model_spec = redundancy_model_spec()) {
  beta_variant <- redundancy_resolve_beta_variant(model_spec)
  P <- redundancy_check_named_full_vector(P, "P", beta_variant = beta_variant)
  tab <- redundancy_cond_design_table()
  rows <- vector("list", nrow(tab))
  for (i in seq_len(nrow(tab))) {
    cl <- tab$cond_label[i]
    m <- redundancy_branch_m_from_design(
      cl,
      tab$num_itemsi[i],
      tab$ColorNi[i],
      tab$redundancy[i],
      P,
      model_spec = model_spec,
      strict = FALSE
    )
    pr <- redundancy_condition_params(P, cl, model_spec = model_spec)
    rows[[i]] <- data.frame(
      cond_label = cl,
      trial_kind = redundancy_trial_kind(cl),
      ColorNi = tab$ColorNi[i],
      num_itemsi = tab$num_itemsi[i],
      color_count_ref = redundancy_resolve_color_count_ref(model_spec),
      m = m,
      ok = is.finite(m) && m > 0,
      betas = paste(
        sprintf("%s=%.4f", names(pr$betas), as.numeric(pr$betas)),
        collapse = ", "
      ),
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}

#' Negative log-likelihood (minimise). One `popcdm300` surface per `cond_label`.
redundancy_nll <- function(
    P_var,
    fit_df,
    P_fix,
    Sel,
    model_spec = redundancy_model_spec(),
    nw = 56L,
    h = 0.0025,
    tmax = 5.0,
    contam_density = 0.05,
    penalty_nll = 1e12,
    trace = FALSE) {
  P_full <- tryCatch(
    redundancy_full_P_from_var(P_var, P_fix, Sel, model_spec = model_spec),
    error = function(e) NULL
  )
  if (is.null(P_full) || any(!is.finite(P_full))) {
    return(penalty_nll)
  }
  beta_nm <- redundancy_beta_names(redundancy_resolve_beta_variant(model_spec))
  if (any(!is.finite(P_full[beta_nm]))) {
    return(penalty_nll)
  }
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
    m <- tryCatch(
      redundancy_branch_m_from_design(
        cl,
        row_design$num_itemsi,
        row_design$ColorNi,
        row_design$redundancy,
        P_full,
        model_spec = model_spec,
        strict = FALSE
      ),
      error = function(e) NA_real_
    )
    if (!is.finite(m) || m <= 0) {
      return(penalty_nll)
    }
    pr <- redundancy_condition_params(P_full, cl, model_spec = model_spec)
    alpha_trial <- pr$alphaEst * m
    if (!is.finite(alpha_trial) || alpha_trial <= 0) {
      return(penalty_nll)
    }
    P8 <- redundancy_popcdm_P8(pr, alpha_trial)
    if (any(!is.finite(P8)) || any(P8 <= 0)) {
      return(penalty_nll)
    }
    out <- tryCatch(
      popcdm300(P8, nw = nw, h = h, tmax = tmax, return_components = FALSE),
      error = function(e) NULL
    )
    if (is.null(out) || any(!is.finite(out$Gt))) {
      return(penalty_nll)
    }
    ll_total <- ll_total + sum(interp_joint_linear_vec(
      out$Theta,
      out$T,
      out$Gt,
      rows$angle_rad,
      rows$rt_sec,
      contam_density = contam_density
    ))
  }
  if (!is.finite(ll_total)) {
    return(penalty_nll)
  }
  -ll_total
}

#' Mesh-edge and floor diagnostics for one `P_var`.
#'
#' For each trial, checks whether `(angle_rad, rt_sec)` lies strictly inside the
#' `Theta` and `T` meshes returned by `popcdm300` for that trial's condition.
#' If many trials sit on RT or angle **edges**, the summed log likelihood is
#' driven by the **contaminant fallback** and optima can be pulled toward extreme
#' `alphaEst`, `kappa`, or `beta` values.
redundancy_mesh_hit_rates <- function(
    P_var,
    fit_df,
    P_fix,
    Sel,
    model_spec = redundancy_model_spec(),
    nw = 56L,
    h = 0.0025,
    tmax = 5.0,
    contam_density = 0.05,
    eps_floor = 1e-6) {
  if (!is.finite(contam_density) || contam_density <= 0) {
    stop("contam_density must be a finite positive scalar", call. = FALSE)
  }
  log_contam <- log(contam_density)
  fit_df <- fit_df[!is.na(fit_df$cond_label), , drop = FALSE]
  if (!nrow(fit_df)) {
    stop("no trials", call. = FALSE)
  }
  P_full <- redundancy_full_P_from_var(P_var, P_fix, Sel, model_spec = model_spec)
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
    m <- redundancy_branch_m_from_design(
      cl,
      row_design$num_itemsi,
      row_design$ColorNi,
      row_design$redundancy,
      P_full,
      model_spec = model_spec,
      strict = FALSE
    )
    if (!is.finite(m) || m <= 0) {
      next
    }
    pr <- redundancy_condition_params(P_full, cl, model_spec = model_spec)
    alpha_trial <- pr$alphaEst * m
    if (!is.finite(alpha_trial) || alpha_trial <= 0) {
      next
    }
    P8 <- redundancy_popcdm_P8(pr, alpha_trial)
    out <- popcdm300(P8, nw = nw, h = h, tmax = tmax, return_components = FALSE)
    Th <- out$Theta
    Tv <- out$T
    nTh <- length(Th)
    nTv <- length(Tv)
    ang <- rows$angle_rad
    rt <- rows$rt_sec
    edge <- (ang <= Th[1L] || ang >= Th[nTh] || rt <= Tv[1L] || rt >= Tv[nTv])
    ll <- interp_joint_linear_vec(Th, Tv, out$Gt, ang, rt, contam_density = contam_density)
    n_eval <- n_eval + length(ang)
    n_edge_mesh <- n_edge_mesh + sum(edge)
    n_floor_ll <- n_floor_ll + sum(ll <= log_contam + eps_floor)
  }
  data.frame(
    n_eval = n_eval,
    frac_on_mesh_edge = n_edge_mesh / n_eval,
    frac_ll_at_contam = n_floor_ll / n_eval,
    stringsAsFactors = FALSE
  )
}


# --- Prediction and plotting helpers ------------------------------------------

redundancy_predict_condition <- function(
    P,
    cond_label,
    model_spec = NULL,
    nw = 56L,
    h = 0.0025,
    tmax = 5.0) {
  if (is.null(model_spec)) {
    model_spec <- redundancy_model_spec(
      beta_variant = redundancy_infer_beta_variant_from_names(names(P))
    )
  }
  beta_variant <- redundancy_resolve_beta_variant(model_spec)
  P <- redundancy_check_named_full_vector(P, "P", beta_variant = beta_variant)
  tab <- redundancy_cond_design_table()
  row_design <- tab[tab$cond_label == cond_label, , drop = FALSE]
  if (nrow(row_design) != 1L) {
    stop("unknown cond_label: ", cond_label, call. = FALSE)
  }
  m <- redundancy_branch_m_from_design(
    cond_label,
    row_design$num_itemsi,
    row_design$ColorNi,
    row_design$redundancy,
    P,
    model_spec = model_spec,
    strict = TRUE
  )
  pr <- redundancy_condition_params(P, cond_label, model_spec = model_spec)
  alpha_trial <- pr$alphaEst * m
  P8 <- redundancy_popcdm_P8(pr, alpha_trial)
  out <- popcdm300(P8, nw = nw, h = h, tmax = tmax, return_components = FALSE)
  list(cond_label = cond_label, P8 = P8, alpha_trial = alpha_trial, out = out)
}

redundancy_angle_marginal_df <- function(pred) {
  theta <- pred$out$Theta
  dens <- pmax(pred$out$Ptheta, 0)
  w <- 2 * pi / length(theta)
  mass <- sum(dens) * w
  if (is.finite(mass) && mass > 0) {
    dens <- dens / mass
  }
  data.frame(angle_rad = theta, density = dens, stringsAsFactors = FALSE)
}

redundancy_rt_marginal_df <- function(pred) {
  theta <- pred$out$Theta
  Tvec <- pred$out$T
  Gt <- pred$out$Gt
  w <- 2 * pi / length(theta)
  h <- if (length(Tvec) > 1L) stats::median(diff(Tvec)) else 1
  dens <- pmax(colSums(Gt) * w, 0)
  mass <- sum(dens) * h
  if (is.finite(mass) && mass > 0) {
    dens <- dens / mass
  }
  data.frame(rt_sec = Tvec, density = dens, stringsAsFactors = FALSE)
}

plot_redundancy_error_marginals <- function(
    fit_df,
    P,
    model_spec = NULL,
    cond_labels = COND_LEVELS,
    nw = 56L,
    h = 0.0025,
    tmax = 5.0,
    n_bins = 30L,
    xlim = c(-pi, pi),
    ylim = NULL) {
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(oldpar), add = TRUE)
  graphics::par(mfrow = c(3, 3), mar = c(3.2, 3.2, 2.2, 0.8), xaxs = "i", yaxs = "i")
  breaks <- seq(-pi, pi, length.out = as.integer(n_bins) + 1L)
  pred_list <- lapply(cond_labels, function(cl) {
    redundancy_angle_marginal_df(
      redundancy_predict_condition(P, cl, model_spec = model_spec, nw = nw, h = h, tmax = tmax)
    )
  })
  names(pred_list) <- cond_labels
  hist_list <- lapply(cond_labels, function(cl) {
    rows <- fit_df[fit_df$cond_label == cl, , drop = FALSE]
    graphics::hist(rows$angle_rad, breaks = breaks, plot = FALSE)
  })
  names(hist_list) <- cond_labels
  if (is.null(ylim)) {
    hist_max <- vapply(hist_list, function(hh) max(hh$density, na.rm = TRUE), numeric(1))
    model_max <- vapply(pred_list, function(adf) max(adf$density, na.rm = TRUE), numeric(1))
    ymax <- max(c(hist_max, model_max), na.rm = TRUE)
    ylim <- c(0, ymax * 1.05)
  }
  for (cl in cond_labels) {
    hh <- hist_list[[cl]]
    adf <- pred_list[[cl]]
    graphics::plot(
      hh,
      freq = FALSE,
      col = "grey85",
      border = "white",
      main = cl,
      xlab = "Signed error (rad)",
      ylab = "Density",
      xlim = xlim,
      ylim = ylim
    )
    graphics::lines(adf$angle_rad, adf$density, col = "#AA0044", lwd = 2)
  }
}

plot_redundancy_rt_marginals <- function(
    fit_df,
    P,
    model_spec = NULL,
    cond_labels = COND_LEVELS,
    nw = 56L,
    h = 0.0025,
    tmax = 5.0,
    n_bins = 30L,
    xlim = NULL,
    ylim = NULL) {
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(oldpar), add = TRUE)
  graphics::par(mfrow = c(3, 3), mar = c(3.2, 3.2, 2.2, 0.8), xaxs = "i", yaxs = "i")
  pred_list <- lapply(cond_labels, function(cl) {
    redundancy_rt_marginal_df(
      redundancy_predict_condition(P, cl, model_spec = model_spec, nw = nw, h = h, tmax = tmax)
    )
  })
  names(pred_list) <- cond_labels
  if (is.null(xlim)) {
    rt <- fit_df$rt_sec[fit_df$cond_label %in% cond_labels]
    rt <- rt[is.finite(rt)]
    pred_rt <- unlist(lapply(pred_list, function(rdf) rdf$rt_sec), use.names = FALSE)
    xlim <- range(c(rt, pred_rt), finite = TRUE)
  }
  breaks <- seq(xlim[1L], xlim[2L], length.out = as.integer(n_bins) + 1L)
  hist_list <- lapply(cond_labels, function(cl) {
    rows <- fit_df[fit_df$cond_label == cl, , drop = FALSE]
    graphics::hist(rows$rt_sec, breaks = breaks, plot = FALSE)
  })
  names(hist_list) <- cond_labels
  if (is.null(ylim)) {
    hist_max <- vapply(hist_list, function(hh) max(hh$density, na.rm = TRUE), numeric(1))
    model_max <- vapply(pred_list, function(rdf) max(rdf$density, na.rm = TRUE), numeric(1))
    ymax <- max(c(hist_max, model_max), na.rm = TRUE)
    ylim <- c(0, ymax * 1.05)
  }
  for (cl in cond_labels) {
    hh <- hist_list[[cl]]
    rdf <- pred_list[[cl]]
    graphics::plot(
      hh,
      freq = FALSE,
      col = "grey85",
      border = "white",
      main = cl,
      xlab = "RT (s)",
      ylab = "Density",
      xlim = xlim,
      ylim = ylim
    )
    graphics::lines(rdf$rt_sec, rdf$density, col = "#225522", lwd = 2)
  }
}


#' 1D slices of NLL: vary `P_var[par_index]` over `par_values`, other coordinates
#' fixed at `P_var_ref`. Use to see ridges (e.g. `alphaEst` vs `kappa`) or
#' multimodality. `par_values` are on the **physical** scale (same as `P_var`).
redundancy_curve_nll_1d <- function(
    par_index,
    par_values,
    P_var_ref,
    fit_df,
    P_fix,
    Sel,
    model_spec = redundancy_model_spec(),
    ...) {
  ni <- as.integer(par_index)
  if (length(ni) != 1L || ni < 1L || ni > length(P_var_ref)) {
    stop("par_index must be one integer in 1:length(P_var_ref)", call. = FALSE)
  }
  vals <- as.numeric(par_values)
  nlls <- vapply(vals, function(v) {
    P <- P_var_ref
    P[ni] <- v
    redundancy_nll(P, fit_df = fit_df, P_fix = P_fix, Sel = Sel, model_spec = model_spec, ...)
  }, numeric(1))
  data.frame(value = vals, nll = nlls, par_index = ni, stringsAsFactors = FALSE)
}

redundancy_optim_beta_names <- function(model_spec = redundancy_model_spec()) {
  if (!is.null(model_spec$scaling_mode) && identical(model_spec$scaling_mode, "none")) {
    return(character(0))
  }
  redundancy_beta_names(redundancy_resolve_beta_variant(model_spec))
}

fit_redundancy_popcdm_participant <- function(
    fit_df,
    P_var_start,
    lower,
    upper,
    P_fix,
    Sel,
    model_spec = redundancy_model_spec(),
    method = "L-BFGS-B",
    beta_link = c("identity", "logit"),
    beta_latent_limit = 15,
    progress = FALSE,
    progress_every = 5L,
    progress_label = NULL,
    ...,
    control = list(maxit = 120L, factr = 1e7)) {
  beta_link <- match.arg(beta_link)
  if (length(lower) != length(P_var_start) || length(upper) != length(P_var_start)) {
    stop("lower/upper same length as P_var_start", call. = FALSE)
  }
  if (is.null(names(P_var_start))) {
    stop("P_var_start must be named", call. = FALSE)
  }
  beta_nm <- redundancy_optim_beta_names(model_spec)
  beta_idx <- match(beta_nm, names(P_var_start), nomatch = 0L)
  beta_idx <- beta_idx[beta_idx > 0L]
  if (length(beta_idx) != length(beta_nm)) {
    stop(
      "P_var_start missing beta parameters for variant '",
      redundancy_resolve_beta_variant(model_spec), "'",
      call. = FALSE
    )
  }
  lower_phys <- lower
  upper_phys <- upper
  bo <- redundancy_optim_bounds_from_phys(
    lower_phys,
    upper_phys,
    beta_link = beta_link,
    beta_idx = beta_idx,
    beta_latent_limit = beta_latent_limit
  )
  par0 <- redundancy_Pvar_working_from_phys(
    P_var_start,
    lower_phys,
    upper_phys,
    beta_link = beta_link,
    beta_idx = beta_idx
  )
  eval_count <- 0L
  progress_every <- max(1L, as.integer(progress_every))
  progress_maxit <- if (!is.null(control$maxit) && is.finite(control$maxit)) {
    as.integer(control$maxit)
  } else {
    NA_integer_
  }
  fn <- function(par_w) {
    pv <- redundancy_Pvar_phys_from_working(
      par_w,
      lower_phys,
      upper_phys,
      beta_link = beta_link,
      beta_idx = beta_idx
    )
    names(pv) <- names(P_var_start)
    nll <- redundancy_nll(
      pv,
      fit_df = fit_df,
      P_fix = P_fix,
      Sel = Sel,
      model_spec = model_spec,
      ...
    )
    eval_count <<- eval_count + 1L
    if (isTRUE(progress) && (eval_count == 1L || eval_count %% progress_every == 0L)) {
      prefix <- if (is.null(progress_label)) "optim" else progress_label
      pct <- if (is.na(progress_maxit)) {
        ""
      } else {
        paste0(" ~", min(100L, round(100 * eval_count / progress_maxit)), "%")
      }
      message(sprintf("%s eval %d%s: nll = %.3f", prefix, eval_count, pct, nll))
    }
    nll
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
    beta_link = beta_link,
    beta_idx = beta_idx
  )
  names(P_var_hat) <- names(P_var_start)
  P_hat <- redundancy_full_P_from_var(P_var_hat, P_fix, Sel, model_spec = model_spec)
  beta_bound_report <- redundancy_beta_bound_report(
    P_var_hat,
    lower_phys,
    upper_phys,
    model_spec = model_spec
  )
  list(
    optim = fit,
    P_hat = P_hat,
    P_var_hat = P_var_hat,
    optim_par_working = if (identical(beta_link, "logit")) fit$par else NULL,
    nll = fit$value,
    n_trials = nrow(fit_df),
    np_free = length(P_var_start),
    P_fix = P_fix,
    Sel = Sel,
    model_spec = model_spec,
    beta_bound_report = beta_bound_report,
    fit_meta = list(
      beta_variant = redundancy_resolve_beta_variant(model_spec),
      color_count_ref = redundancy_resolve_color_count_ref(model_spec),
      beta_link = beta_link,
      beta_latent_limit = beta_latent_limit,
      lower_phys = lower_phys,
      upper_phys = upper_phys,
      note = if (identical(beta_link, "logit")) {
        "optim$par is on the latent scale for beta parameters; use P_var_hat for physical betas."
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
    P_fix,
    Sel,
    model_spec = redundancy_model_spec(),
    n_starts = 8L,
    seed = NULL,
    method = "L-BFGS-B",
    beta_link = c("identity", "logit"),
    beta_latent_limit = 15,
    progress = FALSE,
    progress_every = 5L,
    ...,
    control = list(maxit = 200L, factr = 1e7)) {
  beta_link <- match.arg(beta_link)
  if (is.null(names(P_var_start))) {
    stop("P_var_start must be named", call. = FALSE)
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
  beta_nm <- redundancy_optim_beta_names(model_spec)
  beta_idx <- match(beta_nm, names(P_var_start), nomatch = 0L)
  beta_idx <- beta_idx[beta_idx > 0L]
  if (length(beta_idx) != length(beta_nm)) {
    stop(
      "P_var_start missing beta parameters for variant '",
      redundancy_resolve_beta_variant(model_spec), "'",
      call. = FALSE
    )
  }
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
  colnames(starts_mat) <- names(P_var_start)
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
      Sel = Sel,
      model_spec = model_spec,
      method = method,
      beta_link = beta_link,
      beta_latent_limit = beta_latent_limit,
      progress = progress,
      progress_every = progress_every,
      progress_label = sprintf("start %d/%d", i, n_starts),
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
