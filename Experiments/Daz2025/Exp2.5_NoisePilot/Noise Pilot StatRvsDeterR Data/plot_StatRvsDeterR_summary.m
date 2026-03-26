% Plot summary statistics for HomoInte pilot data
% Figure 1a: Precision (circular SD of absolute errors)
% Figure 1b: RT (median + CI)

clear; close all; clc;

fprintf('=== Loading HomoInte Data ===\n\n');

% Data directory (script runs from within the data folder)
dataDir = '.';

% Participants to include (leave empty to include all)
participantsToInclude = {};  % Include all participants

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

% Separate by method (yS = statistical, yD = deterministic, ySS = new statistical)
ySTrials = allTrials(strcmp(allTrials.Participant, 'yS'), :);
yDTrials = allTrials(strcmp(allTrials.Participant, 'yD'), :);
ySSTrials = allTrials(strcmp(allTrials.Participant, 'ySS'), :);

fprintf('\n=== Data Summary ===\n');
fprintf('yS (statistical) trials: %d\n', height(ySTrials));
fprintf('yD (deterministic) trials: %d\n', height(yDTrials));
fprintf('ySS (new statistical) trials: %d\n', height(ySSTrials));
fprintf('Total trials: %d\n\n', height(allTrials));

% Use all data for global limits
allTrialsAll = allTrials;

% Prepare data for plotting
% Group by: NoiseLevel × ItemN × Condition
noiseLevels = {'low', 'high'};
itemNs = [2, 6];
conditions = {'Baseline', 'Homo_Space'};  % Only Baseline and Space for this pilot

% Compute global axis limits from all data combined
resultsGlobal = buildResults(allTrialsAll, noiseLevels, itemNs, conditions);
globalPrecisionYMax = computeGlobalPrecisionYMax(resultsGlobal, noiseLevels, itemNs, conditions);
globalRTYMaxValue = computeGlobalRTYMax(resultsGlobal, noiseLevels, itemNs, conditions);
% Calculate global max from all precision columns (original, TargetHue_Response, BaseHue_Response)
allPrecisionValues = [abs(allTrialsAll.Precision)];
if ismember('TargetHue_Response', allTrialsAll.Properties.VariableNames)
    allPrecisionValues = [allPrecisionValues; abs(allTrialsAll.TargetHue_Response)];
end
if ismember('BaseHue_Response', allTrialsAll.Properties.VariableNames)
    allPrecisionValues = [allPrecisionValues; abs(allTrialsAll.BaseHue_Response)];
end
globalPrecisionDistYMax = max(allPrecisionValues(~isnan(allPrecisionValues))) * 1.1;
globalRTDistYMax = max(allTrialsAll.ResponseTime) * 1.1;

% Build results for both methods
results_yS = buildResults(ySTrials, noiseLevels, itemNs, conditions);
results_yD = buildResults(yDTrials, noiseLevels, itemNs, conditions);

fprintf('\n=== Creating Plots (Combined yS and yD) ===\n');

% Create figure 1a: Precision
fprintf('Creating Figure 1a: Precision...\n');
fig1a = figure('Position', [100, 100, 1400, 500], 'Color', 'w');

% Order: Low N=2, Low N=6, High N=2, High N=6
xGroups = {'Low N=2', 'Low N=6', 'High N=2', 'High N=6'};
nGroups = length(xGroups);
barsPerGroup = 4;  % yS Baseline, yS Space, yD Baseline, yD Space
totalBars = nGroups * barsPerGroup;

globalYMax = globalPrecisionYMax;

% Prepare data for all bars
allBarData = [];
allBarCI_lower = [];
allBarCI_upper = [];
xPositions = [];
xLabels = {};

