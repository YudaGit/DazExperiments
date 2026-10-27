# Fit the matching AWSS constraints in cauchy_model.R and MaxGumbelModel.R.
# Source both model scripts before calling fit_awss_cells(). By default, fit
# two state-quality values shared across durations, ten display-duration W
# values, and a separate R-selection strength at each duration. Set
# state_by_duration = TRUE and selection_by_duration = FALSE to reproduce
# the earlier parameter sharing. previous_fit supplies warm starts.
awss_selection_weights <- function(W, N, selection_bias = 0) {
  if (any(!is.finite(c(W, N, selection_bias))) ||
      any(W < 0 | W > 1) || any(N < 1) ||
      !(length(selection_bias) %in% c(1L, length(W))) ||
      any(selection_bias < 0 | selection_bias > 1)) {
    stop("Invalid W, N, or selection_bias.")
  }
  # One redundant color and N-1 nonredundant colors. selection_bias is
  # the fraction of the largest feasible selection shift for this display.
  # Both probabilities stay in [0, 1], and expected Kn remains N*W.
  delta <- ifelse(N > 1,
                  selection_bias * pmin(W, (1 - W) / pmax(N - 1, 1)), 0)
  list(delta = delta, W_R = W + (N - 1) * delta,
       W_NR = W - delta)
}

