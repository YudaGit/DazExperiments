% Plot summary statistics for STInte pilot data
% Figure 1a: Precision (circular SD of absolute errors)
% Figure 1b: RT (median + CI)
% Figure 2a: Precision Distributions
% Figure 2b: RT Distributions

clear; close all; clc;

fprintf('=== Loading STInte Data ===\n\n');
fprintf('*** SCRIPT VERSION: UPDATED WITH 9 BARS PER GROUP ***\n\n');

% Data directory (script runs from within the data folder)
dataDir = '.';

% Find all session files
files = dir(fullfile(dataDir, 'STInte_*.mat'));
if isempty(files)
    error('No STInte data files found in %s', dataDir);
end

% Sort files by session number
sessionNumbers = zeros(length(files), 1);
for i = 1:length(files)
    match = regexp(files(i).name, 'sess(\d+)', 'tokens');
    if ~isempty(match) && ~isempty(match{1})
        sessionNumbers(i) = str2double(match{1}{1});
    end
end
[~, sortIdx] = sort(sessionNumbers);
files = files(sortIdx);

% Load all sessions
allTrials = [];
for i = 1:length(files)
    filepath = fullfile(dataDir, files(i).name);
    fprintf('Loading session %d...\n', sessionNumbers(sortIdx(i)));
    
    data = load(filepath, 'expTrials');
    if ~isfield(data, 'expTrials')
        warning('Session %d: No expTrials found, skipping', sessionNumbers(sortIdx(i)));
        continue;
    end
    
    trials = data.expTrials;
    if istable(trials)
        trials.Session = repmat(sessionNumbers(sortIdx(i)), height(trials), 1);
    end
    
    if isempty(allTrials)
        allTrials = trials;
    else
        allTrials = [allTrials; trials];
    end
end

fprintf('\nTotal trials loaded: %d\n\n', height(allTrials));

% Filter out invalid trials (missing precision or RT)
validIdx = ~isnan(allTrials.Precision) & ~isnan(allTrials.ResponseTime) & ...
           allTrials.ResponseTime > 0;
allTrials = allTrials(validIdx, :);
fprintf('Valid trials: %d\n\n', height(allTrials));

% Helper function to compute circular SD for a group
function csd = computeCircSD(errorsDeg)
    % Convert to radians
    errorsRad = deg2rad(errorsDeg);
    % Compute mean resultant length
    R = sqrt(mean(cos(errorsRad)).^2 + mean(sin(errorsRad)).^2);
    % Avoid log(0) or log(negative)
    if R >= 1
        csd = 0;
    elseif R <= 0
        csd = 180; % Maximum spread
    else
        csd = rad2deg(sqrt(-2 * log(R)));
    end
end

% Helper function for bootstrap CI
function ci = bootstrapCI(data, nBootstrap, alpha)
    if isempty(data) || length(data) < 2
        ci = [NaN, NaN];
        return;
    end
    n = length(data);
    bootStats = zeros(nBootstrap, 1);
    for b = 1:nBootstrap
        bootSample = data(randi(n, n, 1));
        bootStats(b) = median(bootSample);
    end
    ci = prctile(bootStats, [alpha/2*100, (1-alpha/2)*100]);
end

% Prepare data for plotting
% Groups: N=4 (high noise), N=6 (high noise)
% For each group: Baseline, AggR-cue, AggNR-cue, RS_TimeOnly_R, RS_TimeOnly_NR, 
%                 RS_SpaceTime_R, RS_SpaceTime_NR, RedundantGrouped_R, RedundantGrouped_NR

itemNs = [4, 6];
xGroups = {'N=4', 'N=6'};
nGroups = length(xGroups);
barsPerGroup = 9;  % Baseline, AggR-cue, AggNR-cue, RS_TimeOnly_R, RS_TimeOnly_NR, 
                   % RS_SpaceTime_R, RS_SpaceTime_NR, RedundantGrouped_R, RedundantGrouped_NR

% Initialize storage for all data
allPrecisionData = cell(nGroups, barsPerGroup);
allRTData = cell(nGroups, barsPerGroup);

