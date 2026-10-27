function [Data, condLevels, d, participantIDs, trialCounts, outFile] = prepareRe2024Data(dataFile, participantIDs, doSave)
%PREPARERE2024DATA Prepare Redundancy 2024 data for POPvJPvCauchy wrappers.
%   Data is an nParticipant x 9 cell array. Each cell contains:
%       column 1: stimulus angle in radians, currently fixed at 0
%       column 2: response error in radians
%       column 3: RT in seconds
%
%   The model wrappers interpolate with Dataj(:,2) against angle and
%   Dataj(:,3) against time, so these units must be radians and seconds.

    if nargin < 1 || isempty(dataFile)
        dataFile = fullfile('/Users/prefabteam_ysl/Documents/GitHub/DazExperiments', ...
            'Data', 'Redundancy 2024', 'Modelling', 'POPCDM', ...
            'DazPreprocessed.csv');
    end
    if nargin < 2 || isempty(participantIDs)
        participantIDs = ["AQ", "ES", "HC", "PG", "YL"];
    end
    participantIDs = string(participantIDs);
    if nargin < 3 || isempty(doSave)
        doSave = true;
    end

    dRaw = readtable(dataFile);
    dRaw.uid = string(dRaw.uid);
    dRaw = dRaw(ismember(dRaw.uid, participantIDs), :);

    missingAngle = ismissing(dRaw.response_error);
    missingRT = ismissing(dRaw.response_RT);
    inRTRange = dRaw.response_RT >= 300 & dRaw.response_RT <= 3000;

    d = dRaw(~missingAngle & ~missingRT & inRTRange, :);

    participantIDs = participantIDs(:).';
    nParticipant = numel(participantIDs);

    nItems = nan(height(d), 1);
    nItems(string(d.num_items) == "Two Items") = 2;
    nItems(string(d.num_items) == "Four Items") = 4;
    nItems(string(d.num_items) == "Six Items") = 6;

    nColors = nan(height(d), 1);
    nColors(string(d.ColorN) == "One Color") = 1;
    nColors(string(d.ColorN) == "Two Colors") = 2;
    nColors(string(d.ColorN) == "Four Colors") = 4;
    nColors(string(d.ColorN) == "Six Colors") = 6;
    if any(isnan(nItems)) || any(isnan(nColors))
        error('Unexpected num_items or ColorN value while creating Cond.');
    end

    redundancyLabel = strings(height(d), 1);
    redundancyLabel(string(d.redundancy) == "Non-Redundant Cued") = "NR";
    redundancyLabel(redundancyLabel == "") = "R";

    d.rAngle = d.response_error * pi / 180;
    d.rt = d.response_RT / 1000;
    d.Cond = "S" + string(nItems) + "C" + string(nColors) + redundancyLabel;

    condLevels = ["S2C2NR", ...
                  "S4C2NR", "S4C2R", "S4C4NR", ...
                  "S6C2NR", "S6C2R", "S6C4NR", "S6C4R", "S6C6NR"];

    [known, condIdx] = ismember(d.Cond, condLevels);
    nOutsideModel = sum(~known);
    if nOutsideModel > 0
        outsideLabels = unique(d.Cond(~known), 'stable');
        outsideLabels = outsideLabels(~ismissing(outsideLabels));
        fprintf('Removed %d trials outside the 9 modeled conditions: %s.\n', ...
            nOutsideModel, char(strjoin(outsideLabels, ', ')));
        d = d(known, :);
        condIdx = condIdx(known);
    end
    d.condIdx = condIdx;

    Data = cell(nParticipant, 9);
    trialCounts = zeros(nParticipant, 9);
    for p = 1:nParticipant
        dp = d(d.uid == participantIDs(p), :);
        for c = 1:9
            dc = dp(dp.condIdx == c, :);
            stimAngle = zeros(height(dc), 1);
            Data{p, c} = [stimAngle, dc.rAngle, dc.rt];
            trialCounts(p, c) = height(dc);
        end
    end

    fprintf('Prepared %d participants from %s.\n', nParticipant, dataFile);
    fprintf('Removed %d trials with missing response_error.\n', sum(missingAngle));
    fprintf('Removed %d trials with missing response_RT.\n', sum(missingRT));
        fprintf('Removed %d trials with response_RT < 300 ms or > 3000 ms.\n', ...
        sum(~missingRT & ~inRTRange));
    fprintf('Removed %d trials outside the 9 modeled conditions.\n', nOutsideModel);
    fprintf('Saved response error in radians and RT in seconds.\n');

    outFile = "";
    if doSave
        outFile = fullfile(fileparts(mfilename('fullpath')), ...
            'Re2024_POPvJPvCauchy_prepared.mat');
        save(outFile, 'Data', 'condLevels', 'd', 'participantIDs', ...
            'trialCounts', 'dataFile');
        fprintf('Saved prepared data to %s.\n', outFile);
    end
end
