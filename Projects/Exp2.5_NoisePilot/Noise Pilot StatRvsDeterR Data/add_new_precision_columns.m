% Calculate and add two new precision error columns to data files
% Column 1: TargetHue - ResponseAngle (response error from target hue with meanOffset)
%   Note: TargetHue = baseHue + meanOffset, so Col1 = stored Precision + meanOffset
% Column 2: baseHue - ResponseAngle (response error from true base hue)
%   Note: This should be identical to the stored Precision (verified: 0 mismatches)

clear; close all; clc;

fprintf('=== Adding New Precision Columns ===\n\n');

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

% Process each file
for i = 1:length(files)
    filepath = fullfile(dataDir, files(i).name);
    participantMatch = regexp(files(i).name, 'HomoInte_([^_]+)_sess', 'tokens', 'once');
    if isempty(participantMatch)
        warning('Skipping file with unrecognized participant: %s', files(i).name);
        continue;
    end
    participantId = participantMatch{1};
    fprintf('Processing %s session %d: %s\n', participantId, sessionNumbers(sortIdx(i)), files(i).name);
    
    % Load the data
    data = load(filepath, 'expTrials');
    if ~isfield(data, 'expTrials')
        warning('Session %d: No expTrials found, skipping', sessionNumbers(sortIdx(i)));
        continue;
    end
    
    trials = data.expTrials;
    
    % Check required columns
    requiredCols = {'Condition', 'Precision', 'ResponseAngle', 'BaseHues', 'MeanOffsets', 'Target'};
    missingCols = setdiff(requiredCols, trials.Properties.VariableNames);
    if ~isempty(missingCols)
        warning('Missing required columns in %s: %s', files(i).name, strjoin(missingCols, ', '));
        continue;
    end
    
    % Check if TargetHue exists, otherwise we'll calculate it
    hasTargetHue = ismember('TargetHue', trials.Properties.VariableNames);
    
    % Initialize new columns
    nTrials = height(trials);
    precisionCol1 = nan(nTrials, 1);  % TargetHue - ResponseAngle
    precisionCol2 = nan(nTrials, 1);  % baseHue - ResponseAngle (should match stored Precision)
    
    % Calculate new precision columns
    for t = 1:nTrials
        cond = trials.Condition{t};
        existingPrecision = trials.Precision(t);
        responseAngle = trials.ResponseAngle(t);
        baseH = trials.BaseHues{t};
        meanOff = trials.MeanOffsets{t};
        
        % Skip if missing data
        if isnan(existingPrecision) || isnan(responseAngle)
            continue;
        end
        
        % Column 1: TargetHue - ResponseAngle
        % Calculate TargetHue from baseHue + meanOffset
        if strcmp(cond, 'Baseline')
            idx = trials.Target(t);
            targetHue = baseH(idx) + meanOff(idx);
        else
            % Homo_Space: baseHue(1) + mean(meanOffsets)
            targetHue = baseH(1) + mean(meanOff);
        end
        % Wrap targetHue to [0, 360)
        targetHue = mod(targetHue, 360);
        
        precisionCol1(t) = targetHue - responseAngle;
        % Wrap to [-180, 180]
        if precisionCol1(t) < -180
            precisionCol1(t) = precisionCol1(t) + 360;
        elseif precisionCol1(t) > 180
            precisionCol1(t) = precisionCol1(t) - 360;
        end
        
        % Column 2: baseHue - ResponseAngle (should match stored Precision)
        if strcmp(cond, 'Baseline')
            idx = trials.Target(t);
            baseHue = baseH(idx);
        else
            % Homo_Space: use baseHue(1) since all items share the same base hue
            baseHue = baseH(1);
        end
        
        precisionCol2(t) = baseHue - responseAngle;
        % Wrap to [-180, 180]
        if precisionCol2(t) < -180
            precisionCol2(t) = precisionCol2(t) + 360;
        elseif precisionCol2(t) > 180
            precisionCol2(t) = precisionCol2(t) - 360;
        end
    end
    
    % Add new columns to trials table
    trials.Precision_Col1 = precisionCol1;  % TargetHue - ResponseAngle
    trials.Precision_Col2 = precisionCol2;  % baseHue - ResponseAngle (should = stored Precision)
    
    % Save updated data
    expTrials = trials;
    save(filepath, 'expTrials', '-v7.3');
    fprintf('  Added new columns and saved: %s\n', files(i).name);
end

fprintf('\n=== Verifying New Columns ===\n\n');

% Now load all data and verify the columns
allTrials = [];
for i = 1:length(files)
    filepath = fullfile(dataDir, files(i).name);
    participantMatch = regexp(files(i).name, 'HomoInte_([^_]+)_sess', 'tokens', 'once');
    if isempty(participantMatch)
        continue;
    end
    participantId = participantMatch{1};
    
    data = load(filepath, 'expTrials');
    if ~isfield(data, 'expTrials')
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

% Check if new columns exist
if ~ismember('Precision_Col1', allTrials.Properties.VariableNames) || ...
   ~ismember('Precision_Col2', allTrials.Properties.VariableNames)
    error('New columns not found. Please run the script again.');
