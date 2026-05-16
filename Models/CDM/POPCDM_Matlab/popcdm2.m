function [T,Gt, Theta, Ptheta, Mt] = popcdm2(P, nw, h, tmax)
% =======================================================================
% Population coding model with CDM. Polar angle of drift given by a
% von Mises/Gumbel-max model 
%    [T,Gt, Theta, Ptheta, Mt] = popcdm2(P, nw, h, tmax) 
%     P = [vnorm, eta1, eta2, a, alpha, kappa, ter, st]
% vnorm is the drift rate norm, eta1 and eta2 are the radial and tangential
% components of drift rate variability. 
% Uses circular shifts of distributions in canonical orientation to make
% eta1 and eta2 radial and tangential variability. Avoids the need to 
% use the complicated expressions in Smith (2019) for the rotationally
% invariant model.
%  =======================================================================
    if length(P) ~= 8
       disp('Wrong length parameter vector, exiting...')
       length(P)
       return
    end 
    w = 2*pi/nw;
    nvm = fix(nw / 2);
    sigma = 1.0; % fix scaling
    vnorm = P(1);
    eta1 = max(P(2), 0.01);
    eta2 = max(P(3), 0.01);
    a = P(4);
    alpha = P(5);
    kappa = P(6);
    ter = P(7);
    st = P(8);   
    Theta = [-pi: w : pi - w];
    T = [0:h:tmax];
    sz = length(T);
    szh = length(Theta);
    Ptheta = zeros(1, szh);
    Mt = zeros(1, szh);
    Gta = zeros(szh, sz); % joint distribution without nondecision times
    Gt = zeros(szh, sz); % joint distribution with nondecision times
      
    % Population code distribution of polar angles of drift rate
    [~,Pang] = popcode([alpha, kappa], nw);
    %size(Theta)
    %size(Pang)
    %Theta
    %plot(Theta, Pang);
    %pause
    % Integrate across distribution of drift rates
    vnorm = P(1);
    v1 = vnorm * cos(Theta(1)); % start with drift vector pointing to -pi, rotate
    v2 = vnorm * sin(Theta(1)); 
    Pi = [v1,v2,eta1,eta2,sigma,a];
    [~,Gts,~,Pthetas,Mts]=cdm(Pi, nw, h, tmax);
    %Gts
    %pause
    %mass = sum(Pang) 
    for i = 1 : nw
         Gmix = circshift(Gts, i-1, 1);
         %pause
         Gta = Gta + Pang(i) * Gmix;
         Ptheta = Ptheta + Pang(i) * circshift(Pthetas, i-1);
         %Pmix = circshift(Pthetas, i-1);
         %[i,Pang(i)]
         %plot(Theta, Pmix)
         %pause
         Mt = Mt + Pang(i) * circshift(Mts, i-1);
    end 
      
   % Add nondecision times
   T = T + ter + st / 2;
   % --------------------
   % Convolve with Ter.
   % --------------------
   if st > 2 * h
       m = round(st / h);
       n = length(T);
       fe = ones(1, m) / m; % Uniform distribution of nondecision times 
       for i = 1 : nw
            Gti = conv(Gta(i,:), fe);
            Gt(i,:) = Gti(1:sz); % truncate extra values from convolution
       end     
       Mt = Mt + ter + st / 2;      
   else
       Gt = Gta; % negligible nondecision time
       Mt = Mt + ter;
   end         
end       
       

function [th, pang] = popcode(P, nw)
% ===============================================================================
% Distribution of the polar angle of drift rates from population coding model
% von Mises tuning, standard Gumbel noise
%     [th, pangth] = popcode(P, nw)
%     P = [alpha, kappa], von Mises amplitude, concentration
% pangth is a probability mass function, not a density
% ================================================================================
    if length(P) < 2
       disp('Wrong length P, returning...')
       length(P)
       return
    end   
    gamma = 0.5772156649; % Euler-Mascheroni constant 
    alpha = P(1);
    kappa = P(2);
    mu = 0;
    beta = 1.0; % Standard Gumbel, other parameters not identified
    gumbel_mean = mu + beta * gamma;
    [th,pth] = vm(kappa, nw);
    Tuning = alpha * pth;
    U = gumbel_mean * ones(size(th));
    PopArray = U + Tuning;
    pang = PopArray / sum(PopArray); % LCM
end

