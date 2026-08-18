function [ll,qaic,qbic, Pred,Gstuff] = movsphere2(Pvar, Pfix, Sel, Data, trace)
% ==========================================================================
% Spherical diffusion model fitted to Experiment 2.
% Polar three-component model with 3 x psi parameters.
% Two coherence conditions. 
%   [ll,qaic,qbic,Pred,Gstuff] =  movsphere2(Pvar, Pfix, Sel, Data, trace)
%    P = [nrm1, nrm2, psi1..psi3,eta1a,eta2a, eta1c,eta2c a  b  a1..a4 alpha, pi2,pi3, ascale, Ter, st]
%           1..2         3..5       6..7,        8..9    10  11 12..15, 16    17..18     19    20   21]
%  'Data' is a 4-element cell array (only two get used)
% pi2 is antipode, pi3 is guessing probabilities - assumed to be equal for the
% four categories; psi - stimulus, psi2 - antipode, psi3 - guessing
%% ===========================================================================
  tmax = 4.0; 
  badix =5;
  amax = 5.1;
 
   
   name = 'MOVSPHERE2: ';
   errmg1 = 'Incorrect number of parameters for model, exiting...';
   errmg2 = 'Incorrect length selector vector, exiting...';
   errmg3 = 'Data should be a 1 x 2 cell array from <makelike>...';


   np = 21;
   ncond = 2;
   ncat = 4;
   tau2 = 1.0; % Overdispersion.
   
   n1 = length(Data{1});
   n2 = length(Data{2});
   ntot = n1 + n2;
   %n3 = length(Data{3});
   %n4 = length(Data{3});
   %ntot = n1 + n2 + n3 + n4;
   
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
   nrm1 = P(1);
   nrm2 = P(2);
   psi1 = P(3);
   psi2 = P(4);
   psi3 = P(5);
   eta1a = P(6);
   eta2a = P(7);
   eta1c = P(8);
   eta2c = P(9);   
   a= P(10);
   b = P(11);  % Two amplitude components
   Abias = P(12:15);
   alpha = P(16);
   pi2 = P(17);
   pi3 = P(18);
   ascale = P(19);
   ter = P(20);
   st = P(21);
   
   % stimulus + antipodal angles the same
   if Sel(4) == 0
      psi2 = psi1;
      P(4) = P(3);
   end   
   % Azimuths are the same
   if Sel(7) == 0
      eta2a = eta1a;
   end   
  
   % Elevations are the same
   if Sel(9) == 0
      eta2c = eta1c;
   end   
   
   % Tangential are negligible 
   eta1b = 0.05;
   eta2b = 0.05;

   Bbias = b * ones(1, ncat);
   sigma =1.0; 
   sa = 0; % Criterion variability
   % Locations hard wired
 
   U2 = ones(1,2);
   U3 = ones(1,3);
   
   invalid_mix = pi2 + pi3 >= 1.0;
   elmax = pi / 2;
   elmin = -pi / 2; 
   elmaxs = pi / 2 - 0.05;
   elmins = -pi / 2 + 0.05; 
 
   amaxh = 1.05 * amax;
   % -------------------------------------------------------------------------------------------------------------------
   %         nrm1,nrm2, psi1..psi3,   eta*a, eta*c     a   b          a1..a4           alpha, pi1..pi2, ascale Ter, st
   % ------------------------------------------------------------------------------------------------------------------- 
   loose_eta = 1;  % change tight from .95 to 1.95, to 1.5; allow Ter to go very negative, 5/9/21
   if loose_eta
        Ub= [ 10.0*U2,  elmax*U3,  5.1*U2,  5.1*U2,   amaxh,  6.5,   pi*ones(1,ncat),      25   1.0*U2,  3.0   1.0, 0.7]; 
        Lb= [-10.0*U2,  elmin*U3,    0*U2,    0*U2,   0.5,     0,   -pi*ones(1,ncat)        0,    0*U2,    0 -0.8, 0];
        Pub=[ 9.5*U2, elmaxs*U3,   5.0*U2,  5.0*U2,   amax, 6.4,   (pi-eps)*ones(1,ncat), 24,  .95*U2,  2.5  0.8, 0.6];
        Plb=[-9.5*U2, elmins*U3,     0*U2,    0*U2,   0.7,  0.02, -(pi+eps)*ones(1,ncat),  0,    0*U2,  0.1  -0.7, 0];
    else
        Ub= [ 10.0*U2,   elmax*U3,  2.2*U2, 2.2*U2,   amaxh,  6.5,   pi*ones(1,ncat),      25   1.0*U2,  3.0  1.0, 0.7]; 
        Lb= [-10.0*U2,   elmin*U3,     0*U2,    0*U2, 0.5,    0,   -pi*ones(1,ncat)        0,     0*U2,   0 -0.8, 0];
        Pub=[ 9.5*U2,  elmaxs*U3,   2.1*U2, 2.1*U2,   amax,  6.4,   (pi-eps)*ones(1,ncat), 24, .95*U2,  2.5   0.8, 0.6];
        Plb=[-9.5*U2,  elmins*U3,      0*U2,    0*U2, 0.7,   0.02, -(pi+eps)*ones(1,ncat),  0,    0*U2,  0.1 -0.7, 0];
    end 

    Pred = cell(3,2); % Only two discriminability conditions
    if any(P - Ub > 0) | any(Lb - P > 0) || invalid_mix
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

    
      P=[nrm1, psi1, psi2, psi3, eta1a, eta1b, eta1c, sigma, a, alpha, sa, pi2, pi3, ascale, ter, st; 
         nrm2, psi1, psi2, psi3, eta2a, eta2b, eta2c, sigma, a, alpha, sa, pi2, pi3, ascale, ter, st];
      ll = zeros(1, ncond);
      Gstuff = cell(3, ncond);
      Pred = cell(3, ncond); % Two discriminability conditions
      Gstuff1 = cell(ncond);
      Gstuff2 = cell(ncond);
      Gstuff3 = cell(ncond);
      Pred1 = cell(ncond);
      Pred2 = cell(ncond);
      Pred3 = cell(ncond);

     for i = 1 : ncond
          [Gstuffi, Predi, lli] = vasphere12j(P(i,:), Data{i}, Abias, Bbias, tmax, badix);
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

