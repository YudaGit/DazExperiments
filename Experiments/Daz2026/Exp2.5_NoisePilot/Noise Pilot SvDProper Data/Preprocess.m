clear; close all; clc;

fprintf('=== Loading SvDProper Data ===\n\n');

% Data directory (script runs from within the data folder)
dataDir = '.';

% Participants to include (leave empty to include all)
participantsToInclude = {'YL'};

% Find all session files
files = dir(fullfile(dataDir, 'SvDProper_*.mat'));
if isempty(files)
    error('No SvDProper data files found in %s', dataDir);
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
    participantMatch = regexp(files(i).name, 'SvDProper_([^_]+)_sess', 'tokens', 'once');
    if isempty(participantMatch)
        warning('Skipping file with unrecognized participant: %s', files(i).name);
        continue;
    end
    participantId = participantMatch{1};
    if ~isempty(participantsToInclude) && ~ismember(participantId, participantsToInclude)
        continue;
    end
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

% Filter out invalid trials (missing precision or RT)
validIdx = ~isnan(allTrials.Precision) & ~isnan(allTrials.ResponseTime) & ...
           allTrials.ResponseTime > 0;
allTrials = allTrials(validIdx, :);

% Split by participant
allTrialsAll = allTrials;
participants = unique(allTrialsAll.Participant, 'stable');

% Save combined trials table to CSV (same folder as the .mat sources)
pTag = strjoin(participantsToInclude, '_');
if isempty(pTag)
    pTag = 'allParticipants';
end
csvFile = fullfile(dataDir, sprintf('allTrials_%s.csv', pTag));
writetable(allTrials, csvFile);
fprintf('\nSaved %d rows × %d columns to %s\n', height(allTrials), width(allTrials), csvFile);