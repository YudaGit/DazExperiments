% Script to verify segment structure and timing for RS_TimeOnly
% Checks that each R item is a separate segment

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

fprintf('\n=== SEGMENT TIMING VERIFICATION ===\n\n');

% Check RS_TimeOnly trials specifically
rsTimeOnlyTrials = strcmp(expTrials.Condition, 'RS_TimeOnly');
rsTimeOnly = expTrials(rsTimeOnlyTrials, :);

fprintf('RS_TimeOnly trials: %d\n\n', height(rsTimeOnly));

violations = [];
for t = 1:height(rsTimeOnly)
    trial = rsTimeOnly(t,:);
    N = trial.ItemN;
    R = trial.RedundantN;
    segs = trial.SegmentOrder{1};
    locs = trial.StimulusLocations{1};
    
    % Check that we have exactly N segments
    if numel(segs) ~= N
        violations(end+1) = t;
        fprintf('VIOLATION: Trial %d (N=%d, R=%d): Expected %d segments, got %d\n', ...
            t, N, R, N, numel(segs));
        continue;
    end
    
    % Check that all segments are singletons
    allSingletons = true;
    for s = 1:numel(segs)
        if ~isscalar(segs{s})
            allSingletons = false;
            violations(end+1) = t;
            fprintf('VIOLATION: Trial %d (N=%d, R=%d): Segment %d is not singleton, has %d items\n', ...
                t, N, R, s, numel(segs{s}));
            break;
        end
    end
    
    % Check that R items appear consecutively
    % Count R segments
    rSegCount = 0;
    rSegPositions = [];
    for s = 1:numel(segs)
        itemIdx = segs{s};
        if itemIdx <= R  % R items are 1:R
            rSegCount = rSegCount + 1;
            rSegPositions(end+1) = s;
        end
    end
    
    if rSegCount ~= R
        violations(end+1) = t;
        fprintf('VIOLATION: Trial %d (N=%d, R=%d): Expected %d R segments, got %d\n', ...
            t, N, R, R, rSegCount);
    end
    
    % Check if R segments are consecutive
    if length(rSegPositions) > 1
        isConsecutive = all(diff(rSegPositions) == 1);
        if ~isConsecutive
            violations(end+1) = t;
            fprintf('VIOLATION: Trial %d (N=%d, R=%d): R segments not consecutive at positions %s\n', ...
                t, N, R, mat2str(rSegPositions));
        end
    end
    
    % Check that each R item appears exactly once
    rItemsFound = [];
    for s = 1:numel(segs)
        itemIdx = segs{s};
        if itemIdx <= R
            rItemsFound(end+1) = itemIdx;
        end
    end
    if length(unique(rItemsFound)) ~= R || length(rItemsFound) ~= R
        violations(end+1) = t;
        fprintf('VIOLATION: Trial %d (N=%d, R=%d): R items not correctly distributed\n', ...
            t, N, R);
        fprintf('  R items found: %s\n', mat2str(sort(rItemsFound)));
    end
    
    % Check locations for R items
    rLocs = [];
    for s = 1:numel(segs)
        itemIdx = segs{s};
        if itemIdx <= R
            rLocs(end+1) = locs(itemIdx);
        end
    end
    if length(unique(rLocs)) ~= 1
        violations(end+1) = t;
        fprintf('VIOLATION: Trial %d (N=%d, R=%d): R items not at same location\n', ...
            t, N, R);
        fprintf('  R item locations: %s\n', mat2str(rLocs));
    end
    
    % Print first few trials for inspection
    if t <= 3
        fprintf('\nTrial %d (N=%d, R=%d):\n', t, N, R);
        fprintf('  Segments: ');
        for s = 1:numel(segs)
            fprintf('[%d] ', segs{s});
        end
        fprintf('\n');
        fprintf('  Locations: %s\n', mat2str(locs));
        fprintf('  R item locations: %s\n', mat2str(unique(rLocs)));
        fprintf('  R segments at positions: %s\n', mat2str(rSegPositions));
    end
end

% Summary
fprintf('\n=== SUMMARY ===\n');
fprintf('RS_TimeOnly trials: %d\n', height(rsTimeOnly));
fprintf('Violations: %d (%.1f%%)\n', length(violations), ...
    100*length(violations)/height(rsTimeOnly));

if isempty(violations)
    fprintf('\n✓ All RS_TimeOnly trials have correct segment structure!\n');
    fprintf('  Each R item is a separate singleton segment\n');
    fprintf('  R items appear consecutively\n');
    fprintf('  All segments should receive equal timing (SegmentDur + ISI)\n');
end

fprintf('\nVerification complete!\n');

