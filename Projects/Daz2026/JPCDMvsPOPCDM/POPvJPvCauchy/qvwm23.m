function figureHandle = qvwm23(fitfunc, Pvar, Pfix, Sel, Data_in, ybounds, conditionLabels)
% ----------------------------------------------------------------------
% Empirical and RT fitted RT quantiles as a function of theta.
% Generic Q x Q plot for VWM23 experiment.
% Equal-mass theta bounds, RTs filtered on [minrt, maxrt]
% 10/12/22 - Assume 'Pred' output of function packages up 
%   Preds and Gstuff as a single structure.
%  
%       qvwm23(@fitfunc, Pvar, Pfix, Sel, Data_in, [ymin,ymax]);
% ----------------------------------------------------------------------
   if nargin < 6
       ybounds = [0.5, 2.5];
   end

   % Preserve the supplied four-condition figure unchanged. Re2024 uses
   % nine conditions, so route it to the generalized team-style layout.
   if nargin < 7 || isempty(conditionLabels)
       conditionLabels = "Condition " + string(1:size(Data_in, 2));
   end
   if size(Data_in, 2) ~= 4
       figureHandle = local_qvwm23_multicond(fitfunc, Pvar, Pfix, Sel, ...
           Data_in, ybounds, conditionLabels);
       return
   end
   figureHandle = [];
  
    minrt = 0.15;  % Filter
    maxrt = 2.5;

    errmg2 = 'QVWMPLOT: Wrong size data matrix, exiting...';

    if size(Data_in) ~= [1,4]
       disp('Wrong size data matrix, exiting...')
       return
    else
       sz = size(Data_in{1})
       two_column = sz(2) == 2;  
    end
    if two_column
        Data = Data_in;
    else
        disp('Three column')
        Data =  cell(1,2);
        Data{1} = Data_in{1}(:, 2:3);
        Data{2} = Data_in{2}(:, 2:3);
        Data{3} = Data_in{3}(:, 2:3);
        Data{4} = Data_in{4}(:, 2:3);
    end; 

    co = [0,0,1; 
         0,0.5,0;
         1,0,0;
         0,0.75,0.75;
         0.75,0,0.75;
         0.75,0.75,0;
         0.25,0.25,0.25];

    set(groot,'defaultAxesColorOrder',co);
    epsx = 1e-9;
    tmax = 4.0;
    nmass = 10;
    massm = 1.0/nmass; % 10 bins

    % Generic fit function call. Now assumes a single Pred output packages up Preds and Gstuff
    [ll,ll2, aic, bic,Pred] = fitfunc(Pvar, Pfix, Sel, Data_in)
    % ------------------
    Preds = Pred{1,1};
    Gstuff = Pred{2,1}
    % ------------------
    ta = Gstuff{1,1};
    thetaa = Gstuff{2,1};
    gtma = Gstuff{3,1};                                                                          

    tb = Gstuff{1,2};
    thetab = Gstuff{2,2};
    gtmb = Gstuff{3,2};

    tc = Gstuff{1,3};                                                                     
    thetac = Gstuff{2,3};
    gtmc = Gstuff{3,3};

    td = Gstuff{1,4};
    thetad = Gstuff{2,4};
    gtmd = Gstuff{3,4};
    
    axhandle =setfig4;
    qploti(co, axhandle(1), Data{1}, gtma, ta, thetaa, tmax, minrt, maxrt, 'm=1', 0, ybounds);
    qploti(co, axhandle(2), Data{2}, gtmb, tb, thetab, tmax, minrt, maxrt, 'm=2', 0, ybounds);
    qploti(co, axhandle(3), Data{3}, gtmc, tc, thetac, tmax, minrt, maxrt, 'm=3', 0, ybounds);
    qploti(co, axhandle(4), Data{4}, gtmd, td, thetad, tmax, minrt, maxrt, 'm=4', 1, ybounds);


end

