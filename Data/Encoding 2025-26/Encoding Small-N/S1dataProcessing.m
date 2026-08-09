%% Experiment 1: combine, clean, summarise, and export trial data
clear; clc;

scriptRoot = fileparts(mfilename('fullpath'));
inputPattern = fullfile(scriptRoot, 'EncodingData_*.mat');
outputFile = fullfile(scriptRoot, 'AnalysesR', 'S1_smallN_model_ready.csv');

setSize = 6;

%% Combine participant-session files
files = dir(inputPattern);
if isempty(files)
    error('No files found matching %s', inputPattern);
end

allSessions = cell(numel(files), 1);

for i = 1:numel(files)
    fileName = files(i).name;
    filePath = fullfile(files(i).folder, fileName);

    token = regexp( ...
        fileName, ...
        '^EncodingData_([A-Za-z]+)_sess(\d+)_', ...
        'tokens', ...
        'once');

    if isempty(token)
        error('Could not identify participant and session from %s.', fileName);
    end

    participantID = upper(string(token{1}));
    sessionNumber = str2double(token{2});

    loaded = load(filePath);
    variableNames = fieldnames(loaded);

    if isfield(loaded, 'expTrials')
        sessionData = loaded.expTrials;
    elseif numel(variableNames) == 1
        sessionData = loaded.(variableNames{1});
    else
        error('File %s does not contain a unique trial-data variable.', fileName);
    end

    if isstruct(sessionData)
        sessionData = struct2table(sessionData);
    end
    if ~istable(sessionData)
        error('Trial data in %s are not a table or struct array.', fileName);
    end

    sessionData.ID = repmat(participantID, height(sessionData), 1);
    sessionData.Session = repmat(sessionNumber, height(sessionData), 1);
    allSessions{i} = sessionData;
end

dataAll = vertcat(allSessions{:});
rawTrialCount = height(dataAll);

requiredFields = {'Precision', 'ResponseTime', 'CueType', 'PresDur', ...
    'Grouping', 'Colors', 'Target'};
missingFields = setdiff(requiredFields, dataAll.Properties.VariableNames);
if ~isempty(missingFields)
    error('Trial table is missing required fields: %s', strjoin(missingFields, ', '));
end

%% Parse display colours (N x 6 item hues, degrees)
itemHues = parseColorsMatrix(dataAll.Colors, setSize);
targetIdx = double(dataAll.Target);

if any(~isfinite(targetIdx) | targetIdx < 1 | targetIdx > setSize | ...
        mod(targetIdx, 1) ~= 0)
    error('Target index must be an integer in 1..%d for all trials.', setSize);
end

