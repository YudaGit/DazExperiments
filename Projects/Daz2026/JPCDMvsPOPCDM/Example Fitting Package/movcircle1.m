function [ll,qaic,qbic, Pred,Gstuff] = movcircle1(Pvar, Pfix, Sel, Data, trace)
% ==========================================================================
% Circular diffusion model for Experiment 1 (4 conditions)
% 2-point antipodal mixture. pi1 now mixing rather than guessing probability.
% May 16, 2021
% Tangential components of v and eta  set to zero
% 1a: 2 x Ter, 2 x st
% Two coherence conditions. 
%   [ll,qaic,qbic,Pred,Gstuff] =  movcircle1(Pvar, Pfix, Sel, Data, trace)
%    P = [v1a..v4a,  eta1a..eta4a, a,  b   a1...a4, alpha, pi1,  Ter  st]
%           1..4         5..8      9,  10, 11...14,   15   16    17   18
%  'Data' is a 4-element cell array
%% ===========================================================================

   tmax = 4.0;
   badix = 5;

   name = 'MOVCIRCLE1: ';
   errmg1 = 'Incorrect number of parameters for model, exiting...';
   errmg2 = 'Incorrect length selector vector, exiting...';
   errmg3 = 'Data should be a 1 x 2 cell array from <makelike>...';


   np = 18;
   ncond = 4;
   ncat = 4;
   tau2 = 1.0; % Overdispersion.
   
   n1 = length(Data{1});
   n2 = length(Data{2});
   n3 = length(Data{3});
   n4 = length(Data{3});
   ntot = n1 + n2 + n3 + n4;
   
   epsx = 1e-9;

   if nargin < 5
       trace = 0;
   end;
   lp = length(Pvar) + length(Pfix);
   if lp ~= np
        [name, errmg1], length(Pvar), length(Pfix), return;
   end
   if length(Sel) ~= np
        [name, errmg2], length(Sel), return;
   end
   if any(size(Data) ~= [1,4])
        [name, errmg3], size(Data), return;
   end     
   
   % Assemble parameter vector.
   P = zeros(1,np);
   P(Sel==1) = Pvar;
   P(Sel==0) = Pfix;
   Ptemp = P;
   save Ptemp Ptemp   

   % Allow for stimulus bias in nonzero second drift component.
   % Asimuth
   v1a = P(1);
   v2a = P(2);
   v3a = P(3);
   v4a = P(4);   
   v1b = 0;
   v2b = 0;
   v3b = 0;
   v4b = 0;

   eta1a = P(5);
   eta2a = P(6);
   eta3a = P(7);
   eta4a = P(8);
   eta1b = 0.05;
   eta2b = 0.05;
   eta3b = 0.05;
   eta4b = 0.05;
   
   if Sel(6) == 0
      eta2a = eta1a;
   end
   if Sel(7) == 0
      eta3a = eta2a;
   end
   if Sel(8) == 0
      eta4a = eta3a;
   end   

   a= P(9);
   b = P(10);  % Two amplitude components
   Abias = P(11:14); % FOUR categories
   alpha = P(15);
   pi1 = P(16);
   ter = P(17);
   st = P(18);
   
   
   Bbias = b * ones(1, ncat);
   sigma =1.0; 
   % Locations hard wired
   U4 = ones(1,4);
   U6 = ones(1,6);

   % Reduce max etas
   % -----------------------------------------------------------------------------------
   % v1a...v4a, eta1a....eta4a, a,    b    a1...a4,       alpha,  pi1, Ter,  st1]
   % -----------------------------------------------------------------------------------
    loose_eta = 1;
    if loose_eta
       Ub= [ 7.0*U4, 4.5*U4,   5.0,  6.0,  pi*ones(1,ncat),       25   1.0,      1.0,  0.7]; 
       Lb= [-7.0*U4,   0*U4,   0.5,    0, -pi*ones(1,ncat),            0,   0,   -0.2,  0];
       Pub=[ 6.5*U4, 4.4*U4,   4.8,  6.5,  (pi-eps)*ones(1,ncat), 24, .95,       0.8,  0.6];
       Plb=[-6.5*U4,   0*U4,   0.7,  0.02, -(pi+eps)*ones(1,ncat),        0,  0, -0.16, 0];
    else
       Ub= [ 7.0*U4, 2.3*U4,   5.0,  6.0,  pi*ones(1,ncat),       25   1.0,      1.0,  0.7]; 
       Lb= [-7.0*U4,   0*U4,   0.5,    0, -pi*ones(1,ncat),            0,   0,   -0.2, 0];
       Pub=[ 6.5*U4, 2.2*U4,   4.8,  6.5,  (pi-eps)*ones(1,ncat), 24, .95,  0.8,   0.6];
       Plb=[-6.5*U4,   0*U4,   0.7,  0.02, -(pi+eps)*ones(1,ncat),        0,  0,  -0.16, 0];
    end      
    Pred = cell(3,2); % Only two discriminability conditions
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
      
    
      P=[v1a, v1b, eta1a, eta1b, sigma, a, alpha, pi1, ter, st; 
         v2a, v2b, eta2a, eta2b, sigma, a, alpha, pi1, ter, st;
         v3a, v3b, eta3a, eta3b, sigma, a, alpha, pi1, ter, st; 
         v4a, v4b, eta4a, eta4b, sigma, a, alpha, pi1, ter, st];
      ll = zeros(1, ncond);
      Gstuff = cell(3, ncond);
      Pred = cell(3, ncond); % Four discriminability conditions
      Gstuff1 = cell(ncond);
      Gstuff2 = cell(ncond);
      Gstuff3 = cell(ncond);
      Pred1 = cell(ncond);
      Pred2 = cell(ncond);
      Pred3 = cell(ncond);


      parfor i = 1 : ncond
          [Gstuffi, Predi, lli] = vacircle12j(P(i,:), Data{i}, Abias, Bbias, tmax, badix);
          Gstuff1{i} = Gstuffi{1};
          Gstuff2{i} = Gstuffi{2};
          Gstuff3{i} = Gstuffi{3};
          Pred1{i} = Predi{1};
          Pred2{i} = Predi{2};
          Pred3{i} = Predi{3};
          ll(i) = lli; 
      end
      Gstuff{1,1} = Gstuff1{1};
      Gstuff{1,2} = Gstuff1{2};
      Gstuff{1,3} = Gstuff1{3};
      Gstuff{1,4} = Gstuff1{4};
      Gstuff{2,1} = Gstuff2{1};
      Gstuff{2,2} = Gstuff2{2};
      Gstuff{2,3} = Gstuff2{3};
      Gstuff{2,4} = Gstuff2{4};
      Gstuff{3,1} = Gstuff3{1};
      Gstuff{3,2} = Gstuff3{2};
      Gstuff{3,3} = Gstuff3{3};
      Gstuff{3,4} = Gstuff3{4};
      Pred{1,1} = Pred1{1};
      Pred{1,2} = Pred1{2};
      Pred{1,3} = Pred1{3};
      Pred{1,4} = Pred1{4};
      Pred{2,1} = Pred2{1};
      Pred{2,2} = Pred2{2};
      Pred{2,3} = Pred2{3};
      Pred{2,4} = Pred2{4};
      Pred{3,1} = Pred3{1};
      Pred{3,2} = Pred3{2};
      Pred{3,3} = Pred3{3};
      Pred{3,4} = Pred3{4};
      ll = sum(ll);
      ll = ll + penalty;  % Took out abs here, screwing up negatives
      qaic = 2 * ll /tau2  + 2 * sum(Sel);
      qbic = 2 * ll/tau2 +  sum(Sel) * log(ntot);   
  end
