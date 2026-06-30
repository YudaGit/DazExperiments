# =============================================================================
# fit_popcdm_redundancy_scaling_branch.R
# =============================================================================
#
# Experimental branch loaded AFTER fit_popcdm_redundancy.R.
#
# Key change:
#   The full vector contains both alpha_* x 9 and kappa_* x 9. The model spec
#   decides whether beta scaling applies to alpha, to kappa, or to neither.
#
# scaling_mode:
#   "alpha_beta" = alpha_trial = alpha_condition * m(beta); kappa unscaled
#   "kappa_beta" = kappa_trial = kappa_condition * m(beta); alpha unscaled
#   "none"       = alpha_trial = alpha_condition; kappa_trial = kappa_condition
#
# This file intentionally reuses data prep, interpolation, plotting, and optim
# wrappers from fit_popcdm_redundancy.R.
# =============================================================================

REDUNDANCY_SCALING_MODES <- c("alpha_beta", "kappa_beta", "none")

redundancy_resolve_scaling_mode <- function(model_spec = redundancy_model_spec()) {
  mode <- model_spec$scaling_mode
  if (is.null(mode) || !nzchar(mode)) {
    return("alpha_beta")
  }
  match.arg(mode, REDUNDANCY_SCALING_MODES)
}

redundancy_param_family_names <- function(family) {
  if (!family %in% c("alpha", "vnorm", "kappa", "a", "ter", "eta1", "eta2")) {
    stop("unknown condition-specific family: ", family, call. = FALSE)
  }
  paste0(family, "_", COND_LEVELS)
}

redundancy_param_names <- function(beta_variant = c("down_up", "base_nr_r")) {
  beta_variant <- match.arg(beta_variant, REDUNDANCY_BETA_VARIANTS)
  c(
    redundancy_param_family_names("alpha"),
    redundancy_param_family_names("vnorm"),
    redundancy_beta_names(beta_variant),
    redundancy_param_family_names("kappa"),
    redundancy_param_family_names("a"),
    redundancy_param_family_names("ter"),
    redundancy_param_family_names("eta1"),
    redundancy_param_family_names("eta2"),
    "st"
  )
}

redundancy_default_P <- function(
    beta_variant = c("down_up", "base_nr_r"),
    alpha = 2.0,
    vnorm = 2.0,
    beta_down = NULL,
    beta_up = NULL,
    beta_baseline = NULL,
    beta_nr = NULL,
    beta_r = NULL,
    kappa = 3.0,
    a = 2.0,
    ter = 0.2,
    eta1 = 1,
    eta2 = 1e-6,
    st = 0.2) {
  beta_variant <- match.arg(beta_variant, REDUNDANCY_BETA_VARIANTS)
  bb <- redundancy_beta_bound_defaults()
  if (is.null(beta_down)) beta_down <- bb$start
  if (is.null(beta_up)) beta_up <- bb$start
  if (is.null(beta_baseline)) beta_baseline <- bb$start
  if (is.null(beta_nr)) beta_nr <- bb$start
  if (is.null(beta_r)) beta_r <- bb$start
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
    stats::setNames(rep(alpha, length(COND_LEVELS)), redundancy_param_family_names("alpha")),
    stats::setNames(rep(vnorm, length(COND_LEVELS)), redundancy_param_family_names("vnorm")),
    beta_block,
    stats::setNames(rep(kappa, length(COND_LEVELS)), redundancy_param_family_names("kappa")),
    stats::setNames(rep(a, length(COND_LEVELS)), redundancy_param_family_names("a")),
    stats::setNames(rep(ter, length(COND_LEVELS)), redundancy_param_family_names("ter")),
    stats::setNames(rep(eta1, length(COND_LEVELS)), redundancy_param_family_names("eta1")),
    stats::setNames(rep(eta2, length(COND_LEVELS)), redundancy_param_family_names("eta2")),
    st = st
  )
  P[redundancy_param_names(beta_variant)]
}

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
    stats::setNames(rep(10.0, length(COND_LEVELS)), redundancy_param_family_names("alpha")),
    stats::setNames(rep(1.0, length(COND_LEVELS)), redundancy_param_family_names("vnorm")),
    beta_lower,
    stats::setNames(rep(1.0, length(COND_LEVELS)), redundancy_param_family_names("kappa")),
    stats::setNames(rep(1.0, length(COND_LEVELS)), redundancy_param_family_names("a")),
    stats::setNames(rep(0.001, length(COND_LEVELS)), redundancy_param_family_names("ter")),
    stats::setNames(rep(0.001, length(COND_LEVELS)), redundancy_param_family_names("eta1")),
    stats::setNames(rep(0.0001, length(COND_LEVELS)), redundancy_param_family_names("eta2")),
    st = 0
  )
  upper <- c(
    stats::setNames(rep(70.0, length(COND_LEVELS)), redundancy_param_family_names("alpha")),
    stats::setNames(rep(15.0, length(COND_LEVELS)), redundancy_param_family_names("vnorm")),
    beta_upper,
    stats::setNames(rep(25.0, length(COND_LEVELS)), redundancy_param_family_names("kappa")),
    stats::setNames(rep(10.0, length(COND_LEVELS)), redundancy_param_family_names("a")),
    stats::setNames(rep(1.0, length(COND_LEVELS)), redundancy_param_family_names("ter")),
    stats::setNames(rep(5.0, length(COND_LEVELS)), redundancy_param_family_names("eta1")),
    stats::setNames(rep(5.0, length(COND_LEVELS)), redundancy_param_family_names("eta2")),
    st = 0.3
  )
  nm <- redundancy_param_names(beta_variant)
  list(lower = lower[nm], upper = upper[nm])
}

