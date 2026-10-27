% Plot summary statistics for HomoInte pilot data
% Figure 1a: Precision (circular SD of absolute errors)
% Figure 1b: RT (median + CI)

clear; close all; clc;

fprintf('=== Loading HomoInte Data ===\n\n');

% Data directory (script runs from within the data folder)
dataDir = '.';

% Participants to include (leave empty to include all)
participantsToInclude = {'YDL', 'AQ'};

% Find all session files
files = dir(fullfile(dataDir, 'HomoInte_*.mat'));
if isempty(files)
    error('No HomoInte data files found in %s', dataDir);
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
    participantMatch = regexp(files(i).name, 'HomoInte_([^_]+)_sess', 'tokens', 'once');
    if isempty(participantMatch)
        warning('Skipping file with unrecognized participant: %s', files(i).name);
        continue;
    end
    participantId = participantMatch{1};
    if ~isempty(participantsToInclude) && ~ismember(participantId, participantsToInclude)
        continue;
    end
    fprintf('Loading %s session %d...\n', participantId, sessionNumbers(sortIdx(i)));
    
    data = load(filepath, 'expTrials');
    if ~isfield(data, 'expTrials')
        warning('Session %d: No expTrials found, skipping', sessionNumbers(sortIdx(i)));
        continue;
    end
    
    trials = data.expTrials;
    if istable(trials)
        trials.Session = repmat(sessionNumbers(sortIdx(i)), height(trials), 1);
        trials.Participant = repmat({participantId}, height(trials), 1);
    end
    
    if isempty(allTrials)
        allTrials = trials;
    else
        % Align table variables before concatenation
        allVarNames = union(allTrials.Properties.VariableNames, trials.Properties.VariableNames);
        for v = 1:numel(allVarNames)
            varName = allVarNames{v};
            if ~ismember(varName, allTrials.Properties.VariableNames)
                allTrials.(varName) = makeMissingColumn(trials.(varName), height(allTrials));
            end
            if ~ismember(varName, trials.Properties.VariableNames)
                trials.(varName) = makeMissingColumn(allTrials.(varName), height(trials));
            end
        end
        % Ensure same variable order
        allTrials = allTrials(:, allVarNames);
        trials = trials(:, allVarNames);
        allTrials = [allTrials; trials];
    end
end

% Filter out invalid trials (missing precision or RT)
validIdx = ~isnan(allTrials.Precision) & ~isnan(allTrials.ResponseTime) & ...
           allTrials.ResponseTime > 0;
allTrials = allTrials(validIdx, :);

% Split by participant
allTrialsAll = allTrials;
participants = unique(allTrialsAll.Participant, 'stable');

% Prepare data for plotting
% Group by: NoiseLevel × ItemN × Condition
noiseLevels = {'low', 'high'};
itemNs = [2, 6];
conditions = {'Baseline', 'Homo_Space', 'Homo_Time', 'Homo_SpaceTime'};

% Compute global axis limits from all participants combined
resultsGlobal = buildResults(allTrialsAll, noiseLevels, itemNs, conditions);
globalPrecisionYMax = computeGlobalPrecisionYMax(resultsGlobal, noiseLevels, itemNs, conditions);
globalRTYMaxValue = computeGlobalRTYMax(resultsGlobal, noiseLevels, itemNs, conditions);
globalPrecisionDistYMax = max(abs(allTrialsAll.Precision)) * 1.1;
globalRTDistYMax = max(allTrialsAll.ResponseTime) * 1.1;

for p = 1:length(participants)
    participantId = participants{p};
    fprintf('\n=== Participant: %s ===\n', participantId);
    allTrials = allTrialsAll(strcmp(allTrialsAll.Participant, participantId), :);
    fprintf('Total trials loaded: %d\n', height(allTrials));
    fprintf('Valid trials: %d\n\n', height(allTrials));

% Calculate circular standard deviation of absolute errors
% Precision is already signed error, so we take absolute value
absErrors = abs(allTrials.Precision);

