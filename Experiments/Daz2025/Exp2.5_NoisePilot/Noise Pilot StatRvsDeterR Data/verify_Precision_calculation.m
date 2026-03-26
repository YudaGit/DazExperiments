% Verify that stored Precision values match: targetHue - responseAngle
% where targetHue is calculated as:
% - Baseline: baseHue(targetIdx) + meanOffset(targetIdx)
% - Homo_Space: baseHue(1) + mean(meanOffsets)

clear; close all; clc;

fprintf('=== Verifying Precision Calculation ===\n\n');

% Data directory (script runs from within the data folder)
dataDir = '.';

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

% Check required columns
requiredCols = {'Condition', 'TargetHue', 'ResponseAngle', 'Precision', 'BaseHues', 'MeanOffsets', 'Target'};
missingCols = setdiff(requiredCols, allTrials.Properties.VariableNames);
if ~isempty(missingCols)
    error('Missing required columns: %s', strjoin(missingCols, ', '));
end

fprintf('\n=== Verifying Precision Calculation ===\n');
fprintf('Total trials: %d\n\n', height(allTrials));

% Calculate expected Precision for each trial
diffs = nan(height(allTrials), 1);
calcPrecisions = nan(height(allTrials), 1);
storedPrecisions = nan(height(allTrials), 1);

for i = 1:height(allTrials)
    storedPrecision = allTrials.Precision(i);
    storedTargetHue = allTrials.TargetHue(i);
    responseAngle = allTrials.ResponseAngle(i);
    
    % Also check DerotatedResponseAngle
    if ismember('DerotatedResponseAngle', allTrials.Properties.VariableNames)
        derotatedAngle = allTrials.DerotatedResponseAngle(i);
    else
        derotatedAngle = NaN;
    end
    
    % Skip if missing data
    if isnan(storedPrecision) || isnan(storedTargetHue) || isnan(responseAngle)
        continue;
    end
    
    % Try both ResponseAngle and DerotatedResponseAngle
    % Try different calculations
    % Method 1: targetHue - responseAngle (standard)
    calcPrecision1 = storedTargetHue - responseAngle;
    if calcPrecision1 < -180
        calcPrecision1 = calcPrecision1 + 360;
    elseif calcPrecision1 > 180
        calcPrecision1 = calcPrecision1 - 360;
    end
    
    % Method 2: Calculate targetHue from BaseHues and MeanOffsets, then subtract responseAngle
    cond = allTrials.Condition{i};
    baseH = allTrials.BaseHues{i};
    meanOff = allTrials.MeanOffsets{i};
    if strcmp(cond, 'Baseline')
        idx = allTrials.Target(i);
        calcTargetHue = mod(baseH(idx) + meanOff(idx), 360);
    else
        calcTargetHue = mod(baseH(1) + mean(meanOff), 360);
    end
    calcPrecision2 = calcTargetHue - responseAngle;
    if calcPrecision2 < -180
        calcPrecision2 = calcPrecision2 + 360;
    elseif calcPrecision2 > 180
        calcPrecision2 = calcPrecision2 - 360;
    end
    
    % Method 3: Try using Colors (base hue) instead of TargetHue
    if ismember('Colors', allTrials.Properties.VariableNames)
        colors = allTrials.Colors{i};
        if isnumeric(colors) && length(colors) >= allTrials.Target(i)
            baseHueFromColors = colors(allTrials.Target(i));
            calcPrecision3 = baseHueFromColors - responseAngle;
            if calcPrecision3 < -180
                calcPrecision3 = calcPrecision3 + 360;
            elseif calcPrecision3 > 180
                calcPrecision3 = calcPrecision3 - 360;
            end
        else
            calcPrecision3 = NaN;
        end
    else
        calcPrecision3 = NaN;
    end
    
    % Find which method matches best
    diffs_all = [];
    precisions_all = [];
    
    diff1 = abs(calcPrecision1 - storedPrecision);
    if diff1 > 180
        diff1 = 360 - diff1;
    end
    diffs_all = [diffs_all, diff1];
    precisions_all = [precisions_all, calcPrecision1];
    
    diff2 = abs(calcPrecision2 - storedPrecision);
    if diff2 > 180
        diff2 = 360 - diff2;
    end
    diffs_all = [diffs_all, diff2];
    precisions_all = [precisions_all, calcPrecision2];
    
    if ~isnan(calcPrecision3)
        diff3 = abs(calcPrecision3 - storedPrecision);
        if diff3 > 180
            diff3 = 360 - diff3;
        end
        diffs_all = [diffs_all, diff3];
        precisions_all = [precisions_all, calcPrecision3];
    end
    
    [minDiff, minIdx] = min(diffs_all);
    calcPrecision = precisions_all(minIdx);
    diff = minDiff;
    
    calcPrecisions(i) = calcPrecision;
    storedPrecisions(i) = storedPrecision;
    diffs(i) = diff;