% Calculate x positions with spacing between groups
barSpacing = 0.5;  % Spacing within a group (thinner bars)
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
    
    % Get keys for both methods
    baselineKey = sprintf('N%d_%s_Baseline', itemN, noise);
    spaceKey = sprintf('N%d_%s_Homo_Space', itemN, noise);
    
    % Compute yS Baseline stats
    if isfield(results_yS.precision_data, baselineKey)
        baselineData_yS = results_yS.precision_data.(baselineKey);
        baselineMean_yS = computeCircSD(baselineData_yS);
        baselineCI_yS = bootci(1000, @computeCircSD, baselineData_yS);
    else
        baselineMean_yS = NaN;
        baselineCI_yS = [NaN, NaN];
    end
    
    % Compute yS Space stats
    if isfield(results_yS.precision_data, spaceKey)
        spaceData_yS = results_yS.precision_data.(spaceKey);
        spaceMean_yS = computeCircSD(spaceData_yS);
        spaceCI_yS = bootci(1000, @computeCircSD, spaceData_yS);
    else
        spaceMean_yS = NaN;
        spaceCI_yS = [NaN, NaN];
    end
    
    % Compute yD Baseline stats
    if isfield(results_yD.precision_data, baselineKey)
        baselineData_yD = results_yD.precision_data.(baselineKey);
        baselineMean_yD = computeCircSD(baselineData_yD);
        baselineCI_yD = bootci(1000, @computeCircSD, baselineData_yD);
    else
        baselineMean_yD = NaN;
        baselineCI_yD = [NaN, NaN];
    end
    
    % Compute yD Space stats
    if isfield(results_yD.precision_data, spaceKey)
        spaceData_yD = results_yD.precision_data.(spaceKey);
        spaceMean_yD = computeCircSD(spaceData_yD);
        spaceCI_yD = bootci(1000, @computeCircSD, spaceData_yD);
    else
        spaceMean_yD = NaN;
        spaceCI_yD = [NaN, NaN];
    end
    
    % Combine all bars for this group: yS Baseline, yS Space, yD Baseline, yD Space
    groupBarData = [baselineMean_yS, spaceMean_yS, baselineMean_yD, spaceMean_yD];
    % Error bars: 95% bootstrap CI (1000 bootstrap samples)
    groupBarCI_lower = [baselineMean_yS - baselineCI_yS(1), spaceMean_yS - spaceCI_yS(1), ...
                        baselineMean_yD - baselineCI_yD(1), spaceMean_yD - spaceCI_yD(1)];
    groupBarCI_upper = [baselineCI_yS(2) - baselineMean_yS, spaceCI_yS(2) - spaceMean_yS, ...
                        baselineCI_yD(2) - baselineMean_yD, spaceCI_yD(2) - spaceMean_yD];
    
    % Calculate x positions for this group
    groupXPos = xStart + (0:(barsPerGroup-1)) * barSpacing;
    
    % Store data
    allBarData = [allBarData, groupBarData];
    allBarCI_lower = [allBarCI_lower, groupBarCI_lower];
    allBarCI_upper = [allBarCI_upper, groupBarCI_upper];
    xPositions = [xPositions, groupXPos];
    
    % Store labels
    xLabels = [xLabels, {'yS Base', 'yS Space', 'yD Base', 'yD Space'}];
    
    % Update xStart for next group
    xStart = max(groupXPos) + groupSpacing;
end

% Plot all bars in single figure (thinner bars: 0.4 instead of 0.6)
b = bar(xPositions, allBarData, 0.4, 'FaceColor', 'flat');

% Set colors for each bar: yS (lighter), yD (darker)
% yS Baseline: [0.5, 0.5, 0.5], yS Space: [0.2, 0.4, 0.8]
% yD Baseline: [0.3, 0.3, 0.3] (darker gray), yD Space: [0.1, 0.2, 0.6] (darker blue)
barColors = repmat([0.5, 0.5, 0.5; 0.2, 0.4, 0.8; 0.3, 0.3, 0.3; 0.1, 0.2, 0.6], nGroups, 1);
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

sgtitle('Figure 1a: Precision (Circular SD of Absolute Errors) - yS (Statistical) vs yD (Deterministic)', 'FontSize', 14, 'FontWeight', 'bold');

% Save figure
saveas(fig1a, fullfile(dataDir, 'Figure1a_Precision_Combined.png'));
fprintf('Saved: Figure1a_Precision_Combined.png\n\n');

