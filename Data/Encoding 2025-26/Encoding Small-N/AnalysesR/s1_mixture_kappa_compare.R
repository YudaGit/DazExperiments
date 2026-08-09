# =============================================================================
# Mixture κ structure comparison (sessions pooled)
# =============================================================================
# Per participant:
#   κ-free  : independent 3-param mixture per Cue × Duration cell (14 × 3 = 42)
#             logLik = sum of cell logLiks (from mixture_cells/ or refit)
#   κ-tied  : one κ per cue (NR, R); β and γ still free per cell
#             parameters = 2 κ + 14 β + 14 γ = 30
#
# BIC = -2 logL + k log(n)
# Negative delta_BIC_free_minus_tied => κ-free wins (duration still needed for κ)
# =============================================================================

suppressPackageStartupMessages(library(tidyverse))

setwd("/Users/prefabteam_ysl/Documents/GitHub/DazExperiments/Data/Encoding 2025-26/Encoding Small-N/AnalysesR")
dir.create("bayes_primary_discrete", showWarnings = FALSE, recursive = TRUE)
set.seed(1234)

# ---- utilities (same as s1_mixture_cells.R) ----
wrap_rad_from_deg <- function(deg) {
  atan2(sin(deg * pi / 180), cos(deg * pi / 180))
}

log_vonmises <- function(x, mu, kappa) {
  log_i0 <- log(pmax(besselI(kappa, 0, expon.scaled = TRUE), .Machine$double.xmin)) + kappa
  # besselI is not vectorised over kappa the way we need when kappa is scalar:
  if (length(kappa) == 1) {
    log_i0 <- log(max(besselI(kappa, 0, expon.scaled = TRUE), .Machine$double.xmin)) + kappa
  }
  kappa * cos(x - mu) - log(2 * pi) - log_i0
}

# Force scalar-kappa path for density
log_vonmises_k <- function(x, mu, kappa) {
  log_i0 <- log(max(besselI(kappa, 0, expon.scaled = TRUE), .Machine$double.xmin)) + kappa
  kappa * cos(x - mu) - log(2 * pi) - log_i0
}

mix_nll_cell <- function(kappa, beta, gamma, theta, mu1, mu2, mu3) {
  if (!is.finite(kappa) || kappa < 1e-6 || kappa > 5000) return(1e12)
  beta <- min(max(beta, 1e-10), 1 - 1e-10)
  gamma <- min(max(gamma, 1e-10), 1 - beta - 1e-10)
  p_target <- 1 - beta - gamma
  if (p_target <= 1e-12) return(1e12)

  log_target <- log(p_target) + log_vonmises_k(theta, 0, kappa)
  log_s1 <- log(beta / 3) + log_vonmises_k(theta, mu1, kappa)
  log_s2 <- log(beta / 3) + log_vonmises_k(theta, mu2, kappa)
  log_s3 <- log(beta / 3) + log_vonmises_k(theta, mu3, kappa)
  m_sw <- pmax(log_s1, log_s2, log_s3)
  log_swap <- m_sw + log(exp(log_s1 - m_sw) + exp(log_s2 - m_sw) + exp(log_s3 - m_sw))
  log_guess <- log(gamma) - log(2 * pi)
  m <- pmax(log_target, log_swap, log_guess)
  ll <- m + log(exp(log_target - m) + exp(log_swap - m) + exp(log_guess - m))
  if (any(!is.finite(ll))) return(1e12)
  -sum(ll)
}

prepare_cell <- function(d_cell) {
  n <- nrow(d_cell)
  theta <- wrap_rad_from_deg(d_cell$SignedErr)
  item_mat <- as.matrix(d_cell[, paste0("ItemHue", 1:6)])
  mu1 <- mu2 <- mu3 <- numeric(n)
  for (t in seq_len(n)) {
    target <- d_cell$TargetHue[t]
    hues <- unique(as.numeric(item_mat[t, ]))
    nontarget <- hues[abs(wrap_rad_from_deg(hues - target)) > 1e-8]
    stopifnot(length(nontarget) == 3)
    mu <- wrap_rad_from_deg(target - nontarget)
    mu1[t] <- mu[1]; mu2[t] <- mu[2]; mu3[t] <- mu[3]
  }
  list(theta = theta, mu1 = mu1, mu2 = mu2, mu3 = mu3, n = n)
}

