# DHAMANA.R
# First passage time density for a bessel process,
# Derivative of Hamana-Matsumoto solution, for x0 = 0 (Eq. 2.7)
# a is starting point.
# kmax controls truncation of series
dhamana <- function(a, sigma, kmax, h, tmax){
  # Empty list to store results
  res <- c() 
  
  sigma2 <- sigma^2
  a2 <- a^2
  
  T0 <- seq(h, tmax, by=h)
  J0k <- besselzero(0, kmax, 1)
  J0k_squared <- J0k^2
  J1k <- besselJ(J0k, 1)
  
  Rt <- rep(0, length(T0))
  
  scaler <- sigma2/a2
  
  for(k in 1:kmax){
    Rt <- Rt + J0k[k] * exp(-J0k_squared[k] * sigma^2 * T0 /(2 * a2)) / J1k[k]
  }
  
  Gt <- scaler * Rt
  
  res$T0 <- c(0, T0) # append zero at the start of time vector
  res$Gt <- c(0, Gt)
  return(res)
}