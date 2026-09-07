% AssessYLPreliminary.m
% Preliminary quality-control, preparation, and plotting for YL sessions.
% Loads completed session files only (not recovery checkpoints), verifies the
% trial structure and planned balance, then saves a combined table, QC tables,
% and a raw-error / conditional circular-SD figure.

clear; clc;

scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end
dataDir = fullfile(scriptDir, 'Daz25EncodingData');
outputDir = fullfile(dataDir, 'PreliminaryReview');
if ~isfolder(outputDir)
    mkdir(outputDir);
end

participantID = "YL";
expectedTrialsPerCell = 35;
setSizes = [2 4 6];
durations = [0.05 0.25];
conditionTypes = ["B" "R" "NR"];

files = dir(fullfile(dataDir, sprintf('EncodingData_%s_sess*.mat', participantID)));
files = files(~endsWith(string({files.name}), "_checkpoint.mat"));
if isempty(files)
    error('No completed data files found for participant %s in %s.', participantID, dataDir);
end
[~, order] = sort({files.name});
files = files(order);

allTrials = table();
for fileIdx = 1:numel(files)
    loaded = load(fullfile(files(fileIdx).folder, files(fileIdx).name), 'expTrials');
    if ~isfield(loaded, 'expTrials') || ~istable(loaded.expTrials)
        error('%s does not contain an expTrials table.', files(fileIdx).name);
    end
    sessionTrials = loaded.expTrials;
    sessionTrials.SourceFile = repmat(string(files(fileIdx).name), height(sessionTrials), 1);
    allTrials = [allTrials; sessionTrials]; %#ok<AGROW>
end

% Derive analysis-only variables from the unchanged Experiment 1 schema.
nTrials = height(allTrials);
cueType = string(allTrials.CueType);
allTrials.ColorN = allTrials.ItemN;
isRedundantArray = allTrials.RedundantN > 0;
allTrials.ColorN(isRedundantArray) = allTrials.ItemN(isRedundantArray) ...
    - allTrials.RedundantN(isRedundantArray) + 1;
allTrials.ConditionType = cueType;
allTrials.ConditionType(~isRedundantArray) = "B";
allTrials.Condition = "S" + string(allTrials.ItemN) + "C" ...
    + string(allTrials.ColorN) + "_" + allTrials.ConditionType;
allTrials.AbsPrecision = abs(allTrials.Precision);

% Validate stimulus construction and target-category assignment.
stimulusOK = false(nTrials, 1);
targetOK = false(nTrials, 1);
cueAssignmentOK = false(nTrials, 1);
for trialIdx = 1:nTrials
    nItems = allTrials.ItemN(trialIdx);
    repeatedN = allTrials.RedundantN(trialIdx);
    target = allTrials.Target(trialIdx);
    colors = allTrials.Colors{trialIdx};
    locations = allTrials.StimulusLocations{trialIdx};
    expectedColorN = nItems;
    if repeatedN > 0
        expectedColorN = nItems - repeatedN + 1;
    end
    stimulusOK(trialIdx) = numel(colors) == nItems ...
        && numel(locations) == nItems ...
        && numel(unique(colors)) == expectedColorN;
    targetOK(trialIdx) = isfinite(target) && target == floor(target) ...
        && target >= 1 && target <= nItems;
    if targetOK(trialIdx)
        targetFrequency = sum(colors == colors(target));
        if repeatedN == 0
            cueAssignmentOK(trialIdx) = cueType(trialIdx) == "NR" ...
                && targetFrequency == 1;
        elseif cueType(trialIdx) == "R"
            cueAssignmentOK(trialIdx) = targetFrequency == repeatedN;
        elseif cueType(trialIdx) == "NR"
            cueAssignmentOK(trialIdx) = targetFrequency == 1;
        end
    end
end

hasFiniteResponse = isfinite(allTrials.Precision) ...
    & isfinite(allTrials.ResponseTime) & allTrials.ResponseTime > 0;
withinCircularRange = ~hasFiniteResponse ...
    | (allTrials.Precision >= -180 & allTrials.Precision <= 180);
