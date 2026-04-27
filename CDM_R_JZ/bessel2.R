# BESSEL2.R
# First passage time density for a bessel process
# For the leading edge (small values of t, near noise floor), use Serafin's
# derivation, and switch to the usual Hamana-Matsumoto for larger values
# 
#    v = 0; Bessel process in 2D
#    v = 1/2; 3D, spherical model
#    v = 1; 4D, hyperspherical model
#
#  Translated from bessel2.m
source("dserafin.R")
source("dhamana.R")
bessel2 <- function(a, sigma, kmax, h, tmax, yfloor, v, x){
  if(missing(x)){
    x <- 1e-6 # Default value for starting point
  }
  res <- c()
  serafin <- dserafin(a, sigma, 0, h, tmax, x)
  hamana <- dhamana(a, sigma, kmax, h, tmax)
  
  Gts <- serafin$Gts
  Gth <- hamana$Gt
  
  # Empty vector to assemble the combined densities
  Gt <- rep(0, length(Gth))
  
  # Find first index where Gth exceeds the noise floor
  idx <- which(Gts > yfloor)[1]
  Gt[1:idx] <- Gts[1:idx]
  Gt[(idx+1):length(Gth)] <- Gth[(idx+1):length(Gth)]
  
  res$T0 <- hamana$T0
  res$Gt <- Gt
  return(res)
}