% Create figure 1b: RT
fprintf('Creating Figure 1b: RT...\n');
fig1b = figure('Position', [100, 100, 1400, 500], 'Color', 'w');

% Order: Low N=2, Low N=6, High N=2, High N=6
xGroups = {'Low N=2', 'Low N=6', 'High N=2', 'High N=6'};
nGroups = length(xGroups);
barsPerGroup = 4;  % yS Baseline, yS Space, yD Baseline, yD Space
totalBars = nGroups * barsPerGroup;

globalRTYMax = globalRTYMaxValue;

% Prepare data for all bars
allBarData = [];
allBarCI_lower = [];
allBarCI_upper = [];
xPositions = [];
xLabels = {};

% Calculate x positions with spacing between groups
barSpacing = 0.5;  % Spacing within a group (thinner bars)
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
    spaceKey = sprintf('N%d_%s_Homo_Space', itemN, noise);
    
    % Compute yS Baseline stats (median + CI)
    if isfield(results_yS.rt_data, baselineKey)
        baselineData_yS = results_yS.rt_data.(baselineKey);
        baselineMedian_yS = median(baselineData_yS);
        baselineCI_yS = bootci(1000, @median, baselineData_yS);
    else
        baselineMedian_yS = NaN;
        baselineCI_yS = [NaN, NaN];
    end
    
    % Compute yS Space stats (median + CI)
    if isfield(results_yS.rt_data, spaceKey)
        spaceData_yS = results_yS.rt_data.(spaceKey);
        spaceMedian_yS = median(spaceData_yS);
        spaceCI_yS = bootci(1000, @median, spaceData_yS);
    else
        spaceMedian_yS = NaN;
        spaceCI_yS = [NaN, NaN];
    end
    
    % Compute yD Baseline stats (median + CI)
    if isfield(results_yD.rt_data, baselineKey)
        baselineData_yD = results_yD.rt_data.(baselineKey);
        baselineMedian_yD = median(baselineData_yD);
        baselineCI_yD = bootci(1000, @median, baselineData_yD);
    else
        baselineMedian_yD = NaN;
        baselineCI_yD = [NaN, NaN];
    end
    
    % Compute yD Space stats (median + CI)
    if isfield(results_yD.rt_data, spaceKey)
        spaceData_yD = results_yD.rt_data.(spaceKey);
        spaceMedian_yD = median(spaceData_yD);
        spaceCI_yD = bootci(1000, @median, spaceData_yD);
    else
        spaceMedian_yD = NaN;
        spaceCI_yD = [NaN, NaN];
    end
    
    % Combine all bars for this group: yS Baseline, yS Space, yD Baseline, yD Space
    groupBarData = [baselineMedian_yS, spaceMedian_yS, baselineMedian_yD, spaceMedian_yD];
    groupBarCI_lower = [baselineMedian_yS - baselineCI_yS(1), spaceMedian_yS - spaceCI_yS(1), ...
                        baselineMedian_yD - baselineCI_yD(1), spaceMedian_yD - spaceCI_yD(1)];
    groupBarCI_upper = [baselineCI_yS(2) - baselineMedian_yS, spaceCI_yS(2) - spaceMedian_yS, ...
                        baselineCI_yD(2) - baselineMedian_yD, spaceCI_yD(2) - spaceMedian_yD];
    
    % Calculate x positions for this group
    groupXPos = xStart + (0:(barsPerGroup-1)) * barSpacing;
    
    % Store data
    allBarData = [allBarData, groupBarData];
    allBarCI_lower = [allBarCI_lower, groupBarCI_lower];
    allBarCI_upper = [allBarCI_upper, groupBarCI_upper];
    xPositions = [xPositions, groupXPos];
    
    % Store labels
    xLabels = [xLabels, {'yS Base', 'yS Space', 'yD Base', 'yD Space'}];
    
    % Update xStart for next group
    xStart = max(groupXPos) + groupSpacing;
end

% Plot all bars in single figure (thinner bars: 0.4 instead of 0.6)
b = bar(xPositions, allBarData, 0.4, 'FaceColor', 'flat');