function qploti(co, axi, Datai, Gt, T, thetai, tmax, minrt, maxrt, labi, do_xlabel, ybounds)
% =======================================================================
% Plot 7 empirical distribution quantiles against predictions for 3
% discriminability conditions.
% =======================================================================
  %disp('in qploti')
  %size(Datai)

   symbol = ['o', 's', 'd', 'v', '^'];

   h = tmax / 300; 
   nw = 50; 
   w = 2*pi/nw;

   lnt = length(T);
   Ft = cumsum(Gt, 2) * h  * (2 * pi / nw); % normalize circular mass
   %size(Ft)
   MaxFt = Ft(:,lnt) * ones(1, lnt);
   % Calculate normalized (conditional) distribution functions.
   NormFt = Ft./ MaxFt;
   % Calculate quantiles
   Qf5 = [.1, .3, .5, .7, .9]; % Summary quantiles (can be changed).
   Qt = zeros(nw, 5);
   for i = 1:nw
       Fti = NormFt(i,:);
       Ix = (Fti >= .025 & Fti <= .975);
       if min(diff(Fti(Ix))) <= 0 
             Qti = [0,0,0,0,0];
             disp('Cannot compute Ft quantiles.');
             i
       else
             Qti=interp1(Fti(Ix)', T(Ix)', Qf5);
       end;
       Qt(i,:) = Qti;
   end;

   axes(axi);

  % Empirical RT quantiles in accuracy bins
   [Q,ThetaCentres] = bin9(Datai, minrt, maxrt);
   bound = 1.25 *  max(abs(ThetaCentres));
   theta = thetai(1:nw)'; % Because of wrap-around.
   Ix = theta >= -bound & theta <= bound;
   plot(theta(Ix), Qt(Ix, 1), '-.k', ...
        theta(Ix), Qt(Ix, 2), '-.k', ...
        theta(Ix), Qt(Ix, 3), '-.k', ...
        theta(Ix), Qt(Ix, 4), '-.k', ...
        theta(Ix), Qt(Ix, 5), '-.k')
   c = get(gca, 'Child');
   set(c(1), 'Linewidth', 2);

   hold
   set(gca, 'XLim', [-3.5,3.5]);

   set(gca, 'YLim', ybounds); 
   if do_xlabel
       xlabel('Response Error (rad)')
   end
   ylabel('Quantile RT (s)')

 
   %ThetaCentres
   %Q
   for j = 1:5
      plot(ThetaCentres, Q(j, :), 'k-')
   end
   for j = 1:5
       plot(ThetaCentres, Q(j,:), symbol(j), 'MarkerSize', 4, ...
       'MarkerEdgeColor', co(j,:), 'MarkerFaceColor', co(j,:));
   end
   label(gca, .65, .80, labi);
end



function figureHandle = local_qvwm23_multicond(fitfunc, Pvar, Pfix, Sel, Data, ybounds, conditionLabels)
% Generalized Re2024 branch using the visual convention of qploti/bin9.
    if ~iscell(Data) || size(Data, 1) ~= 1
        error('QVWM23:DataShape', 'Data must be a 1-by-nConditions cell array.');
    end
    nCond = size(Data, 2);
    conditionLabels = string(conditionLabels);
    if numel(conditionLabels) ~= nCond
        error('QVWM23:ConditionLabels', 'Provide one label per condition.');
    end
    co = [0,0,1; 0,0.5,0; 1,0,0; 0,0.75,0.75; 0.75,0,0.75];
    q = [.1, .3, .5, .7, .9];
    [~, ~, ~, ~, Pred] = fitfunc(Pvar, Pfix, Sel, Data, 0);
    Gstuff = Pred{2};
    nColumns = 3;
    nRows = ceil(nCond / nColumns);
    figureHandle = figure('Color', 'w', 'Position', [50 50 1450 360 * nRows], ...
        'Name', 'QVWM23 Re2024 RT quantiles by response error');
    tiledlayout(figureHandle, nRows, nColumns, 'TileSpacing', 'compact', 'Padding', 'compact');
    for c = 1:nCond
        ax = nexttile;
        local_qplot_re2024(ax, Data{c}, Gstuff{3,c}, Gstuff{1,c}, Gstuff{2,c}, ...
            q, co, ybounds, conditionLabels(c));
        if c > nCond - nColumns
            xlabel(ax, 'Response Error (rad)');
        end
        if mod(c - 1, nColumns) == 0
            ylabel(ax, 'Quantile RT (s)');
        end
    end
end