end

tolerance = 1e-6;

% Verification 1: Col2 should match stored Precision
fprintf('=== Verification 1: Col2 vs Stored Precision ===\n');
validIdx1 = ~isnan(allTrials.Precision) & ~isnan(allTrials.Precision_Col2);
diffs1 = nan(height(allTrials), 1);

for i = 1:height(allTrials)
    if ~validIdx1(i)
        continue;
    end
    
    stored = allTrials.Precision(i);
    col2 = allTrials.Precision_Col2(i);
    
    % Calculate circular difference
    diff = abs(stored - col2);
    if diff > 180
        diff = 360 - diff;
    end
    diffs1(i) = diff;
end

mismatches1 = sum(diffs1(validIdx1) > tolerance);
fprintf('Total trials: %d\n', height(allTrials));
fprintf('Valid trials: %d\n', sum(validIdx1));
fprintf('Mismatches (>%.1e): %d / %d\n', tolerance, mismatches1, sum(validIdx1));
fprintf('Max absolute difference: %.9f deg\n', max(diffs1(validIdx1)));
fprintf('Mean absolute difference: %.9f deg\n', mean(diffs1(validIdx1)));
if mismatches1 == 0
    fprintf('✓ Col2 matches stored Precision perfectly!\n');
else
    fprintf('✗ Warning: Col2 does not match stored Precision\n');
end

% Verification 2: Col1 should differ from stored Precision by exactly meanOffset
fprintf('\n=== Verification 2: Col1 vs (Stored Precision + meanOffset) ===\n');
validIdx2 = ~isnan(allTrials.Precision) & ~isnan(allTrials.Precision_Col1);
diffs2 = nan(height(allTrials), 1);
expectedCol1 = nan(height(allTrials), 1);

for i = 1:height(allTrials)
    if ~validIdx2(i)
        continue;
    end
    
    stored = allTrials.Precision(i);
    col1 = allTrials.Precision_Col1(i);
    cond = allTrials.Condition{i};
    meanOff = allTrials.MeanOffsets{i};
    
    % Calculate expected meanOffset
    if strcmp(cond, 'Baseline')
        idx = allTrials.Target(i);
        meanOffset = meanOff(idx);
    else
        meanOffset = mean(meanOff);
    end
    
    % Expected Col1 = stored Precision + meanOffset
    expected = stored + meanOffset;
    if expected < -180
        expected = expected + 360;
    elseif expected > 180
        expected = expected - 360;
    end
    expectedCol1(i) = expected;
    
    % Calculate circular difference
    diff = abs(col1 - expected);
    if diff > 180
        diff = 360 - diff;
    end
    diffs2(i) = diff;
end

mismatches2 = sum(diffs2(validIdx2) > tolerance);
fprintf('Total trials: %d\n', height(allTrials));
fprintf('Valid trials: %d\n', sum(validIdx2));
fprintf('Mismatches (>%.1e): %d / %d\n', tolerance, mismatches2, sum(validIdx2));
fprintf('Max absolute difference: %.9f deg\n', max(diffs2(validIdx2)));
fprintf('Mean absolute difference: %.9f deg\n', mean(diffs2(validIdx2)));
if mismatches2 == 0
    fprintf('✓ Col1 = stored Precision + meanOffset perfectly!\n');
else
    fprintf('✗ Warning: Col1 does not match expected value\n');
end

% Show examples
fprintf('\n=== Example Verifications (First 10 trials) ===\n');
exampleIdx = find(validIdx2, 10);
for j = 1:min(10, length(exampleIdx))
    idx = exampleIdx(j);
    cond = allTrials.Condition{idx};
    stored = allTrials.Precision(idx);
    col1 = allTrials.Precision_Col1(idx);
    col2 = allTrials.Precision_Col2(idx);
    meanOff = allTrials.MeanOffsets{idx};
    if strcmp(cond, 'Baseline')
        meanOffset = meanOff(allTrials.Target(idx));
    else
        meanOffset = mean(meanOff);
    end
    fprintf('  Trial %d (%s): Stored=%.6f, Col1=%.6f, Col2=%.6f, meanOffset=%.6f, Col1-Stored=%.6f\n', ...
        idx, cond, stored, col1, col2, meanOffset, col1 - stored);
end

% Separate by condition
fprintf('\n=== Verification by Condition ===\n');
conditions = unique(allTrials.Condition, 'stable');
for c = 1:length(conditions)
    cond = conditions{c};
    condIdx = validIdx2 & strcmp(allTrials.Condition, cond);
    condDiffs = diffs2(condIdx);
    condMismatches = sum(condDiffs > tolerance);
    fprintf('\n%s:\n', cond);
    fprintf('  Total trials: %d\n', sum(condIdx));
    fprintf('  Mismatches: %d\n', condMismatches);
    if sum(condIdx) > 0
        fprintf('  Max diff: %.9f deg\n', max(condDiffs));
        fprintf('  Mean diff: %.9f deg\n', mean(condDiffs));
    end
end

fprintf('\n=== Complete ===\n');

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