% Collect data for each group and condition
for g = 1:nGroups
    itemN = itemNs(g);
    
    % 1. Baseline
    idx = allTrials.ItemN == itemN & strcmp(allTrials.Condition, 'Baseline');
    if sum(idx) > 0
        allPrecisionData{g, 1} = abs(allTrials.Precision(idx));
        allRTData{g, 1} = allTrials.ResponseTime(idx);
    end
    
    % 2. Aggregated R-cue (RS_TimeOnly + RS_SpaceTime + RedundantGrouped, CueType='R')
    idx = allTrials.ItemN == itemN & ...
          ismember(allTrials.Condition, {'RS_TimeOnly', 'RS_SpaceTime', 'RedundantGrouped'}) & ...
          strcmp(allTrials.CueType, 'R');
    if sum(idx) > 0
        allPrecisionData{g, 2} = abs(allTrials.Precision(idx));
        allRTData{g, 2} = allTrials.ResponseTime(idx);
    end
    
    % 3. Aggregated NR-cue (RS_TimeOnly + RS_SpaceTime + RedundantGrouped, CueType='NR')
    idx = allTrials.ItemN == itemN & ...
          ismember(allTrials.Condition, {'RS_TimeOnly', 'RS_SpaceTime', 'RedundantGrouped'}) & ...
          strcmp(allTrials.CueType, 'NR');
    if sum(idx) > 0
        allPrecisionData{g, 3} = abs(allTrials.Precision(idx));
        allRTData{g, 3} = allTrials.ResponseTime(idx);
    end
    
    % 4. RS_TimeOnly_R (R-cue only)
    idx = allTrials.ItemN == itemN & strcmp(allTrials.Condition, 'RS_TimeOnly') & ...
          strcmp(allTrials.CueType, 'R');
    if sum(idx) > 0
        allPrecisionData{g, 4} = abs(allTrials.Precision(idx));
        allRTData{g, 4} = allTrials.ResponseTime(idx);
    end
    
    % 5. RS_TimeOnly_NR (NR-cue only)
    idx = allTrials.ItemN == itemN & strcmp(allTrials.Condition, 'RS_TimeOnly') & ...
          strcmp(allTrials.CueType, 'NR');
    if sum(idx) > 0
        allPrecisionData{g, 5} = abs(allTrials.Precision(idx));
        allRTData{g, 5} = allTrials.ResponseTime(idx);
    end
    
    % 6. RS_SpaceTime_R (R-cue only)
    idx = allTrials.ItemN == itemN & strcmp(allTrials.Condition, 'RS_SpaceTime') & ...
          strcmp(allTrials.CueType, 'R');
    if sum(idx) > 0
        allPrecisionData{g, 6} = abs(allTrials.Precision(idx));
        allRTData{g, 6} = allTrials.ResponseTime(idx);
    end
    
    % 7. RS_SpaceTime_NR (NR-cue only)
    idx = allTrials.ItemN == itemN & strcmp(allTrials.Condition, 'RS_SpaceTime') & ...
          strcmp(allTrials.CueType, 'NR');
    if sum(idx) > 0
        allPrecisionData{g, 7} = abs(allTrials.Precision(idx));
        allRTData{g, 7} = allTrials.ResponseTime(idx);
    end
    
    % 8. RedundantGrouped_R (R-cue only)
    idx = allTrials.ItemN == itemN & strcmp(allTrials.Condition, 'RedundantGrouped') & ...
          strcmp(allTrials.CueType, 'R');
    if sum(idx) > 0
        allPrecisionData{g, 8} = abs(allTrials.Precision(idx));
        allRTData{g, 8} = allTrials.ResponseTime(idx);
    end
    
    % 9. RedundantGrouped_NR (NR-cue only)
    idx = allTrials.ItemN == itemN & strcmp(allTrials.Condition, 'RedundantGrouped') & ...
          strcmp(allTrials.CueType, 'NR');
    if sum(idx) > 0
        allPrecisionData{g, 9} = abs(allTrials.Precision(idx));
        allRTData{g, 9} = allTrials.ResponseTime(idx);
    end
