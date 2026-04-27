# BESSELZERO.R
# Find first k positive zeros of the Bessel function J(n,x) or Y(n,x) using Halley's method.
# Adapted from besselzero.m written by Greg von Winckel
# mathworks.com/matlabcentral/fileexchange/6794-bessel-function-zeros

# Also implemented in CircularDDM https://rdrr.io/cran/CircularDDM/man/besselzero.html

besselzero <- function(n, k, kind){
  
  k3 <- 3*k
  x = rep(0, k3)
  
  for(j in 1:k3){
    # Initial guess of zeroes
    x0 <- 1 + sqrt(2) + (j-1) * pi + n + n^0.4
    
    # Halley's method
    x[j] <- findzero(n, x0, kind)
    
    if(x[j] == 1e9){
      error('Bad guess')
    }
  }
  x <- sort(x, decreasing = FALSE)
  dx <- c(1, abs(diff(x)))
  x <- x[dx > 1e-8]
  x <- x[1:k]
  return(x)
}


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
      a <- besselJ(x0, n)
      b <- besselJ(x0, n1)
    } else if(kind == 2){
      a <- besselY(x0, n)
      b <- besselY(x0, n1)
    }
    
    x02 <- x0^2
    err <- 2*a*x0*(n*a-b*x0)/(2*b*b*x02-a*b*x0*(4*n+1)+(n*n1+x02)*a*a)
    
    x <- x0-err
    x0 <- x
    iter <- iter + 1
  }
  
  if(iter > maxiter){
    warning('Failed to converge to within tolerance. Try a different initial guess')
    x <- 1e9
  }
  return(x)
}