function [ll, qaic, qbic, Pred] = jgjp5(Pvar, Pfix, Sel, Data, trace)
% ==========================================================================
% Circular diffusion model with Jones-Pewsey phase angle to Jay Gu's
% desaturation experiment, 2 saturation x 4 set size (1, 2, 4, 6)
% Same as Allen Qian's experiment but with blocked saturation. 
% Power-law 2 x beta model. Modified <vwmjp79x> % 27/04/26
% 03/05/26 - delta > .25, already has st < .25
%   [ll,qaic, qbic,Pred] =  jgj5(Pvar, Pfix, Sel, Data, trace)
% P = [nrm1:nrm8 k1:k8, eta1..eta4, Psi1..Psi4,   B,     A,   alpha, a, Ter1:Ter4 st delta, beta1:beta2]  
%         1:8     9:16   17:20       21:24      25:28  29:32   33   34   35:38    39   40   41:42
%    'Data' is a (2 x 4) -element cell array using the new conventions. 
%     A is raw bias angles, B is bias strength; k, and psi are JP precision
%     and shape. The etas are radial variability.
% 5/5/26 - modified to allow A to go outside (-pi,pi], wraps around
% 5/5/26 - allow 1 x eta
% ===========================================================================

   name = 'JGJP5: ';
   errmg1 = 'Incorrect number of parameters for model, exiting...';
   errmg2 = 'Incorrect length selector vector, exiting...';
   errmg3 = 'Data should be a 2 x 4 cell array...';

   tau2 = 1.0; % No overdispersion.

   nsat = 2; % Number of saturations
   nset = 4; % Number of set sizes
   np = 42;
   M = [1, 2, 4, 6];
   tmax = 5.0;  % Set from histograms by eye 

   noise = 1e-12;
   kstep = 0.01; % interpolation mesk for kappas
   nw = 50; 
   nv = 50; 
   sz = 300; 

   % Number of trials in each discriminability condition.
   N = 0;
   for i = 1:nsat
      for j = 1:nset
         N = N + length(Data{i,j});
      end
   end

   epsx = 1e-9;

   if nargin < 5
       trace = 0;
   end;
   lp = length(Pvar) + length(Pfix);
   if lp ~= np
        [name, errmg1], length(Pvar) + length(Pfix), return;
   end
   if length(Sel) ~= np
        [name, errmg2], length(Sel), return;
   end
   if size(Data) ~= [nsat,nset]
        [name, errmg3], size(Data), return;
   end     
    
   % Assemble parameter vector.
   P = zeros(1,np);
   P(Sel==1) = Pvar;
   P(Sel==0) = Pfix;
   Ptemp = P;
   save Ptemp Ptemp 

   Vnrm = P(1:8);
   Kappa = P(9:16);
   Eta = P(17:20);
   Psi = P(21:24);
   Bbias =P(25:28);
   Abias = wrapped_angle(P(29:32));
   alpha = P(33);
   a = P(34);
   Ter = P(35:38);
   st = P(39);
   delta = P(40);
   Beta = P(41:42);

   if Sel(2) == 0
      Vnrm(2) = Vnrm(1);
   end   
   if Sel(3) == 0
      Vnrm(3) = Vnrm(2);
   end   
   if Sel(4) == 0
      Vnrm(4) = Vnrm(3);
   end   

   % Need for 1 x v models
   if Sel(5) == 0
      Vnrm(5) = Vnrm(4);
   end     
   if Sel(6) == 0
      Vnrm(6) = Vnrm(5);
   end   
   if Sel(7) == 0
      Vnrm(7) = Vnrm(6);
   end   
   if Sel(8) == 0
      Vnrm(8) = Vnrm(7);
   end 
   %Vnrm
   % 1 x eta models
   if Sel(18) == 0 
       Eta(2) = Eta(1);
   end
   if Sel(19) == 0 
       Eta(3) = Eta(2);
   end
   if Sel(20) == 0 
       Eta(4) = Eta(3);
   end
   %Eta
   % 1 x psi models
   if Sel(22) == 0
       Psi(2) = Psi(1);
   end
   if Sel(23) == 0
      Psi(3) = Psi(2);
   end
   if Sel(24) == 0
      Psi(4) = Psi(3);
   end
   %Psi
   % Must do before kappa
   if Sel(42) == 0 % single beta
          Beta(2) = Beta(1);
   end
   