end

% Compute summary statistics
allBarData = zeros(nGroups * barsPerGroup, 1);
allBarCI_upper = zeros(nGroups * barsPerGroup, 1);
allBarCI_lower = zeros(nGroups * barsPerGroup, 1);
allRTBarData = zeros(nGroups * barsPerGroup, 1);
allRTBarCI_upper = zeros(nGroups * barsPerGroup, 1);
allRTBarCI_lower = zeros(nGroups * barsPerGroup, 1);

for g = 1:nGroups
    for b = 1:barsPerGroup
        idx = (g-1)*barsPerGroup + b;
        
        % Precision: circular SD
        if ~isempty(allPrecisionData{g, b})
            allBarData(idx) = computeCircSD(allPrecisionData{g, b});
            % Bootstrap CI for circular SD
            nBootstrap = 1000;
            bootStats = zeros(nBootstrap, 1);
            for boot = 1:nBootstrap
                bootSample = allPrecisionData{g, b}(randi(length(allPrecisionData{g, b}), length(allPrecisionData{g, b}), 1));
                bootStats(boot) = computeCircSD(bootSample);
            end
            allBarCI_upper(idx) = prctile(bootStats, 97.5);
            allBarCI_lower(idx) = prctile(bootStats, 2.5);
        end
        
        % RT: median
        if ~isempty(allRTData{g, b})
            allRTBarData(idx) = median(allRTData{g, b});
            ci = bootstrapCI(allRTData{g, b}, 1000, 0.05);
            allRTBarCI_upper(idx) = ci(2);
            allRTBarCI_lower(idx) = ci(1);
        end
    end
end

% --- Figure 1a: Precision ---
fprintf('Creating Figure 1a: Precision...\n');
fprintf('*** DEBUG: barsPerGroup = %d ***\n', barsPerGroup);
fprintf('*** DEBUG: total bars = %d ***\n', length(allBarData));
fig1a = figure('Position', [100, 100, 1600, 500], 'Color', 'w');

% Determine global Y-axis max
globalYMax = max(allBarData + allBarCI_upper) * 1.1;

% Set up x-positions
barSpacing = 0.6;  % Spacing between bars within a group (reduced for more bars)
groupSpacing = 2.0;  % Spacing between groups
xPositions = [];
xLabels = {};

xStart = 1;
for g = 1:nGroups
    groupXPos = xStart + (0:(barsPerGroup-1)) * barSpacing;
    xPositions = [xPositions, groupXPos];
    
    % Labels: Baseline, AggR-cue, AggNR-cue, RS_Time_R, RS_Time_NR, RS_SpaceTime_R, RS_SpaceTime_NR, RG_Space_R, RG_Space_NR
    xLabels = [xLabels, {'Baseline', 'AggR-cue', 'AggNR-cue', 'RS_Time_R', 'RS_Time_NR', ...
                         'RS_ST_R', 'RS_ST_NR', 'RG_Space_R', 'RG_Space_NR'}];
    
    xStart = max(groupXPos) + groupSpacing;
end

% Plot all bars in single figure
b = bar(xPositions, allBarData, 0.4, 'FaceColor', 'flat');  % 0.4 = narrower bar width for more bars

% Set colors for each bar
% Gray (Baseline), Blue (AggR-cue), Red (AggNR-cue), 
% Darker blue (RS_Time_R), Lighter blue (RS_Time_NR),
% Darker red (RS_SpaceTime_R), Lighter red (RS_SpaceTime_NR),
% Darker green (RG_Space_R), Lighter green (RG_Space_NR)
barColors = repmat([0.5, 0.5, 0.5; 0.2, 0.6, 0.8; 0.8, 0.2, 0.2; ...
                    0.2, 0.4, 0.8; 0.4, 0.6, 0.9; ...
                    0.8, 0.2, 0.2; 0.9, 0.4, 0.4; ...
                    0.2, 0.8, 0.4; 0.4, 0.9, 0.6], nGroups, 1);
b.CData = barColors;

