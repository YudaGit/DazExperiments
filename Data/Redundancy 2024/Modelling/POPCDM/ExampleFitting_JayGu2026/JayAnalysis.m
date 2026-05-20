clear; close all; clc;

datapath = 'Data_SaturationExp1';

d = dir(fullfile(datapath, '*.mat'));
pattern = ['^(?<prefix>.+?)_' ...         % prefix before `_'
            '(?<ID>[^_]+)_' ...           % a non-empty string (no _ spaces)
            '(?<session>\d+)_' ...        % digits               (session)
            '(?<date>\d{4}-\d{2}-\d{2})_' ... % yyyy-mm-dd           (date)
            '(?<time>\d{2}-\d{2}-\d{2})' ...  % HH-MM-SS             (time)
            '\.mat$'];                    % .mat files only
allInfo = arrayfun(@(f) regexp(f.name, pattern, 'names'), d);
dates = datetime( {allInfo.date}, 'InputFormat', 'yyyy-MM-dd');
files = {d.name};

for ii = 1:length(files)
    f = load(fullfile(datapath, files{ii}));
    f = f.trials;
    session = regexp(d(ii).name, '_(\d+)_2026', 'tokens');

    if ii == 1
        data = f;
    else
        data = [data;f];
    end

end



clearvars -except data

data = data(strcmp(data.ID, 'G01'),:);
data = data(data.MouseInitTooSlow == 0 & data.MouseInitTooFast == 0 & data.TrialTooSlow == 0, :);

set(figure(1), 'Position', get(0, 'Screensize'), 'color','w');
ii = 1;
bandwidth = 10;
xgrid = linspace(-180, 180, 361);
for n = [1,2,4,6]
    for sat = {'high','low'}

        d = data( strcmp( data.StimulusSaturation, sat) & data.ItemN == n, : );
        
        subplot_tight(2, 4, ii, [0.05, 0.05]);
        
        histogram(d.Precision, 'Normalization', 'pdf', 'BinWidth', bandwidth, 'EdgeColor', 'none', 'FaceColor', [.5, .5, .5], 'FaceAlpha',.33); hold on;
        ksdensity( d.Precision, xgrid,  'Bandwidth', bandwidth)
        set(gca, 'linewidth', 1,'fontweight','bold','fontsize',14, 'box','off','TickLabelInterpreter','LaTeX');

        ylim([0, 0.025])
        xlim([-180, 180])

        yticks(0:0.005:0.015);

        ii = ii + 1;
    end
end



set(figure(2), 'Position', get(0, 'Screensize'), 'color','w');
ii = 1;
bandwidth = 100;
%xgrid = linspace(0, 5000/bandwidth, 5000);
for n = [1,2,4,6]
    for sat = {'high','low'}

        d = data( strcmp( data.StimulusSaturation, sat) & data.ItemN == n, : );
        
        subplot_tight(2, 4, ii, [0.05, 0.05]);
        
        histogram(d.ResponseTime, 'Normalization', 'pdf', 'BinWidth', bandwidth, 'EdgeColor', 'none', 'FaceColor', [.5, .5, .5], 'FaceAlpha',.33); hold on;
        %ksdensity( d.ResponseTime, xgrid,  'Bandwidth', bandwidth);
        set(gca, 'linewidth', 1,'fontweight','bold','fontsize',14, 'box','off','TickLabelInterpreter','LaTeX');

        ylim([0, 0.0025])
        xlim([0, 5000])

        %yticks(0:0.005:0.015);

        ii = ii + 1;
    end
end


% So this is for set size 6 at low saturation given the last loop of d in
% the above loop...
x = EZ_CDM(d);



%%

function [std_circ, variance, SEr, SEs] = circular_std(theta)
    % theta is the angular data in radians
    n = length(theta); % Number of data points
    C = sum(cos(theta)); % Sum of cosines
    S = sum(sin(theta)); % Sum of sines
    R = sqrt(C^2 + S^2) / n; % Mean resultant length
    std_circ = sqrt(-2 * log(R)); % Circular standard deviation
    variance = 1 - R;
    SEr = sqrt(1 - R ^ 2) / sqrt(n);
    SEs = (1 / (R * sqrt(-2 * log(R)))) * SEr;
end

function output = EZ_CDM(data, robust)
    % Check if robust mode is specified
    if nargin < 2
        robust = true; % Default is robust mode
    end

    % Convert response error to radians
    CA = deg2rad(data.Precision);

    % Number of rows
    N = size(data.Precision, 1);

    % Mean Circular Angle (MCA)
    sinSum = sum(sin(CA));
    cosSum = sum(cos(CA));
    MCA = atan2(sinSum / N, cosSum / N);

    % Circular Variance (VCA)
    VCA = 1 - (1 / N) * sqrt(cosSum^2 + sinSum^2);

    % Mean and Variance of Response Time (RT)
    if robust
        MRT = median(data.ResponseTime / 1000); % Convert to seconds
        VRT = iqr(data.ResponseTime/ 1000); % Interquartile Range
    else
        MRT = mean(data.ResponseTime / 1000); % Convert to seconds
        VRT = var(data.ResponseTime / 1000); % Variance
    end

    % Initial estimate of von Mises concentration parameter (k0)
    R = 1 - VCA;
    k0 = R * (2 - R^2) / (1 - R^2);

    % Refine k0 using Newton-Raphson method to estimate k1
    % Bessel function of the first kind
    iv = @(x, n) besseli(n, x); 
    k1 = k0 - (iv(k0, 1) / iv(k0, 0) - R) / ...
         (1 - (iv(k0, 1) / iv(k0, 0))^2 - iv(k0, 1) / iv(k0, 0) / k0);

    % Calculate drift rate (v)
    v = ((k1^2 * R^2 + 2 * k1 * R - k1^2) / VRT)^(1 / 4);

    % Calculate boundary separation (a)
    a = k1 / v;

    % Calculate non-decision time (t0)
    t0 = MRT - (a / v) * R;

    % Prepare results in a table
    output = table(N, MCA, R, k0, k1, v, a, t0, ...
        'VariableNames', {'N', 'theta_v', 'R', 'k0', 'k1', 'v', 'a', 't0'});
end

function h = subplot_tight(m,n,p,margins,varargin)
    % Usage example: h=subplot_tight((2,3,1:2,[0.5,0.2])
    if (nargin<4) || isempty(margins); margins=[0.01,0.01]; end
    if length(margins)==1; margins(2)=margins;end
    
    %note n and m are switched as Matlab indexing is column-wise, while subplot indexing is row-wise :(
    [subplot_col,subplot_row]=ind2sub([n,m],p);  
    height=(1-(m+1)*margins(1))/m; % single subplot height
    width=(1-(n+1)*margins(2))/n;  % single subplot width
    
    % note subplot suppors vector p inputs- so a merged subplot of higher dimentions will be created
    subplot_cols=1+max(subplot_col)-min(subplot_col); % number of column elements in merged subplot 
    subplot_rows=1+max(subplot_row)-min(subplot_row); % number of row elements in merged subplot   
    
    merged_height=subplot_rows*( height+margins(1) )- margins(1);   % merged subplot height
    merged_width= subplot_cols*( width +margins(2) )- margins(2);   % merged subplot width
    
    merged_bottom=(m-max(subplot_row))*(height+margins(1)) +margins(1); % merged subplot bottom position
    merged_left=min(subplot_col)*(width+margins(2))-width;              % merged subplot left position
    pos_vec=[merged_left merged_bottom merged_width merged_height];
    h_subplot=subplot('Position',pos_vec,varargin{:});
    
    if nargout~=0
        h=h_subplot;
    end
end