% Set colors for each bar: yS (lighter), yD (darker)
barColors = repmat([0.5, 0.5, 0.5; 0.2, 0.4, 0.8; 0.3, 0.3, 0.3; 0.1, 0.2, 0.6], nGroups, 1);
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

sgtitle('Figure 1b: Response Time (Median + CI) - yS (Statistical) vs yD (Deterministic)', 'FontSize', 14, 'FontWeight', 'bold');

% Save figure
saveas(fig1b, fullfile(dataDir, 'Figure1b_RT_Combined.png'));
fprintf('Saved: Figure1b_RT_Combined.png\n\n');

% ============================================================================
% Figure 2a: Distribution plots showing both TargetHue and BaseHue response data
% ============================================================================

% Create figure 2a: Precision distributions (TargetHue and BaseHue)
fprintf('Creating Figure 2a: Precision Distributions (TargetHue and BaseHue)...\n');
fig2a = figure('Position', [100, 100, 1400, 500], 'Color', 'w');

% Check if new columns exist
if ~ismember('TargetHue_Response', ySTrials.Properties.VariableNames) || ...
   ~ismember('BaseHue_Response', ySTrials.Properties.VariableNames) || ...
   ~ismember('TargetHue_Response', yDTrials.Properties.VariableNames) || ...
   ~ismember('BaseHue_Response', yDTrials.Properties.VariableNames)
    error('TargetHue_Response or BaseHue_Response columns not found. Please run rename_precision_columns.m first.');
end
% Check ySS columns if ySS data exists
if height(ySSTrials) > 0 && (~ismember('TargetHue_Response', ySSTrials.Properties.VariableNames) || ...
   ~ismember('BaseHue_Response', ySSTrials.Properties.VariableNames))
    error('TargetHue_Response or BaseHue_Response columns not found in ySS data. Please run rename_precision_columns.m first.');
end

% Order: Low N=2, Low N=6, High N=2, High N=6
xGroups = {'Low N=2', 'Low N=6', 'High N=2', 'High N=6'};
nGroups = length(xGroups);
% 10 bars per group: yD Baseline, yD Space, yS TargetHue Baseline, yS BaseHue Baseline, yS TargetHue Space, yS BaseHue Space,
%                    ySS TargetHue Baseline, ySS BaseHue Baseline, ySS TargetHue Space, ySS BaseHue Space
barsPerGroup = 10;

% Calculate x positions with spacing between groups
barSpacing = 0.5;
groupSpacing = 2.5;
xStart = 1;
xPositions = [];
xLabels = {};

