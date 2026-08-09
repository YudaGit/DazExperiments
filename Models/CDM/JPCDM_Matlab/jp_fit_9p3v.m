% =========================================================================
% Fitting JPCDM to data
%==========================================================================

clear; clc;

% 1. Load data and keep the participants for this first fitting exercise

targetIDs = ["AQ", "ES", "HC", "PG", "YL"];

dAll = readtable(['/Users/prefabteam_ysl/Documents/GitHub/DazExperiments/Data/' ...
    'Redundancy 2024/Modelling/POPCDM/DazPreprocessed.csv']);

dAll.uid = string(dAll.uid);

d = dAll(ismember(dAll.uid, targetIDs), :);

% 2. Remove unusable trials

nBeforeMissingError = height(d);
d = d(~ismissing(d.response_error), :);
nMissingErrorRemoved = nBeforeMissingError - height(d);

nBeforeRT = height(d);
rtOK = d.response_RT >= 300 & d.response_RT <= 3000;
d = d(rtOK, :);
nRTRemoved = nBeforeRT - height(d);

fprintf('Removed %d trials with missing response_error.\n', nMissingErrorRemoved);
fprintf('Removed %d trials with response_RT < 300 ms or > 3000 ms.\n', nRTRemoved);
fprintf('Remaining trials after filtering: %d.\n', height(d));

% 3. Create condition labels, redundant-element counts, and model ready
% data columns

numItemsText = string(d.num_items);
colorNText = string(d.ColorN);
redundancyText = string(d.redundancy);

nItems = nan(height(d), 1);
nItems(numItemsText == "Two Items") = 2;
nItems(numItemsText == "Four Items") = 4;
nItems(numItemsText == "Six Items") = 6;

nColors = nan(height(d), 1);
nColors(colorNText == "One Color") = 1;
nColors(colorNText == "Two Colors") = 2;
nColors(colorNText == "Four Colors") = 4;
nColors(colorNText == "Six Colors") = 6;

d.rAngle = d.response_error * pi / 180;
d.rt = d.response_RT / 1000;

if any(isnan(nItems)) || any(isnan(nColors))
    error('Unexpected num_items or ColorN value found while creating Cond.');
end

redundancyLabel = strings(height(d), 1);
redundancyLabel(redundancyText == "Non-Redundant Cued") = "NR";
redundancyLabel(redundancyLabel == "") = "R";

d.Cond = "S" + string(nItems) + "C" + string(nColors) + redundancyLabel;
d.RedunN = nItems - nColors + 1;
d = movevars(d, ["Cond", "RedunN"], "After", "redundancy");

trialCounts = groupsummary(d, "uid");
trialCounts.Properties.VariableNames{'GroupCount'} = 'nTrials';

fprintf('Loaded %d trials from %d selected IDs.\n', height(d), numel(targetIDs));
disp(trialCounts(:, ["uid", "nTrials"]));

condCounts = groupsummary(d, "Cond");
condCounts.Properties.VariableNames{'GroupCount'} = 'nTrials';

redunCounts = groupsummary(d, "RedunN");
redunCounts.Properties.VariableNames{'GroupCount'} = 'nTrials';

fprintf('Condition counts after filtering.\n');
disp(condCounts(:, ["Cond", "nTrials"]));

fprintf('Redundant-element counts after filtering.\n');
disp(redunCounts(:, ["RedunN", "nTrials"]));

% 4. set up data conditions

condLevels = ["S2C2NR", "S4C2NR", "S4C2R", ...
              "S4C4NR", "S6C2NR", "S6C2R", ...
              "S6C4NR", "S6C4R", "S6C6NR"];

[isKnownCond, condIdx] = ismember(d.Cond, condLevels);

if any(~isKnownCond)
    error('Unexpected Cond value found.');
end
d.condIdx = condIdx;
stFixed = 0.20;
tmax = 3.0;
nCond = numel(condLevels);

