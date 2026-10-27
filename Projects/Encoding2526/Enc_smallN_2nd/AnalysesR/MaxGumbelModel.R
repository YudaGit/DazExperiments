# R translation of the guplcm/gull core in MaxGumbelModels2.m.
# P[1] = von Mises signal amplitude; P[2] = signal-shape kappa.
# Independent unit-scale Gumbel noise plus max decoding is evaluated by softmax.

max_gumbel_report <- function(P, n = 360L) {
  amplitude <- P[1]
  kappa <- P[2]
  theta <- -pi + (0:(n - 1L)) * (2 * pi / n)
  h <- 2 * pi / n

  signal <- amplitude * exp(kappa * cos(theta)) / (2 * pi)
  weights <- exp(signal - max(signal))
  ptheta <- (weights / sum(weights)) / h

  list(theta = theta, ptheta = ptheta)
}

max_gumbel_ll <- function(P, error_rad, n = 360L) {
  # Negative log likelihood at the nearest one-degree response option.
  if (length(P) != 2L || any(!is.finite(P)) || any(P <= 0) ||
      any(!is.finite(error_rad))) return(Inf)

  prediction <- max_gumbel_report(P, n)
  h <- 2 * pi / n
  
  position <- ((error_rad + pi) %% (2 * pi)) / h
  index <- (round(position) %% n) + 1L
  density <- prediction$ptheta[index]
  
  -sum(log(pmax(density, .Machine$double.xmin)))
}

# AWSS extension with shared tuning shape. The attended/unattended states
# differ in single-color signal amplitude, which scales as sqrt(r/N).
# r is the number of repeated copies of the probed color.
# P = c(amplitude_att_1, amplitude_unatt_1, W, shared_kappa).
# W is the probability that the probed target is in the attended state.
# Mix the two choice distributions after Luce's rule: the state is latent
# on a trial, while each state's response rule is nonlinear in its signal.
max_gumbel_awss_report <- function(P, n = 360L, N, r = 1) {
  if (length(P) != 4L || any(!is.finite(P)) ||
      length(N) != 1L || !is.finite(N) || N < 1 ||
      length(r) != 1L || !is.finite(r) || r < 1 ||
      n < 2L || n != as.integer(n) ||
      P[1] <= P[2] || P[2] <= 0 ||
      P[3] < 0 || P[3] > 1 || P[4] <= 0) {
    stop("Require amplitude_att_1 > amplitude_unatt_1 > 0, 0 <= W <= 1, and kappa > 0.")
  }

  W <- P[3]
  attended <- max_gumbel_report(c(P[1] * sqrt(r / N), P[4]), n)
  unattended <- max_gumbel_report(c(P[2] * sqrt(r / N), P[4]), n)
  ptheta <- W * attended$ptheta +
    (1 - W) * unattended$ptheta

  list(theta = attended$theta, ptheta = ptheta, W = W,
       Kn_est = N * W, N = N, r = r,
       amplitude_att = P[1] * sqrt(r / N),
       amplitude_unatt = P[2] * sqrt(r / N),
       ptheta_att = attended$ptheta,
       ptheta_unatt = unattended$ptheta)
}

max_gumbel_awss_ll <- function(P, error_rad, n = 360L, N, r = 1) {
  if (any(!is.finite(error_rad))) return(Inf)
  pred <- tryCatch(max_gumbel_awss_report(P, n, N, r),
                   error = function(e) NULL)
  if (is.null(pred)) return(Inf)

  h <- 2 * pi / n
  position <- ((error_rad + pi) %% (2 * pi)) / h
  index <- (round(position) %% n) + 1L
  -sum(log(pmax(pred$ptheta[index], .Machine$double.xmin)))
}

fit_max_gumbel_cells <- function(trials, n = 360L, n_starts = 100L,
                                 seed = 20261009L, maxit = 3000L,
                                 factr = 1e5, pgtol = 1e-7,
                                 ndeps = 1e-5) {
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

  # One shared signal shape and one amplitude per condition cell.
  # Optimize positive values on log scale.
  objective <- function(log_parameters) {
    amplitude <- exp(log_parameters[seq_len(n_cells)])
    kappa <- exp(log_parameters[n_cells + 1L])
    sum(vapply(seq_len(n_cells), function(i) {
      max_gumbel_ll(c(amplitude[i], kappa), errors[[i]], n)
    }, numeric(1)))
  }

  anchors <- list(
    log(c(rep(1, n_cells), 2)),
    log(c(rep(5, n_cells), 1)),
    log(c(rep(0.1, n_cells), 3))
  )
  starts <- anchors[seq_len(min(n_starts, length(anchors)))]
  if (n_starts > length(starts)) {
    had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    if (had_seed) old_seed <- get(".Random.seed", envir = .GlobalEnv)
    on.exit({
      if (had_seed) assign(".Random.seed", old_seed, envir = .GlobalEnv)
      else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
        rm(".Random.seed", envir = .GlobalEnv)
    }, add = TRUE)
    set.seed(seed)
    extra <- n_starts - length(starts)
    kappa_strata <- sample.int(extra)
    for (j in seq_len(extra)) {
      amplitude_start <- runif(n_cells, log(1e-4), log(30))
      u <- (kappa_strata[j] - 1 + runif(1)) / extra
      kappa_start <- log(0.05) + u * log(6 / 0.05)
      starts[[length(starts) + 1L]] <- c(amplitude_start, kappa_start)
    }
  }
  lower <- log(c(rep(1e-5, n_cells), 0.01))
  upper <- log(c(rep(100, n_cells), 10))
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
    initial_kappa = exp(vapply(starts, function(x) x[n_cells + 1L], numeric(1))),
    final_kappa = exp(vapply(fits, function(x) x$par[n_cells + 1L], numeric(1))),
    negative_ll = fit_values,
    convergence = vapply(fits, `[[`, integer(1), "convergence"),
    boundary_hit = vapply(fits, function(x) {
      any(abs(x$par - lower) < 1e-4 | abs(x$par - upper) < 1e-4)
    }, logical(1))
  )

  amplitude <- exp(fit$par[seq_len(n_cells)])
  kappa <- exp(fit$par[n_cells + 1L])
  result <- data.frame(
    cell_info,
    trials = lengths(errors),
    amplitude = amplitude,
    negative_ll = vapply(seq_len(n_cells), function(i) {
      max_gumbel_ll(c(amplitude[i], kappa), errors[[i]], n)
    }, numeric(1)),
    row.names = NULL
  )

  list(model = "maxgumbel_shared_kappa", kappa = kappa, cells = result,
       total_negative_ll = fit$value, convergence = fit$convergence,
       optimizer_message = fit$message,
       parameter_count = n_cells + 1L,
       trial_count = sum(lengths(errors)), best_start = best_index,
       starts = start_results,
       optimizer_settings = list(method = "L-BFGS-B", n_starts = n_starts,
                                 seed = seed, maxit = maxit, factr = factr,
                                 pgtol = pgtol, ndeps = ndeps,
                                 amplitude_bounds = exp(c(lower[1], upper[1])),
                                 kappa_bounds = exp(c(tail(lower, 1),
                                                      tail(upper, 1)))))
}