speedFlag = allTrials.TrialTooSlow == 1 ...
    | allTrials.MouseInitTooSlow == 1 | allTrials.MouseInitTooFast == 1;

allTrials.StimulusOK = stimulusOK;
allTrials.TargetOK = targetOK;
allTrials.CueAssignmentOK = cueAssignmentOK;
allTrials.HasFiniteResponse = hasFiniteResponse;
allTrials.WithinCircularRange = withinCircularRange;
allTrials.SpeedFlag = speedFlag;
allTrials.IsUsable = stimulusOK & targetOK & cueAssignmentOK ...
    & hasFiniteResponse & withinCircularRange & ~speedFlag;

% Planned-cell balance: each session should contain 35 trials for every
% valid condition × duration combination.
balanceBySession = table();
for session = unique(allTrials.SessionN)'
    for setSize = setSizes
        for duration = durations
            for conditionType = conditionTypes
                validCell = (setSize == 2 && conditionType == "B") ...
                    || (setSize > 2);
                if ~validCell
                    continue
                end
                inCell = allTrials.SessionN == session ...
                    & allTrials.ItemN == setSize ...
                    & allTrials.PresDur == duration ...
                    & allTrials.ConditionType == conditionType;
                cellN = sum(inCell);
                cellTargets = allTrials.Target(inCell);
                validTargets = isfinite(cellTargets) & cellTargets == floor(cellTargets) ...
                    & cellTargets >= 1 & cellTargets <= setSize;
                targetCounts = accumarray(cellTargets(validTargets), 1, [setSize 1], @sum, 0);
                row = table(session, setSize, duration, conditionType, cellN, ...
                    min(targetCounts), max(targetCounts), ...
                    'VariableNames', {'SessionN','ItemN','PresDur','ConditionType', ...
                    'TrialN','MinTargetIndexN','MaxTargetIndexN'});
                balanceBySession = [balanceBySession; row]; %#ok<AGROW>
            end
        end
    end
end
balanceBySession.IsBalanced = balanceBySession.TrialN == expectedTrialsPerCell;

% Circular SD is calculated from signed response error among usable trials.
conditionSummary = table();
for setSize = setSizes
    for duration = durations
        for conditionType = conditionTypes
            inCondition = allTrials.ItemN == setSize ...
                & allTrials.PresDur == duration ...
                & allTrials.ConditionType == conditionType;
            if ~any(inCondition)
                continue
            end
            usable = inCondition & allTrials.IsUsable;
            errors = allTrials.Precision(usable);
            resultantLength = abs(mean(exp(1i * deg2rad(errors))));
            cirSD = rad2deg(sqrt(-2 * log(max(resultantLength, realmin))));
            row = table(setSize, duration, conditionType, sum(inCondition), ...
                sum(usable), mean(abs(errors), 'omitnan'), cirSD, ...
                'VariableNames', {'ItemN','PresDur','ConditionType','TrialN', ...
                'UsableN','MeanAbsPrecision','CirSD'});
            conditionSummary = [conditionSummary; row]; %#ok<AGROW>
        end
    end
end

% Session-level QC summary.
sessionQC = table();
for session = unique(allTrials.SessionN)'
    inSession = allTrials.SessionN == session;
    row = table(session, sum(inSession), sum(allTrials.IsUsable(inSession)), ...
        sum(~allTrials.HasFiniteResponse(inSession)), sum(allTrials.SpeedFlag(inSession)), ...
        sum(~allTrials.StimulusOK(inSession)), sum(~allTrials.TargetOK(inSession)), ...
        sum(~allTrials.CueAssignmentOK(inSession)), ...
        'VariableNames', {'SessionN','TrialN','UsableN','MissingResponseN', ...
        'SpeedFlagN','StimulusProblemN','TargetProblemN','CueProblemN'});
    sessionQC = [sessionQC; row]; %#ok<AGROW>
end

% Save analysis-ready data and human-readable QC tables.
save(fullfile(outputDir, 'YL_preliminary_combined.mat'), 'allTrials', ...
    'balanceBySession', 'conditionSummary', 'sessionQC');
