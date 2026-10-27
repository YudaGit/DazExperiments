% Rename Precision_Col1 to TargetHue_Response and Precision_Col2 to BaseHue_Response

clear; close all; clc;

fprintf('=== Renaming Precision Columns ===\n\n');

% Data directory
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

% Process each file
for i = 1:length(files)
    filepath = fullfile(dataDir, files(i).name);
    participantMatch = regexp(files(i).name, 'HomoInte_([^_]+)_sess', 'tokens', 'once');
    if isempty(participantMatch)
        continue;
    end
    participantId = participantMatch{1};
    sessionNum = sessionNumbers(sortIdx(i));
    
    fprintf('Processing %s session %d: %s\n', participantId, sessionNum, files(i).name);
    
    data = load(filepath, 'expTrials');
    trials = data.expTrials;
    
    % Check if columns exist
    if ismember('Precision_Col1', trials.Properties.VariableNames)
        trials.TargetHue_Response = trials.Precision_Col1;
        trials = removevars(trials, 'Precision_Col1');
        fprintf('  Renamed Precision_Col1 -> TargetHue_Response\n');
    end
    
    if ismember('Precision_Col2', trials.Properties.VariableNames)
        trials.BaseHue_Response = trials.Precision_Col2;
        trials = removevars(trials, 'Precision_Col2');
        fprintf('  Renamed Precision_Col2 -> BaseHue_Response\n');
    end
    
    % Save updated data
    expTrials = trials;
    save(filepath, 'expTrials', '-v7.3');
    fprintf('  Saved: %s\n\n', files(i).name);
end

fprintf('=== Renaming Complete ===\n');
