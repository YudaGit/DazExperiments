% ==========================================================================
%  Extended polar three-component model with 3 x psi parameters.
%  Three component circular model: stimulus + antipode + categories
%  [T, Gt, Theta, Ptheta, Mt] = threesphere300pg(P, Abias, Bbias, Qbias, tmax, badix);
%  P = [phi, vnrm, psi1, psi2, psi3, eta1, eta2, eta3, sigma, a, alpha, pi2, pi3, ascale]
%  phi is stimulus angle; psi1, is elevation of stimulus process; psi2 is
%  is elevation of guessing process. Point of nonzero psi1 is to account
%  for shadow mode. 
%  pi2 = antipode, p23 = guessing
%  mex threesphere300pgx.c -lgsl  -lgslcblas -lm
% ===========================================================================