% 5. Model 2: free psi, shared kappa, grouped vnorm, fitted per participant
%
% Q = [vnormBase, vnormNR, vnormR, eta, kappa, a, ter, ...
%      psi_S2C2NR, ..., psi_S6C6NR]
%
% vnormBase: S2C2NR, S4C4NR, S6C6NR
% vnormNR:   S4C2NR, S6C2NR, S6C4NR
% vnormR:    S4C2R,  S6C2R,  S6C4R

modelPsiCond.name = "FreePsi_GroupedVnorm";
modelPsiCond.paramNames = ["vnormBase", "vnormNR", "vnormR", ...
                           "eta", "kappa", "a", "ter", ...
                           "psi_" + condLevels];

lb = [0.01, 0.01, 0.01, 0.01, 0.01, 0.10, 0.00, ...
      repmat(-1.00, 1, nCond)];
ub = [20.0, 20.0, 20.0, 8.00, 30.0, 8.00, 1.00, ...
      repmat(1.00, 1, nCond)];

% Use "smoke" first to verify runtime/progress. Use "full" for the real fit.
fitMode = "full";

if fitMode == "smoke"
    fitIDs = targetIDs(1);
    nStarts = 2;
    useParallel = false;
    makeDiagnosticPlots = false;
    maxIter = 120;
    maxFunEvals = 400;
elseif fitMode == "full"
    fitIDs = targetIDs;
    nStarts = 24;
    useParallel = true;
    makeDiagnosticPlots = true;
    maxIter = 800;
    maxFunEvals = 2500;
else
    error('Unknown fitMode: %s', fitMode);
end

nWorkers = 8;

options = optimset('Display', 'off', ...
    'MaxIter', maxIter, ...
    'MaxFunEvals', maxFunEvals, ...
    'TolX', 1e-5, ...
    'TolFun', 1e-5);

if useParallel
    try
        pool = gcp('nocreate');
        if isempty(pool) || pool.NumWorkers ~= nWorkers
            if ~isempty(pool)
                delete(pool);
            end
            parpool('local', nWorkers);
        end
    catch ME
        warning('Parallel pool could not be started. Falling back to serial fitting.\n%s', ME.message);
        useParallel = false;
    end
end

fitResultPsiCond = struct();
allParticipantFits = table();

