# DSERAFIN.R
# Asymptotic first-passage time density of the Bessel process. 
# mu = nu in standard notation, boundary a = 1
# Serafin (2017), Theorem 3.3, p. 3172, 
# v = 0 2D, v = 1/2 3D; v = 1, 4D; x = starting point
# Uses v rather than mu (Serafin (2017) used mu)

# Translated from MATLAB function dserafin.m into R

dserafin <- function(a, sigma, v, h, tmax, x){
  res <- c()
  scale <- (a/sigma)^2
  tmaxs <- tmax / scale
  hs <- h / scale
  
  Ts <- seq(hs, tmaxs, by = hs)
  
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
  