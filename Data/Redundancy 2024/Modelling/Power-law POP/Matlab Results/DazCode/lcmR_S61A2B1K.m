
function [ll, aic, bic, Pred] = lcmR_S61A2B1K(Pvar, Pfix, Sel, Data, set_Size)
% =====================================================================================
% Fit Redundancy gain LCM-Gumbel model to all conditions
% Data is cells according to conditions
% 
% [ll, aic, bic, Pred] = lcmR_S51A6B1K(Pvar, Pfix, Sel, Data, set_Size)
% P = [a2, beta1, beta2, kappa]
% 
% The a's parameterize amplitude that follows beta power law
% The beta is the power exponent for the power law relationships for 
% both redundancy gain and set-size effect.
% The kappa parameterizes individual tuning sensitivity.
% =====================================================================================
    name = 'lcmR_S61A2B1K';
    errmg1 = 'Incorrect number of parameters for model, exiting...';
    
    np = 4;
    nset = 9;
    colour_Num = [2, 4, 6, 2, 2, 2, 2, 4, 4];
    n = 360;  
    lp = length(Pvar) + length(Pfix);
    
    if lp ~= np
        error('%s: %s Number of parameters: %d', name, errmg1, lp);
    else
        P = zeros(1, np);
        P(Sel == 1) = Pvar;
        P(Sel == 0) = Pfix;

        a2 = P(1); 
        beta = P(2:3); 
        kappa = P(4); 
        save('Ptemp.mat', 'P');
    end

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
        return;
    else
        ll = 0;

        for i = 1:nset
            if ~isempty(Data{i})

                kappamin = 0.1;
                penaltyK = 1e4 * max(kappamin - kappa, 0);
                % kappamax = 3.54;
                % penaltyK = 1e4 * max(kappa - kappamax, 0);
                ampmin = 0.1;
                penaltyA = 1e4 * max(ampmin - a2, 0);

                if any(i == [1, 2, 3]) % Standard conditions
                    baseAmp = a2 * 2 ^ 0.5;
                    amplitude = baseAmp * colour_Num(i) .^ -0.5; %
                    
                    Pi = [amplitude, kappa];
                    Datai = Data{i};
                    lli = gull(Pi, Datai, n);
                    ll = ll + lli + penaltyK + penaltyA;

                elseif any(i == [4, 6, 8]) % Redundant Cue
                    B = beta(1);
                    baseAmp = a2 * 2 .^ B;
                    redunAmp = baseAmp * ((set_Size(i) - (colour_Num(i)-1)) .^B); % It is important that this works when set size and colour number equals, so its not a special case
                    amplitude = redunAmp * (colour_Num(i) .^ -B); % fairly parsimonous right now, but maybe room

                    betamin = 0.01; % This gets pushed down to quite low
                    penaltyBmin = 1e4 * max(betamin - B, 0);
                    betamax = 0.9;
                    penaltyBmax = 1e4 * max(B - betamax , 0);

                    Pi = [amplitude, kappa];
                    Datai = Data{i};
                    lli = gull(Pi, Datai, n);
                    ll = ll + lli + penaltyBmin + penaltyBmax + penaltyK + penaltyA;

                else % Non-redundant Cue
                    B = beta(2);
                    baseAmp = a2 * 2 .^ B;
                    amplitude = baseAmp * (colour_Num(i) .^ -B);

                    betamin = 0.01; % This tend to be higher
                    penaltyBmin = 1e4 * max(betamin - B, 0);
                    betamax = 0.99;
                    penaltyBmax = 1e4 * max(B - betamax , 0);

                    Pi = [amplitude, kappa];
                    Datai = Data{i};
                    lli = gull(Pi, Datai, n);
                    ll = ll + lli + penaltyBmin + penaltyBmax + penaltyK + penaltyA;
                end
                
            end
        end
        
        aic = 2 * ll + 2 * np;
        bic = 2 * ll + np * log(N);  
    end
end


function ll = gull(P, Data, n)
% ====================================================================================
% log-likelihood for Gumbel LCM.
%     ll = gull(P, Data, n)
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
