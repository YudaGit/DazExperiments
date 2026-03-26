% Check yS trials to verify Col1 differs from stored Precision by meanOffset

clear; close all; clc;

fprintf('=== Checking yS Trials (should have non-zero meanOffset) ===\n\n');

% Load one yS file
dataDir = '.';
filepath = fullfile(dataDir, 'HomoInte_yS_sess1_2026-01-30_14-10-20.mat');
data = load(filepath, 'expTrials');
trials = data.expTrials;

% Find yS trials with non-zero meanOffset
fprintf('Checking first 10 yS trials:\n\n');

count = 0;
for t = 1:height(trials)
    if count >= 10
        break;
    end
    
    stored = trials.Precision(t);
    col1 = trials.Precision_Col1(t);
    col2 = trials.Precision_Col2(t);
    cond = trials.Condition{t};
    meanOff = trials.MeanOffsets{t};
    
    if isnan(stored) || isnan(col1) || isnan(col2)
        continue;
    end
    
    % Calculate meanOffset
    if strcmp(cond, 'Baseline')
        idx = trials.Target(t);
        meanOffset = meanOff(idx);
    else
        meanOffset = mean(meanOff);
    end
    
    % Only show trials with non-zero meanOffset
    if abs(meanOffset) > 0.001
        count = count + 1;
        fprintf('Trial %d (%s):\n', t, cond);
        fprintf('  Stored Precision: %.6f\n', stored);
        fprintf('  Col1 (TargetHue-Resp): %.6f\n', col1);
        fprintf('  Col2 (baseHue-Resp): %.6f\n', col2);
        fprintf('  meanOffset: %.6f\n', meanOffset);
        fprintf('  Col1 - Stored: %.6f (should = meanOffset)\n', col1 - stored);
        fprintf('  Col2 - Stored: %.6f (should = 0)\n', col2 - stored);
        fprintf('  Col1 - Col2: %.6f (should = meanOffset)\n', col1 - col2);
        fprintf('\n');
    end
end

if count == 0
    fprintf('No trials with non-zero meanOffset found in first 100 trials.\n');
    fprintf('Checking all trials...\n\n');
    
    for t = 1:height(trials)
        stored = trials.Precision(t);
        col1 = trials.Precision_Col1(t);
        col2 = trials.Precision_Col2(t);
        cond = trials.Condition{t};
        meanOff = trials.MeanOffsets{t};
        
        if isnan(stored) || isnan(col1) || isnan(col2)
            continue;
        end
        
        % Calculate meanOffset
        if strcmp(cond, 'Baseline')
            idx = trials.Target(t);
            meanOffset = meanOff(idx);
        else
            meanOffset = mean(meanOff);
        end
        
        if abs(meanOffset) > 0.001
            fprintf('Trial %d (%s): meanOffset=%.6f, Col1-Stored=%.6f, Col2-Stored=%.6f\n', ...
                t, cond, meanOffset, col1 - stored, col2 - stored);
        end
    end
end
