function [ll, Pred] = slabcdmsim3(Pvar, Pfix, Sel, Data, trace)
% ====================================================================================
% Fit of spike-and-slab simulated CDM to Landolt 21 data. Selects from drift rate
% distribution with probability qi, slab with probability 1 - qi. Slab is uniformly
% distributed with amplitude vnormi.  
%     [ll, Pred] = slabcdmsim3(Pvar, Pfix, Sel, Data, trace)
%      P = [vnorm1:vnorm4, etar1:etar4, etat, a, Ter1:Ter4, st, q1:q4]
%                 1:4          5:8        9   10    11:14,  15  16:19
%    'Data' is a 4-element cell array
%  Passes back the aic and bic penalties rather than the statistics themselves because
%  likelihood varies.
%  <feucdmsim1> allows etar to vary with condition.
%  10/3/25
%  ===================================================================================

   tmax = 3.0;
   ntrials = 10000;   
   
   name = 'SLABCDMSIM3: ';
   errmg1 = 'Incorrect number of parameters for model, exiting...';
   errmg2 = 'Incorrect length selector vector, exiting...';
   errmg3 = 'Data should be a 4 x 1 cell array...';
  
   np = 19;
   ncond = 4; 
   % Number of trials in each discriminability condition. (SB a bit unbalanced).
   n1 = length(Data{1});
   n2 = length(Data{2});
   n3 = length(Data{3});
   n4 = length(Data{4});
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


   Vnorm = P(1:4);
   Etar = P(5:8);
   etat = P(9);
   a = P(10); 
   Ter = P(11:14);
   st = P(15);
   Q = P(16:19);

   if Sel(6) == 0
      Etar(2) = Etar(1);
   end
   if Sel(7) == 0
      Etar(3) = Etar(2);
   end
   if Sel(8) == 0
      Etar(4) = Etar(3);
   end

   if Sel(12) == 0
      Ter(2) = Ter(1);
   end
   if Sel(13) == 0
      Ter(3) = Ter(2);
   end
   if Sel(14) == 0
      Ter(4) = Ter(3);
   end

   U4 = ones(1,4);

   % --------------------------------------------------------------- 
   %   [vnorm1:vnorm4, etar1:etar4, etat, a, Ter1:Ter4, st, q1:q4]
   %          1:4           5:8        9   10    11:14,  15 16:19
   % --------------------------------------------------------------
   Ub = [12*U4,   3.5*U4, 3.5, 5.0, .6*U4,  .5, 1.0 * U4];
   Lb = [0*U4,      0*U4   0, 0.5, -.25*U4, 0,     0 *U4];
   Pub =[11.8*U4, 3.0*U4, 3.0, 4.5, .5*U4,  .4   0.99*U4];
   Plb = [0.1*U4,   0*U4,   0, 0.5, -.15*U4, 0,  0.01*U4];
 
    
   Pred = cell(ncond);
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
     end    

      P = [Vnorm(1), Etar(1), etat, a, Ter(1), st, Q(1);
           Vnorm(2), Etar(2), etat, a, Ter(2), st, Q(2);
           Vnorm(3), Etar(3), etat, a, Ter(3), st, Q(3);
           Vnorm(4), Etar(4), etat, a, Ter(4), st, Q(4)];
                   
      ll = zeros(1, ncond);
      Pred = cell(ncond); % Four discriminability conditions (cell array of cell arrays)
      [ll1, Pred1] = cdmsimll5(P(1,:), Data{1}(:, 2:3), tmax, ntrials, 0); % Just pass errors and RT
      [ll2, Pred2] = cdmsimll5(P(2,:), Data{2}(:, 2:3), tmax, ntrials, 0);
      [ll3, Pred3] = cdmsimll5(P(3,:), Data{3}(:, 2:3), tmax, ntrials, 0);
      [ll4, Pred4] = cdmsimll5(P(4,:), Data{4}(:, 2:3), tmax, ntrials, 0);
      Pred{1} = Pred1; 
      Pred{2} = Pred2; 
      Pred{3} = Pred3; 
      Pred{4} = Pred4; 
      ll = sum(ll1) + sum(ll2) + sum(ll3) + sum(ll4);
      ll = ll + penalty;  % Took out abs here, screwing up negatives
      apen = 2 * sum(Sel);
      bpen = sum(Sel) * log(ntot);
   end
end

function [ll, Pred] = cdmsimll5(P, Data, tmax, ntrials, trace)
% =======================================================================================================
% Fit a model to a data distribution using the PDA method Both are ntrials x 2 [resp, time]
%     cdmsimll5(Data, Pred) #5 is spike-and-slab
% =======================================================================================================

     contamden = 0.05;  % Contaminant density.
     pred_angles = -pi:2*pi/72:pi;
     pred_times = 0:.05:3.5;
     [x1,x2]=meshgrid(pred_angles, pred_times);
     x1 = x1(:);
     x2 = x2(:);
     xi = [x1 x2];
     
     [x, t, rx, tx, trx] = simcdm5(P, tmax, ntrials, trace);
     gxt = ksdensity(trx, xi); % Kernel density approximation for the predicted joint distributions 
     gx = ksdensity(trx(:,1), pred_angles); % Kernel density approximation to the predicted error distribution
     gt = ksdensity(trx(:,2), pred_times); % Kernel density approximation to the predicted RT distribution
     gxt_2d = reshape(gxt, length(pred_times), length(pred_angles));     
     Pred = cell(1,5);
     Pred{1} = x;
     Pred{2} = t;
     Pred{3} = rx;
     Pred{4} = tx;
     Pred{5} = trx;
     
  % 71 x 73
     l0 = interp2(pred_angles, pred_times, gxt_2d, Data(:,1), Data(:,2));
     Cx = isnan(l0) | l0 == 0;
     l0(Cx) = contamden;
     ll0 = -log(l0);
     ll= sum(ll0);