%function [t, gtm, ftm, theta, pthetam, mtheta, mdtheta, etheta, ll0] = vacircle12j(Pj, Dataj, ABias, BBias)
function [Gstuff, Pred, sll0] = vasphere12j(Pj, Dataj, Abias, Bbias, tmax, badix)
% ===============================================================================================
% Compute predictions and log-likelihoods for one condition.
% Initially return predictions marginalized across stimulus angle.
% Pass out everything as a cell array to facilitate parallelization.
%  
%     [Gstuff, Pred, sll0] = vasphere12j(Pj, Dataj, Abias, Bbias)
% Now puts everything into canonical orientation to avoid the etas problem
%      P = [nrm, psi1, psi2, psi3, eta1, eta2, eta3, sigma, a, alpha, sa, pi2, pi3, ascale, ter, st]
%  Calculate components of likelihood for one discriminability condition.
%  B is the amplitute of the bias vectors; currently hardwired; RawBias is the location 
% ===============================================================================================
   np = 16;
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
   contamden = 0.001; %% 0.05;  % Contaminant density. 
   ter = Pj(15);
   st = Pj(16);
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

   [t, gt, thetas, theta, ptheta, mtheta] = vjoint5density(Pj(1:14), Abias, Bbias, tmax, badix, nw1, nv1, nt);
   % Filter zeros  
   gt = max(gt, epsx); % [51, 300, 51] % with wrap-around.
   % Add nondecision time
   t = t + ter + st / 2;
   %gttest1 = gt(25, :, 25);
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
   %gttest2 = gt(25, :, 25);
   %plot(t, gttest1, t, gttest2)
   %pause
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
   %size(t)
   %size(gtm)
   %plot(t, gtm(25, :))
   %pause
   Pred{1} = [t; ftm];
   Pred{2} = [theta; pthetam'];
   Pred{3} = [theta; etheta; mtheta; mdtheta];       
end

function [t, gt, thetas, thetaerr, ptheta, mtheta] = vjoint5density(P, Abias, Bbias, tmax, badix, nw1, nv1, nt)
% ===============================================================================================
%  [t,gt,thetas, thetaerr,ptheta,mtheta] = vjoint5density(P, BiasAngle, tmax, nw1, nv1, nt);
% P = [nrm, psi1..psi3, eta1, eta2, eta3, sigma, a, alpha, sa, pi2, pi3, ascale]
% Circular diffusion predictions as a function of stimulus angle.
% Stimuli in canonical orientation (i.e., re 0), bias computed as an offset. 
% ===============================================================================================
  np = 14;
  if length(P) ~= np
       disp('vjoin5density: wrong length parameter vector, return...');
       P
       return
   end 
   nrm = P(1);
   psi1 = P(2);
   psi2 = P(3);
   psi3 = P(4);
   eta1 = P(5);
   eta2 = P(6);  % Fix tangential, vary elevation.
   eta3 = P(7); 
   sigma = P(8);
   a = P(9);
   alpha = P(10);
   sa = P(11);
   pi2 = P(12);
   pi3 = P(13);
   ascale = P(14);
   nt = 300; % number of time steps
   ncat = 4; % ### Must be made consistent with global declaration because not passed in.)
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

   % Assume equal guessing probabilities for 4 categories.
   Qbias = [0.25, 0.25, 0.25, 0.25];  

   % Category computations now internal to threesphere300 
   %P = [0, nrm, psi1, psi2, psi3, eta1, eta2, eta3, sigma, a, alpha, pi2, pi3, ascale];
   parfor k = 1:nv1 
        P = [thetas(k), nrm, psi1, psi2, psi3, eta1, eta2, eta3, sigma, a, alpha, pi2, pi3, ascale];
        [~,gt1(:,:,k), ~, ptheta1(:,k), mtheta1(:,k)] = threesphere300pgx(P, Abias, Bbias, Qbias, tmax, badix);
   end
   gt = gt1;
   ptheta = ptheta1;
   mtheta = mtheta1;
end

