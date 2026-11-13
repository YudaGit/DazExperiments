%==========================================================================
%  Circular diffusion model 300-step C version. Jones-Pewsey distribution.
%  Uses <rotcat> rather than <vdcircle> so that eta_rad and eta_tan
%  are correct for all phase angles of the stimulus.
%  December 22, 2022
%
%  [T, Gt, Theta, Ptheta, Mt] = vjp300rot(P, tmax, noise);
%   P = [vnorm, kappa, eta_rad, eta_tan, phi, psi, sigma, a]
%  
%  Building: mex vjp300rot.c -lgsl -lgslcblas -lm
% =========================================================================== 

