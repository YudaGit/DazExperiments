function [ll,qaic,qbic, Pred,Gstuff] = movcircle2(Pvar, Pfix, Sel, Data, trace)
% ==========================================================================
% Circular diffusion model for Experiment 2 (4 conditions)
% 2-point antipodal mixture. pi1 now mixing rather than guessing probability.
% May 16, 2021
% Tangential components of v and eta  set to zero
% Two coherence conditions. 
%   [ll,qaic,qbic,Pred,Gstuff] =  movcircle2(Pvar, Pfix, Sel, Data, trace)
%    P = [v1a..v2a, eta1a..eta2a, a  b   a1..a4 alpha, pi1, Ter, st]
%           1..2      3..4        5  6    7..10, 11    12   13  14]
%  'Data' is a 4-element cell array (only two get used)
%% ===========================================================================

   tmax = 4.0; % Set from histograms by eye
   badix = 20;   % ## 5 or 15

   name = 'MOVCIRCLE2: ';
   errmg1 = 'Incorrect number of parameters for model, exiting...';
   errmg2 = 'Incorrect length selector vector, exiting...';
   errmg3 = 'Data should be a 1 x 2 cell array from <makelike>...';

   np = 14;
   ncond = 2;
   ncat = 4;
   tau2 = 1.0; % Overdispersion.
   
   n1 = length(Data{1});
   n2 = length(Data{2});
   ntot = n1 + n2;
 
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
   if size(Data) ~= [1,2]
        [name, errmg3], size(Data), return;
   end     
   
   % Assemble parameter vector.
   P = zeros(1,np);
   P(Sel==1) = Pvar;
   P(Sel==0) = Pfix;
   Ptemp = P;
 
   save Ptemp Ptemp   

   % Allow for stimulus bias in nonzero second drift component.
      
   v1a = P(1);
   v2a = P(2);
   eta1a = P(3);
   eta2a = P(4);
   a= P(5);
   b = P(6);  % Two amplitude components
   Abias = P(7:10);
   alpha = P(11);
   pi1 = P(12);
   ter = P(13);
   st = P(14);
 
   v1b = 0;  % Force tangential to zero.
   v2b = 0; 
   % Azimuths are the same
   if Sel(4) == 0
      eta2a = eta1a;
   end   
      
   % Tangential are negligible 
   eta1b = 0.05;
   eta2b = 0.05;
   Bbias = b * ones(1, ncat);
   sigma =1.0; 
   sa = 0; % Criterion variability
   % Locations hard wired
 
   U2 = ones(1,2);
   U4 = ones(1,4);
   % --------------------------------------------------------------------------------------
   % v1a..v2a,   eta1a..eta2a,  a  b           a1..a4          alpha, pi1, Ter, st
   % --------------------------------------------------------------------------------------- 
    loose_eta = 1;
    if loose_eta
        Ub= [ 7.0*U2,   3.1*U2,   5.0,  6.0,   pi*ones(1,ncat),      25   1.0,  1.0, 0.7]; 
        Lb= [-7.0*U2,    0*U2,    0.5,    0,   -pi*ones(1,ncat)        0,   0,    0.05, 0];
        Pub=[ 6.5*U2,  3.0*U2,    4.8,  6.5,   (pi-eps)*ones(1,ncat), 24, .95,   0.8, 0.6];
        Plb=[-6.5*U2,    0*U2,    0.7,  0.02, -(pi+eps)*ones(1,ncat),  0,  0,    0.08, 0];
    else
        Ub=[ 7.0*U2,   1.3*U2,   5.0,  6.0,   pi*ones(1,ncat),      25   1.0,  1.0, 0.7]; 
        Lb= [-7.0*U2,    0*U2,    0.5,    0,   -pi*ones(1,ncat)        0,   0,    0.05, 0];
        Pub=[ 6.5*U2,  1.2*U2,    4.8,  6.5,   (pi-eps)*ones(1,ncat), 24, .95,   0.8, 0.6];
        Plb=[-6.5*U2,    0*U2,    0.7,  0.02, -(pi+eps)*ones(1,ncat),  0,  0,    0.08, 0];
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
      
    
      P=[v1a, v1b, eta1a, eta1b, sigma, a, alpha, sa, pi1, ter, st; 
         v2a, v2b, eta2a, eta2b, sigma, a, alpha, sa, pi1, ter, st];
      ll = zeros(1, ncond);
      Gstuff = cell(3, ncond);
      Pred = cell(3, ncond); % Two discriminability conditions
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
%     [Gstuff, Pred, sll0] = vacircle12j(Pj, Dataj, Abias, Bbias, tmax, badix)
% Now puts everything into canonical orientation to avoid the etas problem
%      P = [v1, v2, eta1, eta2, sigma, a, alpha, sa, pii, ter, st]
%  Calculate components of likelihood for one discriminability condition.
%  B is the amplitute of the bias vectors; currently hardwired; RawBias is the location 
% ===============================================================================================
   np = 11;
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
   ter = Pj(10);
   st = Pj(11);
   ld = size(Dataj);
   if ld(2) ~= 4   % #### modified for Dataj (extra column)
      disp('VAICIRCLE300J: Wrong size data matrix, returning...')
      size(Dataj)
      return
   end
   if length(Pj) ~= np
      disp('Wrong length parameter vector, returning...');
      np
      return
   end

   [t, gt, thetas, theta, ptheta, mtheta] = vjoint5density(Pj(1:9), Abias, Bbias, nw1, nv1, nt, tmax, badix);
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
%  [t,gt,thetas, thetaerr,ptheta,mtheta] = vjoint5density(P, BiasAngle, nw1, nv1, nt, tmax, badix);
% P = [v1, v2, eta1, eta2, sigma, a, alpha, sa, pii]
% Circular diffusion predictions as a function of stimulus angle.
% Stimuli in canonical orientation (i.e., re 0), bias computed as an offset. 
% ===============================================================================================
  np = 9;
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
   sa = P(8);
   pmix = P(9);
   nt = 300; % number of time steps
   ncat = 4; % ### Must be made consistent with global declaration because not passed in.
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
       [~,gt1(:,:,k), ~, ptheta1(:,k), mtheta1(:,k)] = vdcircle300cls([Vtheta(1,k), Vtheta(2,k), ...
                    eta1, eta2, sigma, a], tmax, badix);
   end
    % Wrap around to close for interpolation.
   gt1(:,:,nv1) = gt1(:,:, 1);
   ptheta1(:,nv1) = ptheta1(:, 1);
   mtheta1(:, nv1) = mtheta1(:, 1);
   if pmix < .05  % No antipodal point
       gt = gt1;
       ptheta = ptheta1;
       mtheta = mtheta1;
   else  % Do second component of mixture - categories should work in anticanonical orientation.
       % Same categories for prime and antipode
       for k = 1:nv1 
            Vtheta(1,k) = -v1 + SumBiasCos(k);
            Vtheta(2,k) = v2 + SumBiasSin(k);    
            [~,gt2(:,:,k), ~, ptheta2(:,k), mtheta2(:,k)] = vdcircle300cls([Vtheta(1,k), Vtheta(2,k), ...
                                                   eta1, eta2, sigma, a], tmax, badix);
       end             
       % Wrap around to close for interpolation.
       gt2(:,:,nv1) = gt2(:,:, 1);
       ptheta2(:,nv1) = ptheta2(:, 1);
       mtheta2(:, nv1) = mtheta2(:, 1);
       gt = (1 - pmix) * gt1 + pmix * gt2;
       ptheta = (1 - pmix) * ptheta1 + pmix * ptheta2;
       mtheta = (1 - pmix) * mtheta1 + pmix * mtheta2;
   end  
   
   
end


