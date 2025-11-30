% Script to verify location spacing in trial matrix generation
% Checks that all locations are evenly spaced around the circle

clear; close all;

% Add path if needed
addpath(genpath(pwd));

% Initialize minimal V structure needed for trial matrix generation
global V
V.color.rotation = randi([0, 359]);  % Random rotation for color wheel

% Design parameters matching NoisePilot_STInte.m
design.ItemNList = [4 6];
design.NoiseLevels = {'high'};
design.BaselineReps = 10;
design.RSReps = 20;
design.GroupedReps = 20;
design.presDur = 0.30;
design.retDur = 1.0;
design.SegmentDur = 0.30;
design.ISI = 0.15;

sessionN = 1;
participantID = 'TEST';
age = 25;
timestamp = datestr(now, 'yyyymmdd_HHMMSS');

% Generate trial matrix
fprintf('Generating trial matrix...\n');
[pracTrials, expTrials] = TrialMatrixSeq3way_STInte(design, sessionN, participantID, age, timestamp);

fprintf('\n=== LOCATION SPACING VERIFICATION ===\n\n');
fprintf('Total trials: %d\n\n', height(expTrials));

% Function to calculate circular distance
circdist = @(a,b) min(abs(a-b), 360-abs(a-b));

% Check each trial
violations = [];
for t = 1:height(expTrials)
    trial = expTrials(t,:);
    cond = trial.Condition{1};
    N = trial.ItemN;
    locs = trial.StimulusLocations{1};
    
    % Get unique locations used in this trial
    uniqueLocs = unique(locs);
    numUniqueLocs = length(uniqueLocs);
    
    % Expected number of unique locations
    if strcmp(cond, 'RS_TimeOnly')
        expectedNumLocs = N - trial.RedundantN + 1;
    else
        expectedNumLocs = N;  % All other conditions use N locations
    end
    
    % Check if we have the correct number of unique locations
    if numUniqueLocs ~= expectedNumLocs
        violations(end+1) = t;
        fprintf('VIOLATION: Trial %d (%s, N=%d): Expected %d unique locations, got %d\n', ...
            t, cond, N, expectedNumLocs, numUniqueLocs);
        fprintf('  Locations: %s\n', mat2str(sort(uniqueLocs)));
        fprintf('  All locations: %s\n', mat2str(locs));
        continue;
    end
    
    % Check if locations are evenly spaced
    % Sort locations
    sortedLocs = sort(uniqueLocs);
    
    % Calculate spacing between consecutive locations (including wrap-around)
    spacings = [];
    for i = 1:length(sortedLocs)
        if i < length(sortedLocs)
            spacing = circdist(sortedLocs(i), sortedLocs(i+1));
        else
            % Wrap around
            spacing = circdist(sortedLocs(end), sortedLocs(1));
        end
        spacings(end+1) = spacing;
    end
    
    % Expected spacing for evenly spaced locations
    expectedSpacing = 360 / numUniqueLocs;
    
    % Check if all spacings are approximately equal (within 1 degree tolerance)
    spacingVariance = std(spacings);
    if spacingVariance > 1
        violations(end+1) = t;
        fprintf('VIOLATION: Trial %d (%s, N=%d): Locations not evenly spaced\n', ...
            t, cond, N);
        fprintf('  Unique locations: %s\n', mat2str(sortedLocs));
        fprintf('  Spacings: %s (expected: %.1f°)\n', mat2str(spacings), expectedSpacing);
        fprintf('  Spacing std: %.2f°\n', spacingVariance);
    end
end

% Summary
fprintf('\n=== SUMMARY ===\n');
fprintf('Total trials: %d\n', height(expTrials));
fprintf('Spacing violations: %d (%.1f%%)\n', length(violations), ...
    100*length(violations)/height(expTrials));

if ~isempty(violations)
    fprintf('\n=== VIOLATIONS BY CONDITION ===\n');
    conds = unique(expTrials.Condition);
    for c = 1:length(conds)
        condTrials = strcmp(expTrials.Condition, conds{c});
        condViolations = sum(ismember(violations, find(condTrials)));
        fprintf('%s: %d violations out of %d trials\n', ...
            conds{c}, condViolations, sum(condTrials));
    end
else
    fprintf('\n✓ All trials have evenly spaced locations!\n');
end

fprintf('\nVerification complete!\n');

