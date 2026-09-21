function figureHandle = qvwm_ydl26(fitOrPred, Pvar, Pfix, Sel, Data_in, ybounds, conditionLabels)
% ----------------------------------------------------------------------
% Empirical and RT fitted RT quantiles as a function of theta.
% Generic Q x Q plot for VWM23 experiment.
% Equal-mass theta bounds, RTs filtered on [minrt, maxrt]
% 10/12/22 - Assume 'Pred' output of function packages up 
%   Preds and Gstuff as a single structure.
%  
%       qvwm_ydl26(@fitfunc, Pvar, Pfix, Sel, Data_in, [ymin,ymax]);
%       qvwm_ydl26(Pred, [], [], [], Data_in, [ymin,ymax]);
% ----------------------------------------------------------------------
   if nargin < 6
       ybounds = [0.3, 3.0];
   end
   if nargin < 7 || isempty(conditionLabels)
       conditionLabels = "Condition " + string(1:size(Data_in, 2));
   end
  
    minrt = 0.3;  % Filter
    maxrt = 3.0;

    if ~iscell(Data_in) || size(Data_in, 1) ~= 1
       error('QVWM_YDL26:DataShape', ...
           'Data_in must be a 1-by-nConditions cell array.');
    end
    nCond = size(Data_in, 2);
    conditionLabels = string(conditionLabels);
    if numel(conditionLabels) ~= nCond
       error('QVWM_YDL26:ConditionLabels', ...
           'Provide one label per data condition.');
    end

    Data = cell(1, nCond);
    for c = 1:nCond
        if size(Data_in{c}, 2) == 2
            Data{c} = Data_in{c};
        elseif size(Data_in{c}, 2) == 3
            Data{c} = Data_in{c}(:, 2:3);
        else
            error('QVWM_YDL26:DataColumns', ...
                'Each data cell must contain [error RT] or [stimulus error RT].');
        end
    end

    co = [0,0,1; 
         0,0.5,0;
         1,0,0;
         0,0.75,0.75;
         0.75,0,0.75;
         0.75,0.75,0;
         0.25,0.25,0.25];

    set(groot,'defaultAxesColorOrder',co);
    tmax = 3.0;

    % Either call the model wrapper to regenerate Pred, or accept a saved Pred.
    if isa(fitOrPred, 'function_handle')
        [ll, ll2, aic, bic, Pred] = fitOrPred(Pvar, Pfix, Sel, Data_in, 0);
    else
        Pred = fitOrPred;
    end
    % ------------------
    Gstuff = Pred{2};
    % ------------------

    nColumns = 3;
    nRows = ceil(nCond / nColumns);
    figureHandle = figure('Color', 'w', ...
        'Position', [50 50 1450 360 * nRows], ...
        'Name', 'QVWM original convention');
    tiledlayout(figureHandle, nRows, nColumns, ...
        'TileSpacing', 'compact', 'Padding', 'compact');

    axhandle = gobjects(1, nCond);
    for c = 1:nCond
        axhandle(c) = nexttile;
        do_xlabel = c > nCond - nColumns;
        qploti(co, axhandle(c), Data{c}, Gstuff{3,c}, Gstuff{1,c}, ...
            Gstuff{2,c}, tmax, minrt, maxrt, char(conditionLabels(c)), ...
            do_xlabel, ybounds);
    end


end

function qploti(co, axi, Datai, Gt, T, thetai, tmax, minrt, maxrt, labi, do_xlabel, ybounds)
% =======================================================================
% Plot 5 empirical distribution quantiles against predictions
% =======================================================================
  %disp('in qploti')
  %size(Datai)

   symbol = ['o', 's', 'd', 'v', '^'];

   % Use the model's actual time-grid spacing rather than assuming 300 bins.
   h = T(2) - T(1); 
   nw = 50; 
   w = 2*pi/nw;

   lnt = length(T);
   Ft = cumsum(Gt, 2) * h  * (2 * pi / nw); % normalize circular mass 
   %  
   % cumulatively sums across time: for each error angle, build a 
   % cumulative RT distribution
   % Then multiplying by h * w converts density into ~ probability mass
   
   %size(Ft)
   MaxFt = Ft(:,lnt) * ones(1, lnt);
   % Calculate normalized (conditional) distribution functions
   % Normalizes each error-angle row by its final cumulative mass

   NormFt = Ft./ MaxFt;
   % at this angle, what is the RT distribution


   % Calculate quantiles
   Qf5 = [.1, .3, .5, .7, .9]; % Summary quantiles (can be changed).
   Qt = zeros(nw, 5);
   for i = 1:nw
       Fti = NormFt(i,:);
       Ix = (Fti >= .025 & Fti <= .975);
       if nnz(Ix) < 2 || min(diff(Fti(Ix))) <= 0 
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

   hold on
   set(gca, 'XLim', [-2.7,2.7]);

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


function [Q, ThetaCentres] = bin9(Data, minrt, maxrt);
% ========================================================================================
%    [Q, ThetaCentres] = bin9(Data, minrt, maxrt)
%    Bin RTs into 9 equal-mass bins, filter out long RTs.
% ========================================================================================
% Equal-mass theta boundaries
ntheta = 9;
lnd = length(Data);
thetabin = round(lnd * (1:ntheta) / ntheta);

% Keep the original equal-mass convention, but allocate enough rows for the
% largest possible bin rather than assuming no bin will exceed 110 trials.
maxBinCount = max(diff([0, thetabin]));
BinRT = zeros(maxBinCount, ntheta);
BinTheta = zeros(1, ntheta);
BinCount = zeros(1, ntheta);

[~,I] = sort(Data(:,1));
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
    truncrt = rts(rts >= minrt & rts <= maxrt);
    if isempty(truncrt)
        Q(:,j) = NaN;
        continue
    end
    Qx = ceil(length(truncrt) * Qp);
    Qx = max(Qx, 1);
    Q(:,j) = truncrt(Qx); 
end
end
