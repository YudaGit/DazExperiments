% Verify that TargetHue was calculated correctly for all trials
% For Baseline: TargetHue = mod(BaseHue(Target) + MeanOffsets(Target), 360)
% For Homo_Space: TargetHue = mod(BaseHue(1) + mean(MeanOffsets), 360)

clear; close all; clc;

fprintf('=== Verifying TargetHue Calculations ===\n\n');

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
requiredCols = {'Condition', 'TargetHue', 'BaseHues', 'MeanOffsets', 'Target'};
missingCols = setdiff(requiredCols, allTrials.Properties.VariableNames);
if ~isempty(missingCols)
    error('Missing required columns: %s', strjoin(missingCols, ', '));
end

fprintf('\n=== Verifying TargetHue Calculations ===\n');
fprintf('Total trials: %d\n\n', height(allTrials));

% Calculate expected TargetHue for each trial
diffs = nan(height(allTrials), 1);
calcTargetHues = nan(height(allTrials), 1);
storedTargetHues = nan(height(allTrials), 1);

for i = 1:height(allTrials)
    cond = allTrials.Condition{i};
    baseH = allTrials.BaseHues{i};
    meanOff = allTrials.MeanOffsets{i};
    storedHue = allTrials.TargetHue(i);
    
    % Calculate expected target hue based on condition
    if strcmp(cond, 'Baseline')
        idx = allTrials.Target(i);
        calcHue = mod(baseH(idx) + meanOff(idx), 360);
    else
        % For Homo_Space (and other homogeneous conditions)
        calcHue = mod(baseH(1) + mean(meanOff), 360);
    end
    
    calcTargetHues(i) = calcHue;
    storedTargetHues(i) = storedHue;
    
    % Calculate circular difference
    diff = mod(calcHue - storedHue + 180, 360) - 180;
    diffs(i) = abs(diff);
end

% Report results
tolerance = 1e-6;
mismatches = sum(diffs > tolerance);
fprintf('TargetHue mismatches (>%.1e): %d / %d\n', tolerance, mismatches, height(allTrials));
fprintf('Max absolute difference: %.9f deg\n', max(diffs));
fprintf('Mean absolute difference: %.9f deg\n', mean(diffs));
fprintf('Median absolute difference: %.9f deg\n', median(diffs));

% Show details for mismatches
if mismatches > 0
    fprintf('\n=== Mismatch Details ===\n');
    mismatchIdx = find(diffs > tolerance);
    fprintf('Showing first 10 mismatches:\n');
    for i = 1:min(10, length(mismatchIdx))
        idx = mismatchIdx(i);
        fprintf('  Trial %d: Condition=%s, Calc=%.6f, Stored=%.6f, Diff=%.6f deg\n', ...
            idx, allTrials.Condition{idx}, calcTargetHues(idx), storedTargetHues(idx), diffs(idx));
    end
    if length(mismatchIdx) > 10
        fprintf('  ... and %d more mismatches\n', length(mismatchIdx) - 10);
    end
end

% Separate analysis by condition
fprintf('\n=== Analysis by Condition ===\n');
conditions = unique(allTrials.Condition, 'stable');
for c = 1:length(conditions)
    cond = conditions{c};
    condIdx = strcmp(allTrials.Condition, cond);
    condDiffs = diffs(condIdx);
    condMismatches = sum(condDiffs > tolerance);
    fprintf('\n%s:\n', cond);
    fprintf('  Total trials: %d\n', sum(condIdx));
    fprintf('  Mismatches: %d\n', condMismatches);
    if sum(condIdx) > 0
        fprintf('  Max diff: %.9f deg\n', max(condDiffs));
        fprintf('  Mean diff: %.9f deg\n', mean(condDiffs));
    end
end

% Separate analysis for Homo_Space, high noise (the condition of interest)
fprintf('\n=== Homo_Space, High Noise (Specific Verification) ===\n');
homoSpaceHigh = strcmp(allTrials.Condition, 'Homo_Space') & ...
              strcmp(allTrials.NoiseLevel, 'high');
homoSpaceHighDiffs = diffs(homoSpaceHigh);
homoSpaceHighMismatches = sum(homoSpaceHighDiffs > tolerance);
fprintf('Total trials: %d\n', sum(homoSpaceHigh));
fprintf('Mismatches: %d\n', homoSpaceHighMismatches);
if sum(homoSpaceHigh) > 0
    fprintf('Max diff: %.9f deg\n', max(homoSpaceHighDiffs));
    fprintf('Mean diff: %.9f deg\n', mean(homoSpaceHighDiffs));
    fprintf('Median diff: %.9f deg\n', median(homoSpaceHighDiffs));
    
    % Show a few examples
    fprintf('\nExample calculations (first 5 trials):\n');
    exampleIdx = find(homoSpaceHigh, 5);
    for i = 1:min(5, length(exampleIdx))
        idx = exampleIdx(i);
        baseH = allTrials.BaseHues{idx};
        meanOff = allTrials.MeanOffsets{idx};
        calcHue = mod(baseH(1) + mean(meanOff), 360);
        storedHue = allTrials.TargetHue(idx);
        fprintf('  Trial %d (N=%d): BaseHue(1)=%.2f, mean(MeanOffsets)=%.6f, ', ...
            idx, allTrials.ItemN(idx), baseH(1), mean(meanOff));
        fprintf('Calc=%.6f, Stored=%.6f, Diff=%.9f deg\n', ...
            calcHue, storedHue, diffs(idx));
    end
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