% Circular SD formula: sqrt(-2 * log(R))
% where R is the mean resultant length of unit vectors
% For absolute errors, we convert to radians and compute circular stats
absErrorsRad = deg2rad(absErrors);
R = sqrt(mean(cos(absErrorsRad)).^2 + mean(sin(absErrorsRad)).^2);
circSD = rad2deg(sqrt(-2 * log(R)));

% But actually, for absolute errors (which are already 0-180 range),
% we might want to use regular SD or circular SD appropriately
% Let's compute both and use circular SD for now

results = buildResults(allTrials, noiseLevels, itemNs, conditions);

% Create figure 1a: Precision
fprintf('Creating Figure 1a: Precision...\n');
fig1a = figure('Position', [100, 100, 1400, 500], 'Color', 'w');

% Order: Low N=2, High N=2, Low N=6, High N=6
xGroups = {'Low N=2', 'High N=2', 'Low N=6', 'High N=6'};
nGroups = length(xGroups);
barsPerGroup = 5;  % Baseline, HomoR, Space, Time, SpaceTime
totalBars = nGroups * barsPerGroup;

globalYMax = globalPrecisionYMax;

% Prepare data for all bars
allBarData = [];
allBarCI_lower = [];
allBarCI_upper = [];
xPositions = [];
xLabels = {};

% Calculate x positions with spacing between groups
barSpacing = 0.8;  % Spacing within a group
groupSpacing = 2.0;  % Spacing between groups
xStart = 1;

for g = 1:nGroups
    % Parse group
    if contains(xGroups{g}, 'Low')
        noise = 'low';
    else
        noise = 'high';
    end
    if contains(xGroups{g}, 'N=2')
        itemN = 2;
    else
        itemN = 6;
    end
    
    % Get Baseline data
    baselineKey = sprintf('N%d_%s_Baseline', itemN, noise);
    homoRKeys = {sprintf('N%d_%s_Homo_Space', itemN, noise), ...
                  sprintf('N%d_%s_Homo_Time', itemN, noise), ...
                  sprintf('N%d_%s_Homo_SpaceTime', itemN, noise)};
    
    % Compute Baseline stats
    if isfield(results.precision_data, baselineKey)
        baselineData = results.precision_data.(baselineKey);
        baselineMean = computeCircSD(baselineData);
        baselineCI = bootci(1000, @computeCircSD, baselineData);
    else
        baselineMean = NaN;
        baselineCI = [NaN, NaN];
    end
    
    % Compute HomoR aggregated stats
    homoRData = [];
    for k = 1:length(homoRKeys)
        if isfield(results.precision_data, homoRKeys{k})
            homoRData = [homoRData; results.precision_data.(homoRKeys{k})];
        end
    end
    if ~isempty(homoRData)
        homoRMean = computeCircSD(homoRData);
        homoRCI = bootci(1000, @computeCircSD, homoRData);
    else
        homoRMean = NaN;
        homoRCI = [NaN, NaN];
    end
    
    % Get data for each HomoR condition
    homoMeans = [];
    homoCIs = [];
    for k = 1:length(homoRKeys)
        if isfield(results.precision_data, homoRKeys{k})
            data = results.precision_data.(homoRKeys{k});
            homoMeans(k) = computeCircSD(data);
            ci = bootci(1000, @computeCircSD, data);
            homoCIs(:, k) = [ci(2) - homoMeans(k); homoMeans(k) - ci(1)];
        else
            homoMeans(k) = NaN;
            homoCIs(:, k) = [NaN; NaN];
        end
    end
    
    % Combine all bars for this group
    groupBarData = [baselineMean, homoRMean, homoMeans];
    % Error bars: 95% bootstrap CI (1000 bootstrap samples)
    % Asymmetry is expected if the underlying distribution is skewed
    % CI format: [lower_bound, upper_bound]
    groupBarCI_lower = [baselineMean - baselineCI(1), homoRMean - homoRCI(1), homoCIs(1,:)];
    groupBarCI_upper = [baselineCI(2) - baselineMean, homoRCI(2) - homoRMean, homoCIs(2,:)];
    
    % Calculate x positions for this group
    groupXPos = xStart + (0:(barsPerGroup-1)) * barSpacing;
    
    % Store data
    allBarData = [allBarData, groupBarData];
    allBarCI_lower = [allBarCI_lower, groupBarCI_lower];
    allBarCI_upper = [allBarCI_upper, groupBarCI_upper];
    xPositions = [xPositions, groupXPos];
    
    % Store labels
    xLabels = [xLabels, {'Baseline', 'HomoR', 'Space', 'Time', 'Space+Time'}];
    
    % Update xStart for next group
    xStart = max(groupXPos) + groupSpacing;
