% Check trial counts per condition for STInte data across all sessions
% This script loads all session files and counts trials by condition

fprintf('=== STInte Data Analysis: Trial Counts by Condition ===\n\n');

% Data directory
dataDir = 'Noise Pilot STInte Data';

% Find all session files
files = dir(fullfile(dataDir, 'STInte_*.mat'));
if isempty(files)
    error('No STInte data files found in %s', dataDir);
end

% Sort files by session number (extract from filename)
sessionNumbers = zeros(length(files), 1);
for i = 1:length(files)
    % Extract session number from filename: STInte_*_sessN_*.mat
    % Use regexp to find 'sess' followed by digits
    match = regexp(files(i).name, 'sess(\d+)', 'tokens');
    if ~isempty(match) && ~isempty(match{1})
        sessionNumbers(i) = str2double(match{1}{1});
    else
        % Fallback: try strsplit method
        parts = strsplit(files(i).name, '_');
        sessIdx = find(contains(parts, 'sess'), 1);
        if ~isempty(sessIdx) && sessIdx < length(parts)
            % Extract number from 'sessN' string
            sessStr = parts{sessIdx};
            numStr = regexp(sessStr, '\d+', 'match');
            if ~isempty(numStr)
                sessionNumbers(i) = str2double(numStr{1});
            end
        end
    end
end
[~, sortIdx] = sort(sessionNumbers);
files = files(sortIdx);

fprintf('Found %d session files:\n', length(files));
for i = 1:length(files)
    fprintf('  Session %d: %s\n', sessionNumbers(sortIdx(i)), files(i).name);
end
fprintf('\n');

% Initialize counters
allTrials = [];
sessionInfo = struct();

% Load all sessions
for i = 1:length(files)
    filepath = fullfile(dataDir, files(i).name);
    fprintf('Loading session %d...\n', sessionNumbers(sortIdx(i)));
    
    try
        data = load(filepath, 'expTrials');
        if ~isfield(data, 'expTrials')
            warning('Session %d: No expTrials found, skipping', sessionNumbers(sortIdx(i)));
            continue;
        end
        
        trials = data.expTrials;
        
        % Add session number to trials
        if istable(trials)
            trials.Session = repmat(sessionNumbers(sortIdx(i)), height(trials), 1);
        end
        
        % Store session info
        sessionInfo(i).session = sessionNumbers(sortIdx(i));
        sessionInfo(i).filename = files(i).name;
        sessionInfo(i).nTrials = height(trials);
        
        % Combine with all trials
        if isempty(allTrials)
            allTrials = trials;
        else
            allTrials = [allTrials; trials];
        end
        
        fprintf('  ✓ Loaded %d trials\n', height(trials));
        
    catch ME
        warning('Failed to load session %d: %s', sessionNumbers(sortIdx(i)), ME.message);
    end
end

fprintf('\n=== Total Trials Loaded: %d ===\n\n', height(allTrials));

% Check what condition columns exist
fprintf('Available columns in trial table:\n');
if istable(allTrials)
    fprintf('  %s\n', strjoin(allTrials.Properties.VariableNames, ', '));
end
fprintf('\n');

