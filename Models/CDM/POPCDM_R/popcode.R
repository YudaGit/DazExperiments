############################################
# Helper functions for population code layer
############################################

###############################################################################
vm <- function(kappa, nw){
###############################################################################
# Von Mises density function
# [theta, ftheta] = vm(kappa, nw)
###############################################################################
  # input checks
  if (!is.numeric(kappa) || length(kappa) != 1L || !is.finite(kappa) || kappa < 0) {
    stop("kappa must be a finite numeric scalar >= 0", call. = FALSE)
  }
  if (!is.numeric(nw) || length(nw) != 1L || nw < 3 || nw != as.integer(nw)) {
    stop("nw must be an integer >= 3", call. = FALSE)
  }
  
  w <- 2 * pi / nw
  theta <- -pi + (0:(nw-1)) * w
  
  # grid sanity
  if (length(theta) != nw) {
    stop("theta grid length mismatch", call. = FALSE)
  }
  
  I0 <- besselI(kappa, 0)
  K <- 2 * pi * I0
  ftheta <-  exp(kappa * cos(theta)) / K
  
  # density sanity
  if (any(!is.finite(ftheta)) || any(ftheta < 0)) {
    stop("vm produced invalid density values", call. = FALSE)
  }
  # optional: numerical integral check (warning only)
  mass <- sum(ftheta) * w
  if (abs(mass - 1) > 1e-3) {
    warning(sprintf("vm grid integral is %.6f (expected ~1)", mass))
  }
  
  list(theta = theta, ftheta = ftheta)
}

###############################################################################
popcode <- function(P, nw){
###############################################################################
# Distribution of the polar angle of drift rates from population coding model
# von Mises tuning, standard Gumbel noise
#     [th, pangth] = popcode(P, nw)
#     P = [alpha, kappa], von Mises amplitude, concentration
# pangth is a probability mass function, not a density
###############################################################################
  if (length(P) < 2) {
    stop("Wrong length P: expected at least 2 values (alpha, kappa)", call. = FALSE)
  }
  
  gamma <-  0.5772156649 # Euler-Mascheroni constant
  alpha <-  P[1]
  kappa <-  P[2]
  mu <-  0
  beta <- 1.0 # Standard Gumbel, other parameters not identified
  gumbel_mean <-  mu + beta * gamma
  
  vm_out <- vm(kappa, nw)
  th <- vm_out$theta
  pth <- vm_out$ftheta
  
  tuning <- alpha * pth
  # U  <- gumbel_mean * rep(1, length(th)) 
  # skipped given R's direct scalar-vector broadcasting
  popArray <- gumbel_mean + tuning
  pang <- popArray / sum(popArray) # LCM
  
  if (any(!is.finite(pang)) || any(pang < 0)) {
    stop("popcode produced invalid PMF values", call. = FALSE)
  }
  if (abs(sum(pang) - 1) > 1e-10) {
    warning(sprintf("sum(pang)=%.12f (expected ~1)", sum(pang)))
  }
  
  list(th = th, pang = pang)
}