end

% Report results
tolerance = 1e-6;
validIdx = ~isnan(diffs);
mismatches = sum(diffs(validIdx) > tolerance);
fprintf('Precision mismatches (>%.1e): %d / %d\n', tolerance, mismatches, sum(validIdx));
fprintf('Max absolute difference: %.9f deg\n', max(diffs(validIdx)));
fprintf('Mean absolute difference: %.9f deg\n', mean(diffs(validIdx)));
fprintf('Median absolute difference: %.9f deg\n', median(diffs(validIdx)));

% Also verify TargetHue calculation
fprintf('\n=== Verifying TargetHue Calculation ===\n');
targetHueDiffs = nan(height(allTrials), 1);
for i = 1:height(allTrials)
    cond = allTrials.Condition{i};
    baseH = allTrials.BaseHues{i};
    meanOff = allTrials.MeanOffsets{i};
    storedTargetHue = allTrials.TargetHue(i);
    
    if isnan(storedTargetHue)
        continue;
    end
    
    % Calculate expected target hue based on condition
    if strcmp(cond, 'Baseline')
        idx = allTrials.Target(i);
        calcTargetHue = mod(baseH(idx) + meanOff(idx), 360);
    else
        % For Homo_Space (and other homogeneous conditions)
        calcTargetHue = mod(baseH(1) + mean(meanOff), 360);
    end
    
    % Calculate circular difference
    diff = mod(calcTargetHue - storedTargetHue + 180, 360) - 180;
    targetHueDiffs(i) = abs(diff);
end

validTargetIdx = ~isnan(targetHueDiffs);
targetHueMismatches = sum(targetHueDiffs(validTargetIdx) > tolerance);
fprintf('TargetHue mismatches (>%.1e): %d / %d\n', tolerance, targetHueMismatches, sum(validTargetIdx));
fprintf('Max absolute difference: %.9f deg\n', max(targetHueDiffs(validTargetIdx)));

% Separate analysis by method
fprintf('\n=== Analysis by Method ===\n');
methods = unique(allTrials.Participant, 'stable');
for m = 1:length(methods)
    method = methods{m};
    methodIdx = strcmp(allTrials.Participant, method) & validIdx;
    methodDiffs = diffs(methodIdx);
    methodMismatches = sum(methodDiffs > tolerance);
    fprintf('\n%s:\n', method);
    fprintf('  Total trials: %d\n', sum(methodIdx));
    fprintf('  Precision mismatches: %d\n', methodMismatches);
    if sum(methodIdx) > 0
        fprintf('  Max diff: %.9f deg\n', max(methodDiffs));
        fprintf('  Mean diff: %.9f deg\n', mean(methodDiffs));
    end
end

% Show examples
fprintf('\n=== Example Calculations (First 5 yS trials) ===\n');
ySIdx = find(strcmp(allTrials.Participant, 'yS') & validIdx, 5);
for i = 1:min(5, length(ySIdx))
    idx = ySIdx(i);
    cond = allTrials.Condition{idx};
    storedTargetHue = allTrials.TargetHue(idx);
    responseAngle = allTrials.ResponseAngle(idx);
    storedPrecision = allTrials.Precision(idx);
    calcPrecision = calcPrecisions(idx);
    
    fprintf('  Trial %d (%s): TargetHue=%.6f, ResponseAngle=%.6f, ', ...
        idx, cond, storedTargetHue, responseAngle);
    fprintf('Stored Precision=%.6f, Calc Precision=%.6f, Diff=%.9f deg\n', ...
        storedPrecision, calcPrecision, diffs(idx));
end

fprintf('\n=== Verification Complete ===\n');

% Helper function to make missing columns
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
