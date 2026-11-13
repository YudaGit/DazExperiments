# Refit YL AWSS models with a fixed circular Gaussian response mapping width.
# Run from the Encoding2526 project root.
project <- normalizePath(getwd())
analysis <- file.path(project, "Enc_smallN_2nd/AnalysesR")
source(file.path(analysis, "cauchy_model.R"))
source(file.path(analysis, "MaxGumbelModel.R"))
source(file.path(analysis, "awss_runner.R"))
trials <- read.csv(file.path(project,
  "Enc_smallN_2nd/Daz25EncodingData/PreliminaryReview/YL_model_trials.csv"))
trials <- trials[trials$IsUsable == 1 & is.finite(trials$Precision), ]
trials$ColorN <- ifelse(trials$RedundantN > 0,
  trials$ItemN - trials$RedundantN + 1, trials$ItemN)
trials$cell <- sprintf("S%dC%d_%s_%dms", trials$ItemN, trials$ColorN,
  trials$ConditionType, round(1000 * trials$PresDur))
trials$W_group <- sprintf("S%dC%d_%dms", trials$ItemN, trials$ColorN,
  round(1000 * trials$PresDur))
trials$r <- ifelse(trials$ConditionType == "R",
  trials$ItemN - trials$ColorN + 1, 1)
error_rad <- split(trials$Precision * pi / 180, trials$cell)
meta <- unique(trials[c("cell", "ItemN", "ColorN", "ConditionType",
  "PresDur", "W_group", "r")])
meta <- meta[match(names(error_rad), meta$cell), ]
stopifnot(!anyNA(meta$cell), !anyDuplicated(meta$cell), nrow(meta) == 14L)

n <- 360L
h <- 2 * pi / n
theta <- -pi + (0:(n - 1L)) * h
origin <- which.min(abs(theta))
shift <- c(origin:n, seq_len(origin - 1L))
counts <- lapply(error_rad, function(x) {
  position <- ((x + pi) %% (2 * pi)) / h
  tabulate((round(position) %% n) + 1L, nbins = n)
})
groups <- unique(meta$W_group)
durations <- sort(unique(meta$PresDur))
group_index <- match(meta$W_group, groups)
duration_index <- match(meta$PresDur, durations)
profile_keys <- paste(meta$ColorN, meta$r, sep = "_")
unique_profiles <- unique(profile_keys)
profile_index <- match(profile_keys, unique_profiles)
profile_meta <- meta[match(unique_profiles, profile_keys), c("ColorN", "r")]
stopifnot(length(groups) == 10L, length(durations) == 2L,
          sum(lengths(error_rad)) == 4893L)

mapping_kernel <- function(sd_rad) {
  if (sd_rad == 0) return(NULL)
  d <- abs(atan2(sin(theta), cos(theta)))
  k <- exp(-0.5 * (d / sd_rad)^2)
  k / sum(k)
}
convolve_mass <- function(a, b) {
  out <- stats::convolve(a[shift], b[shift], type = "circular",
                         conj = FALSE)
  ans <- pmax(Re(out[order(shift)]), 0)
  ans / sum(ans)
}