fit_awss_cells <- function(trials, model = c("cauchy", "maxgumbel"),
                           n = 360L, n_starts = 12L,
                           seed = 20261013L, maxit = 3000L,
                           factr = 1e5, pgtol = 1e-7, ndeps = 1e-5,
                           selection = c("prefer_R", "quality_only"),
                           decision_signal = c("cosine", "cauchy", "exponential",
                                               "gaussian_kernel"),
                           fixed_similarity_decay = NULL,
                           state_by_duration = FALSE,
                           selection_by_duration = TRUE,
                           previous_fit = NULL) {
  model <- match.arg(model)
  selection <- match.arg(selection)
  decision_signal <- match.arg(decision_signal)
  if (model != "cauchy" && decision_signal != "cosine")
    stop("decision_signal applies only to the Cauchy model.")
  if (!is.null(fixed_similarity_decay) &&
      (decision_signal != "exponential" ||
       length(fixed_similarity_decay) != 1L ||
       !is.finite(fixed_similarity_decay) ||
       fixed_similarity_decay <= 0))
    stop("fixed_similarity_decay requires a positive exponential decay rate.")
  if (length(state_by_duration) != 1L || is.na(state_by_duration) ||
      !is.logical(state_by_duration) ||
      length(selection_by_duration) != 1L || is.na(selection_by_duration) ||
      !is.logical(selection_by_duration)) {
    stop("state_by_duration and selection_by_duration must be TRUE or FALSE.")
  }
  if (length(n_starts) != 1L || !is.finite(n_starts) ||
      n_starts < 1 || n_starts != as.integer(n_starts)) {
    stop("n_starts must be a positive integer.")
  }
  needed <- c("ItemN", "RedundantN", "PresDur", "ConditionType",
              "Precision", "IsUsable")
  if (!all(needed %in% names(trials))) {
    stop("Missing columns: ", paste(setdiff(needed, names(trials)), collapse = ", "))
  }
  trials <- trials[trials$IsUsable == 1 & is.finite(trials$Precision), ]
  if (!nrow(trials)) stop("No usable trials.")
  trials$ColorN <- ifelse(trials$RedundantN > 0,
                          trials$ItemN - trials$RedundantN + 1, trials$ItemN)
  trials$cell <- sprintf("S%dC%d_%s_%dms", trials$ItemN, trials$ColorN,
                         trials$ConditionType, round(1000 * trials$PresDur))
  # R and NR have the same display, duration and W group.
  trials$W_group <- sprintf("S%dC%d_%dms", trials$ItemN, trials$ColorN,
                            round(1000 * trials$PresDur))
  trials$r <- ifelse(trials$ConditionType == "R",
                     trials$ItemN - trials$ColorN + 1, 1)
  errors <- split(trials$Precision * pi / 180, trials$cell)
  cell_names <- names(errors)
  meta <- unique(trials[c("cell", "ItemN", "ColorN", "ConditionType",
                          "PresDur", "W_group", "r")])
  meta <- meta[match(cell_names, meta$cell), ]
  if (anyNA(meta$cell) || anyDuplicated(meta$cell) ||
      any(meta$ColorN < 1) || any(meta$r < 1)) {
    stop("Invalid condition mapping.")
  }
  durations <- sort(unique(meta$PresDur))
  groups <- unique(meta$W_group)
  duration_index <- match(meta$PresDur, durations)
  group_index <- match(meta$W_group, groups)
  nd <- length(durations)
  ng <- length(groups)
  ns <- if (state_by_duration) nd else 1L
  nb <- if (selection_by_duration) nd else 1L
  state_index <- if (state_by_duration) duration_index else
    rep(1L, length(duration_index))
  bias_for_cell <- if (selection_by_duration) duration_index else
    rep(1L, length(duration_index))
  state1 <- seq_len(ns)
  gap <- ns + seq_len(ns)
  weight <- 2L * ns + seq_len(ng)
  shared <- 2L * ns + ng + 1L
  bias_index <- shared + seq_len(if (selection == "prefer_R") nb else 0L)
  fit_decay <- model == "cauchy" && decision_signal == "exponential" &&
    is.null(fixed_similarity_decay)
  decay_index <- shared + length(bias_index) + 1L

  # Positive state1; state2/state1 = 1 + positive excess. In Cauchy,
  # state1 is attended and narrower. In MaxGumbel, state1 is unattended
  # and weaker. Thus the ordering has the intended interpretation.
  decode <- function(x) {
    base <- exp(x[state1])
    other <- base * (1 + exp(x[gap]))
    W <- plogis(x[weight])
    common <- exp(x[shared])
    decay <- if (fit_decay) exp(x[decay_index]) else fixed_similarity_decay
    selection_bias <- if (selection == "prefer_R") x[bias_index] else
      rep(0, nb)
    list(base = base, other = other, W = W, common = common, decay = decay,
         selection_bias = selection_bias)
  }
  ll_function <- if (model == "cauchy") {
    function(P, error_rad, n, N, r, decay)
      cauAWSSll(P, error_rad, n, N, r,
                decision_signal = decision_signal,
                similarity_decay = decay)
  } else function(P, error_rad, n, N, r, decay)
    max_gumbel_awss_ll(P, error_rad, n, N, r)
  cell_W <- function(par, i) {
    W <- par$W[group_index[i]]
    if (selection == "quality_only" || meta$ConditionType[i] == "B")
      return(W)
    allocation <- awss_selection_weights(W, meta$ColorN[i],
                                         par$selection_bias[bias_for_cell[i]])
    if (meta$ConditionType[i] == "R") allocation$W_R else allocation$W_NR
  }
  cell_P <- function(par, i) {
    d <- state_index[i]
    if (model == "cauchy")
      c(par$base[d], par$other[d], cell_W(par, i), par$common)
    else
      c(par$other[d], par$base[d], cell_W(par, i), par$common)
  }
  objective <- function(x) {
    par <- decode(x)
    sum(vapply(seq_along(errors), function(i) {
      ll_function(cell_P(par, i), errors[[i]], n,
                  N = meta$ColorN[i], r = meta$r[i], decay = par$decay)
    }, numeric(1)))
  }

  base_bounds <- if (model == "cauchy") c(0.005, 3) else c(0.001, 20)
  shared_bounds <- if (model == "cauchy" && decision_signal == "cauchy")
    c(1e-6, 500) else if (model == "cauchy" &&
                        decision_signal == "gaussian_kernel")
    c(pi / 360, pi) else if (model == "cauchy") c(0.01, 500) else c(0.01, 10)
  lower <- c(rep(log(base_bounds[1]), ns), rep(log(0.01), ns),
             rep(qlogis(0.005), ng), log(shared_bounds[1]),
             if (selection == "prefer_R") rep(0, nb),
             if (fit_decay) log(1e-6))
  upper <- c(rep(log(base_bounds[2]), ns), rep(log(30), ns),
             rep(qlogis(0.995), ng), log(shared_bounds[2]),
             if (selection == "prefer_R") rep(1, nb),
             if (fit_decay) log(100))
  anchor <- if (model == "cauchy") {
    c(rep(log(0.15), ns), rep(log(4), ns),
      rep(qlogis(0.5), ng),
      log(if (decision_signal == "cauchy") 0.5 else
          if (decision_signal == "gaussian_kernel") pi / 9 else 18),
      if (selection == "prefer_R") rep(0.3, nb),
      if (fit_decay) log(2))
  } else {
    c(rep(log(1), ns), rep(log(4), ns),
      rep(qlogis(0.5), ng), log(2.4),
      if (selection == "prefer_R") rep(0.3, nb))
  }
  starts <- list(anchor)
  if (!is.null(previous_fit) && n_starts > 1L) {
    if (!startsWith(previous_fit$model, paste0(model, "_awss")))
      stop("previous_fit must use the same model family.")
    old_states <- previous_fit$state_parameters[
      match(durations, previous_fit$state_parameters$PresDur), ]
    old_weights <- previous_fit$weights$W[
      match(groups, previous_fit$weights$W_group)]
    if (anyNA(old_states$attended_1) || anyNA(old_weights))
      stop("previous_fit has different durations or display groups.")
    base <- if (model == "cauchy") old_states$attended_1 else
      old_states$unattended_1
    other <- if (model == "cauchy") old_states$unattended_1 else
      old_states$attended_1
    if (!state_by_duration) {
      base <- exp(mean(log(base)))
      other <- exp(mean(log(other)))
    }
    old_bias <- previous_fit$selection_bias
    if (is.null(old_bias)) old_bias <- 0
    if (selection_by_duration && length(old_bias) == 1L)
      old_bias <- rep(old_bias, nd)
    if (!selection_by_duration) old_bias <- mean(old_bias)
    prior <- c(log(base), log(other / base - 1),
               qlogis(old_weights),
               log(if (decision_signal == "gaussian_kernel" &&
                      previous_fit$shared_parameter != "decision_width_rad")
                 pi / 9 else previous_fit$shared_value),
               if (selection == "prefer_R") old_bias,
               if (fit_decay) log(if (is.null(previous_fit$similarity_decay))
                 2 else previous_fit$similarity_decay))
    prior <- pmin(pmax(prior, lower), upper)
    starts <- list(prior, anchor)
    if (selection == "prefer_R" && n_starts > 2L) {
      biased_prior <- prior
      biased_prior[bias_index] <- 0.7
      starts[[3L]] <- biased_prior
    }
  }
  starts <- starts[seq_len(min(n_starts, length(starts)))]
  if (n_starts > length(starts)) {
    had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    if (had_seed) old_seed <- get(".Random.seed", envir = .GlobalEnv)
    on.exit({
      if (had_seed) assign(".Random.seed", old_seed, envir = .GlobalEnv)
      else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
        rm(".Random.seed", envir = .GlobalEnv)
    }, add = TRUE)
    set.seed(seed)
    for (j in seq_len(n_starts - length(starts))) {
      starts[[length(starts) + 1L]] <- c(
        runif(ns, log(base_bounds[1] * 2), log(base_bounds[2] / 2)),
        runif(ns, log(0.1), log(12)),
        qlogis(runif(ng, 0.1, 0.9)),
        if (model == "cauchy" && decision_signal == "cauchy")
          runif(1, log(1e-4), log(10))
        else if (model == "cauchy" &&
                 decision_signal == "gaussian_kernel")
          runif(1, log(pi / 90), log(pi / 3))
        else if (model == "cauchy") runif(1, log(2), log(100))
        else runif(1, log(0.5), log(5)),
        if (selection == "prefer_R") runif(nb, 0, 1),
        if (fit_decay) runif(1, log(1e-5), log(20))
      )
    }
  }
  control <- list(maxit = maxit, factr = factr, pgtol = pgtol,
                  ndeps = rep(ndeps, length(lower)))
  fit_time <- system.time(fits <- lapply(starts, function(start) tryCatch(
    optim(start, objective, method = "L-BFGS-B",
          lower = lower, upper = upper, control = control),
    error = function(e) list(par = start, value = Inf,
                             convergence = 100L,
                             message = conditionMessage(e)))
  ))
  values <- vapply(fits, `[[`, numeric(1), "value")
  if (!any(is.finite(values))) stop("Every optimizer start failed.")
  best_index <- which.min(values)
  best <- fits[[best_index]]
  par <- decode(best$par)
  start_results <- data.frame(
    start = seq_along(starts), negative_ll = values,
    convergence = vapply(fits, `[[`, integer(1), "convergence"),
    function_evaluations = vapply(fits, function(f) {
      if (is.null(f$counts)) NA_real_ else unname(f$counts[1])
    }, numeric(1)),
    boundary_hit = vapply(fits, function(f) {
      any(abs(f$par - lower) < 1e-4 | abs(f$par - upper) < 1e-4)
    }, logical(1)))
  state_parameters <- data.frame(
    PresDur = durations,
    attended_1 = if (model == "cauchy") par$base[
      if (state_by_duration) seq_len(nd) else rep(1L, nd)] else par$other[
      if (state_by_duration) seq_len(nd) else rep(1L, nd)],
    unattended_1 = if (model == "cauchy") par$other[
      if (state_by_duration) seq_len(nd) else rep(1L, nd)] else par$base[
      if (state_by_duration) seq_len(nd) else rep(1L, nd)])
  weights <- data.frame(W_group = groups,
                        W = par$W,
                        ColorN = meta$ColorN[match(groups, meta$W_group)])
  weights$Kn_est <- weights$ColorN * weights$W
  group_duration_index <- match(
    meta$PresDur[match(groups, meta$W_group)], durations)
  group_bias <- par$selection_bias[
    if (selection_by_duration) group_duration_index else rep(1L, ng)]
  allocation <- awss_selection_weights(weights$W, weights$ColorN,
                                       group_bias)
  has_R <- vapply(groups, function(g) {
    any(meta$W_group == g & meta$ConditionType == "R")
  }, logical(1))
  weights$delta <- ifelse(has_R, allocation$delta, 0)
  weights$W_R <- ifelse(has_R, allocation$W_R, NA_real_)
  weights$W_NR <- ifelse(has_R, allocation$W_NR, NA_real_)
  weights$selection_bias <- ifelse(has_R, group_bias, NA_real_)
  cells <- data.frame(meta, trials = lengths(errors),
                      W = vapply(seq_along(errors), function(i) cell_W(par, i),
                                 numeric(1)),
                      W_display = par$W[group_index],
                      Kn_est = meta$ColorN * par$W[group_index],
                      attended_1 = state_parameters$attended_1[duration_index],
                      unattended_1 = state_parameters$unattended_1[duration_index],
                      negative_ll = vapply(seq_along(errors), function(i) {
                        ll_function(cell_P(par, i), errors[[i]], n,
                                    N = meta$ColorN[i], r = meta$r[i],
                                    decay = par$decay)
                      }, numeric(1)), row.names = NULL)
  scale_factor <- if (model == "cauchy")
    sqrt(cells$ColorN / cells$r) else sqrt(cells$r / cells$ColorN)
  cells$attended_effective <- cells$attended_1 * scale_factor
  cells$unattended_effective <- cells$unattended_1 * scale_factor
  list(model = paste0(model, "_awss",
                      if (model == "cauchy" && decision_signal == "cauchy")
                        "_cauchy_signal" else "",
                      if (decision_signal == "exponential")
                        "_exponential_signal" else "",
                      if (decision_signal == "gaussian_kernel")
                        "_gaussian_kernel" else "",
                      if (selection == "prefer_R") "_prefer_R" else "",
                      if (!state_by_duration) "_shared_quality" else "",
                      if (selection_by_duration && selection == "prefer_R")
                        "_duration_bias" else ""),
       selection_bias = setNames(par$selection_bias,
                                 if (selection_by_duration) durations else
                                   "shared"),
       state_by_duration = state_by_duration,
       selection_by_duration = selection_by_duration,
       shared_parameter = if (model == "cauchy" &&
                              decision_signal == "gaussian_kernel")
         "decision_width_rad" else if (model == "cauchy")
         "sensitivity" else "kappa",
       shared_value = par$common,
       similarity_decay = par$decay,
       decision_signal = decision_signal,
       state_parameters = state_parameters, weights = weights,
       cells = cells, parameter_count = length(best$par),
       trial_count = sum(lengths(errors)),
       total_negative_ll = best$value, best_start = best_index,
       convergence = best$convergence, starts = start_results,
       elapsed_seconds = unname(fit_time["elapsed"]),
       optimizer_settings = list(n_starts = n_starts, seed = seed,
                                 maxit = maxit, factr = factr,
                                 pgtol = pgtol, ndeps = ndeps,
                                 method = "L-BFGS-B",
                                 fixed_similarity_decay = fixed_similarity_decay))
}
