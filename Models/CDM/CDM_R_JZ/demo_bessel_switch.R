# DEMO_BESSEL_SWITCH.R
source('dhamana.R')
source('bessel2.R')
source('besselzero.R')
# Using a pre-selected set of diffusion parameters, replicate the issue with the
# instability of leading edge predictions (probability spike due to amplification
# of noise) with the standard Hamana-Matusmoto solution for the first passage time
# density for a bessel process. This problem is worse when criterion, drift and/or
# drift variability takes large values. Then, demonstrate how combining an asymptotic 
# approximation (at short times) with the standard series expression (at long times)
# results in stable predictions across a wide range of parameter spaces
demo_serafin <- function(is_serafin){
  # Define some values 
  tmax <- 5.1 # Maximum response time
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
  v1 <- 7 # Mean drift*, x
  v2 <- 0 # Mean drift, y
  eta1 <- 1 # Drift variability*, x
  eta2 <- 0.1 # Driaft variability, y
  sigma <- 1 # Diffusion coefficient (i.e. speed of the "clock")
  a <- 5 # Decision criterion*
  
  # *Combinations of these parameters at large values exacerbates the instability
  
  # If eta = 0, then the Girsanov transformation becomes undefined, therefore set 
  # set it to some arbitrary small value
  if(eta1 < epsx){
    eta1 <- 0.01
  }
  
  if(eta2 < epsx){
    eta2 <- 0.01
  }
  
  if(is_serafin){
    res <- bessel2(a, sigma, kmax, h, tmax, yfloor, 0) # last argument, v = 0, 2D process
  } else {
    # First-passage time distribution of the Bessel process, straight Hamana-Matusmoto
    res <- dhamana(a, sigma, kmax, h, tmax)
  }
  T0 <- res$T0 # Timesteps. R treats 'T' as a boolean value, so T0 is disambiguous 
  Gt0 <- res$Gt 

  # Vector of angular steps 
  Theta <- seq(-pi, pi, by = w)
  szTheta <- length(Theta)
  
  szT <- length(T0)
  Pmt <- rep(0, szTheta)
  
  for(i in 1:szTheta){
    Pmt[i] = exp(a * cos(Theta[i]) * v1 / sigma^2 + a * sin(Theta[i]) * v2 / sigma^2);
  }
  
  Gt0 <- Gt0/(2*pi)
  
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
  
  # Filter zeroes
  Gt[Gt < epsx] <- epsx
  
  # Plot the marginal distribution of response times
  gtm <- colSums(Gt) * w
  plot_stuff <- c()
  plot_stuff$T <- T0
  plot_stuff$density <- gtm
  return(plot_stuff)
}

uncorrected <- demo_serafin(FALSE)
corrected <- demo_serafin(TRUE)
par(mfrow = c(1, 2))
plot(uncorrected$T, uncorrected$density, type = 'l', lwd = 1.75, col = 'red', ylim = c(0,4), xlab=substitute(paste(bold('Time'))), ylab=substitute(paste(bold('Density'))), main = 'Uncorrected')
plot(corrected$T, corrected$density, type = 'l', lwd = 1.75, col = 'blue', ylim = c(0,4), xlab=substitute(paste(bold('Time'))), ylab=substitute(paste(bold('Density'))), main = 'Corrected')
