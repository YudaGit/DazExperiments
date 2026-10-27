% Count trials by condition for YDL's 8 sessions
% Counts for: Baseline/Homo_Space × Low/High Noise × Set Size 2/6

clear; close all; clc;

fprintf('=== Counting Trials for YDL (8 sessions) ===\n\n');

% Data directory (script runs from within the data folder)
dataDir = '.';

% Find all YDL session files
files = dir(fullfile(dataDir, 'HomoInte_YDL_*.mat'));
if isempty(files)
    error('No YDL data files found in %s', dataDir);
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

fprintf('Found %d YDL sessions\n\n', length(files));

% Load all sessions
allTrials = [];
for i = 1:length(files)
    filepath = fullfile(dataDir, files(i).name);
    fprintf('Loading session %d: %s\n', sessionNumbers(sortIdx(i)), files(i).name);
    
    data = load(filepath, 'expTrials');
    if ~isfield(data, 'expTrials')
        warning('Session %d: No expTrials found, skipping', sessionNumbers(sortIdx(i)));
        continue;
    end
    
    trials = data.expTrials;
    if istable(trials)
        trials.Session = repmat(sessionNumbers(sortIdx(i)), height(trials), 1);
        trials.Participant = repmat({'YDL'}, height(trials), 1);
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

fprintf('\nTotal trials loaded: %d\n\n', height(allTrials));

% Check required columns
requiredCols = {'Condition', 'NoiseLevel', 'ItemN'};
missingCols = setdiff(requiredCols, allTrials.Properties.VariableNames);
if ~isempty(missingCols)
    error('Missing required columns: %s', strjoin(missingCols, ', '));
end

% Initialize counts
conditions = {'Baseline', 'Homo_Space'};
noiseLevels = {'low', 'high'};
itemNs = [2, 6];

% Create count table
fprintf('=== Trial Counts ===\n\n');

% Print header
fprintf('%-15s %-10s %-10s %-10s\n', 'Condition', 'Noise', 'Set Size', 'Count');
fprintf('%s\n', repmat('-', 1, 50));

totalCount = 0;
for c = 1:length(conditions)
    cond = conditions{c};
    for n = 1:length(noiseLevels)
        noise = noiseLevels{n};
        for i = 1:length(itemNs)
            itemN = itemNs(i);
            
            % Count trials matching this condition
            idx = strcmp(allTrials.Condition, cond) & ...
                  strcmp(allTrials.NoiseLevel, noise) & ...
                  allTrials.ItemN == itemN;
            
            count = sum(idx);
            totalCount = totalCount + count;
            
            fprintf('%-15s %-10s %-10d %-10d\n', cond, noise, itemN, count);
        end
    end
end

fprintf('%s\n', repmat('-', 1, 50));
fprintf('%-15s %-10s %-10s %-10d\n', 'TOTAL', '', '', totalCount);

% Also show breakdown by session
fprintf('\n\n=== Breakdown by Session ===\n\n');
sessions = unique(allTrials.Session, 'stable');
for s = 1:length(sessions)
    sessNum = sessions(s);
    sessTrials = allTrials(allTrials.Session == sessNum, :);
    fprintf('Session %d: %d trials\n', sessNum, height(sessTrials));
    
    for c = 1:length(conditions)
        cond = conditions{c};
        for n = 1:length(noiseLevels)
            noise = noiseLevels{n};
            for i = 1:length(itemNs)
                itemN = itemNs(i);
                idx = strcmp(sessTrials.Condition, cond) & ...
                      strcmp(sessTrials.NoiseLevel, noise) & ...
                      sessTrials.ItemN == itemN;
                count = sum(idx);
                if count > 0
                    fprintf('  %s, %s, N=%d: %d\n', cond, noise, itemN, count);
                end
            end
        end
    end
    fprintf('\n');
end

fprintf('=== Analysis Complete ===\n');

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