end

% Plot all bars in single figure
b = bar(xPositions, allBarData, 0.6, 'FaceColor', 'flat');  % 0.6 = bar width

% Set colors for each bar
barColors = repmat([0.5, 0.5, 0.5; 0.2, 0.6, 0.8; 0.2, 0.4, 0.8; 0.8, 0.2, 0.2; 0.2, 0.8, 0.4], nGroups, 1);
b.CData = barColors;

hold on;
% Error bars: 95% bootstrap CI (asymmetric if distribution is skewed)
errorbar(xPositions, allBarData, allBarCI_upper, allBarCI_lower, 'k', 'LineWidth', 1.2, 'CapSize', 6, 'LineStyle', 'none');
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

sgtitle(sprintf('Figure 1a: Precision (Circular SD of Absolute Errors) - %s', participantId), 'FontSize', 14, 'FontWeight', 'bold');

% Save figure
saveas(fig1a, fullfile(dataDir, sprintf('Figure1a_Precision_%s.png', participantId)));
fprintf('Saved: Figure1a_Precision_%s.png\n\n', participantId);

% Create figure 1b: RT
fprintf('Creating Figure 1b: RT...\n');
fig1b = figure('Position', [100, 100, 1400, 500], 'Color', 'w');

% Order: Low N=2, High N=2, Low N=6, High N=6
xGroups = {'Low N=2', 'High N=2', 'Low N=6', 'High N=6'};
nGroups = length(xGroups);
barsPerGroup = 5;  % Baseline, HomoR, Space, Time, SpaceTime
totalBars = nGroups * barsPerGroup;

globalRTYMax = globalRTYMaxValue;

% Prepare data for all bars
allBarData = [];
allBarCI_lower = [];
allBarCI_upper = [];
xPositions = [];
xLabels = {};

% Calculate x positions with spacing between groups
barSpacing = 0.8;  % Spacing within a group
groupSpacing = 2.0;  % Spacing between groups
xStart = 1;

