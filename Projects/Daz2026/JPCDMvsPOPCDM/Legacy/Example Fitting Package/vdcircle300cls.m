function [T,Gt, Theta, Ptheta, Mt] = vdcircle300cls(P, nw, h, tmax, badix)
% ========================================================================
% 2D diffusion on a circle with independent normal drift variability
%     [T, Gt, Theta, Ptheta, Mt] = vdcircle300cls(P, tmax, badix)
%     P = [v1, v2, eta1, eta2, sigma, a]
%     [-pi:pi] closed domain so don't lose last bin in interpolation.
% Building:
%            mex vdcircle300.c -lgsl -lgslcblas  -lm 
% ========================================================================