end

function [Gstuff, Pred, sll0] = vacircle12j(Pj, Dataj, Abias, Bbias, tmax, badix)
% ===============================================================================================
% Compute predictions and log-likelihoods for one condition.
% Initially return predictions marginalized across stimulus angle.
% Pass out everything as a cell array to facilitate parallelization.
%  
%     [Gstuff, Pred, sll0] = vacircle12j(Pj, Dataj, Abias, Bbias)
% Now puts everything into canonical orientation to avoid the etas problem
%      P = [v1, v2, eta1, eta2, sigma, a, alpha, pii, ter, st]
%  Calculate components of likelihood for one discriminability condition.
%  B is the amplitute of the bias vectors; currently hardwired; RawBias is the location 
% ===============================================================================================
   np = 10; 
   nw = 50; 
   nv = 50; 
   nt = 300; 
   h = tmax / nt; 
   w = 2 * pi / nw;
   nvm = fix(nv / 2);
   nw1 = nw + 1;
   nv1 = nv + 1;
   %Abias = sort(signed_angle(Abias)); % (radians unsigned);
  
   epsx = 1e-9;
   contamden = 0.05;  % Contaminant density.
   ter = Pj(9);
   st = Pj(10);
   ld = size(Dataj);
   if ld(2) ~= 4
      disp('MOVSPHERE2A: Wrong size data matrix, returning...')
      size(Dataj)
      return
   end
   if length(Pj) ~= np
      disp('Wrong length parameter vector, returning...');
      np
      return
   end

   [t, gt, thetas, theta, ptheta, mtheta] = vjoint5density(Pj(1:8), Abias, Bbias, nw1, nv1, nt, tmax, badix);
   % Filter zeros  
   gt = max(gt, epsx); % [51, 300, 51] % with wrap-around.
   % Add nondecision time
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
   Cx = isnan(l0);
   l0(Cx) = contamden;
   ll0 = -log(l0);
   sll0 = sum(ll0); % Summing now done here to avoid passing back different sized structures

  % Marginals for accuracy, joint distribution and MRT
   gtm = zeros(nw, nt);  % Last index is stimulus phase
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
  %ptheta
  %etheta
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
   ft = zeros(nt, nv1);
   ft(:,:) = cumsum(sum(gt, 1)) * w * h;
   for j = 1:nv
        mjlo = max(find(ft(:, j) <  0.5));
        mjhi = max(find(ft(:, j) <= 0.5));
        mdtheta(j) = (t(mjlo) + t(mjhi)) / 2; 
   end
   mdtheta(nv1) = mdtheta(1); 
   
  % Do this locally now and only pass back output structures
   Gstuff = cell(3, 1);
   Pred = cell(3, 1);
   Gstuff{1} = t;
   Gstuff{2} = theta;
   Gstuff{3} = gtm;
   Pred{1} = [t; ftm];
   Pred{2} = [theta; pthetam'];
   Pred{3} = [theta; etheta; mtheta; mdtheta];       
end



function [t, gt, thetas, thetaerr, ptheta, mtheta] = vjoint5density(P, Abias, Bbias, nw1, nv1, nt, tmax, badix)
% ===============================================================================================
% [t,gt,thetas, thetaerr,ptheta,mtheta] = vjoint5density(P, BiasAngle, nw1, nv1, nt, tmax, badix);
% P = [v1, v2, eta1, eta2, sigma, a, alpha, pmix]
% pi1 now pmix - antipodal mixing probability
% Circular diffusion predictions as a function of stimulus angle.
% Stimuli in canonical orientation (i.e., re 0), bias computed as an offset. 
% ===============================================================================================
  np = 8;
  if length(P) ~= np
       disp('vjoin5density: wrong length parameter vector, return...');
       P
       return
   end 
   v1 = P(1);
   v2 = P(2);
   eta1 = P(3);
   eta2 = P(4);  % Fix tangential, vary elevation.
   sigma = P(5);
   a = P(6);
   alpha = P(7);
   pmix = P(8);
   nt = 300; % number of time steps
   ncat = 4;
   epsilon  = 0.0001;
   n_sa_step = 11;
   nv = nv1 - 1;
   v = 2 * pi / nv;
   B = Bbias; 

   thetaerr = linspace(-pi, pi, nw1); % To accommodate wrap around. 
   thetas = linspace(-pi, pi,  nv1);
   ltheta = length(thetas);
   thetav = zeros(1, ltheta);
   Vtheta = zeros(2, ltheta);   % Values of drift at stimulus angle.
   %VthetaPhase = zeros(1, ltheta)
   gt = zeros(nw1, nt, nv1);  % Last index is stimulus phase
   ptheta = zeros(nw1, nv1);
   mtheta = zeros(nw1, nv1);
   etheta = zeros(nw1, nv1);
   t = linspace(0, tmax, nt);

   gt_all = zeros(nw1, nt, nv1, n_sa_step);  % Last index is stimulus phase
   ptheta_all = zeros(nw1, nv1, n_sa_step);
   mtheta_all = zeros(nw1, nv1, n_sa_step);

   % Structures for parfor

   vnorm = sqrt(v1^2 + v2^2);
   % Bias
   Thetasex = ones(ncat,1) * thetas;
   %thetas
   %BiasAngle
   BiasAnglex = Abias' * ones(1, nv1);
   Bias = B' * ones(1, nv1);
  % Use 1 - cos distance. 
   Distance = BiasAnglex - Thetasex;
   CircularDistance = 1 - cos(Distance);
   DecayedBias =  vnorm * Bias .* exp(-alpha * CircularDistance);
   DistanceCos = cos(Distance);
   DistanceSin = sin(Distance);
   SumBiasCos = sum(DecayedBias .* DistanceCos);
   SumBiasSin = sum(DecayedBias .* DistanceSin);
   for k = 1:nv1 
       Vtheta(1,k) = v1 + SumBiasCos(k);
       Vtheta(2,k) = v2 + SumBiasSin(k);    
       %[Vtheta(1,k), 0, Vtheta(2,k), ...
       %      eta1, 0, eta2, sigma, a]    
       [~,gt1(:,:,k), ~, ptheta1(:,k), mtheta1(:,k)] = vdcircle300cls([Vtheta(1,k), Vtheta(2,k), ...
               eta1, eta2, sigma, a], tmax, badix);
  end

  if pmix < 0.05
      gt = gt1;
      ptheta = ptheta1;
      mtheta = mtheta1;
  else
      for k = 1:nv1 
          Vtheta(1,k) = -v1 + SumBiasCos(k);
          Vtheta(2,k) = v2 + SumBiasSin(k);    
          %[Vtheta(1,k), 0, Vtheta(2,k), ...
          %      eta1, 0, eta2, sigma, a]    
          [~,gt2(:,:,k), ~, ptheta2(:,k), mtheta2(:,k)] = vdcircle300cls([Vtheta(1,k), Vtheta(2,k), ...
                 eta1, eta2, sigma, a], tmax, badix);
      end   
      gt = (1 - pmix) * gt1 + pmix * gt2;
      ptheta = (1 - pmix) * ptheta1 + pmix * ptheta2;
      mtheta = (1 - pmix) * mtheta1 + pmix * mtheta2;
  end
end


