# GET_LIKELIHOOD.R

# This is a demonstration of how you might fit the circular model, by getting the summed 
# log likelihood of a set of data by interpolating each trial in the 2D likelihood matrix
# which can then be optimised.

source('vdcircle300.R')

# Need function to do 2D interpolation in R, using the 'pracma' package for this
if (!require(pracma)) install.packages('pracma')
library(pracma)

# Define the parameter vector
# Note sigma (diffusion coefficient) is 1 by convention
#     1   2   3     4     5     6     7     8
#     v1  v2  eta1  eta2  sigma  a   ter   st
P <- c(5, 0,  1,    0,    1,     3,  .15,  0)  # Example parameter vector
tmax <- 5.1

# Some dummy data for the sake of the example. Double-check this against MATLAB for equivalence
angles <- c(-0.09, 0.20, -0.02, -2.72, 2.86)
RTs <- c(2.38, 0.60, 0.67, 0.78, 0.91)
data <- cbind(angles, RTs)

get_likelihood <- function(P, data){
  # Call vdcircle with the parameter vector P
  CDM <- vdcircle300(P, tmax)
  
  # Iterate over the data points. This could be made more efficient by using apply() over data, but first test equivalence w MATLAB.
  # Doesn't really matter for our purposes, but for actual application this should probably be made better
  like <- vector(mode = "numeric", length = nrow(data))
  for(i in 1:nrow(data)){
    this_angle <- data[[i, 1]]
    this_RT <- data[[i, 2]]
    # To get the likelihood of a given trial (angle and RT), we do 2D interpolation
    # GT is a matrix of likelihoods, 
    this_like <- interp2(CDM$T, CDM$Theta, CDM$Gt, this_RT, this_angle, 'linear')
    like[i] <- this_like
  }
  
  # Out of range values returned as NaN's. Treat as contaminants - set small.
  like[is.na(like)] <- 1e-9
  nLL <- sum(-log(like))
  return(nLL)
}

# Now, plug in the parameters and the data 
nLL <- get_likelihood(P, data)
print(nLL)
