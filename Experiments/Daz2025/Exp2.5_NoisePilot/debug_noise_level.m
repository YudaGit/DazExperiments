% Debug script to check noise level assignment and randomization
% Run this to verify noise levels are being assigned correctly

clear; clc;

% Design parameters
design.ItemNList    = [2 6];
design.NoiseLevels  = {'low', 'high'};
design.BaselineReps = 12;
design.HomoReps     = 4;
design.PracticeReps = 0;
design.presDur      = 0.30;
design.retDur       = 0.75;
design.SegmentDur   = 0.15;
design.ISI          = 0.15;

% Mock session info
sessionN = 1;
participantID = 'DEBUG';
age = 25;
timestamp = datestr(now,'yyyy-mm-dd_HH-MM-SS');

% Generate trial matrix
try
    [pracTrials, expTrials] = TrialMatrixSeq3way_HomoInte(design, sessionN, participantID, age, timestamp);
    
    fprintf('=== NOISE LEVEL VERIFICATION ===\n\n');
    fprintf('Total trials: %d\n\n', height(expTrials));
    
    % Check noise level distribution
    fprintf('=== NOISE LEVEL DISTRIBUTION ===\n');
    lowCount = sum(strcmp(expTrials.NoiseLevel, 'low'));
    highCount = sum(strcmp(expTrials.NoiseLevel, 'high'));
    fprintf('Low noise: %d trials (%.1f%%)\n', lowCount, 100*lowCount/height(expTrials));
    fprintf('High noise: %d trials (%.1f%%)\n', highCount, 100*highCount/height(expTrials));
    
    % Check first 30 trials
    fprintf('\n=== FIRST 30 TRIALS ===\n');
    fprintf('Trial | ItemN | Condition      | NoiseLevel\n');
    fprintf('------|-------|----------------|-----------\n');
    for i = 1:min(30, height(expTrials))
        % Check how NoiseLevel is stored
        if iscell(expTrials.NoiseLevel)
            noiseVal = expTrials.NoiseLevel{i};
        else
            noiseVal = expTrials.NoiseLevel(i);
        end
        
        fprintf('%5d | %5d | %-14s | %s\n', i, expTrials.ItemN(i), ...
                expTrials.Condition{i}, noiseVal);
    end
    
    % Check if NoiseLevel is cell array or string array
    fprintf('\n=== NOISE LEVEL STORAGE TYPE ===\n');
    fprintf('NoiseLevel class: %s\n', class(expTrials.NoiseLevel));
    if iscell(expTrials.NoiseLevel)
        fprintf('First value: %s (class: %s)\n', expTrials.NoiseLevel{1}, class(expTrials.NoiseLevel{1}));
    else
        fprintf('First value: %s\n', string(expTrials.NoiseLevel(1)));
    end
    
    % Check randomization
    fprintf('\n=== RANDOMIZATION CHECK ===\n');
    fprintf('First 10 trials noise levels: ');
    for i = 1:min(10, height(expTrials))
        if iscell(expTrials.NoiseLevel)
            fprintf('%s ', expTrials.NoiseLevel{i});
        else
            fprintf('%s ', string(expTrials.NoiseLevel(i)));
        end
    end
    fprintf('\n');
    
catch ME
    fprintf('Error: %s\n', ME.message);
    fprintf('Stack trace:\n');
    for k = 1:length(ME.stack)
        fprintf('  %s (line %d)\n', ME.stack(k).name, ME.stack(k).line);
    end
end

