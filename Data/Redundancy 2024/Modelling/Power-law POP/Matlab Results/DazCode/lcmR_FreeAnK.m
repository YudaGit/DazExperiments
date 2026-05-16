function [ll, aic, bic, Pred] = lcmR_FreeAnK(Pvar, Pfix, Sel, Data)
% =====================================================================================
% Fit simple LCM-Gumbel model to redundancy data
% Data is N (set-size) array
% [ll, aic, bic, Pred] = lcm_Step1(Pvar, Pfix, Sel, Data)
% P = [a1, a2, a3, a4, a5, a6, a7, a8, a9, kappa1, kappa2, kappa3, kappa4, kappa5, kappa6, kappa7, kappa8, kappa9] 
% The a's parameterize activation; 
% the kappas parameterize individual tuning sensitivity.
% =====================================================================================

   name = 'lcm_Step1';
   errmg1 = 'Incorrect number of parameters for model, exiting...';
   errmg2 = 'Data should be a 4 cell array...';
   
   np = 18;
   nset = 9; 
   n = 360; % Hard wired number of detectors 
   lp = length(Pvar) + length(Pfix);
   
   if lp ~= np
      error('%s: %s Number of parameters: %d', name, errmg1, lp);
   else
      P = zeros(1, np);
      P(Sel == 1) = Pvar;
      P(Sel == 0) = Pfix;
      A = P(1:9); % A contains 4 elements
      Kappa = P(10:18); % Kappa contains 4 elements
      save('Ptemp.mat', 'P');
   end

   % Calculate total number of data points
   N = 0;
   for i = 1:nset
      if ~isempty(Data{i})
          N = N + length(Data{i});
      end
   end   
    
   Pred = cell(nset, 1);
   if any(P <= 0)
        ll = 1e9;
        aic = 1e9;
        bic = 1e9;
        return
   else
       ll = 0;

       for i = 1:nset
           if ~isempty(Data{i})
               Pi = [A(i), Kappa(i)];
               Datai = Data{i};
               lli = gull(Pi, Datai, n);
               ll = ll + lli;
               [thi, pthi] = guplcm(Pi, n);
               Predi = [thi; pthi];
               Pred{i} = Predi;
           end           
       end
      aic = 2 * ll + 2 * np;
      bic = 2 * ll + np * log(N);   
   end  
end


function ll = gull(P, Data, n)
% ====================================================================================
% log-likelihood for Gumbel LCM.
%     ll = gull(P, Data)
%     P = [a, kappa]
% Data is a vector of response errors
% ====================================================================================
    lzero = 0.05; % Likelihood of zeros

    % Convert Data to numeric array if it's a cell
    if iscell(Data)
        E = cell2mat(Data); 
    else
        E = Data;
    end

    % Get tuning function parameters
    [theta, ptheta] = guplcm(P, n);
    h = theta(2) - theta(1);
    sz = length(theta);
    ld = length(E);
    L = zeros(1, ld); % Adjusted to match length of data
    LL = zeros(1, ld); % Adjusted to match length of data

    % Calculate log-likelihood for each data point
    for i = 1:ld
       index_thmin = find(E(i) > theta, 1, 'last');
       if ~isempty(index_thmin)
           thmin = theta(index_thmin);
           pmin = ptheta(index_thmin);
           if index_thmin < sz
               pmax = ptheta(index_thmin + 1);
               thfrac = (E(i) - thmin) / h;
               Li = thfrac * pmin + (1 - thfrac) * pmax;
           else
              Li = ptheta(sz);
           end          
           L(i) = Li;
       else
           L(i) = lzero;
       end
    end
    L(L <= 0) = lzero;
    LL = log(L);
    ll = -sum(LL);
end


function [theta, ptheta] = guplcm(P, n)
% ================================================================================
% Distribution of a maximum of Gumbel distributed detectors with a von Mises
% tuning function, scaled as PDF
%    [theta, ptheta] = guplcm(P, n);
%    P = [a, kappa] von Mises amplitude and dispersion
%    n is number of detectors on circle
% ================================================================================
   a = P(1);
   kappa = P(2);
   theta = linspace(-pi, pi, n); % will wrap around
   utheta = a * exp(kappa * cos(theta)) / (2 * pi); % Tuning function
   ptheta = exp(utheta) / sum(exp(utheta));
   h = theta(2) - theta(1);
   ptheta = ptheta / h;
end