% Count trials by condition
if istable(allTrials)
    % Check for Condition column
    if ismember('Condition', allTrials.Properties.VariableNames)
        fprintf('=== Trial Counts by Condition ===\n\n');
        conditions = unique(allTrials.Condition);
        for cond = conditions(:)'
            if iscell(cond)
                condName = cond{1};
            else
                condName = char(cond);
            end
            count = sum(strcmp(allTrials.Condition, condName));
            fprintf('  %s: %d trials\n', condName, count);
        end
        fprintf('\n');
    end
    
    % Count by Condition × Set Size
    if ismember('Condition', allTrials.Properties.VariableNames) && ...
       ismember('ItemN', allTrials.Properties.VariableNames)
        fprintf('=== Trial Counts by Condition × Set Size ===\n\n');
        conditions = unique(allTrials.Condition);
        itemNs = unique(allTrials.ItemN);
        
        for cond = conditions(:)'
            if iscell(cond)
                condName = cond{1};
            else
                condName = char(cond);
            end
            fprintf('  %s:\n', condName);
            for n = itemNs(:)'
                count = sum(strcmp(allTrials.Condition, condName) & allTrials.ItemN == n);
                fprintf('    N=%d: %d trials\n', n, count);
            end
            fprintf('\n');
        end
    end
    
    % Count by Condition × Cue Type
    if ismember('Condition', allTrials.Properties.VariableNames) && ...
       ismember('CueType', allTrials.Properties.VariableNames)
        fprintf('=== Trial Counts by Condition × Cue Type ===\n\n');
        conditions = unique(allTrials.Condition);
        cueTypes = unique(allTrials.CueType);
        
        for cond = conditions(:)'
            if iscell(cond)
                condName = cond{1};
            else
                condName = char(cond);
            end
            fprintf('  %s:\n', condName);
            for cue = cueTypes(:)'
                if iscell(cue)
                    cueName = cue{1};
                else
                    cueName = char(cue);
                end
                count = sum(strcmp(allTrials.Condition, condName) & ...
                           strcmp(allTrials.CueType, cueName));
                fprintf('    %s: %d trials\n', cueName, count);
            end
            fprintf('\n');
        end
    end
    
    % Count by Condition × Set Size × Cue Type
    if ismember('Condition', allTrials.Properties.VariableNames) && ...
       ismember('ItemN', allTrials.Properties.VariableNames) && ...
       ismember('CueType', allTrials.Properties.VariableNames)
        fprintf('=== Trial Counts by Condition × Set Size × Cue Type ===\n\n');
        conditions = unique(allTrials.Condition);
        itemNs = unique(allTrials.ItemN);
        cueTypes = unique(allTrials.CueType);
        
        for cond = conditions(:)'
            if iscell(cond)
                condName = cond{1};
            else
                condName = char(cond);
            end
            fprintf('  %s:\n', condName);
            for n = itemNs(:)'
                fprintf('    N=%d:\n', n);
                for cue = cueTypes(:)'
                    if iscell(cue)
                        cueName = cue{1};
                    else
                        cueName = char(cue);
                    end
                    count = sum(strcmp(allTrials.Condition, condName) & ...
                               allTrials.ItemN == n & ...
                               strcmp(allTrials.CueType, cueName));
                    fprintf('      %s: %d trials\n', cueName, count);
                end
            end
            fprintf('\n');
        end
    end
    
    % Count by Condition × Noise Level (if available)
    if ismember('Condition', allTrials.Properties.VariableNames) && ...
       ismember('NoiseLevel', allTrials.Properties.VariableNames)
        fprintf('=== Trial Counts by Condition × Noise Level ===\n\n');
        conditions = unique(allTrials.Condition);
        noiseLevels = unique(allTrials.NoiseLevel);
        
        for cond = conditions(:)'
            if iscell(cond)
                condName = cond{1};
            else
                condName = char(cond);
            end
            fprintf('  %s:\n', condName);
            for noise = noiseLevels(:)'
                if iscell(noise)
                    noiseName = noise{1};
                else
                    noiseName = char(noise);
                end
                count = sum(strcmp(allTrials.Condition, condName) & ...
                           strcmp(allTrials.NoiseLevel, noiseName));
                fprintf('    %s: %d trials\n', noiseName, count);
            end
            fprintf('\n');
        end
    end
    
    % Count by Session
    if ismember('Session', allTrials.Properties.VariableNames)
        fprintf('=== Trial Counts by Session ===\n\n');
        sessions = unique(allTrials.Session);
        for sess = sessions(:)'
            count = sum(allTrials.Session == sess);
            fprintf('  Session %d: %d trials\n', sess, count);
        end
        fprintf('\n');
    end
end

fprintf('=== Summary ===\n');
fprintf('Total sessions: %d\n', length(files));
fprintf('Total trials: %d\n', height(allTrials));
fprintf('\nAnalysis complete!\n');

