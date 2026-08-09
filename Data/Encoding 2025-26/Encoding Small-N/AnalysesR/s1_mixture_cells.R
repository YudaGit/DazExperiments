# =============================================================================
# Experiment 1 — per-cell circular mixture (ML)
# =============================================================================
#
# GOAL
#   For each participant × cue × duration cell, fit a Bays-style mixture to
#   signed colour-report errors (sessions pooled within cell).
#
# MODEL (Bays, Catalao & Husain, 2009; colour version)
#   On every trial there are always 4 unique colours → 1 target + 3 non-targets.
#   Signed error θ (radians) is modelled as:
#
#     p(θ) = p_target * VM(θ; 0, κ)
#          + (β/3) * [ VM(θ; μ1, κ) + VM(θ; μ2, κ) + VM(θ; μ3, κ) ]
#          + γ * (1 / 2π)
#
#     Conditional on a colour-swap, the three non-target colours as equally 
#     likely, creating three von Mises bumps, i.e., "probability β split equally
#     across 3 swaps".
#
# PARAMETERS (3 free per cell)
#   κ > 0                 shared precision for target and swap bumps
#   β ∈ (0, 1)            colour-swap rate  (estimated FIRST)
#   γ ∈ (0, 1−β)          guess rate from the leftover after swap
#   p_target = 1 − β − γ  target rate (remainder; pure guesses expected rare)
#
# WHY SWAP BEFORE GUESS (stick-break order)
#   Theory: pure random guesses should be rare; many large errors are swaps.
#   So we allocate swap probability first, then let guess take a fraction of
#   whatever probability remains.
#
# HOW TO READ THIS FILE
#   Part A  — tiny helpers (angle wrap, VM log-density)
#   Part B  — one worked example cell (AQ / NR / 50ms) with comments
#   Part C  — same fit repeated for all 14 × 3 cells; save tables
#
# RUN
#   Rscript s1_mixture_cells.R
# =============================================================================

library(tidyverse)

setwd("/Users/prefabteam_ysl/Documents/GitHub/DazExperiments/Data/Encoding 2025-26/Encoding Small-N/AnalysesR")
dir.create("mixture_cells", showWarnings = FALSE, recursive = TRUE)
set.seed(1234)

# =============================================================================
# Part A — small utilities (kept short on purpose)
# =============================================================================

# Wrap degrees or radians onto (-π, π] using atan2.
wrap_rad_from_deg <- function(deg) {
  atan2(sin(deg * pi / 180), cos(deg * pi / 180))
}

# log von Mises density of angle x around centre mu, concentration kappa.
# Formula: log VM = κ cos(x−μ) − log(2π) − log I0(κ)
log_vonmises <- function(x, mu, kappa) {
  # expon.scaled=TRUE returns I0(κ)*exp(−κ); add κ back for log I0.
  log_i0 <- log(max(besselI(kappa, 0, expon.scaled = TRUE), .Machine$double.xmin)) + kappa
  kappa * cos(x - mu) - log(2 * pi) - log_i0
}

# Decode unconstrained optim() parameters → (κ, β, γ, p_target).
#   par[1] = log(κ)
#   par[2] = logit(β)                         # SWAP FIRST
#   par[3] = logit( γ / (1 − β) )             # guess from leftover
decode_par <- function(par) {
  kappa <- exp(par[1])
  beta  <- 1 / (1 + exp(-par[2]))                 # plogis
  gamma <- (1 / (1 + exp(-par[3]))) * (1 - beta)  # stick-break
  list(
    kappa = kappa,
    beta = beta,
    gamma = gamma,
    p_target = 1 - beta - gamma
  )
}

# Circular SD (degrees) implied by κ.
circSD_from_kappa <- function(kappa) {
  a <- besselI(kappa, 1, expon.scaled = TRUE) /
    max(besselI(kappa, 0, expon.scaled = TRUE), .Machine$double.xmin)
  a <- min(max(a, 1e-12), 1 - 1e-12)
  sqrt(-2 * log(a)) * (180 / pi)
}

# =============================================================================
# Part A continued — negative log-likelihood for one cell
# =============================================================================
#
# Written trial-by-trial so the mixture is easy to follow.
# mu1, mu2, mu3 are the three non-target centres (radians) for each trial.