end
  

function [x, t, rx, tx, trx] = simcdm5(P, tmax, ntrials, trace);
% ==========================================================================
%    [x, t, rx, tx, trx] = simcdm1(P, tmax, ntrials, {trace});
%    Simulate ntrials of CDM, no categories (cf. <simcircle1> in Feu24).
%    P = [vnorm, eta1, eta2, a, Ter, st, q]
%    7/3/25 Previously discretized the hitting angle for consistency with <sdcm3>
%    but this produces spikes in the probability mass. Remove.
% ==========================================================================
    vnorm = P(1);
    eta1 = P(2);
    eta2 = P(3);
    a = P(4);
    ter = P(5);
    st = P(6);
    q = P(7);
    sigma = 1.0; % Standard scaling
        
    h = .01; % 10 ms steps
    ns = tmax / h;
    nw = 73; % Like scdm3 without the padding
    w = 2 * pi / nw;
    x = linspace(-pi, pi, nw); % same as scdm - wrap around at left end
    rx = zeros(1, ntrials);
    tx = zeros(1, ntrials);
    trx = zeros(ntrials, 2); % ksdensity wants two columns
    t = [1:ns]*h;     
    a = a - sigma * sqrt(h) / 2; % Overshoot correction for random walk 
        
    % Simulate ntrials
    n_terminated = 0;
    Ter = st * (rand(1, ntrials) - 0.5) + ter; % Vector of random Ter values
    MuSpike = [vnorm + eta1 * randn(1, ntrials);  eta2 * randn(1, ntrials)]; % Matrix of random drift rate components
    SlabAngle = (2 * pi - 0.0) * rand(1, ntrials) - pi;
    MuSlab = [vnorm * cos(SlabAngle); vnorm * sin(SlabAngle)];
    Q = rand(1,ntrials) < q;
    Mu = Q .* MuSpike + (1 - Q) .* MuSlab;  % Mixture of spike and slab with mixing proportion q.  
    a2 = a * a;    
    nmax = floor(tmax/h);
    % allocate space once
    Xt = zeros(2, nmax);    
    for j = 1:ntrials
        Xt(1,:) = 0; % reinitialize
        Mut = [Mu(1,j) * ones(1,nmax); Mu(2,j) * ones(1, nmax)]; % Mut has eta variability across trials
        Sigma_Wt = [sigma * randn(1,nmax); sigma * randn(1,nmax)]; 
        Dt2 = 0; % squared distance
        i = 2;
        while(Dt2 < a2 && i <= nmax)
            Xt(:,i) =  Xt(:,i-1) + Mut(:,i) * h + Sigma_Wt(:,i) * sqrt(h);
            Dt2 = Xt(1, i)^2 + Xt(2, i)^2;
            i = i + 1;
        end
        athetaj = atan2(Xt(2, i-1), Xt(1,i-1));  % angle of first two components.
        rx(j) = athetaj;
        tx(j) = (i-1) * h + Ter(j); % add uniform ter to decision time
        trx(j,1) = rx(j);  % Joint density pairs.
        trx(j,2) = tx(j);               
        if trace
            terminating_step = i;
            terminating_time = tx(j);
        end
        n_terminated = n_terminated + 1;
    end
    if trace
        n_terminated = n_terminated + 1;   
   end
   %histogram(rx, 50, 'Normalization', 'pdf')
   %pause
   %histogram(tx, 50, 'Normalization', 'pdf')
   %pause  
end     



function [ll, Pred] = scdmll3(P, Data, tmax, ntrials, trace)
% =======================================================================================================
% Fit a model to a data distribution using the PDA method Both are ntrials x 2 [resp, time]
%     scdmll3(Data, Pred)
% =======================================================================================================

     contamden = 0.05;  % Contaminant density.
     pred_angles = -pi:2*pi/72:pi;
     pred_times = 0:.05:3.5;
     [x1,x2]=meshgrid(pred_angles, pred_times);
     x1 = x1(:);
     x2 = x2(:);
     xi = [x1 x2];
     
     [x, t, rx, tx, trx] = scdm3(P, tmax, ntrials, trace);
     gxt = ksdensity(trx, xi); % Kernel density approximation for the predicted joint distributions 
     gx = ksdensity(trx(:,1), pred_angles); % Kernel density approximation to the predicted error distribution
     gt = ksdensity(trx(:,2), pred_times); % Kernel density approximation to the predicted RT distribution
     gxt_2d = reshape(gxt, length(pred_times), length(pred_angles));     
     Pred = cell(1,5);
     Pred{1} = x;
     Pred{2} = t;
     Pred{3} = rx;
     Pred{4} = tx;
     Pred{5} = trx;
     
  % 71 x 73
     l0 = interp2(pred_angles, pred_times, gxt_2d, Data(:,1), Data(:,2));
     Cx = isnan(l0) | l0 == 0;
     l0(Cx) = contamden;
     ll0 = -log(l0);
     ll= sum(ll0);
end


function y = phi(x);
    % gaussian density
    y = exp( -x.^2 / 2) / (2 * pi)^0.5;
end    


