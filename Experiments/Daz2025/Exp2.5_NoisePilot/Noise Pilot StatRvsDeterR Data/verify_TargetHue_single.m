% Verify TargetHue for a single session file
% Usage: Set filename variable below

clear; close all; clc;

% Set the filename to verify
filename = 'HomoInte_yD_sess1_2026-02-01_11-31-27.mat';

fprintf('=== Verifying TargetHue for: %s ===\n\n', filename);

% Data directory (script runs from within the data folder)
dataDir = '.';
filepath = fullfile(dataDir, filename);

if ~exist(filepath, 'file')
    error('File not found: %s', filepath);
end

% Load the session
fprintf('Loading %s...\n', filename);
data = load(filepath, 'expTrials');
if ~isfield(data, 'expTrials')
    error('No expTrials found in %s', filename);
end

allTrials = data.expTrials;
fprintf('Total trials: %d\n\n', height(allTrials));

% Check required columns
requiredCols = {'Condition', 'TargetHue', 'BaseHues', 'MeanOffsets', 'Target'};
missingCols = setdiff(requiredCols, allTrials.Properties.VariableNames);
if ~isempty(missingCols)
    error('Missing required columns: %s', strjoin(missingCols, ', '));
end

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
fprintf('=== Verification Results ===\n');
fprintf('TargetHue mismatches (>%.1e): %d / %d\n', tolerance, mismatches, height(allTrials));
fprintf('Max absolute difference: %.9f deg\n', max(diffs));
fprintf('Mean absolute difference: %.9f deg\n', mean(diffs));
fprintf('Median absolute difference: %.9f deg\n', median(diffs));

% Show details for mismatches
if mismatches > 0
    fprintf('\n=== Mismatch Details ===\n');
    mismatchIdx = find(diffs > tolerance);
    fprintf('Showing all mismatches:\n');
    for i = 1:length(mismatchIdx)
        idx = mismatchIdx(i);
        fprintf('  Trial %d: Condition=%s, Calc=%.6f, Stored=%.6f, Diff=%.6f deg\n', ...
            idx, allTrials.Condition{idx}, calcTargetHues(idx), storedTargetHues(idx), diffs(idx));
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

% Show examples
fprintf('\n=== Example Calculations (First 5 trials) ===\n');
for i = 1:min(5, height(allTrials))
    cond = allTrials.Condition{i};
    baseH = allTrials.BaseHues{i};
    meanOff = allTrials.MeanOffsets{i};
    storedHue = allTrials.TargetHue(i);
    
    if strcmp(cond, 'Baseline')
        idx = allTrials.Target(i);
        calcHue = mod(baseH(idx) + meanOff(idx), 360);
        fprintf('  Trial %d (Baseline, N=%d): BaseHue(%d)=%.2f, MeanOffset(%d)=%.6f, ', ...
            i, allTrials.ItemN(i), idx, baseH(idx), idx, meanOff(idx));
    else
        calcHue = mod(baseH(1) + mean(meanOff), 360);
        fprintf('  Trial %d (%s, N=%d): BaseHue(1)=%.2f, mean(MeanOffsets)=%.6f, ', ...
            i, cond, allTrials.ItemN(i), baseH(1), mean(meanOff));
    end
    fprintf('Calc=%.6f, Stored=%.6f, Diff=%.9f deg\n', ...
        calcHue, storedHue, diffs(i));
end

fprintf('\n=== Verification Complete ===\n');
