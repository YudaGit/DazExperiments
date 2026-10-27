# Fit one Cauchy memory dispersion per condition cell and one shared sensitivity.
# Source cauchy_model.R before calling this function.

fit_cauchy_cells <- function(trials, n = 360L, fixed_sensitivity = NULL,
                             n_starts = 100L, seed = 20261009L,
                             maxit = 3000L, factr = 1e5, pgtol = 1e-7,
                             ndeps = 1e-5) {
  if (!is.null(fixed_sensitivity) &&
      (length(fixed_sensitivity) != 1L || !is.finite(fixed_sensitivity) ||
       fixed_sensitivity < 0)) {
    stop("fixed_sensitivity must be a single nonnegative number.")
  }
  if (length(n_starts) != 1L || !is.finite(n_starts) ||
      n_starts < 1 || n_starts != as.integer(n_starts)) {
    stop("n_starts must be a positive integer.")
  }
  if (length(seed) != 1L || !is.finite(seed)) stop("seed must be finite.")
  needed <- c("ItemN", "RedundantN", "PresDur", "ConditionType",
              "Precision", "IsUsable")
  if (!all(needed %in% names(trials))) {
    stop("Missing columns: ", paste(setdiff(needed, names(trials)), collapse = ", "))
  }

  trials <- trials[trials$IsUsable == 1 & is.finite(trials$Precision), ]
  if (nrow(trials) == 0L) stop("No usable trials.")
  trials$ColorN <- ifelse(trials$RedundantN > 0,
                          trials$ItemN - trials$RedundantN + 1, trials$ItemN)
  trials$cell <- sprintf("S%dC%d_%s_%dms", trials$ItemN, trials$ColorN,
                         trials$ConditionType, round(1000 * trials$PresDur))
  errors <- split(trials$Precision * pi / 180, trials$cell)
  cell_names <- names(errors)
  n_cells <- length(errors)
  cell_info <- unique(trials[c("cell", "ItemN", "ColorN", "ConditionType", "PresDur")])
  cell_info <- cell_info[match(cell_names, cell_info$cell), ]

  # Optimize each cell's kappa and, when requested, one shared sensitivity.
  objective <- function(log_parameters) {
    kappa <- exp(log_parameters[seq_len(n_cells)])
    sensitivity <- if (is.null(fixed_sensitivity))
      exp(log_parameters[n_cells + 1L]) else fixed_sensitivity
    sum(vapply(seq_len(n_cells), function(i) {
      caull(c(kappa[i], sensitivity), errors[[i]], n)
    }, numeric(1)))
  }

  anchor_starts <- if (is.null(fixed_sensitivity)) list(
    log(c(rep(0.5, n_cells), 20)),
    log(c(rep(1, n_cells), 5)),
    log(c(rep(0.2, n_cells), 50))
  ) else list(log(rep(0.5, n_cells)),
              log(rep(1, n_cells)),
              log(rep(0.2, n_cells)))
  lower <- if (is.null(fixed_sensitivity))
    log(c(rep(0.02, n_cells), 0.01)) else log(rep(0.001, n_cells))
  upper <- if (is.null(fixed_sensitivity))
    log(c(rep(10, n_cells), 500)) else log(rep(10, n_cells))
  starts <- anchor_starts[seq_len(min(n_starts, length(anchor_starts)))]
  if (n_starts > length(starts)) {
    # Reproducible stratification of sensitivity, with varied cell dispersions.
    had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    if (had_seed) old_seed <- get(".Random.seed", envir = .GlobalEnv)
    on.exit({
      if (had_seed) assign(".Random.seed", old_seed, envir = .GlobalEnv)
      else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
        rm(".Random.seed", envir = .GlobalEnv)
    }, add = TRUE)
    set.seed(seed)
    extra <- n_starts - length(starts)
    sensitivity_strata <- sample.int(extra)
    for (j in seq_len(extra)) {
      kappa_start <- runif(n_cells, log(0.03), log(3))
      if (is.null(fixed_sensitivity)) {
        u <- (sensitivity_strata[j] - 1 + runif(1)) / extra
        sensitivity_start <- log(0.05) + u * log(250 / 0.05)
        starts[[length(starts) + 1L]] <- c(kappa_start, sensitivity_start)
      } else starts[[length(starts) + 1L]] <- kappa_start
    }
  }
  control <- list(maxit = maxit, factr = factr, pgtol = pgtol,
                  ndeps = rep(ndeps, length(lower)))
  fits <- lapply(starts, function(start) tryCatch(
    optim(par = start, fn = objective, method = "L-BFGS-B",
          lower = lower, upper = upper, control = control),
    error = function(e) list(par = start, value = Inf, convergence = 100L,
                             message = conditionMessage(e),
                             counts = setNames(c(NA_real_, NA_real_),
                                               c("function", "gradient")))
  ))
  fit_values <- vapply(fits, `[[`, numeric(1), "value")
  if (!any(is.finite(fit_values))) stop("Every optimizer start failed.")
  best_index <- which.min(fit_values)
  fit <- fits[[best_index]]
  start_results <- data.frame(
    start = seq_along(starts),
    initial_sensitivity = if (is.null(fixed_sensitivity))
      exp(vapply(starts, function(x) x[n_cells + 1L], numeric(1))) else
      rep(fixed_sensitivity, length(starts)),
    final_sensitivity = if (is.null(fixed_sensitivity))
      exp(vapply(fits, function(x) x$par[n_cells + 1L], numeric(1))) else
      rep(fixed_sensitivity, length(starts)),
    negative_ll = fit_values,
    convergence = vapply(fits, `[[`, integer(1), "convergence"),
    function_evaluations = vapply(fits, function(x) unname(x$counts[1]), numeric(1)),
    boundary_hit = vapply(fits, function(x) {
      any(abs(x$par - lower) < 1e-4 | abs(x$par - upper) < 1e-4)
    }, logical(1))
  )

  kappa <- exp(fit$par[seq_len(n_cells)])
  sensitivity <- if (is.null(fixed_sensitivity))
    exp(fit$par[n_cells + 1L]) else fixed_sensitivity
  circular_sd <- function(angles, probability = NULL) {
    resultant <- if (is.null(probability)) mean(exp(1i * angles)) else
      sum(probability * exp(1i * angles)) / sum(probability)
    sqrt(-2 * log(min(1, max(Mod(resultant), .Machine$double.eps)))) * 180 / pi
  }

  predictions <- lapply(kappa, function(k) caureport(c(k, sensitivity), n))
  result <- data.frame(
    cell_info,
    trials = lengths(errors),
    kappa = kappa,
    observed_csd_deg = vapply(errors, circular_sd, numeric(1)),
    predicted_csd_deg = vapply(predictions, function(pred) {
      circular_sd(pred$theta, pred$ptheta)
    }, numeric(1)),
    negative_ll = vapply(seq_len(n_cells), function(i) {
      caull(c(kappa[i], sensitivity), errors[[i]], n)
    }, numeric(1)),
    row.names = NULL
  )

  list(model = "cauchy_memory", sensitivity = sensitivity,
       parameters = n_cells + is.null(fixed_sensitivity),
       cells = result,
       total_negative_ll = fit$value, convergence = fit$convergence,
       optimizer_message = fit$message, best_start = best_index,
       starts = start_results,
       optimizer_settings = list(method = "L-BFGS-B", n_starts = n_starts,
                                 seed = seed, maxit = maxit, factr = factr,
                                 pgtol = pgtol, ndeps = ndeps,
                                 kappa_bounds = exp(c(lower[1], upper[1])),
                                 sensitivity_bounds = if (is.null(fixed_sensitivity))
                                   exp(c(tail(lower, 1), tail(upper, 1))) else
                                   fixed_sensitivity))
}
