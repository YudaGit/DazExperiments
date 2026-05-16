function [ll, aic, bic, Pred, ModelID, rawAIC, rawBIC] = MaxGumbelModels2(Pvar, Pfix, Sel, Data, modifiers)
    P = zeros(1, length(Sel));
    P(Sel == 1) = Pvar;
    P(Sel == 0) = Pfix;

    Pred = cell(9, 1);
    ll = 0;

    if any(P <= 0) || any(P(end-2:end) > 1 )
        ll = 1e9;
        aic = 1e9;
        bic = 1e9;
        ModelID = '';
        return
    end

    ampFocus    = modifiers(1);
    complement  = modifiers(2);
    betaN       = modifiers(3);
    NRstandard  = modifiers(4);
    ItemOrColor = modifiers(5);

    amplitude = P(1:9);
    kappa = P(10:18);
    beta  = P(19:21);

    % 2, 42r, 42n, 4, 62r, 62n, 64r, 64n, 6
    items2 = [1, 0, 0, 0, 0, 0, 0, 0, 0];
    items4 = [0, 1, 1, 1, 0, 0, 0, 0, 0];
    items6 = [0, 0, 0, 0, 1, 1, 1, 1, 1];
    color2 = [1, 1, 1, 0, 1, 1, 0, 0, 0];
    color4 = [0, 0, 0, 1, 0, 0, 1, 1, 0];
    color6 = [0, 0, 0, 0, 0, 0, 0, 0, 1];
    redundant    = [-1, 1, 0, -1, 1, 0, 1, 0, -1]; % -1 standard. 1 redundant. 0 not redundant.
    redcolors    = [NaN, 3, NaN, NaN, 5, NaN, 3, NaN, NaN];
    items        = [2, 4, 4, 4, 6, 6, 6, 6, 6];
    colorN       = [2, 2, 2, 4, 2, 2, 4, 4, 6];
    
    for cnds = 1:9
        if ItemOrColor == 1
            n = colorN(cnds);
            nid = ' by ColorN';
        elseif ItemOrColor == 2
            n = items(cnds);
            nid = ' by ItemN';
        else
            nid = '';
        end

        % Free Models
        if isnan(ampFocus) 
            % All Free
            a = amplitude(cnds);
            k = kappa(cnds);
            ModelID = 'Free A and K';
        elseif ampFocus == 1 && complement == 0 && betaN == 0 && ItemOrColor == 0
            % Amplitude Free
            a = amplitude(cnds);
            k = kappa(1);
            ModelID = 'Free A';
        elseif ampFocus == 0 && complement == 0 && betaN == 0 && ItemOrColor == 0
            % Kappa Free
            k = kappa(cnds);
            a = amplitude(1);
            ModelID = 'Free K';
        end
    
        % Beta Model Fits
        if betaN > 0
            if complement == 1
                % Select Beta or 1-Beta for Redundant and Non-redundant
                % conditions, and either 1-Beta or sample size for standard
                % conditions.
                if NRstandard == 1
                    ModelID = 'Beta Complement, NR on Standard';
                elseif NRstandard == 0
                    ModelID = 'Beta Complement, SS on Standard';
                end

                if redundant(cnds) == -1 & NRstandard == 1
                    B = 1-beta(1);
                elseif redundant(cnds) == -1 & NRstandard == 0
                    B = 0.5;
                elseif redundant(cnds) == 0
                    B = 1-beta(1);
                elseif redundant(cnds) == 1
                    B = beta(1);
                end
            elseif complement == 0
                if NRstandard == 1 && sum(Sel(end-2:end)) == 2
                    ModelID = 'Two Independent Betas, NR on Standard';
                elseif NRstandard == 0 && sum(Sel(end-2:end)) == 2
                    ModelID = 'Two Independent Betas, SS on Standard';
                elseif sum(Sel(end-2:end)) == 3
                    ModelID = 'Three Independent Betas';
                end
                
                % Independent Betas for Redundant and Non-Redundant conditions.
                % However, standard conditions can either be dependent on
                % the NR condition, sample size, or independently estimated.
                if redundant(cnds) == -1 & NRstandard == 1
                    B = beta(2);
                elseif redundant(cnds) == -1 & NRstandard == 0
                    if sum(Sel(end-2:end)) == 3
                        B = beta(3);
                    elseif sum(Sel(end-2:end)) == 2
                        B = 0.5;
                    end
                elseif redundant(cnds) == 0
                    B = beta(2);
                elseif redundant(cnds) == 1
                    B = beta(1);
                end
            end
            
            % Apply Betas based on Amplitude or Kappa being the paramater
            % of modification, and whether the condition was redundant.
            if ampFocus == 1
                ModelID = ['Mod.A, ', ModelID, nid];
                k = kappa(1);
                startingAmp = amplitude(1) * 2 ^ B;
                if redundant(cnds) == 1
                    redunAmp = startingAmp * redcolors(cnds) ^ B;
                    a = redunAmp * (n ^ -B);
                else
                    a = startingAmp * (n ^ -B);
                end
                
            elseif ampFocus == 0
                ModelID = ['Mod.K, ', ModelID, nid];
                a = amplitude(1);
                startingKappa = kappa(1) * 2 ^ B;
                if redundant(cnds) == 1
                    redunKappa = startingKappa * redcolors(cnds) ^ B;
                    k = redunKappa * (n ^ -B);
                else
                    k = startingKappa * (n ^ -B);
                end
            end
        end
    
        % Sample Size Model Fits
        if complement == 1 && betaN == 0
            if ampFocus == 1
                ModelID = ['SS on Amplitude', nid];
                k = kappa(1);
                startingAmp = amplitude(1) * 2 ^ .5;
                a = startingAmp * (n ^ -.5);
            elseif ampFocus == 0
                ModelID = ['SS on Kappa', nid];
                a = amplitude(1);
                startingKappa = kappa(1) * 2 ^ .5;
                k = startingKappa * (n ^ -.5);
            end
        end

        Datai = deg2rad(Data.response_error( Data.Cnd == cnds ));
        
        Pi = [a, k];
        ndetectors = 360;
        lli = gull(Pi, Datai, ndetectors);
        ll = ll + lli;
        [thi, pthi] = guplcm(Pi, ndetectors);
        Predi = [thi; pthi];
        Pred{cnds} = Predi;

    end

    residual_deviance = 2 * ll;
    degrees_of_freedom = size(Data, 1) - sum(Sel);
    c_hat = residual_deviance / degrees_of_freedom;
    
    rawAIC = 2 * ll + 2 * sum(Sel);
    rawBIC = 2 * ll + sum(Sel) * log(size(Data,1));  
    
    aic = rawAIC / c_hat;
    bic = rawBIC / c_hat;

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