redundancy_default_sel <- function(
    beta_variant = c("down_up", "base_nr_r"),
    free_eta2 = FALSE,
    free_st = FALSE) {
  beta_variant <- match.arg(beta_variant, REDUNDANCY_BETA_VARIANTS)
  nm <- redundancy_param_names(beta_variant)
  Sel <- stats::setNames(rep(TRUE, length(nm)), nm)
  Sel[redundancy_param_family_names("eta2")] <- isTRUE(free_eta2)
  Sel["st"] <- isTRUE(free_st)
  Sel
}

redundancy_model_spec <- function(
    equal_groups = list(),
    label = "scaling_branch",
    beta_variant = c("down_up", "base_nr_r"),
    scaling_mode = c("alpha_beta", "kappa_beta", "none"),
    color_count_ref = DEFAULT_COLOR_COUNT_REF) {
  beta_variant <- match.arg(beta_variant, REDUNDANCY_BETA_VARIANTS)
  scaling_mode <- match.arg(scaling_mode, REDUNDANCY_SCALING_MODES)
  color_count_ref <- as.integer(color_count_ref)
  if (length(color_count_ref) != 1L || !is.finite(color_count_ref) || color_count_ref < 1L) {
    stop("color_count_ref must be a positive integer scalar", call. = FALSE)
  }
  list(
    label = label,
    equal_groups = redundancy_normalize_equal_groups(equal_groups),
    beta_variant = beta_variant,
    scaling_mode = scaling_mode,
    color_count_ref = color_count_ref
  )
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
  scaling_mode <- redundancy_resolve_scaling_mode(model_spec)
  if (is.null(P_start)) {
    P_start <- redundancy_default_P(beta_variant = beta_variant)
  }
  if (is.null(lower) || is.null(upper)) {
    bb <- redundancy_default_bounds(beta_variant = beta_variant)
    if (is.null(lower)) lower <- bb$lower
    if (is.null(upper)) upper <- bb$upper
  }
  if (is.null(Sel)) {
    Sel <- redundancy_default_sel(beta_variant = beta_variant)
  }
  P_start <- redundancy_check_named_full_vector(P_start, "P_start", beta_variant = beta_variant)
  lower <- redundancy_check_named_full_vector(lower, "lower", beta_variant = beta_variant)
  upper <- redundancy_check_named_full_vector(upper, "upper", beta_variant = beta_variant)
  Sel <- redundancy_check_named_full_vector(Sel, "Sel", beta_variant = beta_variant)
  if (identical(scaling_mode, "none")) {
    Sel[redundancy_beta_names(beta_variant)] <- FALSE
  }
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
  betas <- stats::setNames(as.numeric(P[beta_nm]), beta_nm)
  list(
    alpha = unname(P[paste0("alpha_", cond_label)]),
    vnorm = unname(P[paste0("vnorm_", cond_label)]),
    betas = betas,
    beta_variant = beta_variant,
    kappa = unname(P[paste0("kappa_", cond_label)]),
    a = unname(P[paste0("a_", cond_label)]),
    ter = unname(P[paste0("ter_", cond_label)]),
    eta1 = unname(P[paste0("eta1_", cond_label)]),
    eta2 = unname(P[paste0("eta2_", cond_label)]),
    st = unname(P["st"])
  )
}