for g = 1:nGroups
    % Parse group
    if contains(xGroups{g}, 'Low')
        noise = 'low';
    else
        noise = 'high';
    end
    if contains(xGroups{g}, 'N=2')
        itemN = 2;
    else
        itemN = 6;
    end
    
    baselineKey = sprintf('N%d_%s_Baseline', itemN, noise);
    homoRKeys = {sprintf('N%d_%s_Homo_Space', itemN, noise), ...
                  sprintf('N%d_%s_Homo_Time', itemN, noise), ...
                  sprintf('N%d_%s_Homo_SpaceTime', itemN, noise)};
    
    % Compute Baseline stats (median + CI)
    if isfield(results.rt_data, baselineKey)
        baselineData = results.rt_data.(baselineKey);
        baselineMedian = median(baselineData);
        baselineCI = bootci(1000, @median, baselineData);
    else
        baselineMedian = NaN;
        baselineCI = [NaN, NaN];
    end
    
    % Compute HomoR aggregated stats
    homoRData = [];
    for k = 1:length(homoRKeys)
        if isfield(results.rt_data, homoRKeys{k})
            homoRData = [homoRData; results.rt_data.(homoRKeys{k})];
        end
    end
    if ~isempty(homoRData)
        homoRMedian = median(homoRData);
        homoRCI = bootci(1000, @median, homoRData);
    else
        homoRMedian = NaN;
        homoRCI = [NaN, NaN];
    end
    
    % Get data for each HomoR condition
    homoMedians = [];
    homoCIs = [];
    for k = 1:length(homoRKeys)
        if isfield(results.rt_data, homoRKeys{k})
            data = results.rt_data.(homoRKeys{k});
            homoMedians(k) = median(data);
            ci = bootci(1000, @median, data);
            homoCIs(:, k) = [ci(2) - homoMedians(k); homoMedians(k) - ci(1)];
        else
            homoMedians(k) = NaN;
            homoCIs(:, k) = [NaN; NaN];
        end
    end
    
    % Combine all bars for this group
    groupBarData = [baselineMedian, homoRMedian, homoMedians];
    groupBarCI_lower = [baselineMedian - baselineCI(1), homoRMedian - homoRCI(1), homoCIs(1,:)];
    groupBarCI_upper = [baselineCI(2) - baselineMedian, homoRCI(2) - homoRMedian, homoCIs(2,:)];
    
    % Calculate x positions for this group
    groupXPos = xStart + (0:(barsPerGroup-1)) * barSpacing;
    
    % Store data
    allBarData = [allBarData, groupBarData];
    allBarCI_lower = [allBarCI_lower, groupBarCI_lower];
    allBarCI_upper = [allBarCI_upper, groupBarCI_upper];
    xPositions = [xPositions, groupXPos];
    
    % Store labels
    xLabels = [xLabels, {'Baseline', 'HomoR', 'Space', 'Time', 'Space+Time'}];
    
    % Update xStart for next group
    xStart = max(groupXPos) + groupSpacing;
end

% Plot all bars in single figure
b = bar(xPositions, allBarData, 0.6, 'FaceColor', 'flat');  % 0.6 = bar width

% Set colors for each bar
barColors = repmat([0.5, 0.5, 0.5; 0.2, 0.6, 0.8; 0.2, 0.4, 0.8; 0.8, 0.2, 0.2; 0.2, 0.8, 0.4], nGroups, 1);
b.CData = barColors;

hold on;
errorbar(xPositions, allBarData, allBarCI_upper, allBarCI_lower, 'k', 'LineWidth', 1.2, 'CapSize', 6, 'LineStyle', 'none');
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

sgtitle(sprintf('Figure 1b: Response Time (Median + CI) - %s', participantId), 'FontSize', 14, 'FontWeight', 'bold');

% Save figure
saveas(fig1b, fullfile(dataDir, sprintf('Figure1b_RT_%s.png', participantId)));
fprintf('Saved: Figure1b_RT_%s.png\n\n', participantId);

% ============================================================================
% Figure 2a/2b: Distribution plots (scatter plots with semi-transparent points)
% ============================================================================

% Create figure 2a: Precision distributions
fprintf('Creating Figure 2a: Precision Distributions...\n');
fig2a = figure('Position', [100, 100, 1400, 500], 'Color', 'w');

% Order: Low N=2, High N=2, Low N=6, High N=6
xGroups = {'Low N=2', 'High N=2', 'Low N=6', 'High N=6'};
nGroups = length(xGroups);
barsPerGroup = 5;  % Baseline, HomoR, Space, Time, SpaceTime

% Calculate x positions with spacing between groups
barSpacing = 0.8;
groupSpacing = 2.0;
xStart = 1;
xPositions = [];
xLabels = {};

% Prepare all data for plotting
allPrecisionData = cell(nGroups * barsPerGroup, 1);
allXPositions = [];
allColors = [];
xPositions = [];
xLabels = {};