make_objective <- function(model, sd_rad) {
  kernel <- mapping_kernel(sd_rad)
  function(x, return_details = FALSE) {
    if (model == "cauchy") {
      attended <- exp(x[1])
      unattended <- attended * (1 + exp(x[2]))
      common <- sd_rad
      bias <- x[13:14]
    } else {
      unattended <- exp(x[1])
      attended <- unattended * (1 + exp(x[2]))
      common <- exp(x[13])
      bias <- x[14:15]
    }
    W <- plogis(x[3:12])
    state <- lapply(seq_along(unique_profiles), function(j) {
      N <- profile_meta$ColorN[j]
      r <- profile_meta$r[j]
      if (model == "cauchy") {
        a <- caumem(attended * sqrt(N / r), n)$ptheta
        u <- caumem(unattended * sqrt(N / r), n)$ptheta
        a <- a / sum(a)
        u <- u / sum(u)
      } else {
        a <- max_gumbel_report(c(attended * sqrt(r / N), common), n)$ptheta * h
        u <- max_gumbel_report(c(unattended * sqrt(r / N), common), n)$ptheta * h
      }
      if (!is.null(kernel)) {
        a <- convolve_mass(a, kernel)
        u <- convolve_mass(u, kernel)
      }
      list(attended = a, unattended = u)
    })
    cell_w <- numeric(nrow(meta))
    cell_nll <- numeric(nrow(meta))
    for (i in seq_len(nrow(meta))) {
      wi <- W[group_index[i]]
      if (meta$ConditionType[i] != "B") {
        alloc <- awss_selection_weights(wi, meta$ColorN[i],
                                        bias[duration_index[i]])
        wi <- if (meta$ConditionType[i] == "R") alloc$W_R else alloc$W_NR
      }
      cell_w[i] <- wi
      component <- state[[profile_index[i]]]
      density <- (wi * component$attended +
                 (1 - wi) * component$unattended) / h
      cell_nll[i] <- -sum(counts[[i]] * log(pmax(density,
                                                .Machine$double.xmin)))
    }
    value <- sum(cell_nll)
    if (!return_details) return(value)
    weights <- data.frame(W_group = groups, W = W,
      ColorN = meta$ColorN[match(groups, meta$W_group)])
    weights$Kn_est <- weights$ColorN * weights$W
    bias_for_group <- bias[match(meta$PresDur[match(groups, meta$W_group)],
                                 durations)]
    alloc <- awss_selection_weights(weights$W, weights$ColorN,
                                    bias_for_group)
    has_R <- vapply(groups, function(g)
      any(meta$W_group == g & meta$ConditionType == "R"), logical(1))
    weights$delta <- ifelse(has_R, alloc$delta, NA_real_)
    weights$W_R <- ifelse(has_R, alloc$W_R, NA_real_)
    weights$W_NR <- ifelse(has_R, alloc$W_NR, NA_real_)
    list(value = value, attended_1 = attended,
         unattended_1 = unattended, shared_value = common,
         selection_bias = setNames(bias, c("50ms", "250ms")),
         weights = weights,
         cells = data.frame(meta, W_target = cell_w,
                            negative_ll = cell_nll))
  }
}

encode_previous <- function(fit, model) {
  a <- fit$state_parameters$attended_1[1]
  u <- fit$state_parameters$unattended_1[1]
  W <- fit$weights$W[match(groups, fit$weights$W_group)]
  bias <- unname(fit$selection_bias)
  if (model == "cauchy") {
    c(log(a), log(u / a - 1), qlogis(W), bias)
  } else {
    c(log(u), log(a / u - 1), qlogis(W),
      log(fit$shared_value), bias)
  }
}

yl <- file.path(analysis, "results/YL")
previous <- list(
  cauchy = readRDS(file.path(yl,
    "cauchy_awss_gaussian_decision_20starts.rds")),
  maxgumbel = readRDS(file.path(yl,
    "maxgumbel_awss_shared_quality_fit.rds")))

# Verify the independently implemented likelihood reproduces the saved fits.
verification <- c(
  cauchy = make_objective("cauchy", previous$cauchy$shared_value)(
    encode_previous(previous$cauchy, "cauchy")) -
    previous$cauchy$total_negative_ll,
  maxgumbel = make_objective("maxgumbel", 0)(
    encode_previous(previous$maxgumbel, "maxgumbel")) -
    previous$maxgumbel$total_negative_ll)
print(verification)
stopifnot(all(abs(verification) < 1e-5))