writetable(balanceBySession, fullfile(outputDir, 'YL_trial_balance.csv'));
writetable(conditionSummary, fullfile(outputDir, 'YL_condition_summary.csv'));
writetable(sessionQC, fullfile(outputDir, 'YL_session_QC.csv'));

fprintf('\nLoaded %d completed sessions and %d total trials for %s.\n', ...
    numel(files), nTrials, participantID);
disp(sessionQC);
if all(balanceBySession.IsBalanced)
    fprintf('Balance check passed: every valid session × condition × duration cell has %d trials.\n', ...
        expectedTrialsPerCell);
else
    warning('At least one planned cell does not have %d trials. See YL_trial_balance.csv.', ...
        expectedTrialsPerCell);
end
if all(sessionQC.StimulusProblemN == 0) && all(sessionQC.TargetProblemN == 0) ...
        && all(sessionQC.CueProblemN == 0)
    fprintf('Stimulus, target, and R/NR assignment checks passed for all trials.\n');
else
    warning('Stimulus, target, or cue-assignment checks failed. Inspect YL_session_QC.csv.');
end

% Plot: raw absolute errors are semi-transparent; filled diamonds show the
% conditional circular SD of signed error. Both are in degrees.
typeColors = [0.20 0.55 0.85; 0.85 0.30 0.20; 0.20 0.65 0.35]; % B, R, NR
typeOffsets = [-0.20 0 0.20];
rng(1); % Reproducible horizontal jitter only.
figure('Color', 'w', 'Position', [100 100 1200 620]);
hold on;
legendHandles = gobjects(numel(conditionTypes), 1);

for typeIdx = 1:numel(conditionTypes)
    type = conditionTypes(typeIdx);
    color = typeColors(typeIdx, :);
    for setIdx = 1:numel(setSizes)
        for durationIdx = 1:numel(durations)
            xCenter = (setIdx - 1) * numel(durations) + durationIdx;
            inCell = allTrials.ItemN == setSizes(setIdx) ...
                & allTrials.PresDur == durations(durationIdx) ...
                & allTrials.ConditionType == type ...
                & allTrials.IsUsable;
            if ~any(inCell)
                continue
            end
            x = xCenter + typeOffsets(typeIdx) + 0.12 * (rand(sum(inCell), 1) - 0.5);
            scatter(x, allTrials.AbsPrecision(inCell), 24, color, 'filled', ...
                'MarkerFaceAlpha', 0.22, 'MarkerEdgeAlpha', 0.12);
            if ~isgraphics(legendHandles(typeIdx))
                legendHandles(typeIdx) = plot(nan, nan, 'o', 'MarkerSize', 7, ...
                    'MarkerFaceColor', color, 'MarkerEdgeColor', color, ...
                    'LineStyle', 'none');
            end
            summaryCell = conditionSummary.ItemN == setSizes(setIdx) ...
                & conditionSummary.PresDur == durations(durationIdx) ...
                & conditionSummary.ConditionType == type;
            if any(summaryCell)
                scatter(xCenter + typeOffsets(typeIdx), conditionSummary.CirSD(summaryCell), ...
                    173, color, 'd', 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.9);
            end
        end
    end
end

xline(2.5, ':', 'Color', [0.45 0.45 0.45]);
xline(4.5, ':', 'Color', [0.45 0.45 0.45]);
xticks(1:6);
xticklabels(repmat({'50 ms','250 ms'}, 1, 3));
xlim([0.45 6.55]);
ylim([0 195]);
ylabel('Absolute response error / circular SD (degrees)');
xlabel('Encoding duration, grouped by set size');
text(1.5, 187, 'Set size 2', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
text(3.5, 187, 'Set size 4', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
text(5.5, 187, 'Set size 6', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
title(sprintf('%s preliminary data: raw error and conditional circular SD', participantID));
legend(legendHandles(isgraphics(legendHandles)), cellstr(conditionTypes(isgraphics(legendHandles))), ...
    'Location', 'northwest', 'Box', 'off');
grid on; box off;

plotBase = fullfile(outputDir, 'YL_preliminary_error_and_cirSD');
exportgraphics(gcf, [plotBase '.png'], 'Resolution', 300);
