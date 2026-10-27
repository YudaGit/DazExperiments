function [T, Gt, Theta, Ptheta, Mt] = cauchycdm2(P, tmax)
%CAUCHYCDM2 Wrapped-Cauchy phase-angle mixture of circular diffusion.
%
%   [T,Gt,Theta,Ptheta,Mt] = cauchycdm2(P,tmax)
%   P = [vnorm, eta1, eta2, a, kappa, ter, st]
%
% The compiled vjp300rot core fixes Jones-Pewsey psi=-1. The core grid is
% fixed at 50 unique angles and 300 time points; runtime parameters do not
% require recompilation.

    arguments
        P (1,7) double
        tmax (1,1) double {mustBePositive} = 3.0
    end
    if any(~isfinite(P))
        error('CauchyCDM:NonFiniteParameter', 'All parameters must be finite.');
    end
    if exist('vjp300rot', 'file') ~= 3
        error('CauchyCDM:MexMissing', ...
            'vjp300rot MEX is missing. Run build_cauchycdm_mex first.');
    end

    vnorm = P(1);
    eta1 = max(P(2), 0.01);
    eta2 = max(P(3), exp(-6));
    a = P(4);
    kappa = P(5);
    ter = P(6);
    st = P(7);
    sigma = 1.0;
    phi = 0.0;
    noise = 1e-12;

    [T, GtClosed, ThetaClosed, PthetaClosed, MtClosed] = vjp300rot( ...
        [vnorm, kappa, eta1, eta2, phi, sigma, a], tmax, noise);
    Gta = GtClosed(1:end-1, :);
    Theta = ThetaClosed(1:end-1);
    Ptheta = PthetaClosed(1:end-1);
    Mt = MtClosed(1:end-1);

    h = T(2) - T(1);
    T = T + ter + st/2;
    if st > 2*h
        m = round(st/h);
        kernel = ones(1, m) / m;
        % Apply the uniform kernel to the complete angle-by-RT matrix.
        Gt = conv2(Gta, kernel, 'full');
        Gt = Gt(:, 1:numel(T));
        Mt = Mt + ter + st/2;
    else
        Gt = Gta;
        Mt = Mt + ter;
    end
end