% Prepare all data for plotting
allPrecisionData = cell(nGroups * barsPerGroup, 1);
allXPositions = [];
allColors = [];

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
    
    % Calculate x positions for this group
    groupXPos = xStart + (0:(barsPerGroup-1)) * barSpacing;
    xPositions = [xPositions, groupXPos];
    
    % Bar 1: yD Baseline (using TargetHue_Response, same as BaseHue_Response for yD)
    yD_baseline = abs(yDTrials.TargetHue_Response(strcmp(yDTrials.NoiseLevel, noise) & ...
                                                   yDTrials.ItemN == itemN & ...
                                                   strcmp(yDTrials.Condition, 'Baseline')));
    allPrecisionData{(g-1)*barsPerGroup + 1} = yD_baseline;
    allXPositions = [allXPositions, repmat(groupXPos(1), 1, length(yD_baseline))];
    allColors = [allColors; repmat([0.3, 0.3, 0.3], length(yD_baseline), 1)];  % Dark gray
    
    % Bar 2: yD Homo_Space (using TargetHue_Response, same as BaseHue_Response for yD)
    yD_space = abs(yDTrials.TargetHue_Response(strcmp(yDTrials.NoiseLevel, noise) & ...
                                                yDTrials.ItemN == itemN & ...
                                                strcmp(yDTrials.Condition, 'Homo_Space')));
    allPrecisionData{(g-1)*barsPerGroup + 2} = yD_space;
    allXPositions = [allXPositions, repmat(groupXPos(2), 1, length(yD_space))];
    allColors = [allColors; repmat([0.1, 0.2, 0.6], length(yD_space), 1)];  % Dark blue
    
    % Bar 3: yS TargetHue Baseline
    yS_targetHue_baseline = abs(ySTrials.TargetHue_Response(strcmp(ySTrials.NoiseLevel, noise) & ...
                                                             ySTrials.ItemN == itemN & ...
                                                             strcmp(ySTrials.Condition, 'Baseline')));
    allPrecisionData{(g-1)*barsPerGroup + 3} = yS_targetHue_baseline;
    allXPositions = [allXPositions, repmat(groupXPos(3), 1, length(yS_targetHue_baseline))];
    allColors = [allColors; repmat([0.5, 0.5, 0.5], length(yS_targetHue_baseline), 1)];  % Gray
    
    % Bar 4: yS BaseHue Baseline
    yS_baseHue_baseline = abs(ySTrials.BaseHue_Response(strcmp(ySTrials.NoiseLevel, noise) & ...
                                                           ySTrials.ItemN == itemN & ...
                                                           strcmp(ySTrials.Condition, 'Baseline')));
    allPrecisionData{(g-1)*barsPerGroup + 4} = yS_baseHue_baseline;
    allXPositions = [allXPositions, repmat(groupXPos(4), 1, length(yS_baseHue_baseline))];
    allColors = [allColors; repmat([0.7, 0.7, 0.7], length(yS_baseHue_baseline), 1)];  % Light gray
    
    % Bar 5: yS TargetHue Homo_Space
    yS_targetHue_space = abs(ySTrials.TargetHue_Response(strcmp(ySTrials.NoiseLevel, noise) & ...
                                                           ySTrials.ItemN == itemN & ...
                                                           strcmp(ySTrials.Condition, 'Homo_Space')));
    allPrecisionData{(g-1)*barsPerGroup + 5} = yS_targetHue_space;
    allXPositions = [allXPositions, repmat(groupXPos(5), 1, length(yS_targetHue_space))];
    allColors = [allColors; repmat([0.2, 0.4, 0.8], length(yS_targetHue_space), 1)];  % Blue
    
    % Bar 6: yS BaseHue Homo_Space
    yS_baseHue_space = abs(ySTrials.BaseHue_Response(strcmp(ySTrials.NoiseLevel, noise) & ...
                                                      ySTrials.ItemN == itemN & ...
                                                      strcmp(ySTrials.Condition, 'Homo_Space')));
    allPrecisionData{(g-1)*barsPerGroup + 6} = yS_baseHue_space;
    allXPositions = [allXPositions, repmat(groupXPos(6), 1, length(yS_baseHue_space))];
    allColors = [allColors; repmat([0.4, 0.6, 0.9], length(yS_baseHue_space), 1)];  % Light blue
    
    % Bar 7: ySS TargetHue Baseline
    if height(ySSTrials) > 0
        ySS_targetHue_baseline = abs(ySSTrials.TargetHue_Response(strcmp(ySSTrials.NoiseLevel, noise) & ...
                                                                   ySSTrials.ItemN == itemN & ...
                                                                   strcmp(ySSTrials.Condition, 'Baseline')));
        allPrecisionData{(g-1)*barsPerGroup + 7} = ySS_targetHue_baseline;
        allXPositions = [allXPositions, repmat(groupXPos(7), 1, length(ySS_targetHue_baseline))];
        allColors = [allColors; repmat([0.6, 0.4, 0.4], length(ySS_targetHue_baseline), 1)];  % Light red/pink
    else
        allPrecisionData{(g-1)*barsPerGroup + 7} = [];
    end
    
    % Bar 8: ySS BaseHue Baseline
    if height(ySSTrials) > 0
        ySS_baseHue_baseline = abs(ySSTrials.BaseHue_Response(strcmp(ySSTrials.NoiseLevel, noise) & ...
                                                              ySSTrials.ItemN == itemN & ...
                                                              strcmp(ySSTrials.Condition, 'Baseline')));
        allPrecisionData{(g-1)*barsPerGroup + 8} = ySS_baseHue_baseline;
        allXPositions = [allXPositions, repmat(groupXPos(8), 1, length(ySS_baseHue_baseline))];
        allColors = [allColors; repmat([0.8, 0.6, 0.6], length(ySS_baseHue_baseline), 1)];  % Very light red/pink
    else
        allPrecisionData{(g-1)*barsPerGroup + 8} = [];
    end
    
    % Bar 9: ySS TargetHue Homo_Space
    if height(ySSTrials) > 0
        ySS_targetHue_space = abs(ySSTrials.TargetHue_Response(strcmp(ySSTrials.NoiseLevel, noise) & ...
                                                                ySSTrials.ItemN == itemN & ...
                                                                strcmp(ySSTrials.Condition, 'Homo_Space')));
        allPrecisionData{(g-1)*barsPerGroup + 9} = ySS_targetHue_space;
        allXPositions = [allXPositions, repmat(groupXPos(9), 1, length(ySS_targetHue_space))];
        allColors = [allColors; repmat([0.8, 0.3, 0.5], length(ySS_targetHue_space), 1)];  % Pink/magenta
    else
        allPrecisionData{(g-1)*barsPerGroup + 9} = [];
    end
    
    % Bar 10: ySS BaseHue Homo_Space
    if height(ySSTrials) > 0
        ySS_baseHue_space = abs(ySSTrials.BaseHue_Response(strcmp(ySSTrials.NoiseLevel, noise) & ...
                                                            ySSTrials.ItemN == itemN & ...
                                                            strcmp(ySSTrials.Condition, 'Homo_Space')));
        allPrecisionData{(g-1)*barsPerGroup + 10} = ySS_baseHue_space;
        allXPositions = [allXPositions, repmat(groupXPos(10), 1, length(ySS_baseHue_space))];
        allColors = [allColors; repmat([0.9, 0.5, 0.7], length(ySS_baseHue_space), 1)];  % Light pink/magenta
    else
        allPrecisionData{(g-1)*barsPerGroup + 10} = [];
    end
    
    % Store labels
    if height(ySSTrials) > 0
        xLabels = [xLabels, {'yD Base', 'yD Space', 'yS T-Base', 'yS B-Base', 'yS T-Space', 'yS B-Space', ...
                             'ySS T-Base', 'ySS B-Base', 'ySS T-Space', 'ySS B-Space'}];
    else
        xLabels = [xLabels, {'yD Base', 'yD Space', 'yS T-Base', 'yS B-Base', 'yS T-Space', 'yS B-Space', ...
                             '', '', '', ''}];
    end
    
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
        if ~isempty(allPrecisionData{idx}) && length(allPrecisionData{idx}) > 0
            xPos = xPositions(idx);
            data = allPrecisionData{idx};
            
            % Draw box plot elements
            q25 = prctile(data, 25);
            q50 = prctile(data, 50);
            q75 = prctile(data, 75);
            
            % Check that percentiles are valid numbers
            if ~isnan(q25) && ~isnan(q50) && ~isnan(q75) && isfinite(q25) && isfinite(q50) && isfinite(q75)
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

