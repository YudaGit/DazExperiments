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

requiredFields = {'Precision', 'ResponseAngle', 'ResponseTime', 'CueType', ...
    'PresDur', 'Grouping', 'Colors', 'Target'};
missingFields = setdiff(requiredFields, dataAll.Properties.VariableNames);
if ~isempty(missingFields)
    error('Trial table is missing required fields: %s', strjoin(missingFields, ', '));
end

%% Parse display colours (N x 6 item hues, fixed-wheel degrees)
% Colors are assigned at trial generation in fixed colour-wheel space
% (1..360 deg indices). Session wheel rotation (WheelRotation) is applied
% only at response: ResponseAngle = mod(mouseAngle - wheelRotation, 360).
% Item hues therefore need no further derotation.
itemHues = parseColorsMatrix(dataAll.Colors, setSize);
targetIdx = double(dataAll.Target);

if any(~isfinite(targetIdx) | targetIdx < 1 | targetIdx > setSize | ...
        mod(targetIdx, 1) ~= 0)
    error('Target index must be an integer in 1..%d for all trials.', setSize);
end

targetHue = itemHues(sub2ind(size(itemHues), (1:height(itemHues))', targetIdx));

%% Clean trials
missingPrecision = ~isfinite(dataAll.Precision);
missingResponse = ~isfinite(dataAll.ResponseAngle);
missingRT = ~isfinite(dataAll.ResponseTime);
slowRT = dataAll.ResponseTime > 3000;
fastRT = dataAll.ResponseTime < 300;
invalidTargetHue = ~isfinite(targetHue);
invalidItemHue = any(~isfinite(itemHues), 2);

keepTrial = ~(missingPrecision | missingResponse | missingRT | slowRT | ...
    fastRT | invalidTargetHue | invalidItemHue);
dataAll = dataAll(keepTrial, :);
itemHues = itemHues(keepTrial, :);
targetIdx = targetIdx(keepTrial);
targetHue = targetHue(keepTrial);

fprintf('\nTrial cleaning\n');
fprintf('Raw trials:                 %d\n', rawTrialCount);
fprintf('Missing precision:          %d\n', sum(missingPrecision));
fprintf('Missing response angle:     %d\n', sum(missingResponse));
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

% Precision is already signed error in fixed-wheel space (TargetHue - ResponseHue).
SignedErr = double(dataAll.Precision);
if any(SignedErr <= -180 | SignedErr > 180)
    error('Precision must lie in (-180, 180] degrees for all retained trials.');
end
AbsErr = abs(SignedErr);
RT = double(dataAll.ResponseTime);

Session_z = (Session - mean(Session)) ./ std(Session);
SessionPhase = strings(height(dataAll), 1);
SessionPhase(Session <= 2) = "Early";
SessionPhase(Session >= 9) = "Late";
SessionPhase(Session > 2 & Session < 9) = "Middle";
SessionPhase = categorical(SessionPhase, ["Early", "Middle", "Late"]);

% Response hue: use task-recorded ResponseAngle (already derotated from session wheel).
ResponseHue = mod(double(dataAll.ResponseAngle), 360);

% QC: SignedErr must match target-response in signed circular space.
signedFromResponse = wrapSignedDeg(targetHue - ResponseHue);
if max(abs(signedFromResponse - SignedErr)) > 1e-6
    error(['Precision inconsistent with TargetHue and ResponseAngle. ', ...
        'Max abs diff = %.3g deg.'], max(abs(signedFromResponse - SignedErr)));
end

% Per-slot signed error: item hue minus response hue (same convention as Precision).
itemSignedErr = zeros(height(dataAll), setSize);
for ii = 1:height(dataAll)
    responseHue = ResponseHue(ii);
    for jj = 1:setSize
        itemSignedErr(ii, jj) = wrapSignedDeg(itemHues(ii, jj) - responseHue);
    end
end

% Target slot should reproduce SignedErr.
targetSignedErr = itemSignedErr(sub2ind(size(itemSignedErr), ...
    (1:height(itemSignedErr))', targetIdx));
if max(abs(targetSignedErr - SignedErr)) > 1e-6
    error('ItemSignedErr at target slot does not match SignedErr.');
end

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
    targetIdx, ...
    targetHue, ...
    ResponseHue, ...
    itemHues(:, 1), itemHues(:, 2), itemHues(:, 3), ...
    itemHues(:, 4), itemHues(:, 5), itemHues(:, 6), ...
    itemSignedErr(:, 1), itemSignedErr(:, 2), itemSignedErr(:, 3), ...
    itemSignedErr(:, 4), itemSignedErr(:, 5), itemSignedErr(:, 6), ...
    'VariableNames', { ...
    'ID', 'Session', 'Session_z', 'SessionPhase', 'CueType', 'Duration', ...
    'Duration_ms', 'Grouping', 'AbsErr', 'SignedErr', 'RT', ...
    'TargetIdx', 'TargetHue', 'ResponseHue', ...
    'ItemHue1', 'ItemHue2', 'ItemHue3', 'ItemHue4', 'ItemHue5', 'ItemHue6', ...
    'ItemSignedErr1', 'ItemSignedErr2', 'ItemSignedErr3', ...
    'ItemSignedErr4', 'ItemSignedErr5', 'ItemSignedErr6'});

modelT = sortrows(modelT, {'ID', 'Session'});

%% Summarise and save
sessionSummary = groupcounts(modelT, {'ID', 'Session'});
conditionSummary = groupcounts(modelT, {'ID', 'CueType', 'Duration'});

disp('Trials by participant and session');
disp(sessionSummary);

disp('Trials by participant, cue type, and duration');
disp(conditionSummary);

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