xStart = 1;
for g = 1:nGroups
    % Parse group
    if contains(xGroups{g}, 'Low')
        noise = 'low';
    else
        noise = 'high';
    end
    if contains(xGroups{g}, 'N=2')
        itemN = 2;
    else
        itemN = 6;
    end
    
    baselineKey = sprintf('N%d_%s_Baseline', itemN, noise);
    homoRKeys = {sprintf('N%d_%s_Homo_Space', itemN, noise), ...
                  sprintf('N%d_%s_Homo_Time', itemN, noise), ...
                  sprintf('N%d_%s_Homo_SpaceTime', itemN, noise)};
    
    % Calculate x positions for this group
    groupXPos = xStart + (0:(barsPerGroup-1)) * barSpacing;
    xPositions = [xPositions, groupXPos];
    
    % Get Baseline data
    if isfield(results.precision_data, baselineKey)
        baselineData = abs(results.precision_data.(baselineKey));
        allPrecisionData{(g-1)*barsPerGroup + 1} = baselineData;
        allXPositions = [allXPositions, repmat(groupXPos(1), 1, length(baselineData))];
        allColors = [allColors; repmat([0.5, 0.5, 0.5], length(baselineData), 1)];  % Gray
    end
    
    % Get HomoR aggregated data
    homoRData = [];
    for k = 1:length(homoRKeys)
        if isfield(results.precision_data, homoRKeys{k})
            homoRData = [homoRData; abs(results.precision_data.(homoRKeys{k}))];
        end
    end
    if ~isempty(homoRData)
        allPrecisionData{(g-1)*barsPerGroup + 2} = homoRData;
        allXPositions = [allXPositions, repmat(groupXPos(2), 1, length(homoRData))];
        allColors = [allColors; repmat([0.2, 0.6, 0.8], length(homoRData), 1)];  % Blue
    end
    
    % Get individual HomoR condition data
    for k = 1:length(homoRKeys)
        if isfield(results.precision_data, homoRKeys{k})
            data = abs(results.precision_data.(homoRKeys{k}));
            allPrecisionData{(g-1)*barsPerGroup + 2 + k} = data;
            allXPositions = [allXPositions, repmat(groupXPos(2 + k), 1, length(data))];
            if k == 1
                allColors = [allColors; repmat([0.2, 0.4, 0.8], length(data), 1)];  % Darker blue (Space)
            elseif k == 2
                allColors = [allColors; repmat([0.8, 0.2, 0.2], length(data), 1)];  % Red (Time)
            else
                allColors = [allColors; repmat([0.2, 0.8, 0.4], length(data), 1)];  % Green (SpaceTime)
            end
        end
    end
    
    % Store labels
    xLabels = [xLabels, {'Baseline', 'HomoR', 'Space', 'Time', 'Space+Time'}];
    
    % Update xStart for next group
    xStart = max(groupXPos) + groupSpacing;
end

% Plot scatter with jitter
jitterAmount = 0.15;  % Amount of jitter
allYValues = [];
allXJittered = [];

for i = 1:length(allPrecisionData)
    if ~isempty(allPrecisionData{i})
        yVals = allPrecisionData{i}(:);  % Ensure column vector
        xVal = xPositions(i);
        xJittered = xVal + (rand(size(yVals)) - 0.5) * jitterAmount;
        allYValues = [allYValues; yVals];  % Vertical concatenation
        allXJittered = [allXJittered; xJittered(:)];  % Vertical concatenation
    end
end

% Plot semi-transparent scatter
scatter(allXJittered, allYValues, 30, allColors, 'filled', 'MarkerFaceAlpha', 0.4, 'MarkerEdgeAlpha', 0.2);

% Add box plots or summary lines at each x position
hold on;
for g = 1:nGroups
    for b = 1:barsPerGroup
        idx = (g-1)*barsPerGroup + b;
        if ~isempty(allPrecisionData{idx})
            xPos = xPositions(idx);
            data = allPrecisionData{idx};
            
            % Draw box plot elements
            q25 = prctile(data, 25);
            q50 = prctile(data, 50);
            q75 = prctile(data, 75);
            iqr = q75 - q25;
            whiskerLow = max(min(data), q25 - 1.5*iqr);
            whiskerHigh = min(max(data), q75 + 1.5*iqr);
            
            % Box
            boxWidth = 0.3;
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
yMax = globalPrecisionDistYMax;
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