targetHue = itemHues(sub2ind(size(itemHues), (1:height(itemHues))', targetIdx));

%% Clean trials
missingPrecision = ~isfinite(dataAll.Precision);
missingRT = ~isfinite(dataAll.ResponseTime);
slowRT = dataAll.ResponseTime > 3000;
fastRT = dataAll.ResponseTime < 300;
invalidTargetHue = ~isfinite(targetHue);
invalidItemHue = any(~isfinite(itemHues), 2);

keepTrial = ~(missingPrecision | missingRT | slowRT | fastRT | ...
    invalidTargetHue | invalidItemHue);
dataAll = dataAll(keepTrial, :);
itemHues = itemHues(keepTrial, :);
targetIdx = targetIdx(keepTrial);
targetHue = targetHue(keepTrial);

fprintf('\nTrial cleaning\n');
fprintf('Raw trials:                 %d\n', rawTrialCount);
fprintf('Missing precision:          %d\n', sum(missingPrecision));
fprintf('Missing RT:                 %d\n', sum(missingRT));
fprintf('RT > 3000 ms:               %d\n', sum(slowRT & ~missingRT));
fprintf('RT < 300 ms:                %d\n', sum(fastRT & ~missingRT));
fprintf('Invalid colour/target info: %d\n', sum(invalidTargetHue | invalidItemHue));
fprintf('Retained trials:            %d\n\n', height(dataAll));

%% Prepare analysis variables
ID = categorical(dataAll.ID);
Session = double(dataAll.Session);

cueLabels = upper(string(dataAll.CueType));
cueLabels(cueLabels == "REDUNDANT") = "R";
cueLabels(ismember(cueLabels, ["NON-REDUNDANT", "NONREDUNDANT"])) = "NR";
CueType = categorical(cueLabels, ["NR", "R"]);

groupingLabels = upper(string(dataAll.Grouping));
groupingLabels(groupingLabels == "SEPARATE") = "SEPARATED";
Grouping = categorical( ...
    groupingLabels, ...
    ["GROUPED", "SEPARATED"], ...
    ["Grouped", "Separated"]);

Duration_ms = double(dataAll.PresDur);
if max(Duration_ms) <= 10
    Duration_ms = Duration_ms * 1000;
end
Duration_ms = round(Duration_ms);

durationLevels = sort(unique(Duration_ms));
durationLabels = arrayfun( ...
    @(x) sprintf('%dms', x), ...
    durationLevels, ...
    'UniformOutput', ...
    false);
Duration = categorical(Duration_ms, durationLevels, durationLabels);

SignedErr = wrapSignedDeg(double(dataAll.Precision));
AbsErr = abs(SignedErr);
RT = double(dataAll.ResponseTime);
logRT = log(RT);

Session_z = (Session - mean(Session)) ./ std(Session);
SessionPhase = strings(height(dataAll), 1);
SessionPhase(Session <= 2) = "Early";
SessionPhase(Session >= 9) = "Late";
SessionPhase(Session > 2 & Session < 9) = "Middle";
SessionPhase = categorical(SessionPhase, ["Early", "Middle", "Late"]);

% Response hue in the same colour-index space as Colors{1}(Target).
ResponseHue = mod(targetHue - SignedErr, 360);

itemSignedErr = zeros(height(dataAll), setSize);
itemAbsErr = zeros(height(dataAll), setSize);
itemIsRedundant = false(height(dataAll), setSize);
closestItemIdx = nan(height(dataAll), 1);
minNonTargetAbsErr = nan(height(dataAll), 1);
minNonTargetUniqueAbsErr = nan(height(dataAll), 1);
nUniqueColors = nan(height(dataAll), 1);

for ii = 1:height(dataAll)
    hues = itemHues(ii, :);
    responseHue = ResponseHue(ii);
    tgt = targetIdx(ii);

    [~, ~, hueClass] = unique(hues);
    hueCounts = accumarray(hueClass(:), 1);
    itemIsRedundant(ii, :) = hueCounts(hueClass) >= 2;

    for jj = 1:setSize
        err = wrapSignedDeg(hues(jj) - responseHue);
        itemSignedErr(ii, jj) = err;
        itemAbsErr(ii, jj) = abs(err);
    end

    [~, closestItemIdx(ii)] = min(itemAbsErr(ii, :));

    nonTargetMask = true(1, setSize);
    nonTargetMask(tgt) = false;
    minNonTargetAbsErr(ii) = min(itemAbsErr(ii, nonTargetMask));

    uniqueHues = unique(hues);
    nUniqueColors(ii) = numel(uniqueHues);
    targetColourValue = hues(tgt);
    swapHues = uniqueHues(uniqueHues ~= targetColourValue);
    if isempty(swapHues)
        minNonTargetUniqueAbsErr(ii) = NaN;
    else
        swapErr = arrayfun(@(h) abs(wrapSignedDeg(h - responseHue)), swapHues);
        minNonTargetUniqueAbsErr(ii) = min(swapErr);
    end
end

isSwapResponse = closestItemIdx ~= targetIdx;

modelT = table( ...
    ID, ...
    Session, ...
    Session_z, ...
    SessionPhase, ...
    CueType, ...
    Duration, ...
    Duration_ms, ...
    Grouping, ...
    AbsErr, ...
    SignedErr, ...
    RT, ...
    logRT, ...
    targetIdx, ...
    targetHue, ...
    ResponseHue, ...
    itemHues(:, 1), itemHues(:, 2), itemHues(:, 3), ...
    itemHues(:, 4), itemHues(:, 5), itemHues(:, 6), ...
    itemIsRedundant(:, 1), itemIsRedundant(:, 2), itemIsRedundant(:, 3), ...
    itemIsRedundant(:, 4), itemIsRedundant(:, 5), itemIsRedundant(:, 6), ...
    itemSignedErr(:, 1), itemSignedErr(:, 2), itemSignedErr(:, 3), ...
    itemSignedErr(:, 4), itemSignedErr(:, 5), itemSignedErr(:, 6), ...
    closestItemIdx, ...
    isSwapResponse, ...
    minNonTargetAbsErr, ...
    minNonTargetUniqueAbsErr, ...
    nUniqueColors, ...
    'VariableNames', { ...
    'ID', 'Session', 'Session_z', 'SessionPhase', 'CueType', 'Duration', ...
    'Duration_ms', 'Grouping', 'AbsErr', 'SignedErr', 'RT', 'logRT', ...
    'TargetIdx', 'TargetHue', 'ResponseHue', ...
    'ItemHue1', 'ItemHue2', 'ItemHue3', 'ItemHue4', 'ItemHue5', 'ItemHue6', ...
    'ItemIsRedundant1', 'ItemIsRedundant2', 'ItemIsRedundant3', ...
    'ItemIsRedundant4', 'ItemIsRedundant5', 'ItemIsRedundant6', ...
    'ItemSignedErr1', 'ItemSignedErr2', 'ItemSignedErr3', ...
    'ItemSignedErr4', 'ItemSignedErr5', 'ItemSignedErr6', ...
    'ClosestItemIdx', 'IsSwapResponse', ...
    'MinNonTargetAbsErr', 'MinNonTargetUniqueAbsErr', 'NUniqueColors'});

modelT = sortrows(modelT, {'ID', 'Session'});

%% Summarise and save
sessionSummary = groupcounts(modelT, {'ID', 'Session'});
conditionSummary = groupcounts(modelT, {'ID', 'CueType', 'Duration'});

disp('Trials by participant and session');
disp(sessionSummary);

disp('Trials by participant, cue type, and duration');
disp(conditionSummary);

swapSummary = groupsummary(modelT, {'CueType', 'Duration'}, ...
    'mean', {'IsSwapResponse', 'MinNonTargetUniqueAbsErr'});
disp('Swap diagnostics by cue type and duration');
disp(swapSummary);

writetable(modelT, outputFile);
fprintf('Saved %d trials to:\n%s\n', height(modelT), outputFile);

%% Local functions
function hues = parseColorsMatrix(colorsCol, setSize)
n = numel(colorsCol);
hues = nan(n, setSize);

if isnumeric(colorsCol) && size(colorsCol, 2) == setSize
    hues = double(colorsCol);
    return;
end

if iscell(colorsCol)
    for ii = 1:n
        hues(ii, :) = parseOneColorRow(colorsCol{ii}, setSize);
    end
    return;
end

for ii = 1:n
    hues(ii, :) = parseOneColorRow(colorsCol(ii), setSize);
end
end

function row = parseOneColorRow(value, setSize)
row = nan(1, setSize);

if isnumeric(value)
    value = double(value(:))';
    if numel(value) == setSize
        row = value;
        return;
    end
end

textValue = string(value);
tokens = regexp(textValue, '(-?\d+(?:\.\d+)?)', 'match');
if numel(tokens) >= setSize
    row = str2double(tokens(1:setSize));
end
end

function x = wrapSignedDeg(x)
x = mod(double(x) + 180, 360) - 180;
end