function local_qplot_re2024(ax, Datai, Gt, T, theta, q, co, ybounds, labelText)
    if size(Datai, 2) == 3
        Datai = Datai(:, 2:3);
    elseif size(Datai, 2) ~= 2
        error('QVWM23:DataColumns', 'Data cells require [error RT] or [stimulus error RT].');
    end
    nw = size(Gt, 1);
    h = T(2) - T(1);
    w = 2*pi/nw;
    fittedQ = nan(nw, numel(q));
    for i = 1:nw
        F = cumsum(Gt(i,:)) * h * w;
        F = F / F(end);
        [Fu, idx] = unique(F, 'stable');
        keep = Fu > 0 & Fu < 1;
        fittedQ(i,:) = interp1(Fu(keep), T(idx(keep)), q, 'linear', 'extrap');
    end
    [empiricalQ, thetaCentres, ~] = local_bin9_re2024(Datai, ybounds, q);
    hold(ax, 'on');
    theta = theta(1:nw)';
    for j = 1:numel(q)
        plot(ax, theta, fittedQ(:,j), '-.k', 'LineWidth', 1.15, 'HandleVisibility', 'off');
        valid = isfinite(empiricalQ(j,:));
        plot(ax, thetaCentres(valid), empiricalQ(j,valid), 'k-', ...
            'LineWidth', 0.8, 'HandleVisibility', 'off');
        plot(ax, thetaCentres(valid), empiricalQ(j,valid), 'o', 'MarkerSize', 4, ...
            'MarkerEdgeColor', co(j,:), 'MarkerFaceColor', co(j,:), 'HandleVisibility', 'off');
    end
    xlim(ax, [-pi pi]); ylim(ax, ybounds); grid(ax, 'on');
    title(ax, labelText, 'Interpreter', 'none', 'FontSize', 9);
end

function [Q, thetaCentres, binCount] = local_bin9_re2024(Data, ybounds, q)
    Data = Data(Data(:,2) >= ybounds(1) & Data(:,2) <= ybounds(2), :);
    [~, order] = sort(Data(:,1));
    Data = Data(order,:);
    nBins = 9;
    edges = round(linspace(0, size(Data,1), nBins+1));
    Q = nan(numel(q), nBins);
    thetaCentres = nan(1, nBins);
    binCount = zeros(1, nBins);
    for b = 1:nBins
        rows = (edges(b)+1):edges(b+1);
        binCount(b) = numel(rows);
        if ~isempty(rows)
            thetaCentres(b) = mean(Data(rows,1));
            Q(:,b) = quantile(Data(rows,2), q)';
        end
    end
end
function [Q, ThetaCentres] = bin9(Data, minrt, maxrt);
% ========================================================================================
%    [Q, ThetaCentres] = bin9(Data, minrt, maxrt)
%    Bin RTs into 9 equal-mass bins, filter out long RTs.
% ========================================================================================
eps = 0.0001;

% Equal-mass theta boundaries
ntheta = 7;
ntheta = 9;
lnd = length(Data);
%thetabin = round(lnd * [0.1429, 0.2857, 0.4286,  0.5714, 0.7143, 0.8571, 1.0000]);
thetabin = round(lnd * [0.1111, 0.2222, 0.3333,  0.4444, 0.5556, 0.6667, 0.7778, 0.8889, 1.0000]);

BinRT = zeros(110, ntheta);
BinTheta = zeros(1, ntheta);
BinCount = zeros(1, ntheta);

[thetas,I] = sort(Data(:,1));
Data(:,:) = Data(I,:);

j = 1;
k = 1;
for i = 1:lnd
    % Go to next bin (data sorted by ascending theta) and reset RT counter
    if i > thetabin(j)
         j = j + 1;
         k = 1;
    end
    thetai = Data(i,1);
   %j
    BinTheta(j) = BinTheta(j) + thetai;  % Sum thetas
    BinRT(k, j) = Data(i, 2);
    %[i, j, k, Data(i, 2)]
    %pause
    BinCount(j) = BinCount(j) + 1;
    k = k + 1;
end

ThetaCentres = BinTheta ./ BinCount;

% Filter outliers, sort RTs in each bin
Q = zeros(5,ntheta);
Qp =[.1,.3,.5,.7,.9];
for j = 1 : ntheta
    rt = BinRT(1:BinCount(j), j);
    rts = sort(rt);
    truncrt = rts(find(rts >= minrt & rts <= maxrt));
    Qx = ceil(length(truncrt) * Qp);
    Q(:,j) = rts(Qx); 
end
end