if height(ySSTrials) > 0
    sgtitle('Figure 2a: Precision Distributions (TargetHue and BaseHue Response) - yS, ySS, and yD', 'FontSize', 14, 'FontWeight', 'bold');
else
    sgtitle('Figure 2a: Precision Distributions (TargetHue and BaseHue Response) - yS vs yD', 'FontSize', 14, 'FontWeight', 'bold');
end

% Save figure
saveas(fig2a, fullfile(dataDir, 'Figure2a_Precision_Distributions_Combined.png'));
fprintf('Saved: Figure2a_Precision_Distributions_Combined.png\n\n');

% ============================================================================
% Figure 2a_new section removed - now integrated into Figure 2a above
% ============================================================================


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
    spaceKey = sprintf('N%d_%s_Homo_Space', itemN, noise);
    
    % Calculate x positions for this group
    groupXPos = xStart + (0:(barsPerGroup-1)) * barSpacing;
    xPositions = [xPositions, groupXPos];
    
    % Get yS Baseline data
    if isfield(results_yS.rt_data, baselineKey)
        baselineData_yS = results_yS.rt_data.(baselineKey);
        allRTData{(g-1)*barsPerGroup + 1} = baselineData_yS;
        allXPositions = [allXPositions, repmat(groupXPos(1), 1, length(baselineData_yS))];
        allColors = [allColors; repmat([0.5, 0.5, 0.5], length(baselineData_yS), 1)];  % Gray
    end
    
    % Get yS Space data
    if isfield(results_yS.rt_data, spaceKey)
        spaceData_yS = results_yS.rt_data.(spaceKey);
        allRTData{(g-1)*barsPerGroup + 2} = spaceData_yS;
        allXPositions = [allXPositions, repmat(groupXPos(2), 1, length(spaceData_yS))];
        allColors = [allColors; repmat([0.2, 0.4, 0.8], length(spaceData_yS), 1)];  % Blue
    end
    
    % Get yD Baseline data
    if isfield(results_yD.rt_data, baselineKey)
        baselineData_yD = results_yD.rt_data.(baselineKey);
        allRTData{(g-1)*barsPerGroup + 3} = baselineData_yD;
        allXPositions = [allXPositions, repmat(groupXPos(3), 1, length(baselineData_yD))];
        allColors = [allColors; repmat([0.3, 0.3, 0.3], length(baselineData_yD), 1)];  % Darker gray
    end
    
    % Get yD Space data
    if isfield(results_yD.rt_data, spaceKey)
        spaceData_yD = results_yD.rt_data.(spaceKey);
        allRTData{(g-1)*barsPerGroup + 4} = spaceData_yD;
        allXPositions = [allXPositions, repmat(groupXPos(4), 1, length(spaceData_yD))];
        allColors = [allColors; repmat([0.1, 0.2, 0.6], length(spaceData_yD), 1)];  % Darker blue
    end
    
    % Store labels
    xLabels = [xLabels, {'yS Base', 'yS Space', 'yD Base', 'yD Space'}];
    
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