hold on;
% Error bars: 95% bootstrap CI
errorbar(xPositions, allBarData, allBarCI_upper - allBarData, allBarData - allBarCI_lower, ...
         'k', 'LineWidth', 1.2, 'CapSize', 6, 'LineStyle', 'none');
hold off;

% Adjust axes position to make room for group labels at bottom
ax = gca;
axPos = ax.Position;
ax.Position = [axPos(1), axPos(2) + 0.08, axPos(3), axPos(4) - 0.08];  % Make room at bottom

% Set x-axis labels
set(gca, 'XTick', xPositions);
set(gca, 'XTickLabel', xLabels);
set(gca, 'XTickLabelRotation', 45);
ylabel('Circular SD (deg)');
ylim([0, globalYMax]);
grid on;

% Add vertical lines to separate groups
hold on;
for g = 1:(nGroups-1)
    xSep = (max(xPositions((g-1)*barsPerGroup + (1:barsPerGroup))) + ...
            min(xPositions(g*barsPerGroup + (1:barsPerGroup)))) / 2;
    plot([xSep, xSep], [0, globalYMax], 'k--', 'LineWidth', 0.5);
end
hold off;

% Add group labels below condition labels using normalized axes coordinates
for g = 1:nGroups
    groupXCenter = mean(xPositions((g-1)*barsPerGroup + (1:barsPerGroup)));
    % Convert data coordinates to normalized axes coordinates
    xNorm = (groupXCenter - ax.XLim(1)) / (ax.XLim(2) - ax.XLim(1));
    yNorm = -0.15;  % Position below x-axis in normalized coordinates
    text(ax, xNorm, yNorm, xGroups{g}, 'Units', 'normalized', ...
         'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
end

sgtitle('Figure 1a: Precision (Circular SD of Absolute Errors) - Error bars: 95% Bootstrap CI', 'FontSize', 14, 'FontWeight', 'bold');

% Save figure
saveas(fig1a, fullfile(dataDir, 'Figure1a_Precision.png'));
fprintf('Saved: Figure1a_Precision.png\n\n');

% --- Figure 1b: RT ---
fprintf('Creating Figure 1b: RT...\n');
fig1b = figure('Position', [100, 100, 1600, 500], 'Color', 'w');

% Determine global Y-axis max
globalRTYMax = max(allRTBarData + allRTBarCI_upper) * 1.1;

% Use same x-positions and labels
b = bar(xPositions, allRTBarData, 0.4, 'FaceColor', 'flat');  % 0.4 = narrower bar width
b.CData = barColors;

hold on;
errorbar(xPositions, allRTBarData, allRTBarCI_upper - allRTBarData, allRTBarData - allRTBarCI_lower, ...
         'k', 'LineWidth', 1.2, 'CapSize', 6, 'LineStyle', 'none');
hold off;

% Adjust axes position to make room for group labels at bottom
ax = gca;
axPos = ax.Position;
ax.Position = [axPos(1), axPos(2) + 0.08, axPos(3), axPos(4) - 0.08];  % Make room at bottom

% Set x-axis labels
set(gca, 'XTick', xPositions);
set(gca, 'XTickLabel', xLabels);
set(gca, 'XTickLabelRotation', 45);
ylabel('RT Median (s)');
ylim([0, globalRTYMax]);
grid on;

% Add vertical lines to separate groups
hold on;
for g = 1:(nGroups-1)
    xSep = (max(xPositions((g-1)*barsPerGroup + (1:barsPerGroup))) + ...
            min(xPositions(g*barsPerGroup + (1:barsPerGroup)))) / 2;
    plot([xSep, xSep], [0, globalRTYMax], 'k--', 'LineWidth', 0.5);
end
hold off;

% Add group labels below condition labels using normalized axes coordinates
for g = 1:nGroups
    groupXCenter = mean(xPositions((g-1)*barsPerGroup + (1:barsPerGroup)));
    % Convert data coordinates to normalized axes coordinates
    xNorm = (groupXCenter - ax.XLim(1)) / (ax.XLim(2) - ax.XLim(1));
    yNorm = -0.15;  % Position below x-axis in normalized coordinates
    text(ax, xNorm, yNorm, xGroups{g}, 'Units', 'normalized', ...
         'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
end

sgtitle('Figure 1b: Response Time (Median) - Error bars: 95% Bootstrap CI', 'FontSize', 14, 'FontWeight', 'bold');

% Save figure
saveas(fig1b, fullfile(dataDir, 'Figure1b_RT.png'));
fprintf('Saved: Figure1b_RT.png\n\n');

% --- Figure 2a: Precision Distributions ---
fprintf('Creating Figure 2a: Precision Distributions...\n');
fig2a = figure('Position', [100, 100, 1600, 500], 'Color', 'w');

% Prepare scatter plot data
allYValues = [];
allXJittered = [];
allColors = [];

jitterAmount = 0.15;

for g = 1:nGroups
    for b = 1:barsPerGroup
        idx = (g-1)*barsPerGroup + b;
        if ~isempty(allPrecisionData{g, b})
            yVals = allPrecisionData{g, b}(:);
            xVal = xPositions(idx);
            xJittered = xVal + (rand(size(yVals)) - 0.5) * jitterAmount;
            allYValues = [allYValues; yVals];
            allXJittered = [allXJittered; xJittered(:)];
            % Assign colors based on bar index
            if b == 1
                allColors = [allColors; repmat([0.5, 0.5, 0.5], length(yVals), 1)];  % Gray (Baseline)
            elseif b == 2
                allColors = [allColors; repmat([0.2, 0.6, 0.8], length(yVals), 1)];  % Blue (AggR-cue)
            elseif b == 3
                allColors = [allColors; repmat([0.8, 0.2, 0.2], length(yVals), 1)];  % Red (AggNR-cue)
            elseif b == 4
                allColors = [allColors; repmat([0.2, 0.4, 0.8], length(yVals), 1)];  % Darker blue (RS_Time_R)
            elseif b == 5
                allColors = [allColors; repmat([0.4, 0.6, 0.9], length(yVals), 1)];  % Lighter blue (RS_Time_NR)
            elseif b == 6
                allColors = [allColors; repmat([0.8, 0.2, 0.2], length(yVals), 1)];  % Darker red (RS_SpaceTime_R)
            elseif b == 7
                allColors = [allColors; repmat([0.9, 0.4, 0.4], length(yVals), 1)];  % Lighter red (RS_SpaceTime_NR)
            elseif b == 8
                allColors = [allColors; repmat([0.2, 0.8, 0.4], length(yVals), 1)];  % Darker green (RG_Space_R)
            else
                allColors = [allColors; repmat([0.4, 0.9, 0.6], length(yVals), 1)];  % Lighter green (RG_Space_NR)
            end
        end
    end
end

% Plot semi-transparent scatter
scatter(allXJittered, allYValues, 30, allColors, 'filled', 'MarkerFaceAlpha', 0.4, 'MarkerEdgeAlpha', 0.2);

% Add box plots at each x position
hold on;
for g = 1:nGroups
    for b = 1:barsPerGroup
        idx = (g-1)*barsPerGroup + b;
        if ~isempty(allPrecisionData{g, b})
            xPos = xPositions(idx);
            data = allPrecisionData{g, b};
            
            % Draw box plot elements
            q25 = prctile(data, 25);
            q50 = prctile(data, 50);
            q75 = prctile(data, 75);
            iqr = q75 - q25;
            whiskerLow = max(min(data), q25 - 1.5*iqr);
            whiskerHigh = min(max(data), q75 + 1.5*iqr);
            
            % Box
            boxWidth = 0.25;  % Narrower box width for more bars
            rectangle('Position', [xPos - boxWidth/2, q25, boxWidth, q75 - q25], ...
                     'FaceColor', 'none', 'EdgeColor', 'k', 'LineWidth', 1.5);
            % Median line
            plot([xPos - boxWidth/2, xPos + boxWidth/2], [q50, q50], 'k-', 'LineWidth', 2);
            % Whiskers
            plot([xPos, xPos], [whiskerLow, q25], 'k-', 'LineWidth', 1);
            plot([xPos, xPos], [q75, whiskerHigh], 'k-', 'LineWidth', 1);
            plot([xPos - boxWidth/4, xPos + boxWidth/4], [whiskerLow, whiskerLow], 'k-', 'LineWidth', 1);
            plot([xPos - boxWidth/4, xPos + boxWidth/4], [whiskerHigh, whiskerHigh], 'k-', 'LineWidth', 1);
        end
    end
end
hold off;

% Adjust axes position to make room for group labels at bottom
ax = gca;
axPos = ax.Position;
ax.Position = [axPos(1), axPos(2) + 0.08, axPos(3), axPos(4) - 0.08];  % Make room at bottom

% Set x-axis labels
set(gca, 'XTick', xPositions);
set(gca, 'XTickLabel', xLabels);
set(gca, 'XTickLabelRotation', 45);
ylabel('Absolute Error (deg)');
yMax = max(allYValues) * 1.1;
ylim([0, yMax]);
grid on;

% Add vertical lines to separate groups
hold on;
for g = 1:(nGroups-1)
    xSep = (max(xPositions((g-1)*barsPerGroup + (1:barsPerGroup))) + ...
            min(xPositions(g*barsPerGroup + (1:barsPerGroup)))) / 2;
    plot([xSep, xSep], [0, yMax], 'k--', 'LineWidth', 0.5);
end
hold off;

% Add group labels below condition labels using normalized axes coordinates
for g = 1:nGroups
    groupXCenter = mean(xPositions((g-1)*barsPerGroup + (1:barsPerGroup)));
    % Convert data coordinates to normalized axes coordinates
    xNorm = (groupXCenter - ax.XLim(1)) / (ax.XLim(2) - ax.XLim(1));
    yNorm = -0.15;  % Position below x-axis in normalized coordinates
    text(ax, xNorm, yNorm, xGroups{g}, 'Units', 'normalized', ...
         'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
end

sgtitle('Figure 2a: Precision Distributions (Individual Trials)', 'FontSize', 14, 'FontWeight', 'bold');

% Save figure
saveas(fig2a, fullfile(dataDir, 'Figure2a_Precision_Distributions.png'));
fprintf('Saved: Figure2a_Precision_Distributions.png\n\n');

% --- Figure 2b: RT Distributions ---
fprintf('Creating Figure 2b: RT Distributions...\n');
fig2b = figure('Position', [100, 100, 1600, 500], 'Color', 'w');

% Prepare scatter plot data
allYValues = [];
allXJittered = [];
allColors = [];

for g = 1:nGroups
    for b = 1:barsPerGroup
        idx = (g-1)*barsPerGroup + b;
        if ~isempty(allRTData{g, b})
            yVals = allRTData{g, b}(:);
            xVal = xPositions(idx);
            xJittered = xVal + (rand(size(yVals)) - 0.5) * jitterAmount;
            allYValues = [allYValues; yVals];
            allXJittered = [allXJittered; xJittered(:)];
            % Assign colors based on bar index
            if b == 1
                allColors = [allColors; repmat([0.5, 0.5, 0.5], length(yVals), 1)];  % Gray (Baseline)
            elseif b == 2
                allColors = [allColors; repmat([0.2, 0.6, 0.8], length(yVals), 1)];  % Blue (AggR-cue)
            elseif b == 3
                allColors = [allColors; repmat([0.8, 0.2, 0.2], length(yVals), 1)];  % Red (AggNR-cue)
            elseif b == 4
                allColors = [allColors; repmat([0.2, 0.4, 0.8], length(yVals), 1)];  % Darker blue (RS_Time_R)
            elseif b == 5
                allColors = [allColors; repmat([0.4, 0.6, 0.9], length(yVals), 1)];  % Lighter blue (RS_Time_NR)
            elseif b == 6
                allColors = [allColors; repmat([0.8, 0.2, 0.2], length(yVals), 1)];  % Darker red (RS_SpaceTime_R)
            elseif b == 7
                allColors = [allColors; repmat([0.9, 0.4, 0.4], length(yVals), 1)];  % Lighter red (RS_SpaceTime_NR)
            elseif b == 8
                allColors = [allColors; repmat([0.2, 0.8, 0.4], length(yVals), 1)];  % Darker green (RG_Space_R)
            else
                allColors = [allColors; repmat([0.4, 0.9, 0.6], length(yVals), 1)];  % Lighter green (RG_Space_NR)
            end
        end
    end
end

% Plot semi-transparent scatter
scatter(allXJittered, allYValues, 30, allColors, 'filled', 'MarkerFaceAlpha', 0.4, 'MarkerEdgeAlpha', 0.2);

% Add box plots at each x position
hold on;
for g = 1:nGroups
    for b = 1:barsPerGroup
        idx = (g-1)*barsPerGroup + b;
        if ~isempty(allRTData{g, b})
            xPos = xPositions(idx);
            data = allRTData{g, b};
            
            % Draw box plot elements
            q25 = prctile(data, 25);
            q50 = prctile(data, 50);
            q75 = prctile(data, 75);
            iqr = q75 - q25;
            whiskerLow = max(min(data), q25 - 1.5*iqr);
            whiskerHigh = min(max(data), q75 + 1.5*iqr);
            
            % Box
            boxWidth = 0.25;  % Narrower box width for more bars
            rectangle('Position', [xPos - boxWidth/2, q25, boxWidth, q75 - q25], ...
                     'FaceColor', 'none', 'EdgeColor', 'k', 'LineWidth', 1.5);
            % Median line
            plot([xPos - boxWidth/2, xPos + boxWidth/2], [q50, q50], 'k-', 'LineWidth', 2);
            % Whiskers
            plot([xPos, xPos], [whiskerLow, q25], 'k-', 'LineWidth', 1);
            plot([xPos, xPos], [q75, whiskerHigh], 'k-', 'LineWidth', 1);
            plot([xPos - boxWidth/4, xPos + boxWidth/4], [whiskerLow, whiskerLow], 'k-', 'LineWidth', 1);
            plot([xPos - boxWidth/4, xPos + boxWidth/4], [whiskerHigh, whiskerHigh], 'k-', 'LineWidth', 1);
        end
    end
end
hold off;

% Adjust axes position to make room for group labels at bottom
ax = gca;
axPos = ax.Position;
ax.Position = [axPos(1), axPos(2) + 0.08, axPos(3), axPos(4) - 0.08];  % Make room at bottom

% Set x-axis labels
set(gca, 'XTick', xPositions);
set(gca, 'XTickLabel', xLabels);
set(gca, 'XTickLabelRotation', 45);
ylabel('Response Time (s)');
yMax = max(allYValues) * 1.1;
ylim([0, yMax]);
grid on;

% Add vertical lines to separate groups
hold on;
for g = 1:(nGroups-1)
    xSep = (max(xPositions((g-1)*barsPerGroup + (1:barsPerGroup))) + ...
            min(xPositions(g*barsPerGroup + (1:barsPerGroup)))) / 2;
    plot([xSep, xSep], [0, yMax], 'k--', 'LineWidth', 0.5);
end
hold off;

% Add group labels below condition labels using normalized axes coordinates
for g = 1:nGroups
    groupXCenter = mean(xPositions((g-1)*barsPerGroup + (1:barsPerGroup)));
    % Convert data coordinates to normalized axes coordinates
    xNorm = (groupXCenter - ax.XLim(1)) / (ax.XLim(2) - ax.XLim(1));
    yNorm = -0.15;  % Position below x-axis in normalized coordinates
    text(ax, xNorm, yNorm, xGroups{g}, 'Units', 'normalized', ...
         'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
end

sgtitle('Figure 2b: Response Time Distributions (Individual Trials)', 'FontSize', 14, 'FontWeight', 'bold');

% Save figure
saveas(fig2b, fullfile(dataDir, 'Figure2b_RT_Distributions.png'));
fprintf('Saved: Figure2b_RT_Distributions.png\n\n');

fprintf('=== Plotting Complete ===\n');
