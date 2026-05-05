# Trial-to-parameter mapping for POPCDM (population layer scaling only).
# P order: c(vnorm, eta1, eta2, a, alpha, kappa, ter, st)
#
# colorN = itemN - redundantN + 1  ("distinct color count" under trial_gen conventions).
# baseline / R_NR / homoR:  scaled = base / sqrt(colorN) on alpha OR kappa (pop_tune).
# R_R:                 scaled = base / sqrt(colorN) * sqrt(redundantN) on the tuned parameter.

clip_pos <- function(x, lo) pmax(lo, x)

default_beta <- function() {
  list(
    baseAlpha = 1.0,
    baseKappa = 10.0,
    vnorm = 3,
    eta1 = 0.5,
    eta2 = 0.01,
    a = 1.0,
    ter = 0.20,
    st = 0.50
  )
}

map_trial_to_params <- function(trial, beta = default_beta(), pop_tune = c("alpha", "kappa")) {
  pop_tune <- match.arg(pop_tune)
  itemN <- as.integer(trial$set_size)
  rN <- as.integer(trial$redundant_n)
  colorN <- itemN - rN + 1L
  if (colorN < 1L) {
    stop("map_trial_to_params: need colorN = itemN - redundantN + 1 >= 1", call. = FALSE)
  }

  scale <- 1 / sqrt(as.numeric(colorN))
  if (trial$mode == "R_R") {
    scale <- scale * sqrt(as.numeric(rN))
  }

  if (pop_tune == "alpha") {
    alpha <- beta$baseAlpha * scale
    kappa <- beta$baseKappa
  } else {
    alpha <- beta$baseAlpha
    kappa <- beta$baseKappa * scale
  }

  alpha <- clip_pos(alpha, 1e-4)
  kappa <- clip_pos(kappa, 1e-4)

  c(
    clip_pos(beta$vnorm, 1e-4),
    clip_pos(beta$eta1, 0.01),
    clip_pos(beta$eta2, 0.01),
    clip_pos(beta$a, 1e-4),
    alpha,
    kappa,
    clip_pos(beta$ter, 0),
    clip_pos(beta$st, 0)
  )
}
