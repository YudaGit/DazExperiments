# VDCIRCLE300.R
# Circular diffusion model, independent Gaussian drift rates, 300 x 50
# step version. 
# Asymptotic correction to the leading edge of the FPT for the Bessel
# process 20/12/22. Passes yfloor, the yfloor floor, which controls the
# switch between the two representations: yfloor = 1e-12 is good.

# Ensure dependencies are loaded
source('dhamana.R')
source('bessel2.R')
source('besselzero.R')

vdcircle300 <- function(P, tmax, ter, st){
  # tmax <- 5.1 # Maximum response time
  nt <- 300 # Number of time steps
  h <- tmax/nt # Size of a time step
  kmax <- 50 # Controls truncation of series
  nw <- 50 # Number of angular steps on the circle. 7.2 deg. steps
  w <- (2*pi)/ nw # size of the angular step
  
  kmax <- 50 # Maximum number of eigenvalues in dhamana
  epsx <- 1e-9 # A small value to filter zeroes
  yfloor <- 1e-12 # Value of noise floor that determined whether dserafin or dhamana is called.
  # 1e-12 is suggested as a good value of yfloor to use, but this can be changed.
  
  # Define a set of diffusion parameters that reproduces the problem
  v1 <- P[[1]] # Mean drift*, x
  v2 <- P[[2]] # Mean drift, y
  eta1 <- P[[3]] # Drift variability*, x
  eta2 <- P[[4]] # Driaft variability, y
  sigma <- P[[5]] # Diffusion coefficient (i.e. speed of the "clock")
  a <- P[[6]] # Decision criterion*
  
  # *Combinations of these parameters at large values exacerbates the instability
  
  # If eta = 0, then the Girsanov transformation becomes undefined, therefore set 
  # set it to some arbitrary small value
  if(eta1 < epsx){
    eta1 <- 0.01
  }
  
  if(eta2 < epsx){
    eta2 <- 0.01
  }
  

  bessel_out <- bessel2(a, sigma, kmax, h, tmax, yfloor, 0) # last argument, v = 0, 2D 
  T0 <- bessel_out$T0 
  Gt0 <- bessel_out$Gt 
  
  # Vector of angular steps 
  Theta <- seq(-pi, pi, by = w)
  szTheta <- length(Theta)
  
  szT <- length(T0)
  Pmt <- rep(0, szTheta)
  
  for(i in 1:szTheta){
    Pmt[i] = exp(a * cos(Theta[i]) * v1 / sigma^2 + a * sin(Theta[i]) * v2 / sigma^2);
  }
  
  Commonscale = exp(-0.5 * (v1^2/sigma^2 + v2^2/sigma^2) * T0)
  DensityScale = sum(Commonscale * Gt0) * h #integral of K(|mu|)*G_bessel(t)
  
  Gt0 <- Gt0/(2*pi) # Scale to put density on 2d scale.
  
  Gt <- matrix(0, nrow = szTheta, ncol = szT)
  for(i in 1:szTheta){
    G11 = (v1 * sigma^2 + a * eta1^2 * cos(Theta[i]))^2
    G21 = (v2 * sigma^2 + a * eta2^2 * sin(Theta[i]))^2
    Gt[i,1] = 0
    for (k in 2:szT){
      Multiplier = sigma^2/((sigma^2 + eta1^2 * T0[k])^0.5 * (sigma^2 + eta2^2 * T0[k])^0.5)
      G12 = 2 * (eta1^2 * sigma^2) * (sigma^2 + eta1^2 * T0[k])
      G22 = 2 * (eta2^2 * sigma^2) * (sigma^2 + eta2^2 * T0[k])
      Girs1 = exp(G11/G12 - v1^2/(2*eta1^2))
      Girs2 = exp(G21/G22 - v2^2/(2*eta2^2))
      Gt[i,k] = Multiplier * Girs1 * Girs2 * Gt0[k]
    }
  }
  
  # Estimate means numerically (analytic does not work with drift variability)
   totalmass <- sum(Gt) * w * h
   
   Ptheta <- rep(0, szTheta)
   Mt <- rep(0, szTheta)
   
   for(i in 1:szTheta){
     for(k in 2:szT){
       Ptheta[i] <- Ptheta[i] + ((Gt[i, k] + Gt[i, k-1])/2)
       Mt[i] <-  Mt[i] + ((T0[k] * Gt[i, k] + T0[k-1] * Gt[i, k-1])/2)
     }
     Ptheta[i] <- Ptheta[i] * (h / totalmass)
     Mt[i] = Mt[i] * (h / Ptheta[i] / totalmass)
   }
  

  # Filter zeroes
  Gt[Gt < epsx] <- epsx
  
  # Add nondecision times
  T0 = T0 + ter;
  
  # Add nondecision time variability
  if (st > 2 * h){
    m = round(st/h)
    n = length(T0)
    fe = rep(1, m) / m
    for (k in 1:nw+1){
      gti = convolve(Gt[k,], fe, type = 'open')
      Gt[k,] = gti[1:n]
    }
  }
  res <- list()
  res$T  <- T0
  res$Gt <- Gt 
  res$Theta <- Theta
  res$Ptheta <- Ptheta
  res$Mt <- Mt
  return(res)
}