sgtitle('Figure 2b: Response Time Distributions (Individual Trials) - yS (Statistical) vs yD (Deterministic)', 'FontSize', 14, 'FontWeight', 'bold');

% Save figure
saveas(fig2b, fullfile(dataDir, 'Figure2b_RT_Distributions_Combined.png'));
fprintf('Saved: Figure2b_RT_Distributions_Combined.png\n\n');

fprintf('=== Plotting Complete ===\n');

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
    xGroups = {'Low N=2', 'Low N=6', 'High N=2', 'High N=6'};
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
        spaceKey = sprintf('N%d_%s_Homo_Space', itemN, noise);
        if isfield(results.precision_data, baselineKey)
            baselineData = results.precision_data.(baselineKey);
            baselineMean = computeCircSD(baselineData);
            baselineCI = bootci(1000, @computeCircSD, baselineData);
            allPrecisionMeans = [allPrecisionMeans, baselineMean];
            allPrecisionCIs = [allPrecisionCIs, baselineCI(2)];
        end
        if isfield(results.precision_data, spaceKey)
            spaceData = results.precision_data.(spaceKey);
            spaceMean = computeCircSD(spaceData);
            spaceCI = bootci(1000, @computeCircSD, spaceData);
            allPrecisionMeans = [allPrecisionMeans, spaceMean];
            allPrecisionCIs = [allPrecisionCIs, spaceCI(2)];
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
        spaceKey = sprintf('N%d_%s_Homo_Space', itemN, noise);
        if isfield(results.rt_data, baselineKey)
            baselineData = results.rt_data.(baselineKey);
            baselineMedian = median(baselineData);
            baselineCI = bootci(1000, @median, baselineData);
            allRTMedians = [allRTMedians, baselineMedian];
            allRTCIs = [allRTCIs, baselineCI(2)];
        end
        if isfield(results.rt_data, spaceKey)
            spaceData = results.rt_data.(spaceKey);
            spaceMedian = median(spaceData);
            spaceCI = bootci(1000, @median, spaceData);
            allRTMedians = [allRTMedians, spaceMedian];
            allRTCIs = [allRTCIs, spaceCI(2)];
        end
    end
    globalYMax = max(allRTMedians + allRTCIs) * 1.15;
end

