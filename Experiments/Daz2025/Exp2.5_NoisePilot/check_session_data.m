% Script to check session data: trial counts, balancing, and data recording
% Load and analyze the first session data

clear; close all;

% Load the data file
dataFile = 'Noise Pilot HomoInte Data\HomoInte_YDL_sess1_2025-11-30_13-38-59.mat';
fprintf('Loading data from: %s\n\n', dataFile);
load(dataFile);

% Check trial count
nTrials = height(expTrials);
fprintf('=== TRIAL COUNT ===\n');
fprintf('Total trials saved: %d\n', nTrials);
fprintf('Expected: 96 trials\n');
if nTrials == 96
    fprintf('✓ Trial count is correct!\n');
elseif nTrials == 192
    fprintf('✗ WARNING: 192 trials found (double the expected amount)\n');
else
    fprintf('✗ Unexpected trial count\n');
end
fprintf('\n');

% Check balancing across conditions
fprintf('=== CONDITION BALANCING ===\n');

% Set Size
fprintf('\nSet Size:\n');
setSizes = unique(expTrials.ItemN);
for ss = setSizes'
    count = sum(expTrials.ItemN == ss);
    fprintf('  N=%d: %d trials (%.1f%%)\n', ss, count, 100*count/nTrials);
end

% Noise Level
fprintf('\nNoise Level:\n');
if iscell(expTrials.NoiseLevel)
    noiseLevels = unique(cellfun(@char, expTrials.NoiseLevel, 'UniformOutput', false));
    for nl = noiseLevels'
        count = sum(cellfun(@(x) strcmp(char(x), char(nl{1})), expTrials.NoiseLevel));
        fprintf('  %s: %d trials (%.1f%%)\n', char(nl{1}), count, 100*count/nTrials);
    end
else
    noiseLevels = unique(expTrials.NoiseLevel);
    for nl = noiseLevels'
        count = sum(expTrials.NoiseLevel == nl);
        fprintf('  %s: %d trials (%.1f%%)\n', char(nl), count, 100*count/nTrials);
    end
end

% Condition Type
fprintf('\nCondition Type:\n');
if iscell(expTrials.Condition)
    conditions = unique(cellfun(@char, expTrials.Condition, 'UniformOutput', false));
    for cond = conditions'
        count = sum(cellfun(@(x) strcmp(char(x), char(cond{1})), expTrials.Condition));
        fprintf('  %s: %d trials\n', char(cond{1}), count);
    end
else
    conditions = unique(expTrials.Condition);
    for cond = conditions'
        count = sum(expTrials.Condition == cond);
        fprintf('  %s: %d trials\n', char(cond), count);
    end
end

% Cross-tabulation: Set Size × Noise Level × Condition
fprintf('\n=== DETAILED BALANCING (Set Size × Noise Level × Condition) ===\n');
setSizes = unique(expTrials.ItemN);
if iscell(expTrials.NoiseLevel)
    noiseLevels = unique(cellfun(@char, expTrials.NoiseLevel, 'UniformOutput', false));
else
    noiseLevels = unique(expTrials.NoiseLevel);
end
if iscell(expTrials.Condition)
    conditions = unique(cellfun(@char, expTrials.Condition, 'UniformOutput', false));
else
    conditions = unique(expTrials.Condition);
end

for ss = setSizes'
    for nl = noiseLevels'
        for cond = conditions'
            if iscell(expTrials.NoiseLevel)
                nlMatch = cellfun(@(x) strcmp(char(x), char(nl{1})), expTrials.NoiseLevel);
            else
                nlMatch = expTrials.NoiseLevel == nl;
            end
            if iscell(expTrials.Condition)
                condMatch = cellfun(@(x) strcmp(char(x), char(cond{1})), expTrials.Condition);
            else
                condMatch = expTrials.Condition == cond;
            end
            count = sum(expTrials.ItemN == ss & nlMatch & condMatch);
            if count > 0
                nlStr = char(nl); if iscell(nlStr), nlStr = nlStr{1}; end
                condStr = char(cond); if iscell(condStr), condStr = condStr{1}; end
                fprintf('  N=%d, %s, %s: %d trials\n', ss, nlStr, condStr, count);
            end
        end
    end
end

% Check data recording completeness
fprintf('\n=== DATA RECORDING COMPLETENESS ===\n');
requiredFields = {'ResponseAngle', 'Precision', 'ResponseTime', 'MouseX', 'MouseY'};
missingData = false;
for field = requiredFields
    if ismember(field{1}, expTrials.Properties.VariableNames)
        fieldData = expTrials.(field{1});
        if iscell(fieldData)
            missingCount = sum(cellfun(@(x) isempty(x) || (isnumeric(x) && any(isnan(x(:)))), fieldData));
        else
            % Numeric array
            if isempty(fieldData)
                missingCount = nTrials;
            else
                missingCount = sum(isnan(fieldData(:)));
            end
        end
        if missingCount > 0
            fprintf('  ✗ %s: %d missing values\n', field{1}, missingCount);
            missingData = true;
        else
            fprintf('  ✓ %s: All trials recorded\n', field{1});
        end
    else
        fprintf('  ✗ %s: Field not found\n', field{1});
        missingData = true;
    end
end

if ~missingData
    fprintf('\n✓ All data fields are complete!\n');
end

% Check for any NaN or empty values in critical fields
fprintf('\n=== DATA QUALITY CHECK ===\n');
if ismember('Precision', expTrials.Properties.VariableNames)
    nanPrecision = sum(isnan(expTrials.Precision));
    fprintf('  Precision: %d NaN values\n', nanPrecision);
end
if ismember('ResponseAngle', expTrials.Properties.VariableNames)
    nanResponse = sum(isnan(expTrials.ResponseAngle));
    fprintf('  ResponseAngle: %d NaN values\n', nanResponse);
end

fprintf('\n=== SUMMARY ===\n');
fprintf('Total trials: %d\n', nTrials);
fprintf('Expected: 96 trials\n');
if nTrials == 96
    fprintf('Status: ✓ CORRECT\n');
elseif nTrials == 192
    fprintf('Status: ✗ INCORRECT - Double the expected amount (practice + main)\n');
else
    fprintf('Status: ✗ UNEXPECTED COUNT\n');
end