function [theta, ftheta] = vm(kappa, nw)
% ===========================================================
% Von Mises density function
% [theta, ftheta] = vm(kappa, nw)
% ===========================================================
   w = 2 * pi /nw;
   theta = [-pi:w:pi-w];
   ftheta = exp(kappa * cos(theta));
   K = 2 * pi * besseli(0, kappa);
   ftheta = ftheta / K;
end



function [T,Gt, Theta, Ptheta, Mt] = cdm(P, nw, h, tmax)
% ========================================================================
% 2D diffusion on a circle with independent normal drift variability
%     [T, Gt, Theta, Ptheta, Mt] = vdcircle7(P, nw, h, tmax)
%     P = [v1, v2, eta1, eta2, sigma, a]
%     Mt is closed-form E[T]
% ========================================================================
    yfloor = 1e-9;
    kmax = 50; % Truncation length of series.   
    v1 = P(1);
    v2 = P(2);
    eta1 = P(3);
    eta2 = P(4);
    sigma = P(5);
    a = P(6);
    vnorm = sqrt(v1^2 + v2^2);
    % First-passage time density for Serafin corrected 2D Bessel process.
    [T, Gt0]= bessel2([a, sigma], h, tmax, yfloor);
    %plot(T, Gt0)
    %pause
    w = 2*pi/nw;
    Theta = [-pi: w : pi - w];
    szheta = length(Theta);
    sz = length(T);

    Commonscale = exp(-0.5 * (v1^2/sigma^2 + v2^2/sigma^2) * T);
    DensityScale = sum(Commonscale .* Gt0) * h; % Integral of K(|mu|)*G_bessel(t)
    % Multiply theta-dependent drift term by invariant time-dependent term
    Pmt = exp(a * cos(Theta) * v1 / sigma^2 + a * sin(Theta) * v2 / sigma^2);
    Ptheta = Pmt * DensityScale / (2*pi);

    Gt0 = Gt0/ (2 * pi); % Scale to put density on 2d scale.
    Gt0u = ones(nw,1) * Gt0; % Replicate copies of g0.
    for i = 1:szheta
        G11 = (v1 * sigma^2 + a * eta1^2 * cos(Theta(i)))^2;     
        G21 = (v2 * sigma^2 + a * eta2^2 * sin(Theta(i)))^2;     
        Gt(i,1) = 0;
        for k = 2:sz
            Multiplier = sigma^2./((sigma^2 + eta1^2 * T(k)).^0.5 .* (sigma^2 + eta2^2 * T(k)).^0.5);
            G12 = 2 * (eta1^2 * sigma^2) * (sigma^2 + eta1^2 * T(k));
            G22 = 2 * (eta2^2 * sigma^2) * (sigma^2 + eta2^2 * T(k));
            Girs1 = exp(G11/G12 - v1^2/(2*eta1^2));
            Girs2 = exp(G21/G22 - v2^2/(2*eta2^2));
            Gt(i,k) = Multiplier * Girs1 * Girs2 * Gt0(k);
        end
    end    
    Den=sum(Gt, 2);
    Num = (ones(nw, 1) * T).*Gt;
    Mt = sum(Num, 2) ./ Den;

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
    sz = length(T);
    Gt0 = zeros(1, sz);
    i = 1;
    % find the maximum index where Gts is less than the noise floor
    while Gts(i) < yfloor & i <= sz
       i = i + 1;
    end
    for j = 1:sz
        if j < i
           Gt0(j) = Gts(j);
        else
           Gt0(j) = Gth(j);
        end
   end
   %plot(T, Gt0)
   %pause
end       
         
function [T, Gt] = dserafin(P, h, tmax);
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
    j_mu_1 = besselzero(v, 1, 1);
    G1 = (1 - x) .* (1 + T).^(v + 2)./((x + T).^(v + 0.5) .* T.^(3/2));
    w2 = (1 + T).^(v + 2)./((x + T).^(v + 0.5) .* T.^(3/2));
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
    J0k = besselzero(0, kmax, 1); % v = 0 for drift = (2v + 1)/2x 
    J0k_squared = J0k.^2;
    J1k = besselj(1, J0k);
    Rt = zeros(size(T));
    scaler = sigma2 / a2;
    for k = 1:kmax
        Rt = Rt + J0k(k) * exp(-J0k_squared(k) * sigma^2 * T /(2 * a2)) / J1k(k);
    end
    Gt = scaler * Rt;
    T = [0,T];
    Gt = [0,Gt];
    % Not using badix to eliminate the spike
    %if badix > 0 
    %  Gt(1:badix) = 0;
    %end   
end


