% Compute MeanOffsets statistics for Homo_Space, high noise trials
% For set sizes 2 and 6

clear; close all; clc;

fprintf('=== Computing MeanOffsets Statistics ===\n\n');

% Data directory (script runs from within the data folder)
dataDir = '.';

% Find all session files
files = dir(fullfile(dataDir, 'HomoInte_*.mat'));
if isempty(files)
    error('No HomoInte data files found in %s', dataDir);
end

% Sort files by session number
sessionNumbers = zeros(length(files), 1);
for i = 1:length(files)
    match = regexp(files(i).name, 'sess(\d+)', 'tokens');
    if ~isempty(match) && ~isempty(match{1})
        sessionNumbers(i) = str2double(match{1}{1});
    end
end
[~, sortIdx] = sort(sessionNumbers);
files = files(sortIdx);

% Load all sessions
allTrials = [];
for i = 1:length(files)
    filepath = fullfile(dataDir, files(i).name);
    participantMatch = regexp(files(i).name, 'HomoInte_([^_]+)_sess', 'tokens', 'once');
    if isempty(participantMatch)
        warning('Skipping file with unrecognized participant: %s', files(i).name);
        continue;
    end
    participantId = participantMatch{1};
    fprintf('Loading %s session %d...\n', participantId, sessionNumbers(sortIdx(i)));
    
    data = load(filepath, 'expTrials');
    if ~isfield(data, 'expTrials')
        warning('Session %d: No expTrials found, skipping', sessionNumbers(sortIdx(i)));
        continue;
    end
    
    trials = data.expTrials;
    if istable(trials)
        trials.Session = repmat(sessionNumbers(sortIdx(i)), height(trials), 1);
        trials.Participant = repmat({participantId}, height(trials), 1);
    end
    
    if isempty(allTrials)
        allTrials = trials;
    else
        % Align table variables before concatenation
        allVarNames = union(allTrials.Properties.VariableNames, trials.Properties.VariableNames);
        for v = 1:numel(allVarNames)
            varName = allVarNames{v};
            if ~ismember(varName, allTrials.Properties.VariableNames)
                allTrials.(varName) = makeMissingColumn(trials.(varName), height(allTrials));
            end
            if ~ismember(varName, trials.Properties.VariableNames)
                trials.(varName) = makeMissingColumn(allTrials.(varName), height(trials));
            end
        end
        % Ensure same variable order
        allTrials = allTrials(:, allVarNames);
        trials = trials(:, allVarNames);
        allTrials = [allTrials; trials];
    end
end

% Check if MeanOffsets column exists
if ~ismember('MeanOffsets', allTrials.Properties.VariableNames)
    error('MeanOffsets column not found in data');
end

% Filter for Homo_Space, high noise trials
fprintf('\n=== Filtering Data ===\n');
homoSpaceHighNoise = allTrials(strcmp(allTrials.Condition, 'Homo_Space') & ...
                               strcmp(allTrials.NoiseLevel, 'high'), :);

fprintf('Total Homo_Space, high noise trials: %d\n', height(homoSpaceHighNoise));

% Separate by set size
trials_N2 = homoSpaceHighNoise(homoSpaceHighNoise.ItemN == 2, :);
trials_N6 = homoSpaceHighNoise(homoSpaceHighNoise.ItemN == 6, :);

fprintf('Set size 2 trials: %d\n', height(trials_N2));
fprintf('Set size 6 trials: %d\n', height(trials_N6));

% ============================================================================
% Set Size 2 Analysis
% ============================================================================
fprintf('\n=== Set Size 2 (Homo_Space, High Noise) ===\n');

if height(trials_N2) > 0
    % Extract all individual mean offsets
    allIndividualOffsets_N2 = [];
    trialMeans_N2 = [];
    
    for i = 1:height(trials_N2)
        offsets = trials_N2.MeanOffsets{i};
        if isnumeric(offsets) && numel(offsets) == 2
            % Collect individual offsets
            allIndividualOffsets_N2 = [allIndividualOffsets_N2, offsets(:)'];
            % Compute mean of offsets for this trial
            trialMeans_N2 = [trialMeans_N2, mean(offsets)];
        else
            warning('Trial %d: Unexpected MeanOffsets format', i);
        end
    end
    
    fprintf('\n1. Individual Mean Offsets (all %d values):\n', length(allIndividualOffsets_N2));
    fprintf('   Range: [%.6f, %.6f] deg\n', min(allIndividualOffsets_N2), max(allIndividualOffsets_N2));
    fprintf('   Mean: %.6f deg\n', mean(allIndividualOffsets_N2));
    fprintf('   SD: %.6f deg\n', std(allIndividualOffsets_N2));
    
    fprintf('\n2. Trial Means (mean of MeanOffsets for each trial, %d values):\n', length(trialMeans_N2));
    fprintf('   Range: [%.6f, %.6f] deg\n', min(trialMeans_N2), max(trialMeans_N2));
    fprintf('   Mean: %.6f deg\n', mean(trialMeans_N2));
    fprintf('   SD: %.6f deg\n', std(trialMeans_N2));
else
    fprintf('No set size 2 trials found.\n');
end

% ============================================================================
% Set Size 6 Analysis
% ============================================================================
fprintf('\n=== Set Size 6 (Homo_Space, High Noise) ===\n');

if height(trials_N6) > 0
    % Extract all individual mean offsets
    allIndividualOffsets_N6 = [];
    trialMeans_N6 = [];
    
    for i = 1:height(trials_N6)
        offsets = trials_N6.MeanOffsets{i};
        if isnumeric(offsets) && numel(offsets) == 6
            % Collect individual offsets
            allIndividualOffsets_N6 = [allIndividualOffsets_N6, offsets(:)'];
            % Compute mean of offsets for this trial
            trialMeans_N6 = [trialMeans_N6, mean(offsets)];
        else
            warning('Trial %d: Unexpected MeanOffsets format', i);
        end
    end
    
    fprintf('\n1. Individual Mean Offsets (all %d values):\n', length(allIndividualOffsets_N6));
    fprintf('   Range: [%.6f, %.6f] deg\n', min(allIndividualOffsets_N6), max(allIndividualOffsets_N6));
    fprintf('   Mean: %.6f deg\n', mean(allIndividualOffsets_N6));
    fprintf('   SD: %.6f deg\n', std(allIndividualOffsets_N6));
    
    fprintf('\n2. Trial Means (mean of MeanOffsets for each trial, %d values):\n', length(trialMeans_N6));
    fprintf('   Range: [%.6f, %.6f] deg\n', min(trialMeans_N6), max(trialMeans_N6));
    fprintf('   Mean: %.6f deg\n', mean(trialMeans_N6));
    fprintf('   SD: %.6f deg\n', std(trialMeans_N6));
else
    fprintf('No set size 6 trials found.\n');
end

fprintf('\n=== Analysis Complete ===\n');

% Helper function to make missing columns
function col = makeMissingColumn(templateColumn, nRows)
    if isnumeric(templateColumn)
        col = nan(nRows, 1);
    elseif islogical(templateColumn)
        col = false(nRows, 1);
    elseif isstring(templateColumn)
        col = strings(nRows, 1);
    elseif iscategorical(templateColumn)
        col = categorical(repmat(missing, nRows, 1));
    elseif iscell(templateColumn)
        col = cell(nRows, 1);
    else
        col = repmat(missing, nRows, 1);
    end
end