cell_nll <- function(par, theta, mu1, mu2, mu3) {
  p <- decode_par(par)

  # Reject impossible / exploding values instead of returning NaN to optim.
  if (!is.finite(p$kappa) || p$kappa < 1e-6 || p$kappa > 5000) return(1e12)
  if (p$p_target <= 1e-12 || p$beta <= 0 || p$gamma <= 0) return(1e12)

  # Same math as a trial loop, written in vector form for speed:
  # for each trial i:
  #   log_target = log(p_target) + log VM(θ; 0, κ)
  #   log_swap   = log( sum_{j=1..3} (β/3) * VM(θ; μj, κ) )
  #   log_guess  = log(γ) - log(2π)
  #   ll_i       = log( exp(log_target) + exp(log_swap) + exp(log_guess) )

  log_target <- log(p$p_target) + log_vonmises(theta, 0, p$kappa)

  log_s1 <- log(p$beta / 3) + log_vonmises(theta, mu1, p$kappa)
  log_s2 <- log(p$beta / 3) + log_vonmises(theta, mu2, p$kappa)
  log_s3 <- log(p$beta / 3) + log_vonmises(theta, mu3, p$kappa)
  m_sw <- pmax(log_s1, log_s2, log_s3)
  log_swap <- m_sw + log(exp(log_s1 - m_sw) + exp(log_s2 - m_sw) + exp(log_s3 - m_sw))

  log_guess <- log(p$gamma) - log(2 * pi)

  m <- pmax(log_target, log_swap, log_guess)
  ll <- m + log(exp(log_target - m) + exp(log_swap - m) + exp(log_guess - m))

  if (any(!is.finite(ll))) return(1e12)
  -sum(ll)
}

# =============================================================================
# Part A continued — prepare one cell's data
# =============================================================================

prepare_cell <- function(d_cell) {
  n <- nrow(d_cell)
  stopifnot(n > 20)

  # Response errors in radians.
  theta <- wrap_rad_from_deg(d_cell$SignedErr)

  # Three unique non-target colour centres per trial (always M = 3 here).
  item_mat <- as.matrix(d_cell[, paste0("ItemHue", 1:6)])
  mu1 <- mu2 <- mu3 <- numeric(n)

  for (t in seq_len(n)) {
    target <- d_cell$TargetHue[t]
    hues <- unique(as.numeric(item_mat[t, ]))

    # Non-targets = unique hues that are not the target.
    nontarget <- hues[abs(wrap_rad_from_deg(hues - target)) > 1e-8]
    stopifnot(length(nontarget) == 3)  # design check: always 3 unique non-targets

    # Centre in SignedErr space: wrap(TargetHue − nontargetHue).
    mu <- wrap_rad_from_deg(target - nontarget)
    mu1[t] <- mu[1]
    mu2[t] <- mu[2]
    mu3[t] <- mu[3]
  }

  list(theta = theta, mu1 = mu1, mu2 = mu2, mu3 = mu3, n = n)
}

# =============================================================================
# Part A continued — fit one cell with 30 starts
# =============================================================================

fit_one_cell <- function(d_cell) {
  prep <- prepare_cell(d_cell)

  # --- 30 starting points on the unconstrained scale ---
  # 18 from a hand grid of plausible (κ, β, γ_frac), then 12 random.
  start_list <- list()
  grid_k <- c(2, 4, 8, 16)
  grid_b <- c(0.05, 0.15, 0.30)
  grid_gfrac <- c(0.02, 0.10, 0.25)  # γ = gfrac * (1 − β)
  for (k0 in grid_k) {
    for (b0 in grid_b) {
      for (gf in grid_gfrac) {
        if (length(start_list) >= 18) break
        start_list[[length(start_list) + 1]] <- c(log(k0), qlogis(b0), qlogis(gf))
      }
      if (length(start_list) >= 18) break
    }
    if (length(start_list) >= 18) break
  }
  while (length(start_list) < 30) {
    start_list[[length(start_list) + 1]] <- c(
      log(runif(1, 1, 20)),
      qlogis(runif(1, 0.01, 0.45)),
      qlogis(runif(1, 0.01, 0.40))
    )
  }

  # Fine optim settings: many iterations, tight relative tolerance.
  opt_control <- list(maxit = 2000, reltol = 1e-12)

  best_nll <- Inf
  best_par <- NULL
  best_conv <- NA_integer_
  best_start <- NA_integer_

  for (s in seq_along(start_list)) {
    fit <- tryCatch(
      optim(
        par = start_list[[s]],
        fn = cell_nll,
        theta = prep$theta,
        mu1 = prep$mu1,
        mu2 = prep$mu2,
        mu3 = prep$mu3,
        method = "BFGS",
        control = opt_control
      ),
      error = function(e) NULL
    )
    if (is.null(fit)) next
    if (fit$value < best_nll) {
      best_nll <- fit$value
      best_par <- fit$par
      best_conv <- fit$convergence   # 0 = converged
      best_start <- s
    }
  }

  stopifnot(!is.null(best_par), best_conv == 0)

  p <- decode_par(best_par)
  tibble(
    n_trials = prep$n,
    kappa = p$kappa,
    beta = p$beta,
    gamma = p$gamma,
    p_target = p$p_target,
    circSD_deg = circSD_from_kappa(p$kappa),
    nll = best_nll,
    convergence = best_conv,
    start_id = best_start
  )
}

