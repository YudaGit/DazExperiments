% Script to verify ACW progression in trial matrix generation
% Checks that all trials follow ACW progression

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

fprintf('\n=== ACW PROGRESSION VERIFICATION ===\n\n');
fprintf('Total trials: %d\n\n', height(expTrials));

% Function to calculate circular distance
circdist = @(a,b) min(abs(a-b), 360-abs(a-b));

% Function to check ACW progression
function isValid = checkACWProgression(locs, allLocs)
    % Check if locs follows ACW progression
    % locs: sequence of location angles
    % allLocs: all available location angles
    
    isValid = true;
    for i = 2:length(locs)
        prevAngle = locs(i-1);
        currAngle = locs(i);
        
        % If same location (redundant items), that's fine - skip check
        if currAngle == prevAngle
            continue;
        end
        
        % Find all remaining locations ACW from prevAngle
        remainingLocs = setdiff(allLocs, locs(1:i-1));
        % Also include current location if it's not already in remaining
        if ~ismember(currAngle, remainingLocs)
            remainingLocs = [remainingLocs, currAngle];
        end
        
        if ~isempty(remainingLocs)
            % Calculate ACW distances from prevAngle
            distances = mod(remainingLocs - prevAngle + 360, 360);
            % Find minimum ACW distance
            minACWDist = min(distances);
            % Current should be the closest ACW location
            currDist = mod(currAngle - prevAngle + 360, 360);
            
            % Check if current is the closest ACW (within 1 degree tolerance)
            if abs(currDist - minACWDist) > 1
                isValid = false;
                return;
            end
        end
    end
end

% Check each trial
violations = [];
for t = 1:height(expTrials)
    trial = expTrials(t,:);
    cond = trial.Condition{1};
    N = trial.ItemN;
    locs = trial.StimulusLocations{1};
    segs = trial.SegmentOrder{1};
    
    % Build location sequence from segments
    locSequence = [];
    for s = 1:numel(segs)
        idxList = segs{s};
        for idx = idxList
            locSequence(end+1) = locs(idx);
        end
    end
    
    % Get all unique locations for this trial
    allUniqueLocs = unique(locs);
    
    % Check ACW progression
    isValid = checkACWProgression(locSequence, allUniqueLocs);
    
    if ~isValid
        violations(end+1) = t;
        fprintf('VIOLATION: Trial %d (%s, N=%d)\n', t, cond, N);
        fprintf('  Location sequence: %s\n', mat2str(locSequence));
        fprintf('  Unique locations: %s\n', mat2str(sort(allUniqueLocs)));
        fprintf('  Segment order: ');
        for s = 1:numel(segs)
            fprintf('[%s] ', mat2str(segs{s}));
        end
        fprintf('\n');
        
        % Show ACW distances
        fprintf('  ACW distances:\n');
        for i = 2:length(locSequence)
            prevAngle = locSequence(i-1);
            currAngle = locSequence(i);
            if currAngle ~= prevAngle
                dist = mod(currAngle - prevAngle + 360, 360);
                fprintf('    %.1f° -> %.1f°: %.1f° ACW\n', prevAngle, currAngle, dist);
            else
                fprintf('    %.1f° -> %.1f°: SAME LOCATION (redundant)\n', prevAngle, currAngle);
            end
        end
        fprintf('\n');
    end
end

% Summary
fprintf('=== SUMMARY ===\n');
fprintf('Total trials: %d\n', height(expTrials));
fprintf('ACW violations: %d (%.1f%%)\n', length(violations), ...
    100*length(violations)/height(expTrials));

if ~isempty(violations)
    fprintf('\n=== VIOLATIONS BY CONDITION ===\n');
    for v = violations
        condVal = expTrials.Condition{v};
        if iscell(condVal)
            cond = condVal{1};
        else
            cond = char(condVal);
        end
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
else
    fprintf('\n✓ All trials follow ACW progression!\n');
end

fprintf('\nVerification complete!\n');