sgtitle(sprintf('Figure 2a: Precision Distributions (Individual Trials) - %s', participantId), 'FontSize', 14, 'FontWeight', 'bold');

% Save figure
saveas(fig2a, fullfile(dataDir, sprintf('Figure2a_Precision_Distributions_%s.png', participantId)));
fprintf('Saved: Figure2a_Precision_Distributions_%s.png\n\n', participantId);

% Create figure 2b: RT distributions
fprintf('Creating Figure 2b: RT Distributions...\n');
fig2b = figure('Position', [100, 100, 1400, 500], 'Color', 'w');

% Prepare all RT data for plotting
allRTData = cell(nGroups * barsPerGroup, 1);
allXPositions = [];
allColors = [];

xStart = 1;
xPositions = [];
xLabels = {};

for g = 1:nGroups
    % Parse group
    if contains(xGroups{g}, 'Low')
        noise = 'low';
    else
        noise = 'high';
    end
    if contains(xGroups{g}, 'N=2')
        itemN = 2;
    else
        itemN = 6;
    end
    
    baselineKey = sprintf('N%d_%s_Baseline', itemN, noise);
    homoRKeys = {sprintf('N%d_%s_Homo_Space', itemN, noise), ...
                  sprintf('N%d_%s_Homo_Time', itemN, noise), ...
                  sprintf('N%d_%s_Homo_SpaceTime', itemN, noise)};
    
    % Calculate x positions for this group
    groupXPos = xStart + (0:(barsPerGroup-1)) * barSpacing;
    xPositions = [xPositions, groupXPos];
    
    % Get Baseline data
    if isfield(results.rt_data, baselineKey)
        baselineData = results.rt_data.(baselineKey);
        allRTData{(g-1)*barsPerGroup + 1} = baselineData;
        allXPositions = [allXPositions, repmat(groupXPos(1), 1, length(baselineData))];
        allColors = [allColors; repmat([0.5, 0.5, 0.5], length(baselineData), 1)];  % Gray
    end
    
    % Get HomoR aggregated data
    homoRData = [];
    for k = 1:length(homoRKeys)
        if isfield(results.rt_data, homoRKeys{k})
            homoRData = [homoRData; results.rt_data.(homoRKeys{k})];
        end
    end
    if ~isempty(homoRData)
        allRTData{(g-1)*barsPerGroup + 2} = homoRData;
        allXPositions = [allXPositions, repmat(groupXPos(2), 1, length(homoRData))];
        allColors = [allColors; repmat([0.2, 0.6, 0.8], length(homoRData), 1)];  % Blue
    end
    
    % Get individual HomoR condition data
    for k = 1:length(homoRKeys)
        if isfield(results.rt_data, homoRKeys{k})
            data = results.rt_data.(homoRKeys{k});
            allRTData{(g-1)*barsPerGroup + 2 + k} = data;
            allXPositions = [allXPositions, repmat(groupXPos(2 + k), 1, length(data))];
            if k == 1
                allColors = [allColors; repmat([0.2, 0.4, 0.8], length(data), 1)];  % Darker blue (Space)
            elseif k == 2
                allColors = [allColors; repmat([0.8, 0.2, 0.2], length(data), 1)];  % Red (Time)
            else
                allColors = [allColors; repmat([0.2, 0.8, 0.4], length(data), 1)];  % Green (SpaceTime)
            end
        end
    end
    
    % Store labels
    xLabels = [xLabels, {'Baseline', 'HomoR', 'Space', 'Time', 'Space+Time'}];
    
    % Update xStart for next group
    xStart = max(groupXPos) + groupSpacing;
end

% Plot scatter with jitter
allYValues = [];
allXJittered = [];

