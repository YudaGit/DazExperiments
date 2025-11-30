% Script to verify hue spacing in trial matrix generation
% Checks that all hues within each trial are at least 30 degrees apart

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

fprintf('\n=== TRIAL HUE SPACING VERIFICATION ===\n\n');
fprintf('Total trials: %d\n\n', height(expTrials));

% Function to calculate circular distance
circdist = @(a,b) min(abs(a-b), 360-abs(a-b));

% Check each trial
violations = [];
minDistances = [];
allHues = [];

for t = 1:height(expTrials)
    trial = expTrials(t,:);
    cond = trial.Condition{1};
    N = trial.ItemN;
    cols = trial.Colors{1};
    
    % Get all unique hues in this trial
    if strcmp(cond, 'Baseline')
        hues = cols;  % All unique
    else
        % For redundant conditions, get unique hues (redundant items have same hue)
        hues = unique(cols);
    end
    
    % Calculate minimum distance between any pair of hues
    minDist = 360;
    for i = 1:length(hues)
        for j = i+1:length(hues)
            dist = circdist(hues(i), hues(j));
            minDist = min(minDist, dist);
        end
    end
    
    minDistances(end+1) = minDist;
    allHues{end+1} = hues;
    
    % Check for violations (< 30 degrees)
    if minDist < 30
        violations(end+1) = t;
        fprintf('VIOLATION: Trial %d (%s, N=%d): min distance = %.1f°\n', ...
            t, cond, N, minDist);
        fprintf('  Hues: %s\n', mat2str(sort(hues)));
        fprintf('  All colors: %s\n', mat2str(cols));
    end
end

% Summary statistics
fprintf('\n=== SUMMARY ===\n');
fprintf('Total trials: %d\n', height(expTrials));
fprintf('Violations (< 30°): %d (%.1f%%)\n', length(violations), ...
    100*length(violations)/height(expTrials));
fprintf('Minimum distance across all trials: %.1f°\n', min(minDistances));
fprintf('Mean minimum distance: %.1f°\n', mean(minDistances));
fprintf('Median minimum distance: %.1f°\n', median(minDistances));

% Histogram of minimum distances
figure;
histogram(minDistances, 0:5:180);
xlabel('Minimum Hue Distance (degrees)');
ylabel('Number of Trials');
title('Distribution of Minimum Hue Distances Within Trials');
grid on;
hold on;
xline(30, 'r--', 'LineWidth', 2, 'DisplayName', '30° threshold');
legend('Trials', '30° threshold');

% Check if violations are clustered by condition
if ~isempty(violations)
    fprintf('\n=== VIOLATIONS BY CONDITION ===\n');
    for v = violations
        cond = expTrials.Condition{v}{1};
        fprintf('Trial %d: %s\n', v, cond);
    end
    
    % Count by condition
    conds = unique(expTrials.Condition);
    for c = 1:length(conds)
        condTrials = strcmp(expTrials.Condition, conds{c});
        condViolations = sum(ismember(violations, find(condTrials)));
        fprintf('%s: %d violations out of %d trials\n', ...
            conds{c}, condViolations, sum(condTrials));
    end
end

% Check hue distribution (are hues randomly distributed?)
fprintf('\n=== HUE DISTRIBUTION CHECK ===\n');
allUniqueHues = [];
for t = 1:height(expTrials)
    hues = allHues{t};
    allUniqueHues = [allUniqueHues, hues];
end

figure;
histogram(allUniqueHues, 0:30:360);
xlabel('Hue (degrees)');
ylabel('Frequency');
title('Distribution of All Hues Across All Trials');
grid on;

% Check if hues are uniformly distributed (Kolmogorov-Smirnov test)
if length(allUniqueHues) > 10
    [h, p] = kstest(allUniqueHues / 360);
    fprintf('Kolmogorov-Smirnov test for uniform distribution: p = %.4f\n', p);
    if p > 0.05
        fprintf('  Hues appear to be uniformly distributed (p > 0.05)\n');
    else
        fprintf('  WARNING: Hues may not be uniformly distributed (p = %.4f)\n', p);
    end
end

fprintf('\nVerification complete!\n');

