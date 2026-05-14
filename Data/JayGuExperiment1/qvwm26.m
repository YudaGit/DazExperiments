function qvwm24(fitfunc, Pvar, Pfix, Sel, Data, ymax);
% ----------------------------------------------------------------------
% Empirical and RT fitted Quantile RTs as a function of theta.
% Generic Q x Q plot for Allen Qian's desaturation experiment
% Equal-mass theta bounds, RTs filtered on [minrt, maxrt]
% 10/12/22 - Assume 'Pred' output of function packages up 
%   Preds and Gstuff as a single structure.
% Seems to be NaN problem in errors...
%
%       qvwm24(@fitfunc, Pvar, Pfix, Sel, Data, {ymax});
% ----------------------------------------------------------------------
   if nargin < 6
       ymax = 3.0;
   end    

    minrt = 0.15;  % Filter
    maxrt = 4.0;
    errx = 2; % index of errors

    errmg2 = 'QVW24: Wrong size data matrix, exiting...';

    nsat = 2;
    nset = 4;
    if size(Data) ~= [nsat,nset]
       disp('Wrong size data matrix, exiting...')
       return
   % else - not needed after <filternan> preprocessing
   %    % filter out NaNs
   %    for i = 1:nsat
   %       for j = 1:nset
   %          Dataij = Data{i,j};
   %          Ix = find(~isnan(Dataij(:,errx)));
   %          Data{i,j} = Dataij(Ix,:);
   %       end
   %    end         
    end
    SetLab = {'m=1'; 'm=2'; 'm=4'; 'm=6'};
    SatLab = {'S^-';'S^+'};

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
    [ll,aic, bic,Pred] = fitfunc(Pvar, Pfix, Sel, Data);
    axhandle1 = setfig8; % narrow;
    for i = 1:nsat
         for j =1:nset
              axno = nsat * (j - 1) + i;        
              axes(axhandle1(axno));
              % Structures now multidimensional
              Preds = Pred{1}{i,j};
              Gstuff = Pred{2};
              tij = Gstuff{1,i,j};
              thetaij = Gstuff{2,i,j};
              gtmij = Gstuff{3,i,j};
              do_xlabel = axno == 7 | axno == 8; 
              do_ylabel = i == 1;
              % Hack here because of the 2 vs. 3 columm structure in vwm23, vwm23a. 
              % Only passed in the errors and RTs. 
              qploti(co, axhandle1(axno), Data{i,j}(:,2:3), gtmij, tij, thetaij, tmax, minrt, maxrt, ...
                     SatLab{i}, SetLab{j}, do_xlabel, do_ylabel, ymax);
              if axno < 7
                  xticklabels({})
              end                               
         end            
     end
end

function qploti(co, axi, Dataij, Gt, T, thetai, tmax, minrt, maxrt, satlab, setlab, do_xlabel, do_ylabel, ymax)
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
   %Datai
  % Empirical Quantile RTs in accuracy bins
   [Q,ThetaCentres] = bin9(Dataij, minrt, maxrt);
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

   set(gca, 'YLim', [0.2, ymax]);  % maxrt  %%
   if do_xlabel
       xlabel('Response Error (rad)')
   end
   if do_ylabel
       ylabel('Quantile RT (s)');
   end    
   if axi == 1 | axi == 3 || axi == 5 || axi == 7
       ylabel('Quantile RT (s)')
   end    
   for j = 1:5
      plot(ThetaCentres, Q(j, :), 'k-')
   end
   for j = 1:5
       plot(ThetaCentres, Q(j,:), symbol(j), 'MarkerSize', 4, ...
       'MarkerEdgeColor', co(j,:), 'MarkerFaceColor', co(j,:));
   end
   label(gca,  .65, .85, setlab);
   label(gca,  .65, .75, satlab);
end


function [Q, ThetaCentres] = bin9(Dataij, minrt, maxrt);
% ========================================================================================
%    [Q, ThetaCentres] = bin9(Data, minrt, maxrt)
%    Bin RTs into 9 equal-mass bins, filter out long RTs.
% ========================================================================================
eps = 0.0001;

% Equal-mass theta boundaries
%ntheta = 7;
ntheta = 9;
lnd = length(Dataij);
%thetabin = round(lnd * [0.1429, 0.2857, 0.4286,  0.5714, 0.7143, 0.8571, 1.0000]);
thetabin = round(lnd * [0.1111, 0.2222, 0.3333,  0.4444, 0.5556, 0.6667, 0.7778, 0.8889, 1.0000]);

BinRT = zeros(110, ntheta); % was 110 - why this
BinTheta = zeros(1, ntheta);
BinCount = zeros(1, ntheta);

[thetas,I] = sort(Dataij(:,1)); % Sorted on the errors in reduced datak
Dataij(:,:) = Dataij(I,:)

j = 1;
k = 1;
for i = 1:lnd
    % Go to next bin (data sorted by ascending theta) and reset RT counter
    if i > thetabin(j)
         j = j + 1;
         k = 1;
    end
    thetai = Dataij(i,1); 
    BinTheta(j) = BinTheta(j) + thetai;  % Sum thetas
    BinRT(k, j) = Dataij(i, 2); 
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
    truncrt = rts(find(rts >= minrt & rts <= maxrt))
    Qx = ceil(length(truncrt) * Qp)
    Q(:,j) = rts(Qx); 
end
end




