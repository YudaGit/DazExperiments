################################################################################
# Population coding model with CDM. Polar angle of drift given by a
# von Mises/Gumbel-max model 
#    [T,Gt, Theta, Ptheta, Mt] = popcdm2(P, nw, h, tmax) 
#     P = [vnorm, eta1, eta2, a, alpha, kappa, ter, st]
# vnorm is the drift rate norm, eta1 and eta2 are the radial and tangential
# components of drift rate variability. 
# Uses circular shifts of distributions in canonical orientation to make
# eta1 and eta2 radial and tangential variability. Avoids the need to 
# use the complicated expressions in Smith (2019) for the rotationally
# invariant model.

# adopted to R. 30/04/2026 YDL
################################################################################
source("besselFPT.R") # Bessel stack(besselzero, dhamana, dserafin, bessel2)
source("popcode.R") # population coding layer
################################################################################

################################################################################
circshift_rows <- function(M, k) {
################################################################################
# Circular shift rows of a matrix downward by k (MATLAB circshift(M, k, 1))
################################################################################
  nr <- nrow(M)
  if (is.null(nr) || nr == 0) return(M)
  k <- k %% nr
  if (k == 0) return(M)
  idx <- c((nr - k + 1):nr, 1:(nr - k))
  M[idx, , drop = FALSE]
}

################################################################################
circshift_vec <- function(v, k) {
################################################################################
# Circular shift a vector to the right by k (MATLAB circshift(v, k))
################################################################################
  n <- length(v)
  if (n == 0) return(v)
  k <- k %% n
  if (k == 0) return(v)
  idx <- c((n - k + 1):n, 1:(n - k))
  v[idx]
}

################################################################################
cdm_core <- function(P, nw, h, tmax) {
################################################################################
# Circular diffusion model, independent Gaussian drift rates, 300 x 50
# step version. 
# Asymptotic correction to the leading edge of the FPT for the Bessel
# process 20/12/22. Passes yfloor, which controls the switch between
# the two representations: yfloor = 1e-12 is good.
################################################################################
  if (length(P) != 6) {
    stop("P must be length 6: v1,v2,eta1,eta2,sigma,a", call. = FALSE)
  }
  
  epsx <- 1e-9 # A small value to filter zeroes
  yfloor <- 1e-12 # Value of noise floor that determined whether dserafin or dhamana is called.
  # 1e-12 is suggested as a good value of yfloor to use, but this can be changed.
  
  kmax <- 50 # Controls truncation of series/Maximum number of eigenvalues in dhamana
  w <- 2 * pi / nw # size of the angular step
  
  # Define a set of diffusion parameters that reproduces the problem
  v1 <- P[[1]] # Mean drift*, x
  v2 <- P[[2]] # Mean drift, y
  eta1 <- P[[3]] # Drift variability*, x
  eta2 <- P[[4]] # Draft variability, y
  sigma <- P[[5]] # Diffusion coefficient (i.e. speed of the "clock")
  a <- P[[6]] # Decision criterion*
  # *Combinations of these parameters at large values exacerbates the instability
  
  # If eta = 0, then the Girsanov transformation becomes undefined, therefore 
  # set it to some arbitrary small value
  eta1 <- max(eta1, 0.01)
  eta2 <- max(eta2, 0.01)
  
  bessel_out <- bessel2(a, sigma, kmax, h, tmax, yfloor, 0) # last argument, v = 0, 2D 
  T <- bessel_out$T0
  Gt0 <- bessel_out$Gt
  
  # Vector of angular steps 
  Theta <- -pi + (0:(nw-1)) * w
  szTheta <- length(Theta)
  
  szT <- length(T)
  Pmt <- rep(0, szTheta)
  
  for (i in 1:szTheta) {
    Pmt[i] <- exp(a * cos(Theta[i]) * v1 / sigma^2 + a * sin(Theta[i]) * v2 / sigma^2)
  }
  
  Commonscale <- exp(-0.5 * (v1^2/sigma^2 + v2^2/sigma^2) * T)
  DensityScale <- sum(Commonscale * Gt0) * h #integral of K(|mu|)*G_bessel(t)
  
  Ptheta <- Pmt * DensityScale / (2 * pi) 
  
  Gt0 <- Gt0 / (2 * pi) # Scale to put density on 2d scale.
  
  Gt <- matrix(0, nrow = szTheta, ncol = szT)
  for (i in 1:szTheta) {
    G11 <- (v1 * sigma^2 + a * eta1^2 * cos(Theta[i]))^2
    G21 <- (v2 * sigma^2 + a * eta2^2 * sin(Theta[i]))^2
    Gt[i, 1] <- 0
    for (k in 2:szT) {
      Multiplier <- sigma^2 / ((sigma^2 + eta1^2 * T[k])^0.5 * (sigma^2 + eta2^2 * T[k])^0.5)
      G12 <- 2 * (eta1^2 * sigma^2) * (sigma^2 + eta1^2 * T[k])
      G22 <- 2 * (eta2^2 * sigma^2) * (sigma^2 + eta2^2 * T[k])
      Girs1 <- exp(G11/G12 - v1^2/(2*eta1^2))
      Girs2 <- exp(G21/G22 - v2^2/(2*eta2^2))
      Gt[i, k] <- Multiplier * Girs1 * Girs2 * Gt0[k]
    }
  }
  
  # Estimate means numerically (analytic does not work with drift variability)
  totalmass <- sum(Gt) * w * h
  
  Ptheta_num <- rep(0, szTheta)
  Mt <- rep(0, szTheta)
  for (i in 1:szTheta) {
    for (k in 2:szT) {
      Ptheta_num[i] <- Ptheta_num[i] + (Gt[i, k] + Gt[i, k-1]) / 2
      Mt[i] <- Mt[i] + (T[k] * Gt[i, k] + T[k-1] * Gt[i, k-1]) / 2
    }
    Ptheta_num[i] <- Ptheta_num[i] * (h / totalmass)
    Mt[i] <- Mt[i] * (h / Ptheta_num[i] / totalmass)
  }
  Gt[Gt < epsx] <- epsx
  list(T = T, Gt = Gt, Theta = Theta, Ptheta = Ptheta_num, Mt = Mt)
}