redundancy_scaled_alpha_kappa <- function(P, cond_label, row_design, model_spec) {
  pr <- redundancy_condition_params(P, cond_label, model_spec = model_spec)
  mode <- redundancy_resolve_scaling_mode(model_spec)
  m <- if (identical(mode, "none")) {
    1.0
  } else {
    redundancy_branch_m(
      cond_label,
      row_design$num_itemsi,
      row_design$ColorNi,
      row_design$redundancy,
      betas = pr$betas,
      beta_variant = pr$beta_variant,
      color_count_ref = redundancy_resolve_color_count_ref(model_spec),
      strict = FALSE
    )
  }
  if (!is.finite(m) || m <= 0) {
    return(NULL)
  }
  if (identical(mode, "alpha_beta")) {
    pr$alpha_trial <- pr$alpha * m
    pr$kappa_trial <- pr$kappa
  } else if (identical(mode, "kappa_beta")) {
    pr$alpha_trial <- pr$alpha
    pr$kappa_trial <- pr$kappa * m
  } else {
    pr$alpha_trial <- pr$alpha
    pr$kappa_trial <- pr$kappa
  }
  pr$m <- m
  pr
}

redundancy_popcdm_P8 <- function(pr, alpha = NULL) {
  alpha_value <- if (!is.null(alpha)) alpha else pr$alpha_trial
  kappa_value <- if (!is.null(pr$kappa_trial)) pr$kappa_trial else pr$kappa
  c(pr$vnorm, pr$eta1, pr$eta2, pr$a, alpha_value, kappa_value, pr$ter, pr$st)
}

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
  if (!identical(redundancy_resolve_scaling_mode(model_spec), "none")) {
    beta_nm <- redundancy_beta_names(redundancy_resolve_beta_variant(model_spec))
    if (any(!is.finite(P_full[beta_nm]))) {
      return(penalty_nll)
    }
  }
  if (trace) print(P_full)
  fit_df <- fit_df[!is.na(fit_df$cond_label), , drop = FALSE]
  if (!nrow(fit_df)) {
    stop("no trials after condition filter", call. = FALSE)
  }
  tab <- redundancy_cond_design_table()
  ll_total <- 0
  for (cl in unique(fit_df$cond_label)) {
    rows <- fit_df[fit_df$cond_label == cl, , drop = FALSE]
    if (!nrow(rows)) next
    row_design <- tab[tab$cond_label == cl, , drop = FALSE]
    if (nrow(row_design) != 1L) {
      stop("unknown cond_label in NLL: ", cl, call. = FALSE)
    }
    pr <- redundancy_scaled_alpha_kappa(P_full, cl, row_design, model_spec)
    if (is.null(pr) || !is.finite(pr$alpha_trial) || !is.finite(pr$kappa_trial) ||
        pr$alpha_trial <= 0 || pr$kappa_trial <= 0) {
      return(penalty_nll)
    }
    P8 <- redundancy_popcdm_P8(pr)
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

redundancy_predict_condition <- function(P, cond_label, nw = 56L, h = 0.0025, tmax = 5.0, model_spec = redundancy_model_spec()) {
  P <- redundancy_check_named_full_vector(P, "P", beta_variant = redundancy_resolve_beta_variant(model_spec))
  tab <- redundancy_cond_design_table()
  row_design <- tab[tab$cond_label == cond_label, , drop = FALSE]
  if (nrow(row_design) != 1L) {
    stop("unknown cond_label: ", cond_label, call. = FALSE)
  }
  pr <- redundancy_scaled_alpha_kappa(P, cond_label, row_design, model_spec)
  if (is.null(pr)) {
    stop("invalid scaled alpha/kappa for ", cond_label, call. = FALSE)
  }
  P8 <- redundancy_popcdm_P8(pr)
  out <- popcdm300(P8, nw = nw, h = h, tmax = tmax, return_components = FALSE)
  list(cond_label = cond_label, P8 = P8, alpha_trial = pr$alpha_trial, kappa_trial = pr$kappa_trial, out = out)
}

redundancy_population_layer_condition <- function(
    P,
    cond_label,
    model_spec = redundancy_model_spec(),
    nw = 360L) {
  beta_variant <- redundancy_resolve_beta_variant(model_spec)
  P <- redundancy_check_named_full_vector(P, "P", beta_variant = beta_variant)
  tab <- redundancy_cond_design_table()
  row_design <- tab[tab$cond_label == cond_label, , drop = FALSE]
  if (nrow(row_design) != 1L) {
    stop("unknown cond_label: ", cond_label, call. = FALSE)
  }
  pr <- redundancy_scaled_alpha_kappa(P, cond_label, row_design, model_spec)
  if (is.null(pr)) {
    stop("invalid scaled alpha/kappa for ", cond_label, call. = FALSE)
  }
  pc <- popcode(c(pr$alpha_trial, pr$kappa_trial), nw = nw)
  vm_out <- vm(pr$kappa_trial, nw = nw)
  w <- 2 * pi / nw
  data.frame(
    cond_label = cond_label,
    theta = pc$th,
    theta_deg = pc$th * 180 / pi,
    alpha_trial = pr$alpha_trial,
    kappa_trial = pr$kappa_trial,
    popcode_density = pc$pang / w,
    vm_density = vm_out$ftheta,
    stringsAsFactors = FALSE
  )
}

redundancy_population_layer_from_model <- function(
    P,
    cond_label,
    model_spec = redundancy_model_spec(),
    nw = 360L,
    h = 0.01,
    tmax = 3.0) {
  beta_variant <- redundancy_resolve_beta_variant(model_spec)
  P <- redundancy_check_named_full_vector(P, "P", beta_variant = beta_variant)
  tab <- redundancy_cond_design_table()
  row_design <- tab[tab$cond_label == cond_label, , drop = FALSE]
  if (nrow(row_design) != 1L) {
    stop("unknown cond_label: ", cond_label, call. = FALSE)
  }
  pr <- redundancy_scaled_alpha_kappa(P, cond_label, row_design, model_spec)
  if (is.null(pr)) {
    stop("invalid scaled alpha/kappa for ", cond_label, call. = FALSE)
  }
  pred <- redundancy_predict_condition(
    P,
    cond_label,
    nw = nw,
    h = h,
    tmax = tmax,
    model_spec = model_spec
  )
  adf <- redundancy_angle_marginal_df(pred)
  data.frame(
    cond_label = cond_label,
    theta = adf$angle_rad,
    theta_deg = adf$angle_rad * 180 / pi,
    model_error_density = adf$density,
    stringsAsFactors = FALSE
  )
}

redundancy_population_circular_sd <- function(theta, prob_mass) {
  prob_mass <- pmax(as.numeric(prob_mass), 0)
  prob_mass <- prob_mass / sum(prob_mass)
  cbar <- sum(prob_mass * cos(theta))
  sbar <- sum(prob_mass * sin(theta))
  rbar <- sqrt(cbar^2 + sbar^2)
  rbar <- pmin(pmax(rbar, .Machine$double.eps), 1)
  sqrt(-2 * log(rbar))
}

redundancy_population_rbar <- function(theta, prob_mass) {
  prob_mass <- pmax(as.numeric(prob_mass), 0)
  prob_mass <- prob_mass / sum(prob_mass)
  cbar <- sum(prob_mass * cos(theta))
  sbar <- sum(prob_mass * sin(theta))
  sqrt(cbar^2 + sbar^2)
}

redundancy_vm_rbar_from_kappa <- function(kappa) {
  besselI(kappa, 1, expon.scaled = TRUE) / besselI(kappa, 0, expon.scaled = TRUE)
}

redundancy_vm_kappa_from_rbar <- function(rbar) {
  rbar <- pmin(pmax(as.numeric(rbar), 0), 1 - 1e-12)
  if (rbar <= 0) {
    return(0)
  }
  stats::uniroot(
    function(kappa) redundancy_vm_rbar_from_kappa(kappa) - rbar,
    lower = 0,
    upper = 1e4
  )$root
}

redundancy_population_equiv_vm_table <- function(
    P,
    cond_labels = COND_LEVELS,
    model_spec = redundancy_model_spec(),
    nw = 360L) {
  rows <- lapply(cond_labels, function(cl) {
    df <- redundancy_population_layer_condition(P, cl, model_spec = model_spec, nw = nw)
    w <- 2 * pi / nw
    pang_mass <- df$popcode_density * w
    rbar <- redundancy_population_rbar(df$theta, pang_mass)
    kappa_equiv <- redundancy_vm_kappa_from_rbar(rbar)
    vm_equiv <- vm(kappa_equiv, nw = nw)
    data.frame(
      cond_label = cl,
      alpha_trial = df$alpha_trial[1L],
      fitted_kappa_trial = df$kappa_trial[1L],
      pang_rbar = rbar,
      equivalent_vm_kappa = kappa_equiv,
      equivalent_vm_cir_sd_rad = redundancy_population_circular_sd(
        vm_equiv$theta,
        vm_equiv$ftheta * w
      ),
      equivalent_vm_cir_sd_deg = redundancy_population_circular_sd(
        vm_equiv$theta,
        vm_equiv$ftheta * w
      ) * 180 / pi,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

redundancy_population_cirsd_table <- function(
    P,
    cond_labels = COND_LEVELS,
    model_spec = redundancy_model_spec(),
    nw = 360L) {
  rows <- lapply(cond_labels, function(cl) {
    df <- redundancy_population_layer_condition(P, cl, model_spec = model_spec, nw = nw)
    w <- 2 * pi / nw
    data.frame(
      cond_label = cl,
      alpha_trial = df$alpha_trial[1L],
      kappa_trial = df$kappa_trial[1L],
      cir_sd_rad = redundancy_population_circular_sd(df$theta, df$popcode_density * w),
      cir_sd_deg = redundancy_population_circular_sd(df$theta, df$popcode_density * w) * 180 / pi,
      vm_cir_sd_rad = redundancy_population_circular_sd(df$theta, df$vm_density * w),
      vm_cir_sd_deg = redundancy_population_circular_sd(df$theta, df$vm_density * w) * 180 / pi,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

plot_redundancy_population_layers <- function(
    P,
    cond_labels = COND_LEVELS,
    model_spec = redundancy_model_spec(),
    nw = 360L,
    h = 0.01,
    tmax = 3.0,
    ylim = NULL) {
  recon_list <- lapply(cond_labels, function(cl) {
    redundancy_population_layer_condition(P, cl, model_spec = model_spec, nw = nw)
  })
  names(recon_list) <- cond_labels
  model_list <- lapply(cond_labels, function(cl) {
    redundancy_population_layer_from_model(P, cl, model_spec = model_spec, nw = nw, h = h, tmax = tmax)
  })
  names(model_list) <- cond_labels
  if (is.null(ylim)) {
    ymax <- max(
      unlist(lapply(recon_list, function(x) c(x$popcode_density, x$vm_density)), use.names = FALSE),
      unlist(lapply(model_list, function(x) x$model_error_density), use.names = FALSE),
      na.rm = TRUE
    )
    ylim <- c(0, ymax * 1.05)
  }
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(oldpar), add = TRUE)
  graphics::par(mfrow = c(3, 3), mar = c(3.2, 3.2, 2.2, 0.8), xaxs = "i", yaxs = "i")
  for (cl in cond_labels) {
    recon <- recon_list[[cl]]
    model <- model_list[[cl]]
    graphics::plot(
      recon$theta_deg,
      recon$popcode_density,
      type = "l",
      lwd = 2,
      col = "#AA0044",
      xlim = c(-180, 180),
      ylim = ylim,
      main = cl,
      xlab = "Drift angle (deg)",
      ylab = "Density"
    )
    graphics::lines(model$theta_deg, model$model_error_density, col = "black", lwd = 1.5, lty = 2)
    graphics::lines(recon$theta_deg, recon$vm_density, col = "#3366CC", lwd = 1.2, lty = 3)
    graphics::legend(
      "topright",
      legend = c("popcode(alpha, kappa)", "model error marginal", "raw von Mises"),
      col = c("#AA0044", "black", "#3366CC"),
      lty = c(1, 2, 3),
      lwd = c(2, 1.5, 1.2),
      bty = "n",
      cex = 0.65
    )
  }
}

plot_redundancy_error_marginals <- function(
    fit_df,
    P,
    cond_labels = COND_LEVELS,
    nw = 56L,
    h = 0.0025,
    tmax = 5.0,
    n_bins = 30L,
    xlim = c(-180, 180),
    ylim = NULL,
    model_spec = redundancy_model_spec()) {
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(oldpar), add = TRUE)
  graphics::par(mfrow = c(3, 3), mar = c(3.2, 3.2, 2.2, 0.8), xaxs = "i", yaxs = "i")
  rad_per_deg <- pi / 180
  breaks <- seq(xlim[1L], xlim[2L], length.out = as.integer(n_bins) + 1L)
  pred_list <- lapply(cond_labels, function(cl) {
    adf <- redundancy_angle_marginal_df(
      redundancy_predict_condition(P, cl, nw = nw, h = h, tmax = tmax, model_spec = model_spec)
    )
    data.frame(
      angle_deg = adf$angle_rad / rad_per_deg,
      density = adf$density * rad_per_deg,
      stringsAsFactors = FALSE
    )
  })
  names(pred_list) <- cond_labels
  hist_list <- lapply(cond_labels, function(cl) {
    rows <- fit_df[fit_df$cond_label == cl, , drop = FALSE]
    graphics::hist(rows$angle_rad / rad_per_deg, breaks = breaks, plot = FALSE)
  })
  names(hist_list) <- cond_labels
  if (is.null(ylim)) {
    hist_max <- vapply(hist_list, function(hh) max(hh$density, na.rm = TRUE), numeric(1))
    model_max <- vapply(pred_list, function(adf) max(adf$density, na.rm = TRUE), numeric(1))
    ymax <- max(c(hist_max, model_max), na.rm = TRUE)
    ylim <- c(0, ymax * 1.05)
  }
  for (cl in cond_labels) {
    graphics::plot(
      hist_list[[cl]],
      freq = FALSE,
      col = "grey30",
      border = "white",
      main = cl,
      xlab = "Signed error (deg)",
      ylab = "Density",
      xlim = xlim,
      ylim = ylim
    )
    adf <- pred_list[[cl]]
    graphics::lines(adf$angle_deg, adf$density, col = "#AA0044", lwd = 2)
  }
}

plot_redundancy_rt_marginals <- function(
    fit_df,
    P,
    cond_labels = COND_LEVELS,
    nw = 56L,
    h = 0.0025,
    tmax = 5.0,
    n_bins = 30L,
    xlim = NULL,
    ylim = NULL,
    model_spec = redundancy_model_spec()) {
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(oldpar), add = TRUE)
  graphics::par(mfrow = c(3, 3), mar = c(3.2, 3.2, 2.2, 0.8), xaxs = "i", yaxs = "i")
  pred_list <- lapply(cond_labels, function(cl) {
    redundancy_rt_marginal_df(redundancy_predict_condition(P, cl, nw = nw, h = h, tmax = tmax, model_spec = model_spec))
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
    graphics::plot(
      hist_list[[cl]],
      freq = FALSE,
      col = "grey30",
      border = "white",
      main = cl,
      xlab = "RT (s)",
      ylab = "Density",
      xlim = xlim,
      ylim = ylim
    )
    rdf <- pred_list[[cl]]
    graphics::lines(rdf$rt_sec, rdf$density, col = "#225522", lwd = 2)
  }
}
