% Verification script for Pilot 2 trial counts
% Run this to verify the trial matrix generation

clear; clc;

% Current design parameters
design.ItemNList    = [2 6];
design.NoiseLevels  = {'low', 'high'};
design.BaselineReps = 30;
design.HomoReps     = 10;
design.PracticeReps = 0;
design.presDur      = 0.15;
design.retDur       = 0.75;
design.SegmentDur   = 0.15;
design.ISI          = 0.15;

% Mock session info for testing
sessionN = 1;
participantID = 'TEST';
age = 25;
timestamp = datestr(now,'yyyy-mm-dd_HH-MM-SS');

% Generate trial matrix
try
    [pracTrials, expTrials] = TrialMatrixSeq3way_HomoInte(design, sessionN, participantID, age, timestamp);
    
    fprintf('=== TRIAL COUNT VERIFICATION ===\n\n');
    fprintf('Practice trials: %d\n', height(pracTrials));
    fprintf('Main trials: %d\n\n', height(expTrials));
    
    % Count by condition
    fprintf('=== BREAKDOWN BY CONDITION ===\n');
    conditions = unique(expTrials.Condition);
    for c = 1:length(conditions)
        cond = conditions{c};
        count = sum(strcmp(expTrials.Condition, cond));
        fprintf('%s: %d trials\n', cond, count);
    end
    
    fprintf('\n=== BREAKDOWN BY CONDITION × NOISE ===\n');
    for c = 1:length(conditions)
        cond = conditions{c};
        for n = 1:length(design.NoiseLevels)
            noise = design.NoiseLevels{n};
            count = sum(strcmp(expTrials.Condition, cond) & strcmp(expTrials.NoiseLevel, noise));
            fprintf('%s × %s: %d trials\n', cond, noise, count);
        end
    end
    
    fprintf('\n=== BREAKDOWN BY CONDITION × NOISE × SET SIZE ===\n');
    for c = 1:length(conditions)
        cond = conditions{c};
        for n = 1:length(design.NoiseLevels)
            noise = design.NoiseLevels{n};
            for s = 1:length(design.ItemNList)
                N = design.ItemNList(s);
                count = sum(strcmp(expTrials.Condition, cond) & ...
                           strcmp(expTrials.NoiseLevel, noise) & ...
                           expTrials.ItemN == N);
                fprintf('%s × %s × N=%d: %d trials\n', cond, noise, N, count);
            end
        end
    end
    
    fprintf('\n=== EXPECTED vs ACTUAL ===\n');
    fprintf('Expected Baseline: %d (30 reps × 4 combinations)\n', 30*4);
    fprintf('Actual Baseline: %d\n', sum(strcmp(expTrials.Condition, 'Baseline')));
    fprintf('\nExpected each Homo condition: %d (10 reps × 4 combinations)\n', 10*4);
    fprintf('Actual Homo_Space: %d\n', sum(strcmp(expTrials.Condition, 'Homo_Space')));
    fprintf('Actual Homo_Time: %d\n', sum(strcmp(expTrials.Condition, 'Homo_Time')));
    fprintf('Actual Homo_SpaceTime: %d\n', sum(strcmp(expTrials.Condition, 'Homo_SpaceTime')));
    fprintf('\nExpected Total: %d\n', 30*4 + 10*4*3);
    fprintf('Actual Total: %d\n', height(expTrials));
    
catch ME
    fprintf('Error: %s\n', ME.message);
    fprintf('Stack trace:\n');
    for k = 1:length(ME.stack)
        fprintf('  %s (line %d)\n', ME.stack(k).name, ME.stack(k).line);
    end
end

