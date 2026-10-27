# Latent z is the angular direction of the consolidated VWM representation.
# Its wrapped Cauchy distribution describes variability across trials.

caumem <- function(P, n) {
  kappa <- P[1]
  theta <- -pi + (0:(n - 1L)) * (2 * pi / n)
  rho <- exp(-kappa)
  
  ptheta <- (1 - rho^2) /
    (2 * pi * (1 + rho^2 - 2 * rho * cos(theta)))
  
  list(theta = theta, ptheta = ptheta)
}

# Conditional on the representation direction z, a cosine signal plus
# Gumbel noise gives a Luce choice.
# Sum over all possible z to obtain the behavioural response distribution.
# P[1] is memory dispersion; P[2] is shared signal-to-Gumbel-noise ratio.
caureport <- function(P, n, decision_signal = c("cosine", "cauchy")) {
  decision_signal <- match.arg(decision_signal)
  mem <- caumem(P, n)
  theta <- mem$theta
  h <- 2 * pi / n
  sens <- P[2]

  pang <- mem$ptheta / sum(mem$ptheta)
  signal <- if (decision_signal == "cosine")
    sens * (cos(theta) - 1) else sens * mem$ptheta
  
  # Gumbel/Luce trick as decision stage variability
  resp_mass <- exp(signal - max(signal))
  resp_mass <- resp_mass / sum(resp_mass)

  # Circular convolution: report error = representation error + decision error.
  
  # Put the zero-error angle first for circular convolution.
  origin <- which.min(abs(theta))
  shift <- c(origin:n, if (origin > 1L) seq_len(origin - 1L))

  # Sum response curves centered on every possible representation direction.
  resp_0 <- stats::convolve(
    pang[shift],
    resp_mass[shift],
    type = "circular",
    conj = FALSE
  )
  pred_mass <- pmax(Re(resp_0[order(shift)]), 0)
  pred_mass <- pred_mass / sum(pred_mass)
  
  list(theta = theta, ptheta = pred_mass / h)
}

caull <- function(P, error_rad, n = 360L) {
  if (length(P) != 2L || any(!is.finite(P)) || P[1] <= 0 ||
      P[2] < 0 || any(!is.finite(error_rad))) return(Inf)

  pred <- caureport(P, n)
  h <- 2 * pi / n
  position <- ((error_rad + pi) %% (2 * pi)) / h
  index <- (round(position) %% n) + 1L
  density <- pred$ptheta[index]
  -sum(log(pmax(density, .Machine$double.xmin)))
}

# AWSS extension of the latent-direction model. N is the number of unique
# colors in the display. P = c(kappa_att_1, kappa_unatt_1, W, sensitivity).
# W is the probability that the probed color belongs to the better-
# consolidated subset (0 <= W <= 1). The two kappas are
# single-color dispersions. r is the number of repeated copies of the
# probed color: 1 for baseline/NR, and ItemN - ColorN + 1 for R.
cauAWSSreport <- function(P, n = 360L, N, r = 1,
                          decision_signal = c("cosine", "cauchy", "exponential",
                                              "gaussian_kernel"),
                          similarity_decay = NULL) {
  decision_signal <- match.arg(decision_signal)
  if (decision_signal == "exponential" &&
      (length(similarity_decay) != 1L || !is.finite(similarity_decay) ||
       similarity_decay <= 0)) {
    stop("A positive similarity_decay is required for the exponential signal.")
  }
  if (length(P) != 4L || any(!is.finite(P)) ||
      length(N) != 1L || !is.finite(N) || N < 1 ||
      length(r) != 1L || !is.finite(r) || r < 1 ||
      n < 2L || n != as.integer(n) ||
      P[1] <= 0 || P[2] <= P[1] ||
      P[3] < 0 || P[3] > 1 || P[4] < 0) {
    stop("Require 0 < kappa_att_1 < kappa_unatt_1, 0 <= W <= 1, and sensitivity >= 0.")
  }

  kappa_att <- P[1] * sqrt(N / r)
  kappa_unatt <- P[2] * sqrt(N / r)
  attended <- caumem(kappa_att, n)
  unattended <- caumem(kappa_unatt, n)
  theta <- attended$theta
  h <- 2 * pi / n
  W <- P[3]

  pang_att <- attended$ptheta / sum(attended$ptheta)
  pang_unatt <- unattended$ptheta / sum(unattended$ptheta)
  pang <- W * pang_att + (1 - W) * pang_unatt

  origin <- which.min(abs(theta))
  shift <- c(origin:n, if (origin > 1L) seq_len(origin - 1L))
  report_kernel <- function(signal) {
    w <- exp(signal - max(signal))
    w / sum(w)
  }
  convolve_state <- function(memory_mass, report_mass) {
    stats::convolve(memory_mass[shift], report_mass[shift],
                    type = "circular", conj = FALSE)
  }
  if (decision_signal != "cauchy") {
    if (decision_signal == "gaussian_kernel") {
      # Direct conditional report probabilities, with circular distance
      # measured from the latent representation. P[4] is width in radians.
      distance <- abs(atan2(sin(theta), cos(theta)))
      resp_mass <- exp(-0.5 * (distance / P[4])^2)
      resp_mass <- resp_mass / sum(resp_mass)
    } else {
      signal <- if (decision_signal == "cosine") {
        P[4] * (cos(theta) - 1)
      } else {
        distance <- abs(atan2(sin(theta), cos(theta)))
        similarity <- exp(-similarity_decay * distance) *
          expm1(-similarity_decay * (pi - distance)) /
          expm1(-similarity_decay * pi)
        P[4] * similarity
      }
      resp_mass <- report_kernel(signal)
    }
    pred_0 <- convolve_state(pang, resp_mass)
  } else {
    # The same state kappa controls latent-angle dispersion and the
    # Cauchy-shaped conditional report signal centred on that angle.
    resp_att <- report_kernel(P[4] * attended$ptheta)
    resp_unatt <- report_kernel(P[4] * unattended$ptheta)
    pred_0 <- W * convolve_state(pang_att, resp_att) +
      (1 - W) * convolve_state(pang_unatt, resp_unatt)
    resp_mass <- NULL
  }
  pred_mass <- pmax(Re(pred_0[order(shift)]), 0)
  pred_mass <- pred_mass / sum(pred_mass)

  list(theta = theta, ptheta = pred_mass / h,
       pang = pang, pang_att = pang_att, pang_unatt = pang_unatt,
       resp_mass = resp_mass, pred_mass = pred_mass,
       decision_signal = decision_signal,
       W = W, Kn_est = N * W, N = N, r = r,
       kappa_att = kappa_att,
       kappa_unatt = kappa_unatt)
}

cauAWSSll <- function(P, error_rad, n = 360L, N, r = 1,
                      decision_signal = c("cosine", "cauchy", "exponential",
                                          "gaussian_kernel"),
                      similarity_decay = NULL) {
  decision_signal <- match.arg(decision_signal)
  if (any(!is.finite(error_rad))) return(Inf)
  pred <- tryCatch(cauAWSSreport(P, n, N, r,
                                decision_signal = decision_signal,
                                similarity_decay = similarity_decay),
                   error = function(e) NULL)
  if (is.null(pred)) return(Inf)

  h <- 2 * pi / n
  position <- ((error_rad + pi) %% (2 * pi)) / h
  index <- (round(position) %% n) + 1L
  -sum(log(pmax(pred$ptheta[index], .Machine$double.xmin)))
}
