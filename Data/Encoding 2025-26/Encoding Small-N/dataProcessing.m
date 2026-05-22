%% learn how to assess data quickly

% get a list of all “Daz2_*.mat” files in the current folder
filePattern = 'Daz2_*.mat';
files = dir(filePattern);

dataAll = [];   % initialize

for i = 1:numel(files)
    fname = files(i).name;
    sessionStruct = load(fname);      % load into a struct
    
    fnames = fieldnames(sessionStruct);
    if numel(fnames) > 1
        error('File %s contains more than one variable. Adjust script to pick the right one.', fname);
    end
    sessionVar = sessionStruct.(fnames{1});  
    
    % On the first iteration, just assign:
    if i == 1
        dataAll = sessionVar;
    else
        % Subsequent iterations: concatenate “vertically”.
        % This works if sessionVar is a table:       dataAll = [dataAll; sessionVar];
        % or if it’s a struct array:                 dataAll = [dataAll; sessionVar];
        % or if it’s a numeric matrix with same columns: dataAll = [dataAll; sessionVar];
        %
        % If you need to concatenate differently (e.g. horizontally), adjust here.
        dataAll = [dataAll; sessionVar];
    end
end

disp('Combined dataAll summary:');
whos dataAll

% save('dataAll.mat', 'dataAll');

[uniVal, ~, grpIdx] = unique(dataAll.CueType);

counts = accumarray (grpIdx, 1);

%% Descriptive plotting------RT all factors-------------

% Remove trials with RT > 2500 ms
validIdx = dataAll.ResponseTime <= 2500;
dataAll = dataAll(validIdx, :);

% If dataAll is a table, this works:
grouping = categorical(dataAll.Grouping);      % “Grouped” or “Separated”
cueType  = categorical(dataAll.CueType);      % “R” or “NR”
presDur  = dataAll.PresDur;                   % e.g. 0.10, 0.15, …, 0.35
RT       = dataAll.ResponseTime;               % RT in ms
precision = dataAll.Precision;                % in degrees [0, 360)

%Identify the unique levels of each factor, and sort presDur
presDurs = unique(presDur);                    % Should be [0.10;0.15;0.20;0.25;0.30;0.35]
presDurs = sort(presDurs);                     % Just to ensure ascending order

groupLevels = categories(grouping);             % Should be {“Grouped”, “Separated”}
cueLevels   = categories(cueType);              % Should be {“NR”, “R”} or {“R”, “NR”}
% For plotting we want: groupingOrder = {“Grouped”, “Separate”}
%                     cueOrder      = {“R”, “NR”}   (so “R” is marker ○, “NR” is □)
groupingOrder = ["Grouped","Separate"];       
cueOrder      = ["R","NR"];

% Pre‐allocate arrays to hold means and SEMs
nDur = numel(presDurs);
nGrp = numel(groupingOrder);
nCue = numel(cueOrder);

meanRT = nan(nDur, nGrp, nCue);
semRT  = nan(nDur, nGrp, nCue);

% Loop over each combination and compute mean & SEM
for iDur = 1:nDur
    thisDur = presDurs(iDur);
    
    for iGrp = 1:nGrp
        thisGrp = groupingOrder(iGrp);
        
        for iCue = 1:nCue
            thisCue = cueOrder(iCue);
            
            % Logical index of trials matching (PresDur, Grouped, CueType)
            idx = ( presDur == thisDur ) ...
                & ( grouping == thisGrp ) ...
                & ( cueType  == thisCue );
            
            theseRTs = RT(idx);
            meanRT(iDur, iGrp, iCue) = mean(theseRTs);
            semRT(iDur, iGrp, iCue)  = std(theseRTs) / sqrt(numel(theseRTs));
        end
    end
end

% Prepare figure and define “x‐positions” for each sub‐point
%six presDurs along x = 1:6
xCenters = 1:nDur;  

% Within each presDur 4 sub‐positions
% ±0.18 around each center
offsets = [ -0.18, -0.06,  +0.06,  +0.18 ];  
% Mapping of (iGrp,iCue) → which offset index?
%   iGrp=1 (“Grouped”), iCue=1 (“R”)  → offsets(1)
%   iGrp=1 (“Grouped”), iCue=2 (“NR”) → offsets(2)
%   iGrp=2 (“Separated”), iCue=1 (“R”)  → offsets(3)
%   iGrp=2 (“Separated”), iCue=2 (“NR”) → offsets(4)