fit_one <- function(model, n_starts = 50L, seed = 20261105L) {
  sd_rad <- 9.5 * pi / 180
  objective <- make_objective(model, sd_rad)
  old <- previous[[model]]
  prior <- encode_previous(old, model)
  if (model == "cauchy") {
    lower <- c(log(0.005), log(0.01), rep(qlogis(0.005), 10), 0, 0)
    upper <- c(log(3), log(30), rep(qlogis(0.995), 10), 1, 1)
    anchor <- c(log(0.15), log(4), rep(qlogis(0.5), 10), 0.3, 0.3)
  } else {
    lower <- c(log(0.001), log(0.01), rep(qlogis(0.005), 10),
               log(0.01), 0, 0)
    upper <- c(log(20), log(30), rep(qlogis(0.995), 10),
               log(10), 1, 1)
    anchor <- c(log(1), log(4), rep(qlogis(0.5), 10), log(2.4),
                0.3, 0.3)
  }
  prior <- pmin(pmax(prior, lower), upper)
  starts <- list(prior, anchor)
  biased <- prior
  biased[(length(prior) - 1L):length(prior)] <- 0.7
  starts[[3L]] <- biased
  set.seed(seed)
  for (j in seq_len(n_starts - length(starts))) {
    if (model == "cauchy") {
      extra <- c(runif(1, log(0.01), log(1.5)),
                 runif(1, log(0.1), log(12)),
                 qlogis(runif(10, 0.1, 0.9)), runif(2))
    } else {
      extra <- c(runif(1, log(0.002), log(10)),
                 runif(1, log(0.1), log(12)),
                 qlogis(runif(10, 0.1, 0.9)),
                 runif(1, log(0.5), log(5)), runif(2))
    }
    starts[[length(starts) + 1L]] <- extra
  }
  control <- list(maxit = 3000L, factr = 1e5, pgtol = 1e-7,
                  ndeps = rep(1e-5, length(prior)))
  elapsed <- system.time(fits <- lapply(starts, function(start) tryCatch(
    optim(start, objective, method = "L-BFGS-B", lower = lower,
          upper = upper, control = control),
    error = function(e) list(par = start, value = Inf, convergence = 100L,
                             message = conditionMessage(e)))))
  vals <- vapply(fits, `[[`, numeric(1), "value")
  best <- fits[[which.min(vals)]]
  details <- objective(best$par, return_details = TRUE)
  list(model = model, mapping_sd_deg = 9.5,
       parameter_count = length(best$par), trial_count = sum(lengths(error_rad)),
       total_negative_ll = best$value,
       BIC = 2 * best$value + length(best$par) * log(sum(lengths(error_rad))),
       convergence = best$convergence, best_start = which.min(vals),
       starts = data.frame(start = seq_along(fits), NLL = vals,
          convergence = vapply(fits, `[[`, integer(1), "convergence")),
       optimizer_settings = list(n_starts = n_starts, seed = seed,
          maxit = control$maxit, factr = control$factr,
          pgtol = control$pgtol, ndeps = 1e-5),
       elapsed_seconds = unname(elapsed["elapsed"]), details = details)
}

out <- file.path(analysis, "results/YL/fixed_mapping_9p5deg")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
fits <- list()
for (model in c("cauchy", "maxgumbel")) {
  cat("Fitting", model, "\n")
  fit <- fit_one(model, n_starts = 50L,
                 seed = if (model == "cauchy") 20261105L else 20261106L)
  fits[[model]] <- fit
  saveRDS(fit, file.path(out, paste0(model, "_fixed_mapping_9p5deg_YL.rds")))
  cat(model, "NLL", fit$total_negative_ll, "BIC", fit$BIC,
      "converged", sum(fit$starts$convergence == 0L), "/ 50",
      "near best", sum(abs(fit$starts$NLL - fit$total_negative_ll) < .01),
      "/ 50\n")
  flush.console()
}
comparison <- data.frame(
  model = names(fits),
  negative_ll = vapply(fits, `[[`, numeric(1), "total_negative_ll"),
  BIC = vapply(fits, `[[`, numeric(1), "BIC"),
  parameters = vapply(fits, `[[`, integer(1), "parameter_count"),
  trials = vapply(fits, `[[`, integer(1), "trial_count"))
write.csv(comparison, file.path(out, "fixed_mapping_9p5deg_comparison_YL.csv"),
          row.names = FALSE)
print(comparison)