# =============================================================================
# Load data
# =============================================================================

d <- read_csv("S1_smallN_model_ready.csv", show_col_types = FALSE)

stopifnot(all(c(
  "ID", "CueType", "Duration", "SignedErr", "TargetHue",
  paste0("ItemHue", 1:6)
) %in% names(d)))

# Design check from earlier exploration: every trial has 4 unique colours.
stopifnot(all(d$NUniqueColors == 4))

d <- d %>%
  mutate(
    CueType = factor(CueType, levels = c("NR", "R")),
    DurationF = factor(
      Duration,
      levels = c("50ms", "100ms", "150ms", "200ms", "250ms", "300ms", "350ms")
    )
  )

participants <- c("AQ", "HC", "YILIU")
cues <- c("NR", "R")
durs <- levels(d$DurationF)

# =============================================================================
# Part B — worked example: one cell (AQ, NR, 50 ms)
# =============================================================================
#
# Read this section first. Part C is the same procedure in a loop.

message("=== Worked example: AQ / NR / 50ms ===")

d_example <- d %>% filter(ID == "AQ", CueType == "NR", DurationF == "50ms")
example_fit <- fit_one_cell(d_example)

message(
  "  n = ", example_fit$n_trials,
  " | κ = ", round(example_fit$kappa, 2),
  " | β(swap) = ", round(example_fit$beta, 3),
  " | γ(guess) = ", round(example_fit$gamma, 3),
  " | p_target = ", round(example_fit$p_target, 3),
  " | NLL = ", round(example_fit$nll, 1),
  " | start #", example_fit$start_id
)

# Quick visual: histogram of signed errors with a note of fitted weights.
print(
  ggplot(d_example, aes(SignedErr)) +
    geom_histogram(bins = 36, colour = "grey20", fill = "grey80") +
    labs(
      title = "Worked example: AQ · NR · 50ms signed errors",
      subtitle = paste0(
        "ML weights — target ", round(example_fit$p_target, 2),
        ", swap ", round(example_fit$beta, 2),
        ", guess ", round(example_fit$gamma, 2),
        " | κ = ", round(example_fit$kappa, 2)
      ),
      x = "Signed error (deg)", y = "Count"
    )
)

# =============================================================================
# Part C — fit all participant × cue × duration cells
# =============================================================================

message("=== Fitting all cells (30 starts each) ===")

all_rows <- list()
row_i <- 0

for (pid in participants) {
  message("Participant ", pid)

  for (cue in cues) {
    for (dur in durs) {
      d_cell <- d %>% filter(ID == pid, CueType == cue, DurationF == dur)
      fit <- fit_one_cell(d_cell)

      row_i <- row_i + 1
      all_rows[[row_i]] <- fit %>%
        mutate(
          ID = pid,
          CueType = cue,
          DurationF = dur,
          Duration_ms = as.numeric(gsub("ms", "", dur)),
          .before = 1
        )

      message(
        "  ", cue, " ", dur,
        " | κ=", round(fit$kappa, 2),
        " β=", round(fit$beta, 3),
        " γ=", round(fit$gamma, 3),
        " pt=", round(fit$p_target, 3)
      )
    }
  }

  part_tbl <- bind_rows(all_rows) %>% filter(ID == pid)
  write_csv(part_tbl, file.path("mixture_cells", paste0("m_", pid, "_cells.csv")))
  saveRDS(part_tbl, file.path("mixture_cells", paste0("m_", pid, "_cells.rds")))
}

all_cells <- bind_rows(all_rows) %>%
  arrange(ID, CueType, Duration_ms)

# Safety checks.
stopifnot(all(abs(all_cells$p_target + all_cells$beta + all_cells$gamma - 1) < 1e-8))
stopifnot(all(all_cells$convergence == 0))
stopifnot(nrow(all_cells) == 42)

write_csv(all_cells, "mixture_cells/all_cell_params.csv")
saveRDS(all_cells, "mixture_cells/all_cell_params.rds")

print(
  all_cells %>%
    select(ID, CueType, DurationF, kappa, beta, gamma, p_target, circSD_deg, convergence)
)

message("Done. Wrote mixture_cells/all_cell_params.csv")