markerShapes = {'o','s'};   % ‘o’ for “R”,  ‘s’ for “NR”
groupColors  = [ 0.8500 0.3250 0.0980 ;   % RGB for “Grouped” (reddish)
                 0       0.4470 0.7410 ]; % RGB for “Separated” (bluish)

figure('Color','w');
hold on;

% First: scatter all single‐trial RTs with slight x‐jitter & transparency
for iDur = 1:nDur
    for iGrp = 1:nGrp
        for iCue = 1:nCue
            % condition’s central x‐position:
            baseX = xCenters(iDur) + offsets( (iGrp-1)*nCue + iCue );
            
            % get all RTs in this cell again:
            idx = ( presDur == presDurs(iDur) ) ...
                & ( grouping == groupingOrder(iGrp) ) ...
                & ( cueType  == cueOrder(iCue) );
            theseRTs = RT(idx);
            nThis     = numel(theseRTs);
            if nThis==0
                continue
            end
            
            % generate small random jitter in x:
            % (Uniform jitter between [–0.04, +0.04]):
            jitterWidth = 0.04;
            xJitter     = (rand(nThis,1)*2 - 1) * jitterWidth;
            
            % scatter the single trials:
            scatter( ...
                baseX + xJitter, ...      % x‐values ± jitter
                theseRTs, ...             % y‐values are raw RT
                10, ...                   % marker size
                'MarkerFaceColor', groupColors(iGrp,:), ...
                'MarkerEdgeColor', 'none', ...
                'MarkerFaceAlpha', 0.15, ...   % 15% opacity
                'MarkerEdgeAlpha', 0.05)        % 5% outline opacity
            
        end
    end
end

%Next: plot mean ± SEM on top of the cloud
for iDur = 1:nDur
    for iGrp = 1:nGrp
        for iCue = 1:nCue
            baseX = xCenters(iDur) + offsets( (iGrp-1)*nCue + iCue );
            mRT   = meanRT(iDur, iGrp, iCue);
            sRT   = semRT(iDur, iGrp, iCue);
            
            if isnan(mRT)
                continue
            end
            
            % Plot the errorbar (vertical):
            errorbar( ...
                baseX, mRT, sRT, ...         % x, mean, sem
                'LineStyle', 'none', ...
                'Color', groupColors(iGrp,:), ...
                'LineWidth', 1.2 ...
            );
            
            % Plot the mean point on top of the errorbar:
            plot( ...
                baseX, mRT, markerShapes{iCue}, ...
                'MarkerSize', 7, ...
                'MarkerFaceColor', groupColors(iGrp,:), ...
                'MarkerEdgeColor', 'k', ...
                'LineWidth', 1.0 ...
            );
        end
    end
end

% Final cosmetics: axes, labels, legend, etc.
% Make x‐axis tick locations at 1:6, but label them with actual PresDur values
set(gca, ...
    'XTick', xCenters, ...
    'XTickLabel', arrayfun(@(x) sprintf('%.2f', x), presDurs, 'UniformOutput',false), ...
    'FontSize', 12 ...
);
xlabel('Presentation Durations (s)', 'FontSize', 14);
ylabel('RT (ms)', 'FontSize', 14);
title('Mean RT by Pres.Dura + dist. and SE', 'FontSize', 16);

% Build a custom legend for the 4 (Grouping × CueType) combinations:
hLegend = gobjects(4,1);
legLabels = cell(4,1);
k = 0;
for iGrp = 1:nGrp
    for iCue = 1:nCue
        k = k + 1;
        hLegend(k) = plot(NaN, NaN, markerShapes{iCue}, ...
            'MarkerSize', 7, ...
            'MarkerFaceColor', groupColors(iGrp,:), ...
            'MarkerEdgeColor', 'k', ...
            'LineWidth', 1.0);
        legLabels{k} = sprintf('%s, %s', groupingOrder(iGrp), cueOrder(iCue));
    end