for p = 1:numel(fitIDs)
    uid = fitIDs(p);
    dp = d(d.uid == uid, :);

    fprintf('\n==============================\n');
    fprintf('Fitting participant %s (%d trials)\n', uid, height(dp));
    fprintf('==============================\n');

    dataByCond = prepare_condition_data(dp, nCond);

    Qstarts = lb + rand(nStarts, length(lb)) .* (ub - lb);
    allQfit = zeros(nStarts, length(lb));
    allNLL = zeros(nStarts, 1);

    evalTimer = tic;
    testNLL = jpcdm_nll_free_psi_prepared(Qstarts(1, :), dataByCond, condLevels, stFixed, tmax);
    oneEvalTime = toc(evalTimer);
    fprintf('Initial test NLL: %.4f; one objective evaluation takes %.3f s.\n', testNLL, oneEvalTime);
    fprintf('Worst-case configured evaluations per start: %d.\n', maxFunEvals);

    tic;
    if useParallel
        fprintf('Fitting %d starts in parallel using %d workers...\n', nStarts, nWorkers);
        parfor s = 1:nStarts
            qstart = p_to_q(Qstarts(s, :), lb, ub);
            obj = @(q) jpcdm_nll_free_psi_prepared(q_to_p(q, lb, ub), dataByCond, condLevels, stFixed, tmax);

            qfit = fminsearch(obj, qstart, options);

            allQfit(s, :) = q_to_p(qfit, lb, ub);
            allNLL(s) = jpcdm_nll_free_psi_prepared(allQfit(s, :), dataByCond, condLevels, stFixed, tmax);
        end
    else
        for s = 1:nStarts
            qstart = p_to_q(Qstarts(s, :), lb, ub);
            obj = @(q) jpcdm_nll_free_psi_prepared(q_to_p(q, lb, ub), dataByCond, condLevels, stFixed, tmax);

            fprintf('Fitting %s start %d of %d...\n', uid, s, nStarts);
            qfit = fminsearch(obj, qstart, options);

            allQfit(s, :) = q_to_p(qfit, lb, ub);
            allNLL(s) = jpcdm_nll_free_psi_prepared(allQfit(s, :), dataByCond, condLevels, stFixed, tmax);
            fprintf('%s start %d NLL: %.4f\n', uid, s, allNLL(s));
        end
    end

    for s = 1:nStarts
        fprintf('%s start %d NLL: %.4f\n', uid, s, allNLL(s));
    end

    [bestNLL, bestIdx] = min(allNLL);
    Qfit = allQfit(bestIdx, :);
    elapsedSeconds = toc;

    fprintf('\nFinished %s for %s in %.1f minutes.\n', ...
        modelPsiCond.name, uid, elapsedSeconds / 60);
    fprintf('Best start index: %d\n', bestIdx);
    fprintf('Best NLL: %.4f\n', bestNLL);

    fitSummary = table(repmat(uid, numel(modelPsiCond.paramNames), 1), ...
        modelPsiCond.paramNames(:), Qfit(:), lb(:), ub(:), ...
        'VariableNames', {'uid', 'Parameter', 'Estimate', 'LowerBound', 'UpperBound'});

    fprintf('\nParameter estimates for %s.\n', uid);
    disp(fitSummary(:, ["Parameter", "Estimate", "LowerBound", "UpperBound"]));

    condFit = build_free_psi_cond_fit(Qfit, condLevels, stFixed);
    condFit.uid = repmat(uid, height(condFit), 1);
    condFit = movevars(condFit, "uid", "Before", "Cond");

    fprintf('\nCondition-level fitted JPCDM parameters for %s.\n', uid);
    disp(condFit);

    fitResultPsiCond(p).uid = uid;
    fitResultPsiCond(p).Qfit = Qfit;
    fitResultPsiCond(p).bestNLL = bestNLL;
    fitResultPsiCond(p).bestIdx = bestIdx;
    fitResultPsiCond(p).allQfit = allQfit;
    fitResultPsiCond(p).allNLL = allNLL;
    fitResultPsiCond(p).paramNames = modelPsiCond.paramNames;
    fitResultPsiCond(p).fitSummary = fitSummary;
    fitResultPsiCond(p).condFit = condFit;
    fitResultPsiCond(p).stFixed = stFixed;

    allParticipantFits = [allParticipantFits; fitSummary]; %#ok<AGROW>

    if makeDiagnosticPlots
        plot_participant_diagnostics(uid, dp, condFit, condLevels, tmax);
    end
end

%=======================
% Local helper functions
%=======================

function dataByCond = prepare_condition_data(dp, nCond)
    dataByCond = cell(nCond, 1);
    for c = 1:nCond
        dc = dp(dp.condIdx == c, :);
        dataByCond{c}.rt = dc.rt;
        dataByCond{c}.rAngle = dc.rAngle;
    end
end