for i = 1:length(allRTData)
    if ~isempty(allRTData{i})
        yVals = allRTData{i}(:);  % Ensure column vector
        xVal = xPositions(i);
        xJittered = xVal + (rand(size(yVals)) - 0.5) * jitterAmount;
        allYValues = [allYValues; yVals];  % Vertical concatenation
        allXJittered = [allXJittered; xJittered(:)];  % Vertical concatenation
    end
end

% Plot semi-transparent scatter
scatter(allXJittered, allYValues, 30, allColors, 'filled', 'MarkerFaceAlpha', 0.4, 'MarkerEdgeAlpha', 0.2);

% Add box plots at each x position
hold on;
for g = 1:nGroups
    for b = 1:barsPerGroup
        idx = (g-1)*barsPerGroup + b;
        if ~isempty(allRTData{idx})
            xPos = xPositions(idx);
            data = allRTData{idx};
            
            % Draw box plot elements
            q25 = prctile(data, 25);
            q50 = prctile(data, 50);
            q75 = prctile(data, 75);
            iqr = q75 - q25;
            whiskerLow = max(min(data), q25 - 1.5*iqr);
            whiskerHigh = min(max(data), q75 + 1.5*iqr);
            
            % Box
            boxWidth = 0.3;
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
yMax = globalRTDistYMax;
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

sgtitle(sprintf('Figure 2b: Response Time Distributions (Individual Trials) - %s', participantId), 'FontSize', 14, 'FontWeight', 'bold');

% Save figure
saveas(fig2b, fullfile(dataDir, sprintf('Figure2b_RT_Distributions_%s.png', participantId)));
fprintf('Saved: Figure2b_RT_Distributions_%s.png\n\n', participantId);

fprintf('=== Plotting Complete (%s) ===\n', participantId);
end

fprintf('=== Plotting Complete (All Participants) ===\n');

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

function col = makeMissingColumn(templateColumn, nRows)
    if isnumeric(templateColumn)
        col = nan(nRows, 1);
    elseif islogical(templateColumn)
        col = false(nRows, 1);
    elseif isstring(templateColumn)
        col = strings(nRows, 1);
    elseif iscategorical(templateColumn)
        col = categorical(repmat(missing, nRows, 1));
    elseif iscell(templateColumn)
        col = cell(nRows, 1);
    else
        col = repmat(missing, nRows, 1);
    end
end

function results = buildResults(allTrials, noiseLevels, itemNs, conditions)
    results = struct();
    results.precision = struct();
    results.rt = struct();
    for n = 1:length(noiseLevels)
        noise = noiseLevels{n};
        for i = 1:length(itemNs)
            itemN = itemNs(i);
            for c = 1:length(conditions)
                cond = conditions{c};
                idx = strcmp(allTrials.NoiseLevel, noise) & ...
                      allTrials.ItemN == itemN & ...
                      strcmp(allTrials.Condition, cond);
                if sum(idx) > 0
                    absErrs = abs(allTrials.Precision(idx));
                    results.precision.(sprintf('N%d_%s_%s', itemN, noise, cond)) = computeCircSD(absErrs);
                    rts = allTrials.ResponseTime(idx);
                    results.rt.(sprintf('N%d_%s_%s', itemN, noise, cond)) = median(rts);
                    results.precision_data.(sprintf('N%d_%s_%s', itemN, noise, cond)) = absErrs;
                    results.rt_data.(sprintf('N%d_%s_%s', itemN, noise, cond)) = rts;
                end
            end
        end
    end
end

