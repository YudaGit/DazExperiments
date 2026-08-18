function [ll, qaic, qbic, Pred] = vwmjp61(Pvar, Pfix, Sel, Data, trace)
% ==========================================================================
% Circular diffusion model with Jones-Pewsey phase angle to VWM23 experiment.
% M = [1,2,3,4]
% 25/08/24. delta bias (added to previous <vwmjp6>
% 27/08/24. Sample size in 1/CSD rather than kappa (from <vwmjp7>)
% 11/09/24. Power-law beta.
%   [ll,aic, qbic,Pred] =  vwmjp61(Pvar, Pfix, Sel, Data, trace)
% P = [nrm1:nrm4 k1:k4, eta1..eta4, Psi1..Psi4,   B,     A,   alpha, a, Ter1:Ter4 st, delta, beta]  
%         1:4     5:8      9:12        13:16    17:20  21:24   25   26   27:30   31    32    33
%    'Data' is a 4-element cell array using the new conventions. 
%     A is raw bias angles, B is bias strength; k, and Psi are JP precision
%     and shape. The etas are radial variability.
% 18/08/26 - test for B = 0, if so, skip the integration across stimulus space.
% ===========================================================================

   name = 'VWMJP61: ';
   errmg1 = 'Incorrect number of parameters for model, exiting...';
   errmg2 = 'Incorrect length selector vector, exiting...';
   errmg3 = 'Data should be a 1 x 4 cell array from <makelike>...';

   samplesize_in_kappa = false; % else 1/CSD
   
   tau2 = 1.0; % No overdispersion.

   ncond = 4;
   np = 33;

   tmax = 5.0;  % Set from histograms by eye 

   noise = 1e-12;
   kstep = 0.01; % interpolation mesk for kappas
   nw = 50; 
   nv = 50; 
   sz = 300; 

   % Number of trials in each discriminability condition. (SB a bit unbalanced).
   n1 = length(Data{1});
   n2 = length(Data{2});
   n3 = length(Data{3});
   n4 = length(Data{4});

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
   if size(Data) ~= [1,ncond]
        [name, errmg3], size(Data), return;
   end     
    
   % Assemble parameter vector.
   P = zeros(1,np);
   P(Sel==1) = Pvar;
   P(Sel==0) = Pfix;
   Ptemp = P;
   save Ptemp Ptemp 

   Vnrm = P(1:4);
   Kappa = P(5:8);
   Eta = P(9:12);
   if any(Sel(13:16) ~= 0)
      error('CauchyCDM:PsiMustBeFixed', ...
          'Psi is compiled at -1 and cannot be selected as a free parameter.');
   end
   Psi = -ones(1, 4);
   Bbias = P(17:20);
   Abias = P(21:24);
   alpha = P(25);
   a = P(26);
   Ter = P(27:30);
   st = P(31);
   delta = P(32);
   beta = P(33);
                           
  if Sel(2) == 0
      Vnrm(2) = Vnrm(1);
   end   
   if Sel(3) == 0
      Vnrm(3) = Vnrm(2);
   end   
   if Sel(4) == 0
      Vnrm(4) = Vnrm(3);
   end  
   
   if Sel(10) == 0
      Eta(2) = Eta(1);
   end   
   if Sel(11) == 0
      Eta(3) = Eta(2);
   end   
   if Sel(12) == 0
      Eta(4) = Eta(3);
   end   
    
    
   % Equal constraints on Psi's, but only if the first one is free. 
   if Sel(13) ~= 0
       if Sel(14) == 0
           Psi(2) = Psi(1);
       end
       if Sel(15) == 0
           Psi(3) = Psi(2);
       end
       if Sel(16) == 0
           Psi(4) = Psi(3);
       end    
   end

   if samplesize_in_kappa
       if Sel(5) ~= 0
            % SS in kappa 
            M = [1, 2, 3, 4];
            Kpow = Kappa(1) * M.^(-beta);
            Kappa(1) = Kpow(1);
            if Sel(6) == 0
               Kappa(2) = Kpow(2);
            end
           if Sel(7) == 0
               Kappa(3) = Kpow(3);
           end
           if Sel(8) == 0
              Kappa(4) = Kpow(4);
           end
       end
   else    
      % Sample-size in 1/CSD
      if Sel(5) == 1 & Sel(6:8) == 0
          % power law in Prec(v) instead of kappa 11/09/24
          Kappa = invprec([Kappa(1), Psi], [1,2,3,4], kstep, beta);
      end
   end
   %Sel(13:16)
   %Psi
   if Sel(28) == 0 
      Ter(2) = Ter(1);
   end
   if Sel(29) == 0 
      Ter(3) = Ter(2);
   end
      if Sel(30) == 0 
      Ter(4) = Ter(3);
   end
   
   sigma =1.0; 

   U3 = ones(1,3);
   U4 = ones(1,4);

   Ub = [7.5*U4, 7.5*U4,    4.0*U4,     1.0*U4, 9.0*U4,  pi*U4+0.1, 10.0, 5.0, 1.5*U4, 0.7, 1.0, 1.0]; 
   Lb = [  0*U4,   0*U4,      0*U4,    -2.0*U4,   0*U4, -pi*U4-0.1,  0.2,  0.5,  0*U4,   0, 0, 0]; 
   Pub =[7.2*U4, 6.5*U4,    3.5*U4,    0.05*U4, 8.0*U4,  pi*U4+0.05, 9.0, 4.0, 1.0*U4, 0.5, 0.99, 0.9]; 
   Plb =[0.5*U4,  0.1*U4,    0.1*U4,   -1.95*U4, 0.0*U4, -pi*U4-0.05, 1.5, 0.1, eps*U4,  0, 0.01, 0.45]; 

    Predstuff = cell(3,ncond);
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

      P1 = [Vnrm(1), Kappa(1), Eta(1), Psi(1), sigma, a, alpha, Ter(1), st, delta];
      P2 = [Vnrm(2), Kappa(2), Eta(2), Psi(2), sigma, a, alpha, Ter(2), st, delta];
      P3 = [Vnrm(3), Kappa(3), Eta(3), Psi(3), sigma, a, alpha, Ter(3), st, delta];
      P4 = [Vnrm(4), Kappa(4), Eta(4), Psi(4), sigma, a, alpha, Ter(4), st, delta];

      % Estimate likelihoods
      [t1, gtm1, ftm1, theta1, ptheta1, mtheta1, mdtheta1, etheta1, ll1] = ...
                                                 aigvmj(P1, Data{1}, Abias, Bbias, tmax, sz, nw, nv, noise);
      [t2, gtm2, ftm2, theta2, ptheta2, mtheta2, mdtheta2, etheta2, ll2] = ...
                                                 aigvmj(P2, Data{2}, Abias, Bbias, tmax, sz, nw, nv, noise);
      [t3, gtm3, ftm3, theta3, ptheta3, mtheta3, mdtheta3, etheta3, ll3] = ...
                                                 aigvmj(P3, Data{3}, Abias, Bbias, tmax, sz, nw, nv, noise);
      [t4, gtm4, ftm4, theta4, ptheta4, mtheta4, mdtheta4, etheta4, ll4] = ...
                                                 aigvmj(P4, Data{4}, Abias, Bbias, tmax, sz, nw, nv, noise);
      %[sum(ll1), sum(ll2), sum(ll3), sum(ll4)]                                           
      cse1 = circular_standard_deviation(theta1, ptheta1);
      cse2 = circular_standard_deviation(theta2, ptheta2);
      cse3 = circular_standard_deviation(theta3, ptheta3);
      cse4 = circular_standard_deviation(theta4, ptheta4);
      prec1 = 1 / cse1;
      prec2 = 1 / cse2;
      prec3 = 1 / cse3;
      prec4 = 1 / cse4;
      ps1 = [cse1, prec1];
      ps2 = [cse2, prec2];
      ps3 = [cse3, prec3];
      ps4 = [cse4, prec4];
      Precision = [ps1', ps2', ps3', ps4'];


      % Pass out the raw densities for the quantile-probability plot.
      Gstuff = cell(3,ncond);
      Gstuff{1,1} = t1;
      Gstuff{2,1} = theta1;
      Gstuff{3,1} = gtm1;

      Gstuff{1,2} = t2;
      Gstuff{2,2} = theta2;
      Gstuff{3,2} = gtm2;

      Gstuff{1,3} = t3;
      Gstuff{2,3} = theta3;
      Gstuff{3,3} = gtm3;
      
      Gstuff{1,4} = t4;
      Gstuff{2,4} = theta4;
      Gstuff{3,4} = gtm4;
      
     % Minimize sum of minus LL's across two conditions.
     ll = sum(ll1) + sum(ll2) + sum(ll3) + sum(ll4);
     qaic = 2 * ll /tau2  + 2 * sum(Sel); 
     qbic = 2 * ll /tau2 + sum(Sel) * log(n1 + n2 + n3 + n4);
     %ics = [qaic, qbic];
     
     % ftm is a double marginalization across w and v.
     Pgt1 = [t1; ftm1];
     Pgt2 = [t2; ftm2];
     Pgt3 = [t3; ftm3];
     Pgt4 = [t4; ftm4];
        
     Pth1 = [theta1; ptheta1'];
     Pth2 = [theta2; ptheta2'];
     Pth3 = [theta3; ptheta3'];
     Pth4 = [theta4; ptheta4'];
  
     Rth1 = [theta1; etheta1; mtheta1; mdtheta1];
     Rth2 = [theta2; etheta2; mtheta2; mdtheta2];
     Rth3 = [theta3; etheta3; mtheta3; mdtheta3];
     Rth4 = [theta4; etheta4; mtheta4; mdtheta4];

     Predstuff{1,1} = Pgt1;
     Predstuff{1,2} = Pgt2;
     Predstuff{1,3} = Pgt3;
     Predstuff{1,4} = Pgt4;

     Predstuff{2,1} = Pth1;
     Predstuff{2,2} = Pth2;
     Predstuff{2,3} = Pth3;
     Predstuff{2,4} = Pth4;

     Predstuff{3,1} = Rth1;
     Predstuff{3,2} = Rth2;
     Predstuff{3,3} = Rth3;
     Predstuff{3,4} = Rth4;

     % Package these together to facilitation automation
     Pred = cell(3,1);
     Pred{1,1} = Predstuff;
     Pred{2,1} = Gstuff;
     Pred{3,1} = Precision;

    % Penalize log-likelihood quadratically.
     ll = abs(ll) + penalty;
  end
end

function Predk = invprec(P, n, deltak, beta);
% ============================================================================
% Calculate the sample-size kappas for a sample-size model on 1/CSE (Prec(v))
%     Predk = invprec(P, n, deltak);
%      P = [kappa, psi, beta]
% ============================================================================
    maxk = 7.5;
    w = 2*pi / 50;
    Kappas = [0:deltak:maxk];
    sz = length(Kappas);
    kappa = P(1);
    psi = P(2);
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
%          1       2      3     4    5    6   7     8    9    10
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
   
  % Hack 08/08/26 to refit Paul26 data. Didn't have the extra column. 
   ld = size(Dataj);
   if ~(ld(2) == 5 | ld(2) == 4)  % new convention
      disp('aigvmj: Wrong size data matrix, returning...')
      size(Dataj)
      return
   end
   if length(Pj) ~= np
      disp('aigvmj: Wrong length parameter vector, returning...');
      np
      return
   end

   % also need to pass delta
   [t, gt, thetas, theta, ptheta, mtheta] = joint3density([Pj(1:np-3), Pj(np)], Abias, Bbias, tmax, sz, nw1, nv1, noise);
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
   DistanceCos = delta * cos(Distance);  % add delta-bias
   DistanceSin = sin(Distance);
   SumBiasCos = sum(DecayedBias .* DistanceCos);
   SumBiasSin = sum(DecayedBias .* DistanceSin);


   if all(Bbias < eps) % skip integration across stimulus space 
        %disp('No bias, Phi = 0')
        [~,gtk, ~, pthetak, mthetak] = vjp300rot( ...
            [vnorm, kappa, eta, exp(-6), 0, sigma, a], tmax, noise);
        for k = 1:nv1 % nv1 identical copies. 
            gt(:,:,k) = gtk;
            ptheta(:,k) = pthetak;
            mtheta(:,k) = mthetak;      
        end
   else
       %disp('bias, parallelizing')
        % Apply category bias at the mean drift level 
        Vnorm = ones(1, nv1);
        Phik = ones(1, nv1);
        for k = 1:nv1   
            Vtheta(1,k) = v1 + SumBiasCos(k);
            Vtheta(2,k) = v2 + SumBiasSin(k);
            Vnorm(k) = sqrt(Vtheta(1,k)^2 + Vtheta(2,k)^2);
            Phi(k) = atan(Vtheta(2,k)/Vtheta(1,k));
       end     
       parfor k = 1:nv1 % Parallelize here      
            [~,gtk, ~, pthetak, mthetak] = vjp300rot( ...
                [Vnorm(k), kappa, eta, exp(-6), Phi(k), sigma, a], ...
                tmax, noise);
            %[tk,gtk, thetak, pthetak, mthetak] = vjp300rot([Vnorm(k), kappa, eta, Phi(k), psi, sigma, a], tmax, noise);
            %plot(tk, gtk)
            %pause
            gt(:,:,k) = gtk;
            ptheta(:,k) = pthetak;
            mtheta(:,k) = mthetak;
       end     
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
