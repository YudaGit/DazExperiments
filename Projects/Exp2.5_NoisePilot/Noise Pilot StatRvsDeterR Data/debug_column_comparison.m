% Debug why Column 1 and Column 2 don't match perfectly

clear; close all; clc;

fprintf('=== Debugging Column Comparison ===\n\n');

% Data directory
dataDir = '.';

% Load one yS file to check
filepath = fullfile(dataDir, 'HomoInte_yS_sess1_2026-01-30_14-10-20.mat');
data = load(filepath, 'expTrials');
trials = data.expTrials;

% Check required columns
if ~ismember('Precision_Col1', trials.Properties.VariableNames) || ...
   ~ismember('Precision_Col2', trials.Properties.VariableNames)
    error('New columns not found. Run add_new_precision_columns.m first.');
end

fprintf('Checking first 20 trials with mismatches:\n\n');

diffs = [];
for t = 1:min(20, height(trials))
    if isnan(trials.Precision_Col1(t)) || isnan(trials.Precision_Col2(t))
        continue;
    end
    
    col1 = trials.Precision_Col1(t);
    col2 = trials.Precision_Col2(t);
    
    % Calculate difference
    diff = abs(col1 - col2);
    if diff > 180
        diff = 360 - diff;
    end
    
    if diff > 1e-6
        cond = trials.Condition{t};
        existingPrecision = trials.Precision(t);
        responseAngle = trials.ResponseAngle(t);
        baseH = trials.BaseHues{t};
        meanOff = trials.MeanOffsets{t};
        targetHue = trials.TargetHue(t);
        
        if strcmp(cond, 'Baseline')
            idx = trials.Target(t);
            meanOffsetUsed = meanOff(idx);
            baseHueUsed = baseH(idx);
        else
            meanOffsetUsed = mean(meanOff);
            baseHueUsed = baseH(1);
        end
        
        fprintf('Trial %d (%s):\n', t, cond);
        fprintf('  Existing Precision: %.6f\n', existingPrecision);
        fprintf('  TargetHue: %.6f\n', targetHue);
        fprintf('  ResponseAngle: %.6f\n', responseAngle);
        fprintf('  BaseHue used: %.6f\n', baseHueUsed);
        fprintf('  MeanOffset used: %.6f\n', meanOffsetUsed);
        fprintf('  Col1 (Precision - meanOffset): %.6f\n', col1);
        fprintf('  Col2 (baseHue - ResponseAngle): %.6f\n', col2);
        fprintf('  Diff: %.9f deg\n', diff);
        fprintf('  Check: TargetHue should be %.6f (baseHue + meanOffset)\n', mod(baseHueUsed + meanOffsetUsed, 360));
        fprintf('  Check: Existing Precision should be %.6f (TargetHue - ResponseAngle)\n', ...
            mod(targetHue - responseAngle + 180, 360) - 180);
        fprintf('  Check: Col1 should be %.6f (Precision - meanOffset)\n', ...
            mod(existingPrecision - meanOffsetUsed + 180, 360) - 180);
        fprintf('  Check: Col2 should be %.6f (baseHue - ResponseAngle)\n', ...
            mod(baseHueUsed - responseAngle + 180, 360) - 180);
        fprintf('\n');
    end
end

fprintf('=== Debug Complete ===\n');