function condFit = build_free_psi_cond_fit(Qfit, condLevels, stFixed)
    nCond = numel(condLevels);

    vnormBase = Qfit(1);
    vnormNR = Qfit(2);
    vnormR = Qfit(3);
    etaFit = Qfit(4);
    kappaFit = Qfit(5);
    aFit = Qfit(6);
    terFit = Qfit(7);
    psiFit = Qfit(8:end);

    vnormGroup = strings(nCond, 1);
    vnormByCond = nan(nCond, 1);
    for c = 1:nCond
        cond = condLevels(c);
        if ismember(cond, ["S2C2NR", "S4C4NR", "S6C6NR"])
            vnormGroup(c) = "Base";
            vnormByCond(c) = vnormBase;
        elseif ismember(cond, ["S4C2NR", "S6C2NR", "S6C4NR"])
            vnormGroup(c) = "NR";
            vnormByCond(c) = vnormNR;
        else
            vnormGroup(c) = "R";
            vnormByCond(c) = vnormR;
        end
    end

    condFit = table(condLevels(:), vnormGroup, vnormByCond, ...
        repmat(kappaFit, nCond, 1), repmat(etaFit, nCond, 1), psiFit(:), ...
        repmat(aFit, nCond, 1), repmat(terFit, nCond, 1), ...
        repmat(stFixed, nCond, 1), ...
        'VariableNames', {'Cond', 'VnormGroup', 'Vnorm', 'Kappa', ...
                          'Eta', 'Psi', 'A', 'Ter', 'St'});
end

function plot_participant_diagnostics(uid, dp, condFit, condLevels, tmax)
    nCond = numel(condLevels);
    modelThetaDeg = cell(nCond, 1);
    modelPthetaDeg = cell(nCond, 1);
    modelT = cell(nCond, 1);
    modelRTDensity = cell(nCond, 1);

    for c = 1:nCond
        Pcond = [condFit.Vnorm(c), condFit.Kappa(c), condFit.Eta(c), ...
                 condFit.Psi(c), condFit.A(c), condFit.Ter(c), condFit.St(c)];
        [Tmod, Gtmod, Thetamod, Pthetamod] = jpcdm1(Pcond, tmax);

        modelThetaDeg{c} = Thetamod * 180 / pi;
        modelPthetaDeg{c} = Pthetamod * pi / 180; % radian density -> degree density

        ThetaOpenMod = Thetamod(1:end-1);
        GtOpenMod = Gtmod(1:end-1, :);
        dthetaMod = ThetaOpenMod(2) - ThetaOpenMod(1);
        modelT{c} = Tmod;
        modelRTDensity{c} = sum(GtOpenMod, 1) * dthetaMod;
    end

    figure('Name', char(uid + " angle diagnostics"));
    tiledlayout(3, 3);
    sgtitle(uid + " response-error distributions");

    for c = 1:nCond
        dc = dp(dp.condIdx == c, :);
        nexttile;
        histogram(dc.rAngle * 180 / pi, ...
            'Normalization', 'pdf', ...
            'BinWidth', 10, ...
            'FaceColor', [0.25, 0.45, 1.00], ...
            'FaceAlpha', 0.25, ...
            'EdgeColor', [0.25, 0.45, 1.00]);
        hold on;
        plot(modelThetaDeg{c}, modelPthetaDeg{c}, 'r-', 'LineWidth', 2);
        title(condLevels(c), 'Interpreter', 'none');
        xlim([-180, 180]);
        xlabel('Response error (deg)');
        ylabel('Density');
    end

    figure('Name', char(uid + " RT diagnostics"));
    tiledlayout(3, 3);
    sgtitle(uid + " RT distributions");

    for c = 1:nCond
        dc = dp(dp.condIdx == c, :);
        nexttile;
        histogram(dc.rt, ...
            'Normalization', 'pdf', ...
            'BinWidth', 0.05, ...
            'FaceColor', [0.25, 0.45, 1.00], ...
            'FaceAlpha', 0.25, ...
            'EdgeColor', [0.25, 0.45, 1.00]);
        hold on;
        plot(modelT{c}, modelRTDensity{c}, 'r-', 'LineWidth', 2);
        title(condLevels(c), 'Interpreter', 'none');
        xlim([0, tmax]);
        xlabel('RT (s)');
        ylabel('Density');
    end
end

function q = p_to_q(P, lb, ub)
    z = (P - lb) ./ (ub - lb);
    z = min(max(z, 1e-9), 1 - 1e-9);
    q = log(z ./ (1 - z));
end

function P = q_to_p(q, lb, ub)
    z = 1 ./ (1 + exp(-q));
    P = lb + (ub - lb) .* z;
end