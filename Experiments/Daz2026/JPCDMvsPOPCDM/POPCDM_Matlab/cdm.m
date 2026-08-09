function [T,Gt, Theta, Ptheta, Mt] = cdm(P, nw, h, tmax)
% ========================================================================
% 2D diffusion on a circle with independent normal drift variability
%     [T, Gt, Theta, Ptheta, Mt] = cdm(P, nw, h, tmax)
%     P = [v1, v2, eta1, eta2, sigma, a]
%     Mt is closed-form E[T]
% ========================================================================
    yfloor = 1e-9;
    v1 = P(1);
    v2 = P(2);
    eta1 = P(3);
    eta2 = P(4);
    sigma = P(5);
    a = P(6);

    % First-passage time density for Serafin corrected 2D Bessel process.
    [T, Gt0] = bessel2([a, sigma], h, tmax, yfloor);

    w = 2*pi/nw;
    Theta = [-pi: w : pi - w];
    sztheta = length(Theta);
    szt = length(T);

    Commonscale = exp(-0.5 * (v1^2/sigma^2 + v2^2/sigma^2) * T);
    DensityScale = sum(Commonscale .* Gt0) * h; % Integral of K(|mu|)*G_bessel(t)
    % Multiply theta-dependent drift term by invariant time-dependent term
    Pmt = exp(a * cos(Theta) * v1 / sigma^2 + a * sin(Theta) * v2 / sigma^2);
    Ptheta = Pmt * DensityScale / (2*pi);

    Gt0 = Gt0/ (2 * pi); % Scale to put density on 2d scale.

    % ---------------------------------------------------------------------
    % Vectorized Girsanov density calculation
    % ---------------------------------------------------------------------
    % Angle-only quantities are nw x 1 columns and time-only quantities are
    % 1 x (szt-1) rows. MATLAB implicitly expands them to the complete
    % angle-by-time grid, replacing the original nested interpreted loops.
    thetaColumn = Theta(:);
    positiveTime = T(2:end);

    sigma2 = sigma^2;
    eta1Squared = eta1^2;
    eta2Squared = eta2^2;

    % These terms depend only on response angle.
    G11 = (v1 * sigma2 + a * eta1Squared * cos(thetaColumn)).^2;
    G21 = (v2 * sigma2 + a * eta2Squared * sin(thetaColumn)).^2;

    % These terms depend only on time.
    Multiplier = sigma2 ./ sqrt( ...
        (sigma2 + eta1Squared * positiveTime) .* ...
        (sigma2 + eta2Squared * positiveTime));
    G12 = 2 * eta1Squared * sigma2 .* ...
        (sigma2 + eta1Squared * positiveTime);
    G22 = 2 * eta2Squared * sigma2 .* ...
        (sigma2 + eta2Squared * positiveTime);

    % Implicit expansion creates nw x (szt-1) Girsanov matrices.
    Girs1 = exp(G11 ./ G12 - v1^2 / (2 * eta1Squared));
    Girs2 = exp(G21 ./ G22 - v2^2 / (2 * eta2Squared));

    Gt = zeros(sztheta, szt);
    Gt(:, 2:end) = Girs1 .* Girs2 .* Multiplier .* Gt0(2:end);

    % Conditional mean decision time; the common time-step width cancels.
    Den = sum(Gt, 2);
    Mt = sum(Gt .* T, 2) ./ Den;

end

function [T, Gt0] = bessel2(P0, h, tmax, yfloor)
% ==============================================================================
% First-passage density of zero-drift 2D Bessel process with Serafin correction
% at small time values to control for the spike
%    [G, Gt0] = bessel2(P0, tmax, yfloor)
% ==============================================================================
    [T, Gth] = dhamana(P0, h, tmax);
    [~, Gts] = dserafin(P0, h, tmax);
    %plot(T, Gth, T, Gts)
    %pause
    % Preserve the original switch rule without looping over time points.
    % Use Serafin before its first value at/above yfloor, then Hamana.
    switchIndex = find(Gts >= yfloor, 1, 'first');
    if isempty(switchIndex)
        Gt0 = Gts;
    else
        Gt0 = Gth;
        Gt0(1:switchIndex-1) = Gts(1:switchIndex-1);
    end
end       
         
   
function [T, Gt] = dserafin(P, h, tmax)
% =============================================================================
% Asymptotic first-passage time density of the Bessel process. mu = nu in
% standard notation, boundary a = 1
% Serafin (2017), Theorem 3.3, p. 3172, 
% v = 0 2D, v = 1/2 3D; v = 1, 4D; x = starting point
% Uses v rather than mu (Serafin (2017) used mu)
%
%    [T, Gt] = dserafin(P0, tmax, noise)
% =============================================================================
    v = 0; % Abstract parameterization of Bessel process 2D: v = 0;
    x = 1e-9; % starting point of Bessel process (distance from zero)
    a = P(1);
    sigma = P(2); 
    scale = (a/sigma)^2;
    tmaxs = tmax / scale;
    hs = h / scale;
    T = [hs:hs:tmaxs];
    % The first positive J_0 root is constant. Cache it once per MATLAB
    % process or parallel worker.
    persistent j_mu_1
    if isempty(j_mu_1)
        j_mu_1 = besselzero(v, 1, 1);
    end

    G1 = (1 - x) .* (1 + T).^(v + 2)./((x + T).^(v + 0.5) .* T.^(3/2));
    G2 = exp(-(1 - x)^2./(2 * T) - 0.5 * j_mu_1^2 * T);
    Gt = G1 .* G2;
    T = [0:h:tmax]; 
    Gt = [0, Gt / scale];
end

function [T, Gt] = dhamana(P, h, tmax)
% ====================================================================
% First passage time density for a bessel process, 
% Derivative of Hamana-Matsumoto solution, for x0 = 0 (Eq. 2.7)
% [t, gt] = dhamana(P, h, tmax);
% P =[a, sigma];
% kmax controls truncation of series
% badix is number of bad initial values in Gt to zero.
% =====================================================================
    kmax = 50; % truncation of series hard-wired
    a = P(1);
    sigma = P(2);
    sigma2 = sigma^2;
    T = [h:h:tmax];
    a2 = a^2;
    % The roots and J_1 values are independent of fitted parameters.
    % Cache them once and reuse them on every subsequent model evaluation.
    persistent cachedKmax J0k J0k_squared J1k
    if isempty(J0k) || isempty(cachedKmax) || cachedKmax ~= kmax
        J0k = besselzero(0, kmax, 1);
        J0k_squared = J0k.^2;
        J1k = besselj(1, J0k);
        cachedKmax = kmax;
    end

    scaler = sigma2 / a2;

    % Form all root-by-time terms in one matrix, then sum over roots.
    rootWeights = (J0k ./ J1k).';
    decayRates = J0k_squared.' * (sigma2 * T / (2 * a2));
    Rt = sum(rootWeights .* exp(-decayRates), 1);

    Gt = scaler * Rt;
    T = [0,T];
    Gt = [0,Gt];
    % Not using badix to eliminate the spike
    %if badix > 0 
    %  Gt(1:badix) = 0;
    %end   
end

function [n,pn] = poisson(lambda, m)
% ===============================================================================
% Poisson probability, truncated at m
%     [n,pn] = poisson(lambda, m)
% Probability that number in is 1,2...>=m
%  ==============================================================================
    n = 1 : m
    ni = 1 : m-1
    pni = exp(-lambda) * lambda.^ni ./ factorial(ni)
    pn = [pni, 1 - sum(pni)] % Last is probability that the number in >= m
end
    
