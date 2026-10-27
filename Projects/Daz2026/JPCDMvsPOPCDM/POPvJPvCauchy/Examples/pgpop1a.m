function [ll, ll2, qaic, qbic, Pred] = pgpop1a(Pvar, Pfix, Sel, Data, trace)
% ==========================================================================
% Circular diffusion model with Cauchy phase angle to Paul's multirange replication.
% This is M = [1,2,4,6]
%   [ll,ll2,qaic,qbic,Pred] =  pgpop1a(Pvar, Pfix, Sel, Data, trace)
% P =  [nrm1:nrm4 k1, xi  eta,   B,     A,   alpha, a,  Ter1:Ter4 st delta, beta]  
%          1:4    5    6   7   8:11   12:15   16   17   18:21     22   23    24
% 10/08/26
% 20/08/26 - added ll2, B = 0 short-circuit
% 22/08/26 - allow 5 column data array in aigvmj to accommodate {vwm23}
% ===========================================================================

   name = 'JGPOP1A: ';
   errmg1 = 'Incorrect number of parameters for model, exiting...';
   errmg2 = 'Incorrect length selector vector, exiting...';
   errmg3 = 'Data should be a 2 x 4 cell array...';

   tau2 = 1.0; % No overdispersion.

   nsat = 2; % Number of saturations
   nset = 4; % Number of set sizes
   np = 24;
   M = [1, 2, 4, 6];
   tmax = 5.0;  % Set from histograms by eye 

   noise = 1e-12;
   kstep = 0.01; % interpolation mesk for kappas
   nw = 50; 
   nv = 50; 
   sz = 300; 

   % Number of trials in each discriminability condition.
   N = 0;
   for j = 1:nset
       N = N + length(Data{j});
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

   Vnrm = P(1:4);
   kappa = P(5);
   xi1 = P(6);
   eta = P(7);
   Bbias =P(8:11);
   Abias = wrapped_angle(P(12:15));
   alpha = P(16);
   a = P(17);
   Ter = P(18:21);
   st = P(22);
   delta = P(23);
   beta = P(24);

   if Sel(2) == 0
      Vnrm(2) = Vnrm(1);
   end   
   if Sel(3) == 0
      Vnrm(3) = Vnrm(2);
   end   
   if Sel(4) == 0
      Vnrm(4) = Vnrm(3);
   end   

   if Sel(19) == 0 
      Ter(2) = Ter(1);
   end
   if Sel(20) == 0 
      Ter(3) = Ter(2);
   end
      if Sel(21) == 0 
      Ter(4) = Ter(3);
   end
   sigma =1.0; 
 
   Xi = xi1 * M.^beta;

   sigma =1.0; 

   U2 = ones(1,2);
   U4 = ones(1,4);
     
     
   % ----------------------------------------------------------------------------------------
   %  P =  [nrm1:nrm4  k1,  xi  eta,   B,     A,   alpha, a,  Ter1:Ter4 st delta, beta]  
   %            1:4    5    6    7   8:11   12:15   16    17   18:21    22   23     24

   % ----------------------------------------------------------------------------------------
   Ub0 = [7.5*U4,  50.0,    2.0,    4.0,   9.0*U4,  2*pi*U4, 10.0, 7.0, 1.5*U4, 0.4, 1.0,  1.0*U2]; 
   Lb0 = [  0*U4,   1.0,     0,     0,      0*U4, -2*pi*U4,  0.2,  0.5,  0*U4,   0, 0,     0*U2]; 
   Pub0 =[7.2*U4,  45.0,    1.9,    3.5,   8.0*U4,  2*pi*U4, 9.0, 6.0, 1.0*U4, 0.25, 0.99, 0.9*U2];  
   Plb0 =[0.5*U4,   1.1,   0.01,   0.01,   0*U4, -2*pi*U4, 1.3, 0.1, eps*U4,  0, 0.25,   .25*U2]; 

   Ub = Ub0(Sel==1);
   Lb = Lb0(Sel==1);
   Pub = Pub0(Sel==1);
   Plb = Plb0(Sel==1);

    if any(Pvar - Ub > 0) | any(Lb - Pvar > 0)
       ll = 1e7 + ...
            1e3 * (sum(max(Pvar - Ub, 0).^2) + sum(max(Ub - Pvar).^2));
       qaic = 0;     
       qbic = 0;
       Pred = 0;            
       if trace
          max(Pvar - Ub, 0)
          max(Lb - Pvar, 0)
       end
   else
      penalty =  1e3 * (sum(max(Pvar - Pub, 0).^2) + sum(max(Plb - Pvar, 0).^2));
      if trace
          max(Pvar - Pub, 0)
          max(Plb - Pvar, 0)
          penalty
      end
 
      % Calculate and sum likelihoods, precisions, circular standard deviations
      CircSD = zeros(nset);
      Gstuff = cell(3, nset);
      Predstuff = cell(3, nset);

      ll = 0;
      for j = 1:nset
           Pij = [Vnrm(j), kappa, Xi(j), eta, sigma, a, alpha, delta, Ter(j), st];
           [tij, gtmij, ftmij, thetaij, pthetaij, mthetaij, mdthetaij, ethetaij, llij] = ...
                    aigvmj(Pij, Data{j}, Abias, Bbias, tmax, sz, nw, nv, noise);             
           cseij = circular_standard_deviation(thetaij, pthetaij);
           CircSD(j) = cseij;
           % Pass out the raw densities for the quantile-probability plot.
           Gstuff{1,j} = tij;
           Gstuff{2,j} = thetaij;
           Gstuff{3,j} = gtmij;

           % ftm is a double marginalization across w and v.
           Pgtij = [tij; ftmij];
           Pthij = [thetaij; pthetaij'];
           Rthij = [thetaij; ethetaij; mthetaij; mdthetaij];
           Predstuff{1,j} = Pgtij;            
           Predstuff{2,j} = Pthij;
           Predstuff{3,j} = Rthij;                        
             % Sum the log-likelihoods
           ll = ll + sum(llij);
      end            
    
      % Package these together to facilitation automation - now 4d cell arrays
      Pred = cell(3,1);
      Pred{1} = Predstuff;
      Pred{2} = Gstuff;
      Pred{3} = CircSD;
 
      % Penalize log-likelihood quadratically.
      ll2 = 2 * abs(ll);
      qaic = ll2 /tau2  + 2 * sum(Sel); 
      qbic = ll2 /tau2 + sum(Sel) * log(N);
      ll = abs(ll) + penalty;     
   end
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
%    P = [nrm1, kappa,  xi  eta1, sigma, a, alpha, delta, ter, st]
%          1       2    3     4    5    6    7     8    9      10
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
   ter = Pj(np-1);
   st = Pj(np);
   delta = Pj(np);
   
   ld = size(Dataj);
   %if ld(2) ~= 4  % new convention  #### hack
   if ~(ld(2) == 4 | ld(2) == 5)  % 5 columns needed for vwm23 data

      disp('aigvmj: Wrong size data matrix, returning...')
      size(Dataj)
      return
   end
   if length(Pj) ~= np
      disp('aigvmj: Wrong length parameter vector, returning...');
      np
      return
   end

   [t, gt, thetas, theta, ptheta, mtheta] = joint3density([Pj(1:np-2)], Abias, Bbias, tmax, sz, nw1, nv1, noise);
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
%  P = [nrm1, kappa,   xi   eta1, sigma, a, alpha, delta]
%       1       2      3     4     5    6    7       8
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
   xi = P(3);
   eta = P(4);
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

   if all(Bbias < eps) % skip integration across stimulus space 20/08/26
        %disp('No bias, Phi = 0')
       % Pi = [vnorm, kappa, xi, eta, 0, sigma, a]
        [~,gtk, ~, pthetak, mthetak] = vpop300rot([vnorm, kappa, xi, eta, 0, sigma, a], tmax, noise);
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
            [~,gtk, ~, pthetak, mthetak] = vpop300rot([Vnorm(k), kappa, xi, eta, Phi(k), sigma, a], tmax, noise);
            %[tk,gtk, thetak, pthetak, mthetak] = vcau300rot([Vnorm(k), kappa, eta, Phi(k), psi, sigma, a], tmax, noise);
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

function sa = wrapped_angle(a)
% ================================================================
% Convert angle outside (-pi, pi] range to angle inside range
% From Wernicke et al
% ================================================================
    sa = (mod(mod(a, 2*pi) + 3*pi, 2*pi)) - pi; 
end