end
legend(hLegend, legLabels, 'Location', 'northeastoutside');

box on;
grid on;
xlim([0.5, nDur + 0.5]);
hold off;

%% Descriptive Plotting-------------Precision

% Pre‐allocate arrays for CircSD and CircSE (in degrees)
circSD = nan(nDur, nGrp, nCue);
circSE = nan(nDur, nGrp, nCue);

% Compute CircSD and CircSE for each (PresDur, Grouping, CueType)
for iDur = 1:nDur
    thisDur = presDurs(iDur);
    for iGrp = 1:nGrp
        thisGrp = groupingOrder(iGrp);
        for iCue = 1:nCue
            thisCue = cueOrder(iCue);
            
            % Logical index for this condition
            idx = (presDur == thisDur) ...
                & (grouping == thisGrp) ...
                & (cueType  == thisCue);
            thesePrec = precision(idx);  % in degrees
            nTrials = numel(thesePrec);
            
            if nTrials < 2
                % Not enough data to compute a meaningful circSD
                circSD(iDur,iGrp,iCue) = NaN;
                circSE(iDur,iGrp,iCue) = NaN;
                continue
            end
            
            % Convert degrees to radians in [0, 2π):
            theta = thesePrec .* (pi/180);
            
            % Compute mean resultant length R:
            C = sum(cos(theta));
            S = sum(sin(theta));
            Rbar = sqrt(C^2 + S^2) / nTrials;
            
            % Circular standard deviation (in radians):
            %   circSD_rad = sqrt(-2 * log(Rbar))
            circSD_rad = sqrt(-2 * log(Rbar));
            
            % Convert CircSD to degrees:
            circSD_deg = circSD_rad * (180/pi);
            circSD(iDur,iGrp,iCue) = circSD_deg;
            
            % Circular standard error: approximate as circSD / sqrt(n)
            circSE(iDur,iGrp,iCue) = circSD_deg / sqrt(nTrials);
        end
    end
end

% Plotting setup: x positions & formatting
xCenters = 1:nDur;  
offsets = [ -0.18, -0.06, +0.06, +0.18 ];  
% Mapping of (iGrp,iCue) → offset index:
%   (1,1) → -0.18, (1,2) → -0.06, (2,1) → +0.06, (2,2) → +0.18

markerShapes = {'o','s'};   % ‘o’ for “R”, ‘s’ for “NR”
groupColors  = [ 0.8500 0.3250 0.0980;   % “Grouped” (reddish)
                 0       0.4470 0.7410]; % “Separated” (bluish)

figure('Color','w');
hold on;

% Plot CircSD ± CircSE
for iDur = 1:nDur
    for iGrp = 1:nGrp
        for iCue = 1:nCue
            baseX = xCenters(iDur) + offsets( (iGrp-1)*nCue + iCue );
            sdVal = circSD(iDur,iGrp,iCue);
            seVal = circSE(iDur,iGrp,iCue);
            if isnan(sdVal)
                continue
            end
            
            % Plot errorbar (vertical line for ±CircSE)
            errorbar( ...
                baseX, sdVal, seVal, ...
                'LineStyle','none', ...
                'Color', groupColors(iGrp,:), ...
                'LineWidth', 1.2 ...
            );
            
            % Plot the CircSD point on top
            plot( ...
                baseX, sdVal, markerShapes{iCue}, ...
                'MarkerSize', 7, ...
                'MarkerFaceColor', groupColors(iGrp,:), ...
                'MarkerEdgeColor', 'k', ...
                'LineWidth', 1.0 ...
            );
        end
    end
end

% Axes labels, ticks, legend, etc.
set(gca, ...
    'XTick', xCenters, ...
    'XTickLabel', arrayfun(@(x) sprintf('%.2f', x), presDurs, 'UniformOutput', false), ...
    'FontSize', 12 ...
);
xlabel('Presentation Durations', 'FontSize', 14);
ylabel('Cir.SD of Error Magnitude', 'FontSize', 14);
title('Cir.SD with Cir.SE', 'FontSize', 16);

