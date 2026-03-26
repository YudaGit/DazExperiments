% Comprehensive verification of what stored Precision represents
% Check all possible calculations and see which one matches

clear; close all; clc;

fprintf('=== Comprehensive Precision Verification ===\n\n');

% Data directory
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
        % Align table variables
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
        allTrials = allTrials(:, allVarNames);
        trials = trials(:, allVarNames);
        allTrials = [allTrials; trials];
    end
end

% Check required columns
requiredCols = {'Condition', 'Precision', 'TargetHue', 'ResponseAngle', 'BaseHues', 'MeanOffsets', 'Target', 'Participant'};
missingCols = setdiff(requiredCols, allTrials.Properties.VariableNames);
if ~isempty(missingCols)
    error('Missing required columns: %s', strjoin(missingCols, ', '));
end

fprintf('Total trials: %d\n\n', height(allTrials));

% Test different possible calculations
validIdx = ~isnan(allTrials.Precision) & ~isnan(allTrials.TargetHue) & ~isnan(allTrials.ResponseAngle);

% Method 1: TargetHue - ResponseAngle
calc1 = nan(height(allTrials), 1);
% Method 2: baseHue - ResponseAngle
calc2 = nan(height(allTrials), 1);
% Method 3: ResponseAngle - TargetHue (reversed)
calc3 = nan(height(allTrials), 1);
% Method 4: ResponseAngle - baseHue (reversed)
calc4 = nan(height(allTrials), 1);

for i = 1:height(allTrials)
    if ~validIdx(i)
        continue;
    end
    
    cond = allTrials.Condition{i};
    storedPrecision = allTrials.Precision(i);
    targetHue = allTrials.TargetHue(i);
    responseAngle = allTrials.ResponseAngle(i);
    baseH = allTrials.BaseHues{i};
    
    % Get baseHue
    if strcmp(cond, 'Baseline')
        idx = allTrials.Target(i);
        baseHue = baseH(idx);
    else
        baseHue = baseH(1);
    end
    
    % Method 1: TargetHue - ResponseAngle
    calc1(i) = targetHue - responseAngle;
    if calc1(i) < -180
        calc1(i) = calc1(i) + 360;
    elseif calc1(i) > 180
        calc1(i) = calc1(i) - 360;
    end
    
    % Method 2: baseHue - ResponseAngle
    calc2(i) = baseHue - responseAngle;
    if calc2(i) < -180
        calc2(i) = calc2(i) + 360;
    elseif calc2(i) > 180
        calc2(i) = calc2(i) - 360;
    end
    
    % Method 3: ResponseAngle - TargetHue (reversed)
    calc3(i) = responseAngle - targetHue;
    if calc3(i) < -180
        calc3(i) = calc3(i) + 360;
    elseif calc3(i) > 180
        calc3(i) = calc3(i) - 360;
    end
    
    % Method 4: ResponseAngle - baseHue (reversed)
    calc4(i) = responseAngle - baseHue;
    if calc4(i) < -180
        calc4(i) = calc4(i) + 360;
    elseif calc4(i) > 180
        calc4(i) = calc4(i) - 360;
    end
end

% Calculate differences
diffs1 = nan(height(allTrials), 1);
diffs2 = nan(height(allTrials), 1);
diffs3 = nan(height(allTrials), 1);
diffs4 = nan(height(allTrials), 1);

for i = 1:height(allTrials)
    if ~validIdx(i)
        continue;
    end
    
    stored = allTrials.Precision(i);
    
    diff1 = abs(stored - calc1(i));
    if diff1 > 180
        diff1 = 360 - diff1;
    end
    diffs1(i) = diff1;
    
    diff2 = abs(stored - calc2(i));
    if diff2 > 180
        diff2 = 360 - diff2;
    end
    diffs2(i) = diff2;
    
    diff3 = abs(stored - calc3(i));
    if diff3 > 180
        diff3 = 360 - diff3;
    end
    diffs3(i) = diff3;
    
    diff4 = abs(stored - calc4(i));
    if diff4 > 180
        diff4 = 360 - diff4;
    end
    diffs4(i) = diff4;
end

% Report results
tolerance = 1e-6;
fprintf('=== Comparison Results ===\n\n');

fprintf('Method 1: TargetHue - ResponseAngle\n');
mismatches1 = sum(diffs1(validIdx) > tolerance);
fprintf('  Mismatches: %d / %d\n', mismatches1, sum(validIdx));
fprintf('  Max diff: %.9f deg\n', max(diffs1(validIdx)));
fprintf('  Mean diff: %.9f deg\n', mean(diffs1(validIdx)));

fprintf('\nMethod 2: baseHue - ResponseAngle\n');
mismatches2 = sum(diffs2(validIdx) > tolerance);
fprintf('  Mismatches: %d / %d\n', mismatches2, sum(validIdx));
fprintf('  Max diff: %.9f deg\n', max(diffs2(validIdx)));
fprintf('  Mean diff: %.9f deg\n', mean(diffs2(validIdx)));

fprintf('\nMethod 3: ResponseAngle - TargetHue (reversed)\n');
mismatches3 = sum(diffs3(validIdx) > tolerance);
fprintf('  Mismatches: %d / %d\n', mismatches3, sum(validIdx));
fprintf('  Max diff: %.9f deg\n', max(diffs3(validIdx)));
fprintf('  Mean diff: %.9f deg\n', mean(diffs3(validIdx)));

fprintf('\nMethod 4: ResponseAngle - baseHue (reversed)\n');
mismatches4 = sum(diffs4(validIdx) > tolerance);
fprintf('  Mismatches: %d / %d\n', mismatches4, sum(validIdx));
fprintf('  Max diff: %.9f deg\n', max(diffs4(validIdx)));
fprintf('  Mean diff: %.9f deg\n', mean(diffs4(validIdx)));

% Separate by method (yS vs yD)
fprintf('\n=== Analysis by Method ===\n');
methods = unique(allTrials.Participant, 'stable');
for m = 1:length(methods)
    method = methods{m};
    methodIdx = validIdx & strcmp(allTrials.Participant, method);
    
    fprintf('\n%s:\n', method);
    fprintf('  Method 1 (TargetHue-Resp): %d mismatches, max diff=%.9f\n', ...
        sum(diffs1(methodIdx) > tolerance), max(diffs1(methodIdx)));
    fprintf('  Method 2 (baseHue-Resp): %d mismatches, max diff=%.9f\n', ...
        sum(diffs2(methodIdx) > tolerance), max(diffs2(methodIdx)));
end

% Show examples of best matching method
fprintf('\n=== Examples (Best Matching Method) ===\n');
if mismatches2 < mismatches1
    fprintf('Method 2 (baseHue - ResponseAngle) matches best\n');
    exampleIdx = find(validIdx & diffs2 > tolerance, 5);
    for i = 1:min(5, length(exampleIdx))
        idx = exampleIdx(i);
        fprintf('  Trial %d: Stored=%.6f, Calc=%.6f, Diff=%.9f\n', ...
            idx, allTrials.Precision(idx), calc2(idx), diffs2(idx));
    end
else
    fprintf('Method 1 (TargetHue - ResponseAngle) matches best\n');
    exampleIdx = find(validIdx & diffs1 > tolerance, 5);
    for i = 1:min(5, length(exampleIdx))
        idx = exampleIdx(i);
        fprintf('  Trial %d: Stored=%.6f, Calc=%.6f, Diff=%.9f\n', ...
            idx, allTrials.Precision(idx), calc1(idx), diffs1(idx));
    end
end

fprintf('\n=== Verification Complete ===\n');

% Helper function
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