%  Sample-size in 1/CSD  - needs constraint on Psi first - first saturation
   %Kappa
   % 2 x kappa 
   if Sel(9) == 1 & Sel(10:12) == 0
       % sample size in 1/CSD
       Kappa(1:4) = invprec([Kappa(1), Psi(1), Beta(1)], M, kstep);
   end
   if Sel(13:16) == 0 % 1 x kappa only but still 2 x beta
       % sample size in Prec(v) instead of kappa - use kappa1 for both saturations
       Kappa(5:8) = invprec([Kappa(1), Psi(1), Beta(2)], M, kstep);
   end
   if Sel(13) == 1 & Sel(14:16) == 0 % 2 x kappa + 2 x beta
       % sample size in Prec(v) instead of kappa
       Kappa(5:8) = invprec([Kappa(5), Psi(1), Beta(2)], M, kstep);
   end
   %Kappa

   if Sel(36) == 0 
      Ter(2) = Ter(1);
   end
   if Sel(37) == 0 
      Ter(3) = Ter(2);
   end
      if Sel(38) == 0 
      Ter(4) = Ter(3);
   end
   %Ter  
   sigma =1.0; 

   U2 = ones(1,2);
   U4 = ones(1,4);
   U8 = ones(1,8);
     
   % -------------------------------------------------------------------------------------------------
   % P = [nrm1:nrm8 k1:k8, eta1..eta4, Psi1..Psi4,   B,     A,   alpha, a, Ter1:Ter4 st delta beta ]  
   %        1:8     9:16   17:20       21:24      25:28  29:32    33    34   35:38   39   40   41:42 
   % delta > .25  % Relaxes constraints on A (polar angle of bias)
   % -------------------------------------------------------------------------------------------------
   Ub = [7.5*U8, 9.0*U8,  4.0*U4,   1.0*U4,  9.0*U4,  2*pi*U4, 10.0, 7.0, 1.5*U4, 0.4, 1.0, 1.0*U2]; 
   Lb = [  0*U8,    0*U8,  0*U4,    -2.0*U4,    0*U4, -2*pi*U4,  0.2,  0.5,  0*U4,   0, 0,    0*U2]; 
   Pub =[7.2*U8, 6.0*U8,  3.5*U4,   0.05*U4, 8.0*U4,  2*pi*U4, 9.0, 6.0, 1.0*U4, 0.25, 0.99, 0.9*U2];  
   Plb =[0.5*U8,  0.1*U8,  0.01*U4, -1.95*U4,   0*U4, -2*pi*U4, 1.3, 0.1, .15*U4,  0, 0.25, .25*U2]; 

    if any(P - Ub > 0) | any(Lb - P > 0)
       ll = 1e7 + ...
            1e3 * (sum(max(P - Ub, 0).^2) + sum(max(Ub - P).^2));
       bic = 0;
       if trace
          max(P - Ub, 0)
          max(Lb - P, 0)
       end
   else
      penalty =  1e3 * (sum(max(P - Pub, 0).^2) + sum(max(Plb - P, 0).^2));
      if trace
          max(P - Pub, 0)
          max(Plb - P, 0)
          penalty
      end;
      
      % Calculate and sum likelihoods, precisions, circular standard deviations
      CircSD = zeros(nsat, nset);
      Gstuff = cell(3, nsat, nset);
      redstuff = cell(3, nsat, nset);

      ll = 0;
      for i = 1:nsat
          for j = 1:nset
             k = (i-1) * nset + j;  % 8 x v and 8 x kappa (Psi changed i to j - sat to set (12/09/24)
             Pij = [Vnrm(k), Kappa(k), Eta(j), Psi(j), sigma, a, alpha, Ter(j), st, delta];
             [tij, gtmij, ftmij, thetaij, pthetaij, mthetaij, mdthetaij, ethetaij, llij] = ...
                                                 aigvmj(Pij, Data{i,j}, Abias, Bbias, tmax, sz, nw, nv, noise);
             cseij = circular_standard_deviation(thetaij, pthetaij);
             CircSD(i,j) = cseij;

             % Pass out the raw densities for the quantile-probability plot.
             Gstuff{1,i,j} = tij;
             Gstuff{2,i,j} = thetaij;
             Gstuff{3,i,j} = gtmij;

             % ftm is a double marginalization across w and v.
             Pgtij = [tij; ftmij];
             Pthij = [thetaij; pthetaij'];
             Rthij = [thetaij; ethetaij; mthetaij; mdthetaij];
             Predstuff{1,i,j} = Pgtij;            
             Predstuff{2,i,j} = Pthij;
             Predstuff{3,i,j} = Rthij;                        
             % Sum the log-likelihoods
             ll = ll + sum(llij);
          end
      end            
     qaic = 2 * ll /tau2  + 2 * sum(Sel); 
     qbic = 2 * ll /tau2 + sum(Sel) * log(N);
    
     % Package these together to facilitation automation - now 4d cell arrays
     Pred = cell(3,1);
     Pred{1} = Predstuff;
     Pred{2} = Gstuff;
     Pred{3} = CircSD;

    % Penalize log-likelihood quadratically.
     ll = abs(ll) + penalty;
  end
end

function Predk = invprec(P, n, deltak);
% ============================================================================
% Calculate the sample-size kappas for a sample-size model on 1/CSD (Prec(v))
%     Predk = invprec(P, n, deltak);
%      P = [kappa, psi, beta]
% ============================================================================
    maxk = 7.5;
    w = 2*pi / 50;
    Kappas = [0:deltak:maxk];
    sz = length(Kappas);
    kappa = P(1);
    psi = P(2);
    beta = P(3);
    Pv = zeros(1, sz);

    for i = 1:sz
        pvi = prec([Kappas(i), psi], w);
        Pv(i) = pvi;
    end
    Pkappa = Pv;
    pv1 = prec([kappa, psi], w);
    Predv = pv1 * n.^-beta;
    Predk = interp1(Pkappa, Kappas, Predv);     
end        



function pv = prec(P, w);
% ============================================================================
% Jones-Pewsey circular distribution
%   pv = pewsey(P, h); their equation 2.
%   P = [kappa, psi]
% (normalization the same for positive and negative Psi, see their comment
% on p. 1423
% ============================================================================

    % Calculate Jones-Pewsey density
    kappa = P(1);
    psi = P(2);
    Theta = [-pi:w:pi];
    eps = 1e-9;
    if psi == 0 
       psi = eps;
    end
    one_on_psi = 1 / psi;
    Ptheta = (cosh(kappa*psi) + sinh(kappa*psi) * cos(Theta)).^one_on_psi/(2*pi);
    mass = sum(Ptheta)*w;
    Ptheta = Ptheta / mass;
    
    % Calculate CSE and Pred(v) of Jones-Pewsey density
    Ctheta = Ptheta .* cos(Theta);
    Stheta = Ptheta .* sin(Theta);
    Ctheta_sum = sum(Ctheta) * w;
    Stheta_sum = sum(Stheta) * w;
    Rp_bar = sqrt(Ctheta_sum^2 + Stheta_sum^2);
    cse = sqrt(-2 * log(Rp_bar));
    pv = 1 / cse;    
end

function cse = circular_standard_deviation(theta, ptheta)
% ===============================================================================================
% Calculate a theoretical circular standard deviation corresponding to the empirical CSE
% in Circular_Data_Analysis.pdf (follows Mardia and Jupp)
% ================================================================================================
    w = theta(2) - theta(1);
    Ctheta = ptheta' .* cos(theta);
    Stheta = ptheta' .* sin(theta);
    Ctheta_sum = sum(Ctheta) * w;
    Stheta_sum = sum(Stheta) * w;
    Rp_bar = sqrt(Ctheta_sum^2 + Stheta_sum^2);
    cse = sqrt(-2 * log(Rp_bar));    
end

function [t, gtm, ftm, theta, pthetam, mtheta, mdtheta, etheta, ll0] = aigvmj(Pj, Dataj, Abias, Bbias, tmax, sz, nw, nv, noise)
% ===============================================================================================
% Compute predictions and log-likelihoods for one condition.
%    [t, gtm, ftm, theta, pthetam, mtheta, etheta, ll0] = aigvm(.)
%    P = [nrm1, kappa1, eta1, psi, sigma, a, alpha, ter, st, delta]
%          1       2      3     4    5    6   7     8    9
%  Calculate components of likelihood for one discriminability condition.
%  B is the amplitute of the bias vectors; currently hardwired 
% ===============================================================================================
   h = tmax / sz; 
   w = 2 * pi / nw;
   nvm = fix(nv / 2);
   np = 10;
   nw1 = nw + 1;
   nv1 = nv + 1;
   Abias = sort(signed_angle(Abias));

   epsx = 1e-9;
   contamden = 0.05;  % Contaminant density.
   ter = Pj(np-2);
   st = Pj(np-1);
   delta = Pj(np);
   
   ld = size(Dataj);
   if ld(2) ~= 4  % new convention  #### hack
      disp('aigvmj: Wrong size data matrix, returning...')
      size(Dataj)
      return
   end
   if length(Pj) ~= np
      disp('aigvmj: Wrong length parameter vector, returning...');
      np
      return
   end

   [t, gt, thetas, theta, ptheta, mtheta] = joint3density([Pj(1:np-3),delta], Abias, Bbias, tmax, sz, nw1, nv1, noise);
   % Filter zeros  
   gt = max(gt, epsx); % [51, 300, 51] % with wrap-around.
   % Add nondecision times
   t = t + ter + st / 2;
   % --------------------
   % Convolve with Ter.
   % --------------------
   if st > 2 * h
       h = t(2) - t(1);
       m = round(st / h);
       n = length(t);
       fe = ones(1, m) / m;
       gti = zeros(1,n); 
       for i = 1:nw + 1
          for j = 1:nw + 1
              gti = conv(gt(i, :, j), fe);
              gt(i, : ,j) = gti(1:n);
          end
       end
   end
   mtheta = mtheta + ter + st / 2;

   [anglerr, time, angles]=ndgrid(theta, t, thetas);

   % Interpolate in joint density to get likelihoods of each data point
   l0 = interpn(anglerr, time, angles, gt, Dataj(:,2), Dataj(:,3), Dataj(:,1), 'linear');
   Cx = isnan(l0) | l0 == 0;
   l0(Cx) = contamden;
   ll0 = -log(l0);

  % Marginals for accuracy, joint distribution and MRT
   gtm = zeros(nw, sz);  % Last index is stimulus phase
   pthetam = zeros(nw, 1);
   mthetam = zeros(nw, 1);
   etheta = zeros(1, nv);

   gtm = sum(gt(:,:,1:nv), 3) / nv;
   % Predictions for plot
   ftm = sum(gtm) * w;
   pthetam = sum(ptheta(:,1:nv), 2) / nv;
   mthetam = sum(mtheta(:,1:nv), 2) / nv;
   % Mean error computed in canonical orientation - sum across rows for each column (stimulus)
   etheta = sum(ptheta .* theta') * w;
   for j = 1:nv1
       ptheta(:,j) = circshift(ptheta(:, j), j - nvm);
       mtheta(:,j) = circshift(mtheta(:, j), j - nvm);
   end
   % Sum across rows (response angle) gives mean RT for a given stimulus (Nondecision time added above)
   mtheta = sum(ptheta .* mtheta') * w;

   % Do medians
   mdtheta = zeros(1, nv1);
   for j = 1:nv
       gt(:, :, j) = circshift(gt(:, :, j), j - nvm);
   end
   % Sum over response - weird syntax b/c cumsum returns 1 x 300 x 51, need to reduce dimension.
   ft = zeros(sz, nv1);
   ft(:,:) = cumsum(sum(gt, 1)) * w * h;
   for j = 1:nv
        mjlo = max(find(ft(:, j) <  0.5));
        mjhi = max(find(ft(:, j) <= 0.5));
        mdtheta(j) = (t(mjlo) + t(mjhi)) / 2; 
   end
   mdtheta(nv1) = mdtheta(1); 

end


function [t, gt, thetas, thetaerr, ptheta, mtheta] = joint3density(P, Abias, Bbias, tmax, sz, nw1, nv1, noise)
% ===============================================================================================
%  [t,gt,thetas, thetaerr,ptheta,mtheta] = joint3density(P, Abias, Bbias, tmax, nw, nv, noise);
%  P = [nrm1, kappa1, eta1, psi, sigma, a, alpha, delta]
%       1       2      3     4     5    6    7     8
% Circular diffusion predictions as a function of stimulus angle.
% Stimuli in canonical orientation (i.e., re 0), bias computed as an offset. 
% ===============================================================================================

   np = 8; 
   if length(P) ~= np
      disp('joint3density: Wrong length parameter vector, returning...');
      np
      return
   end

   nrm = P(1);
   kappa = P(2);
   eta = P(3);
   psi = P(4);
   sigma = P(5);
   a = P(6);
   alpha = P(7);
   delta = P(8);
   v1 = nrm;  % Always normal
   v2 = 0;  
   
   phi = 0;

   nbias = 4;
   nv = nv1 - 1;
   v = 2 * pi / nv; 

   thetaerr = linspace(-pi, pi, nw1); % To accommodate wrap around. 
   thetas = linspace(-pi, pi,  nv1);
   ltheta = length(thetas);
   thetav = zeros(1, ltheta);
   Vtheta = zeros(2, ltheta);   % Values of drift at stimulus angle.
   %VthetaPhase = zeros(1, ltheta)
   gt = zeros(nw1, sz, nv1);  % Last index is stimulus phase
   ptheta = zeros(nw1, nv1);
   mtheta = zeros(nw1, nv1);
   etheta = zeros(nw1, nv1);
   t = linspace(0, tmax, sz);
 
   % Bias
   Thetasex = ones(nbias,1) * thetas;
   Abiasx = Abias' * ones(1, nv1);
   % TRANSPOSED?
   Bbiasx = Bbias' * ones(1, nv1);
  % Use 1 - cos distance. - distance from the stimuli to each of the bias categories.
   Distance = Abiasx - Thetasex; 
   CircularDistance = 1 - cos(Distance);
   vnorm = sqrt(v1.^2 + v2.^2);
   DecayedBias =  vnorm * Bbiasx .* exp(-alpha * CircularDistance);  
   DistanceCos = delta * cos(Distance);  % Extended bias parameterizes the radial component of bias vector
   DistanceSin = sin(Distance);
   SumBiasCos = sum(DecayedBias .* DistanceCos);
   SumBiasSin = sum(DecayedBias .* DistanceSin);

   % Apply category bias at the mean drift level 
   Vnorm = ones(1, nv1);
   Phik = ones(1, nv1);
   for k = 1:nv1   
        Vtheta(1,k) = v1 + SumBiasCos(k);
        Vtheta(2,k) = v2 + SumBiasSin(k);
        Vnorm(k) = sqrt(Vtheta(1,k)^2 + Vtheta(2,k)^2);
        Phi(k) = atan2(Vtheta(2,k), Vtheta(1,k));
   end     
   parfor k = 1:nv1 % Parallelize here 
        [~,gtk, ~, pthetak, mthetak] = vjp300rot([Vnorm(k), kappa, eta, Phi(k), psi, sigma, a], tmax, noise);
        %plot(tk, gtk)
        %pause
        gt(:,:,k) = gtk;
        ptheta(:,k) = pthetak;
        mtheta(:,k) = mthetak;
   end

   % Wrap around to close for interpolation.
   gt(:,:,nv1) = gt(:,:, 1);
   ptheta(:,nv1) = ptheta(:, 1);
   mtheta(:, nv1) = mtheta(:, 1);

   %plot(thetas, mtheta)
   %disp('In j3')
   %size(ptheta)
   %size(mtheta)
   %pause
end
  
function sa = signed_angle(a)
% ================================================================
% Convert angles on [0 : 2 *pi] to [-pi : +pi]
% ================================================================
    a = a / pi;
    sa = pi * (rem(a , 1) - fix(a / 1));
end

function sa = wrapped_angle(a)
% ================================================================
% Convert angle outside (-pi, pi] range to angle inside range
% From Wernicke et al
% ================================================================
    sa = (mod(mod(a, 2*pi) + 3*pi, 2*pi)) - pi; 
end