# ---- load data ----
d <- read_csv("S1_smallN_model_ready.csv", show_col_types = FALSE) %>%
  mutate(
    CueType = factor(CueType, levels = c("NR", "R")),
    DurationF = factor(
      Duration,
      levels = c("50ms", "100ms", "150ms", "200ms", "250ms", "300ms", "350ms")
    )
  )

cell_grid <- expand_grid(
  CueType = factor(c("NR", "R"), levels = c("NR", "R")),
  DurationF = factor(
    c("50ms", "100ms", "150ms", "200ms", "250ms", "300ms", "350ms"),
    levels = c("50ms", "100ms", "150ms", "200ms", "250ms", "300ms", "350ms")
  )
) %>%
  mutate(cell_id = row_number())

# Existing κ-free cell fits
mix_free <- read_csv("mixture_cells/all_cell_params.csv", show_col_types = FALSE) %>%
  mutate(
    CueType = factor(CueType, levels = c("NR", "R")),
    DurationF = factor(
      DurationF,
      levels = c("50ms", "100ms", "150ms", "200ms", "250ms", "300ms", "350ms")
    )
  )

participants <- c("AQ", "HC", "YILIU")
bic_rows <- list()
param_rows <- list()
row_b <- 0
row_p <- 0

for (pid in participants) {
  message("Fitting κ-tied mixture for ", pid, " ...")
  d_pid <- d %>% filter(ID == pid)
  n_pid <- nrow(d_pid)

  # Precompute cell data packs in grid order
  packs <- vector("list", 14)
  for (i in seq_len(14)) {
    cue <- cell_grid$CueType[i]
    dur <- cell_grid$DurationF[i]
    d_cell <- d_pid %>% filter(CueType == cue, DurationF == dur)
    packs[[i]] <- prepare_cell(d_cell)
    packs[[i]]$CueType <- as.character(cue)
  }

  free_pid <- mix_free %>% filter(ID == pid)
  stopifnot(nrow(free_pid) == 14)
  logLik_free <- -sum(free_pid$nll)
  k_free <- 42L
  bic_free <- -2 * logLik_free + k_free * log(n_pid)
  aic_free <- -2 * logLik_free + 2 * k_free

  # ---- κ-tied NLL ----
  # par: [log_k_NR, log_k_R, then for cells 1..14: logit_beta, logit_gfrac]
  nll_tied <- function(par) {
    k_nr <- exp(par[1])
    k_r <- exp(par[2])
    if (!is.finite(k_nr) || !is.finite(k_r)) return(1e12)
    total <- 0
    for (i in seq_len(14)) {
      beta <- 1 / (1 + exp(-par[2 + 2 * (i - 1) + 1]))
      gfrac <- 1 / (1 + exp(-par[2 + 2 * (i - 1) + 2]))
      gamma <- gfrac * (1 - beta)
      kappa <- if (packs[[i]]$CueType == "NR") k_nr else k_r
      total <- total + mix_nll_cell(
        kappa, beta, gamma,
        packs[[i]]$theta, packs[[i]]$mu1, packs[[i]]$mu2, packs[[i]]$mu3
      )
      if (total > 1e11) return(1e12)
    }
    total
  }

  # Warm start from free fits: mean log κ by cue; cell β, γ from free
  free_ord <- cell_grid %>%
    left_join(free_pid, by = c("CueType", "DurationF"))
  stopifnot(nrow(free_ord) == 14, all(is.finite(free_ord$kappa)))

  k_nr0 <- mean(free_ord$kappa[free_ord$CueType == "NR"])
  k_r0 <- mean(free_ord$kappa[free_ord$CueType == "R"])
  par0 <- c(log(k_nr0), log(k_r0))
  for (i in seq_len(14)) {
    b0 <- min(max(free_ord$beta[i], 1e-4), 0.9)
    # gfrac = gamma / (1 - beta)
    gf0 <- free_ord$gamma[i] / max(1 - free_ord$beta[i], 1e-6)
    gf0 <- min(max(gf0, 1e-4), 0.9)
    par0 <- c(par0, qlogis(b0), qlogis(gf0))
  }

  starts <- list(par0)
  # A few jittered starts
  for (s in 1:4) {
    starts[[length(starts) + 1]] <- par0 + rnorm(length(par0), 0, 0.15)
  }

  best_nll <- Inf
  best_par <- NULL
  best_conv <- NA_integer_
  for (s in seq_along(starts)) {
    message("  start ", s, "/", length(starts))
    fit <- tryCatch(
      optim(
        par = starts[[s]],
        fn = nll_tied,
        method = "BFGS",
        control = list(maxit = 2500, reltol = 1e-10)
      ),
      error = function(e) {
        message("    optim error: ", conditionMessage(e))
        NULL
      }
    )
    if (is.null(fit)) next
    message("    NLL = ", round(fit$value, 2), " conv = ", fit$convergence)
    if (fit$value < best_nll) {
      best_nll <- fit$value
      best_par <- fit$par
      best_conv <- fit$convergence
    }
  }
  stopifnot(!is.null(best_par), best_conv == 0)

  logLik_tied <- -best_nll
  k_tied <- 30L
  bic_tied <- -2 * logLik_tied + k_tied * log(n_pid)
  aic_tied <- -2 * logLik_tied + 2 * k_tied

  k_nr <- exp(best_par[1])
  k_r <- exp(best_par[2])

  row_b <- row_b + 1
  bic_rows[[row_b]] <- tibble(
    ID = pid,
    n_trials = n_pid,
    logLik_k_free = logLik_free,
    logLik_k_tied = logLik_tied,
    k_free = k_free,
    k_tied = k_tied,
    BIC_k_free = bic_free,
    BIC_k_tied = bic_tied,
    AIC_k_free = aic_free,
    AIC_k_tied = aic_tied,
    # < 0 => κ-free (duration-varying κ) preferred
    delta_BIC_free_minus_tied = bic_free - bic_tied,
    delta_AIC_free_minus_tied = aic_free - aic_tied,
    BIC_winner = if_else(bic_free < bic_tied, "k_free_14", "k_tied_2"),
    AIC_winner = if_else(aic_free < aic_tied, "k_free_14", "k_tied_2"),
    kappa_tied_NR = k_nr,
    kappa_tied_R = k_r,
    convergence_tied = best_conv
  )

  # Store tied cell β, γ with shared κ for inspection
  for (i in seq_len(14)) {
    beta <- 1 / (1 + exp(-best_par[2 + 2 * (i - 1) + 1]))
    gfrac <- 1 / (1 + exp(-best_par[2 + 2 * (i - 1) + 2]))
    gamma <- gfrac * (1 - beta)
    kappa <- if (as.character(cell_grid$CueType[i]) == "NR") k_nr else k_r
    row_p <- row_p + 1
    param_rows[[row_p]] <- tibble(
      ID = pid,
      CueType = as.character(cell_grid$CueType[i]),
      DurationF = as.character(cell_grid$DurationF[i]),
      kappa = kappa,
      beta = beta,
      gamma = gamma,
      p_target = 1 - beta - gamma
    )
  }

  message(
    "  BIC free = ", round(bic_free, 1),
    " | BIC tied = ", round(bic_tied, 1),
    " | delta = ", round(bic_free - bic_tied, 1),
    " | winner = ", if_else(bic_free < bic_tied, "k_free", "k_tied")
  )
}

mix_kappa_bic <- bind_rows(bic_rows)
mix_kappa_tied_params <- bind_rows(param_rows)

write_csv(mix_kappa_bic, "bayes_primary_discrete/mixture_kappa_free_vs_tied_bic.csv")
write_csv(mix_kappa_tied_params, "bayes_primary_discrete/mixture_kappa_tied_params.csv")

# Also juxtapose free κ from mixture_cells for the plot/table
mix_kappa_free_params <- mix_free %>%
  select(ID, CueType, DurationF, kappa, beta, gamma, p_target)

write_csv(mix_kappa_free_params, "bayes_primary_discrete/mixture_kappa_free_params.csv")

print(mix_kappa_bic %>% mutate(across(where(is.numeric), ~ round(.x, 2))))
message("Done.")
