simcdm5 <- function(P, tmax, ntrials, trace) {
#SIMCDM5  Spike-and-slab 2D diffusion simulator (random walk), circular boundary.
#   [x, t, rx, tx, trx] <-simcdm5(P, tmax, ntrials)
#   [x, t, rx, tx, trx] <-simcdm5(P, tmax, ntrials, trace)
#
#   Each trial mixes two drift regimes with probability q ("spike") vs 1-q ("slab"):
#   - Spike: drift mean ~ (vnorm, 0) plus Gaussian variability (eta1 radial, eta2 tangential).
#   - Slab: drift has norm vnorm and uniformly random direction on [-pi, pi].
#
#   P <-[vnorm, eta1, eta2, a, Ter, st, q]
#        radial/tangential variability names match slabcdmsim3 (etar <-eta1, etat <-eta2).
#
#   Outputs:
#     x    — angle grid used internally (length nw <-73), linspace(-pi, pi, nw)
#     t    — decision-time grid (seconds), excludes Ter (Ter added into tx)
#     rx   — 1 x ntrials response angles (radians), atan2 at boundary crossing
#     tx   — 1 x ntrials RTs including non-decision (seconds)
#     trx  — ntrials x 2, [rx(:), tx(:)] for KDE / histograms
#
#   sigma is fixed at 1; step size h <-0.01 s. Set rng before calling for reproducibility.
#
#   See also: slabcdmsim3, cdmsimll5 (in slabcdmsim3.m).

  if (missing(trace)) trace <- 0L
  
  vnorm <- P[1]
  eta1 <- P[2]
  eta2 <- P[3]
  a <- P[4]
  ter <- P[5]
  st <- P[6]
  q <- P[7]
  sigma <- 1.0 # Standard scaling
  
  h <- .01 # 10 ms steps
  ns <- tmax / h
  nw <- 73 # Like scdm3 without the padding
  x <- seq(-pi, pi, length.out = nw) # same as scdm - wrap around at left end
  rx <- numeric(ntrials)
  tx <- numeric(ntrials)
  trx <- matrix(0, nrow = ntrials, ncol = 2) # ksdensity wants two columns
  t <- h * seq_len(as.integer(ns)) # R need different syntex?
  a <-a - sigma * sqrt(h) / 2 # Overshoot correction for random walk
  
  # Simulate ntrials
  n_terminated <- 0
  Ter <- st * (runif(ntrials) - 0.5) + ter # Vector of random Ter values
  MuSpike <- rbind(vnorm + eta1 * rnorm(ntrials), eta2 * rnorm(ntrials)) # Matrix of random drift rate components
  SlabAngle <- 2 * pi * runif(ntrials) - pi 
  MuSlab <- rbind(vnorm * cos(SlabAngle), vnorm * sin(SlabAngle))
  Q <- runif(ntrials) < q
  # Spike vs slab: same column uses either MuSpike or MuSlab (both 2 x ntrials).
  Mu <- MuSpike
  Mu[, !Q] <- MuSlab[, !Q, drop = FALSE]

  a2 <- a * a
  nmax <- floor(tmax / h)
  
  # allocate space once
  Xt <- matrix(0, nrow = 2, ncol = nmax)
  
  for (j in seq_len(ntrials)) {
    Xt[, ] <- 0 # reinitialize full state (clearer than MATLAB's row-1-only zero)
    Mut <- rbind(rep(Mu[1, j], nmax), rep(Mu[2, j], nmax))
    Sigma_Wt <- rbind(sigma * rnorm(nmax), sigma * rnorm(nmax))
    Dt2 <- 0 # squared distance to origin; start inside circle so first step runs
    i <- 2L

    while (Dt2 < a2 && i <= nmax) {
      Xt[, i] <- Xt[, i - 1L] + Mut[, i] * h + Sigma_Wt[, i] * sqrt(h)
      Dt2 <- Xt[1, i]^2 + Xt[2, i]^2
      i <- i + 1L
    }

    athetaj <- atan2(Xt[2, i - 1L], Xt[1, i - 1L])
    rx[j] <- athetaj
    tx[j] <- (i - 1L) * h + Ter[j]
    trx[j, 1L] <- rx[j]
    trx[j, 2L] <- tx[j]

    if (trace) {
      terminating_step <- i
      terminating_time <- tx[j]
    }

    n_terminated <- n_terminated + 1L
  }

  if (trace) {
    n_terminated <- n_terminated + 1L
  }

  list(x = x, t = t, rx = rx, tx = tx, trx = trx)
}