function globalYMax = computeGlobalPrecisionYMax(results, noiseLevels, itemNs, conditions)
    allPrecisionMeans = [];
    allPrecisionCIs = [];
    xGroups = {'Low N=2', 'High N=2', 'Low N=6', 'High N=6'};
    nGroups = length(xGroups);
    for g = 1:nGroups
        if contains(xGroups{g}, 'Low')
            noise = 'low';
        else
            noise = 'high';
        end
        if contains(xGroups{g}, 'N=2')
            itemN = 2;
        else
            itemN = 6;
        end
        baselineKey = sprintf('N%d_%s_Baseline', itemN, noise);
        homoRKeys = {sprintf('N%d_%s_Homo_Space', itemN, noise), ...
                      sprintf('N%d_%s_Homo_Time', itemN, noise), ...
                      sprintf('N%d_%s_Homo_SpaceTime', itemN, noise)};
        if isfield(results.precision_data, baselineKey)
            baselineData = results.precision_data.(baselineKey);
            baselineMean = computeCircSD(baselineData);
            baselineCI = bootci(1000, @computeCircSD, baselineData);
            allPrecisionMeans = [allPrecisionMeans, baselineMean];
            allPrecisionCIs = [allPrecisionCIs, baselineCI(2)];
        end
        homoRData = [];
        for k = 1:length(homoRKeys)
            if isfield(results.precision_data, homoRKeys{k})
                homoRData = [homoRData; results.precision_data.(homoRKeys{k})];
            end
        end
        if ~isempty(homoRData)
            homoRMean = computeCircSD(homoRData);
            homoRCI = bootci(1000, @computeCircSD, homoRData);
            allPrecisionMeans = [allPrecisionMeans, homoRMean];
            allPrecisionCIs = [allPrecisionCIs, homoRCI(2)];
        end
        for k = 1:length(homoRKeys)
            if isfield(results.precision_data, homoRKeys{k})
                data = results.precision_data.(homoRKeys{k});
                homoMean = computeCircSD(data);
                ci = bootci(1000, @computeCircSD, data);
                allPrecisionMeans = [allPrecisionMeans, homoMean];
                allPrecisionCIs = [allPrecisionCIs, ci(2)];
            end
        end
    end
    globalYMax = max(allPrecisionMeans + allPrecisionCIs) * 1.15;
end

function globalYMax = computeGlobalRTYMax(results, noiseLevels, itemNs, conditions)
    allRTMedians = [];
    allRTCIs = [];
    xGroups = {'Low N=2', 'High N=2', 'Low N=6', 'High N=6'};
    nGroups = length(xGroups);
    for g = 1:nGroups
        if contains(xGroups{g}, 'Low')
            noise = 'low';
        else
            noise = 'high';
        end
        if contains(xGroups{g}, 'N=2')
            itemN = 2;
        else
            itemN = 6;
        end
        baselineKey = sprintf('N%d_%s_Baseline', itemN, noise);
        homoRKeys = {sprintf('N%d_%s_Homo_Space', itemN, noise), ...
                      sprintf('N%d_%s_Homo_Time', itemN, noise), ...
                      sprintf('N%d_%s_Homo_SpaceTime', itemN, noise)};
        if isfield(results.rt_data, baselineKey)
            baselineData = results.rt_data.(baselineKey);
            baselineMedian = median(baselineData);
            baselineCI = bootci(1000, @median, baselineData);
            allRTMedians = [allRTMedians, baselineMedian];
            allRTCIs = [allRTCIs, baselineCI(2)];
        end
        homoRData = [];
        for k = 1:length(homoRKeys)
            if isfield(results.rt_data, homoRKeys{k})
                homoRData = [homoRData; results.rt_data.(homoRKeys{k})];
            end
        end
        if ~isempty(homoRData)
            homoRMedian = median(homoRData);
            homoRCI = bootci(1000, @median, homoRData);
            allRTMedians = [allRTMedians, homoRMedian];
            allRTCIs = [allRTCIs, homoRCI(2)];
        end
        for k = 1:length(homoRKeys)
            if isfield(results.rt_data, homoRKeys{k})
                data = results.rt_data.(homoRKeys{k});
                homoMedian = median(data);
                ci = bootci(1000, @median, data);
                allRTMedians = [allRTMedians, homoMedian];
                allRTCIs = [allRTCIs, ci(2)];
            end
        end
    end
    globalYMax = max(allRTMedians + allRTCIs) * 1.15;
end