% Build custom legend for the 4 (Grouping × CueType) markers
hLegend = gobjects(4,1);
legLabels = cell(4,1);
k = 0;
for iGrp = 1:nGrp
    for iCue = 1:nCue
        k = k + 1;
        hLegend(k) = plot(NaN, NaN, markerShapes{iCue}, ...
            'MarkerSize', 7, ...
            'MarkerFaceColor', groupColors(iGrp,:), ...
            'MarkerEdgeColor', 'k', ...
            'LineWidth', 1.0);
        legLabels{k} = sprintf('%s, %s', groupingOrder(iGrp), cueOrder(iCue));
    end
end
legend(hLegend, legLabels, 'Location', 'northeastoutside');

box on;
grid on;
xlim([0.5, nDur + 0.5]);
hold off;

%% Descriptive Plotting-----------RT without Grouping

meanRT2 = nan(nDur, nCue);
semRT2  = nan(nDur, nCue);

for iDur = 1:nDur
    thisDur = presDurs(iDur);
    for iCue = 1:nCue
        thisCue = cueOrder(iCue);
        
        idx = (presDur == thisDur) & (cueType == thisCue);
        theseRTs = RT(idx);
        
        if isempty(theseRTs)
            continue
        end
        
        meanRT2(iDur, iCue) = mean(theseRTs);
        semRT2(iDur, iCue)  = std(theseRTs) / sqrt(numel(theseRTs));
    end
end

% Prepare plotting parameters
xCenters = 1:nDur;                     % categorical x positions = 1..6
offsets  = [-0.12, +0.12];             % small horizontal shifts for R vs NR

% Define colors for ‘R’ vs ‘NR’
cueColors = [ 0.8500 0.3250 0.0980;      % ‘R’ → reddish
              0       0.4470 0.7410 ];   % ‘NR’ → bluish

markerSize = 10;
jitterWidth = 0.05;   % for the single‐trial scatter

figure('Color','w');
hold on;

% Scatter all single‐trial RTs (semi‐transparent) by CueType
for iDur = 1:nDur
    for iCue = 1:nCue
        thisCue = cueOrder(iCue);
        idx = (presDur == presDurs(iDur)) & (cueType == thisCue);
        theseRTs = RT(idx);
        nThis = numel(theseRTs);
        if nThis == 0
            continue
        end
        
        % Generate uniform jitter in [–jitterWidth, +jitterWidth]
        xJitter = (rand(nThis,1)*2 - 1) * jitterWidth;
        baseX = xCenters(iDur) + offsets(iCue);
        
        scatter( ...
            baseX + xJitter, ...         % x ± jitter
            theseRTs, ...                % y = RT values
            markerSize, ...
            'MarkerFaceColor', cueColors(iCue,:), ...
            'MarkerEdgeColor', 'none', ...
            'MarkerFaceAlpha', 0.15, ...  % 15% opacity
            'MarkerEdgeAlpha', 0.05 ...   % 5% opacity on edge
        );
    end
end

% Overlay mean ± SEM
for iDur = 1:nDur
    for iCue = 1:nCue
        baseX = xCenters(iDur) + offsets(iCue);
        mRT = meanRT2(iDur, iCue);
        sRT = semRT2(iDur, iCue);
        
        if isnan(mRT)
            continue
        end
        
        % Errorbar (vertical line)
        errorbar( ...
            baseX, mRT, sRT, ...
            'LineStyle','none', ...
            'Color', cueColors(iCue,:), ...
            'LineWidth', 1.5 ...
        );
        
        % Mean marker
        plot( ...
            baseX, mRT, 'o', ...
            'MarkerSize', 8, ...
            'MarkerFaceColor', cueColors(iCue,:), ...
            'MarkerEdgeColor', 'k', ...
            'LineWidth', 1.0 ...
        );
    end
end

% Final axes labeling & legend
set(gca, ...
    'XTick', xCenters, ...
    'XTickLabel', arrayfun(@(x) sprintf('%.2f', x), presDurs, 'UniformOutput',false), ...
    'FontSize', 12 ...
);
xlabel('Presentation Durations', 'FontSize', 14);
ylabel('RT (ms)', 'FontSize', 14);
title('Mean RT by Pres.Dura & Cue', 'FontSize', 16);