################################################################################
popcdm300 <- function(P, nw, h, tmax, return_components = FALSE) {
################################################################################
# POPCDM wrapper (adopted from popcdm2 Matlab)
# P = c(vnorm, eta1, eta2, a, alpha, kappa, ter, st)
################################################################################
  if (length(P) != 8) {
    stop("Wrong length P: expected 8 (vnorm, eta1, eta2, a, alpha, kappa, ter, st)",
         call. = FALSE)
  }
  
  w <- 2 * pi / nw
  sigma <- 1.0  # fixed scaling convention
  
  vnorm <- P[1]
  eta1 <- max(P[2], 0.01)
  eta2 <- max(P[3], 0.01)
  a <- P[4]
  alpha <- P[5]
  kappa <- P[6]
  ter <- P[7]
  st <- P[8]
  
  Theta <- -pi + (0:(nw - 1)) * w
  T <- seq(0, tmax, by = h)
  sz <- length(T)
  szh <- length(Theta)
  
  # Output containers
  Ptheta <- rep(0, szh)
  Mt <- rep(0, szh)
  Gta <- matrix(0, nrow = szh, ncol = sz) # joint dist. without nondecision times
  Gt <- matrix(0, nrow = szh, ncol = sz)  #joint dist. with nondecision time
  Ptheta_components <- if (return_components) matrix(0, nrow = nw, ncol = nw) else NULL
  
  # Population code distribution of polar angles of drift rate
  pc_out <- popcode(c(alpha, kappa), nw)
  Pang <- pc_out$pang
  
  # Integrate across distribution of drift rates
  # Canonical orientation: drift starts at first theta bin (-pi)
  v1 <- vnorm * cos(Theta[1]) # start with drift vector pointing to -pi, rotate
  v2 <- vnorm * sin(Theta[1])
  Pi <- c(v1, v2, eta1, eta2, sigma, a)
  
  base <- cdm_core(Pi, nw, h, tmax)
  Gts <- base$Gt
  Pthetas <- base$Ptheta
  Mts <- base$Mt
  
  # Mix by circularly shifting canonical CDM outputs
  for (i in 1:nw) {
    k <- i - 1
    Gmix <- circshift_rows(Gts, k)
    Ptheta_i <- circshift_vec(Pthetas, k)
    Mt_i <- circshift_vec(Mts, k)
    Gta <- Gta + Pang[i] * Gmix
    Ptheta <- Ptheta + Pang[i] * Ptheta_i
    Mt <- Mt + Pang[i] * Mt_i
    if (return_components) {
      Ptheta_components[i, ] <- Ptheta_i
    }
  }
  
  # Add nondecision time mean shift
  T <- T + ter + st / 2
  
  # Add nondecision time variability by uniform convolution
  if (st > 2 * h) {
    m <- round(st / h)
    fe <- rep(1, m) / m #Uniform distribution of nondecision times
    for (i in 1:nw) {
      Gti <- convolve(Gta[i, ], fe, type = "open")
      Gt[i, ] <- Gti[1:sz]  # truncate extra values from convolution
    }
    Mt <- Mt + ter + st / 2
  } else {
    Gt <- Gta # negligible nondecision time
    Mt <- Mt + ter
  }
  
  out <- list(T = T, Gt = Gt, Theta = Theta, Ptheta = Ptheta, Mt = Mt)
  if (return_components) {
    out$Pang <- Pang
    out$Ptheta_components <- Ptheta_components
  }
  out
}