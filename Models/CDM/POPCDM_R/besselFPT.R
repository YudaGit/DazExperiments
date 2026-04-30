# The bessel stack functions

#################################################################
# findzero() besselzero()
# Find first k positive zeros of the Bessel function J(n,x) or Y(n,x) using Halley's method.
# Adapted from besselzero.m written by Greg von Winckel
# mathworks.com/matlabcentral/fileexchange/6794-bessel-function-zeros

# Also implemented in CircularDDM https://rdrr.io/cran/CircularDDM/man/besselzero.html
#################################################################
findzero <- function(n, x0, kind){
  n1 <- n+1
  n2 <- n^2
  
  # Tolerance
  tol <- 1e-12
  
  # Maximum number of iterations
  maxiter <- 100
  
  # Initial error
  err <- 1
  iter <- 0
  
  while((abs(err) > tol) && (iter < maxiter)){
    if(kind == 1){
      jn <- besselJ(x0, n)
      jn1 <- besselJ(x0, n1)
    } else if(kind == 2){
      jn <- besselY(x0, n)
      jn1 <- besselY(x0, n1)
    }
    
    x02 <- x0^2
    err <- 2*jn*x0*(n*jn-jn1*x0)/(2*jn1*jn1*x02-jn*jn1*x0*(4*n+1)+(n*n1+x02)*jn*jn)
    
    x <- x0-err
    x0 <- x
    iter <- iter + 1
  }
  
  if(iter >= maxiter){ # need to understand this part**
    warning('Failed to converge to within tolerance. Try a different initial guess')
    x <- 1e9
  }
  return(x)
}
#################################################################
besselzero <- function(n, k, kind){
#################################################################  
  k3 <- 3*k
  x = rep(0, k3)
  
  for(j in 1:k3){
    # Initial guess of zeroes
    x0 <- 1 + sqrt(2) + (j-1) * pi + n + n^0.4
    
    # Halley's method
    x[j] <- findzero(n, x0, kind)
    
    if(x[j] == 1e9){
      stop('Bad guess') # Updated error() to stop() to suit base R
    }
  }
  x <- sort(x, decreasing = FALSE)
  dx <- c(1, abs(diff(x)))
  x <- x[dx > 1e-8]
  x <- x[1:k]
  return(x)
}

#################################################################
# dhamana()
# First passage time density for a bessel process,
# Derivative of Hamana-Matsumoto solution, for x0 = 0 (Eq. 2.7)
# a is the absorbing boundary/criterion
# kmax controls truncation of series
#################################################################
dhamana <- function(a, sigma, kmax, h, tmax){
  # Empty list to store results
  res <- list() # updated c() to list()
  sigma2 <- sigma^2
  a2 <- a^2
  T0 <- seq(h, tmax, by=h)
  J0k <- besselzero(0, kmax, 1)
  J0k_squared <- J0k^2
  J1k <- besselJ(J0k, 1)
  
  Rt <- rep(0, length(T0))
  
  scaler <- sigma2/a2 # radial scaler
  
  for(k in 1:kmax){
    Rt <- Rt + J0k[k] * exp(-J0k_squared[k] * sigma^2 * T0 /(2 * a2)) / J1k[k]
  }
  
  Gt <- scaler * Rt
  
  res$T0 <- c(0, T0) # append zero at the start of time vector
  res$Gt <- c(0, Gt)
  return(res)
}

#################################################################
# dserafin()
# Asymptotic first-passage time density of the Bessel process. 
# mu = nu in standard notation, boundary a = 1
# Serafin (2017), Theorem 3.3, p. 3172, 
# v = 0 2D, v = 1/2 3D; v = 1, 4D; x = starting point
# Uses v rather than mu (Serafin (2017) used mu)

# Translated from MATLAB function dserafin.m into R
#################################################################
dserafin <- function(a, sigma, v, h, tmax, x){
  res <- list() # updated c() to list ()
  scale <- (a/sigma)^2 # Normalized formulation
  tmaxs <- tmax / scale
  hs <- h / scale
  
  Ts <- seq(hs, tmaxs, by = hs)
  
  #j_mu_1 is the first positive zero of Jv
  j_mu_1 <- besselzero(v, 1, 1)
  G1 <- (1 - x) * (1 + Ts)^(v + 2)/((x + Ts)^(v + 0.5) * Ts^(3/2))
  G2 <- exp(-(1 - x)^2/(2 * Ts) - 0.5 * c(j_mu_1)^2 * Ts)
  Gt <- G1 * G2
  
  T0 <- seq(0, tmax, by = h) 
  Gt <- c(0, Gt/scale)
  
  res$Ts <- T0
  res$Gts <- Gt
  return(res)
}

#################################################################
# bessel2()
# First passage time density for a bessel process
# For the leading edge (small values of t, near noise floor), use Serafin's
# derivation, and switch to the usual Hamana-Matsumoto for larger values
# 
#    v = 0; Bessel process in 2D
#    v = 1/2; 3D, spherical model
#    v = 1; 4D, hyperspherical model
#
#  Translated from bessel2.m
#################################################################

bessel2 <- function(a, sigma, kmax, h, tmax, yfloor, v, x){
  if(missing(x)){
    x <- 1e-6 # Default value for starting point
  } 
  res <- list() # changed from c() to list()**
  serafin <- dserafin(a, sigma, 0, h, tmax, x)
  hamana <- dhamana(a, sigma, kmax, h, tmax)
  
  Gts <- serafin$Gts
  Gth <- hamana$Gt
  
  # Empty vector to assemble the combined densities
  Gt <- rep(0, length(Gth))
  
  # Find first index where Gts exceeds the noise floor
  idx <- which(Gts > yfloor)[1] # use Serafin until Serafin’s density exceeds yfloor
                                # need safeguard here in case every Gts value is ≤ yfloor?**
  Gt[1:idx] <- Gts[1:idx]
  Gt[(idx+1):length(Gth)] <- Gth[(idx+1):length(Gth)]
  
  res$T0 <- hamana$T0
  res$Gt <- Gt
  return(res)
}