% Legend for CueType
hLegend = gobjects(nCue,1);
legLabels = cell(nCue,1);
for iCue = 1:nCue
    hLegend(iCue) = plot(NaN, NaN, 'o', ...
        'MarkerSize', 8, ...
        'MarkerFaceColor', cueColors(iCue,:), ...
        'MarkerEdgeColor', 'k', ...
        'LineWidth', 1.0);
    legLabels{iCue} = sprintf('Cue = %s', cueOrder(iCue));
end
legend(hLegend, legLabels, 'Location', 'northeastoutside');

box on;
grid on;
xlim([0.5, nDur + 0.5]);
hold off;

%% Descriptive Plotting------------Precision no grouping
% Pre‐allocate for circSD & circSE (degrees)
circSD2 = nan(nDur, nCue);
circSE2 = nan(nDur, nCue);

for iDur = 1:nDur
    thisDur = presDurs(iDur);
    for iCue = 1:nCue
        thisCue = cueOrder(iCue);
        
        % Select all Precision values for this (PresDur, CueType) combo:
        idx = (presDur == thisDur) & (cueType == thisCue);
        thesePrec = precision(idx);  % in degrees
        
        nT = numel(thesePrec);
        if nT < 2
            continue
        end
        
        % Convert to radians in [0,2π):
        theta = thesePrec .* (pi/180);
        
        % Compute mean resultant length Rbar:
        C = sum(cos(theta));
        S = sum(sin(theta));
        Rbar = sqrt(C^2 + S^2) / nT;
        
        % Circular SD in radians:
        circSD_rad = sqrt(-2 * log(Rbar));
        
        % Convert to degrees:
        circSD_deg = circSD_rad * (180/pi);
        circSD2(iDur, iCue) = circSD_deg;
        
        % Circular SE = circSD / sqrt(nT)
        circSE2(iDur, iCue) = circSD_deg / sqrt(nT);
    end
end

% Plotting setup
xCenters = 1:nDur;
offsets  = [-0.12, +0.12];  % separate R vs NR horizontally

% Colors for ‘R’ vs ‘NR’ (same as RT plot)
cueColors = [ 0.8500 0.3250 0.0980;    % R (reddish)
              0       0.4470 0.7410 ]; % NR (bluish)

figure('Color','w');
hold on;

% Plot CircSD ± CircSE (no raw scatter)
for iDur = 1:nDur
    for iCue = 1:nCue
        baseX = xCenters(iDur) + offsets(iCue);
        sdVal = circSD2(iDur, iCue);
        seVal = circSE2(iDur, iCue);
        
        if isnan(sdVal)
            continue
        end
        
        % Errorbar (vertical whisker)
        errorbar( ...
            baseX, sdVal, seVal, ...
            'LineStyle', 'none', ...
            'Color', cueColors(iCue,:), ...
            'LineWidth', 1.5 ...
        );
        
        % Plot the CircSD marker
        plot( ...
            baseX, sdVal, 'o', ...
            'MarkerSize', 8, ...
            'MarkerFaceColor', cueColors(iCue,:), ...
            'MarkerEdgeColor', 'k', ...
            'LineWidth', 1.0 ...
        );
    end
end

% Final cosmetics
set(gca, ...
    'XTick', xCenters, ...
    'XTickLabel', arrayfun(@(x) sprintf('%.2f', x), presDurs, 'UniformOutput', false), ...
    'FontSize', 12 ...
);
xlabel('Presentation Durations',          'FontSize', 14);
ylabel('Cir.SD of Precision', 'FontSize', 14);
title('Cir.SD with Cir.SE by Durations', 'FontSize', 16);

% Legend for CueType
hLegend = gobjects(nCue,1);
legLabels = cell(nCue,1);
for iCue = 1:nCue
    hLegend(iCue) = plot(NaN, NaN, 'o', ...
        'MarkerSize', 8, ...
        'MarkerFaceColor', cueColors(iCue,:), ...
        'MarkerEdgeColor', 'k', ...
        'LineWidth', 1.0);
    legLabels{iCue} = sprintf('Cue = %s', cueOrder(iCue));
end
legend(hLegend, legLabels, 'Location', 'northeastoutside');

box on;
grid on;
xlim([0.5, nDur + 0.5]);
hold off;