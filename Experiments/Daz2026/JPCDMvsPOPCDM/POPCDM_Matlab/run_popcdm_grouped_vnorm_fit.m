function output = run_popcdm_grouped_vnorm_fit(freeParameter, fitMode)
%RUN_POPCDM_GROUPED_VNORM_FIT Shared participant-level POPCDM fitting code.
%   output = run_popcdm_grouped_vnorm_fit("kappa", "full") fits 9k3v.
%   output = run_popcdm_grouped_vnorm_fit("alpha", "full") fits 9a3v.
%
% Data preparation, participant splitting, vnorm groups, multistart
% optimization, bounds transformation, and diagnostic layout mirror the
% corresponding JPCDM fitting scripts.

    arguments
        freeParameter (1,1) string {mustBeMember(freeParameter, ["kappa","alpha"])}
        fitMode (1,1) string {mustBeMember(fitMode, ["smoke","full"])} = "full"
    end

    targetIDs = ["AQ", "ES", "HC", "PG", "YL"];
    dataFile = ['/Users/prefabteam_ysl/Documents/GitHub/DazExperiments/Data/' ...
        'Redundancy 2024/Modelling/POPCDM/DazPreprocessed.csv'];

    dAll = readtable(dataFile);
    dAll.uid = string(dAll.uid);
    d = dAll(ismember(dAll.uid, targetIDs), :);

    % Apply exactly the same trial exclusions as the JPCDM fits.
    nBeforeMissingError = height(d);
    d = d(~ismissing(d.response_error), :);
    nMissingErrorRemoved = nBeforeMissingError - height(d);

    nBeforeRT = height(d);
    d = d(d.response_RT >= 300 & d.response_RT <= 3000, :);
    nRTRemoved = nBeforeRT - height(d);

    fprintf('Removed %d trials with missing response_error.\n', nMissingErrorRemoved);
    fprintf('Removed %d trials with response_RT < 300 ms or > 3000 ms.\n', nRTRemoved);
    fprintf('Remaining trials after filtering: %d.\n', height(d));

    % Build condition labels

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
    d.RedunN = nItems - nColors + 1;

    condLevels = ["S2C2NR", "S4C2NR", "S4C2R", ...
                  "S4C4NR", "S6C2NR", "S6C2R", ...
                  "S6C4NR", "S6C4R", "S6C6NR"];
    [isKnownCond, condIdx] = ismember(d.Cond, condLevels);
    if any(~isKnownCond)
        error('Unexpected condition value found.');
    end
    d.condIdx = condIdx;

    trialCounts = groupsummary(d, "uid");
    trialCounts.Properties.VariableNames{'GroupCount'} = 'nTrials';
    fprintf('Loaded %d trials from %d selected IDs.\n', height(d), numel(targetIDs));
    disp(trialCounts(:, ["uid", "nTrials"]));

    % Shared numerical settings. eta2 and st are fixed just as tangential
    % eta and st are fixed in the JPCDM comparison.
    nw = 50;
    tmax = 3.0;
    h = tmax / 300;
    % JPCDM's C core clamps both variability components to at least 0.02.
    % Use that effective tangential value here for a matched comparison.
    eta2Fixed = 0.02;
    stFixed = 0.20;
    nCond = numel(condLevels);

    % Both specifications contain 18 fitted parameters:
    % 3 grouped vnorm + eta1 + one shared population parameter + a
    % + 3 nondecision-time means (C2, C4, C6)
    % + 9 condition-specific values of the other population parameter.
    if freeParameter == "kappa"
        model.name = "POPCDM_FreeKappa_GroupedVnorm";
        model.shortName = "9k3v";
        model.paramNames = ["vnormBase", "vnormNR", "vnormR", ...
            "eta1", "alpha", "a", "terC2", "terC4", "terC6", ...
            "kappa_" + condLevels];
        lb = [0.01, 0.01, 0.01, 0.02, 0.01, 0.10, 0.00, 0.00, 0.00, ...
              repmat(0.01, 1, nCond)];
        ub = [20.0, 20.0, 20.0, 8.00, 30.0, 8.00, 1.00, 1.00, 1.00, ...
              repmat(30.0, 1, nCond)];
    else
        model.name = "POPCDM_FreeAlpha_GroupedVnorm";
        model.shortName = "9a3v";
        model.paramNames = ["vnormBase", "vnormNR", "vnormR", ...
            "eta1", "kappa", "a", "terC2", "terC4", "terC6", ...
            "alpha_" + condLevels];
        lb = [0.01, 0.01, 0.01, 0.02, 0.01, 0.10, 0.00, 0.00, 0.00, ...
              repmat(0.01, 1, nCond)];
        ub = [20.0, 20.0, 20.0, 8.00, 30.0, 8.00, 1.00, 1.00, 1.00, ...
              repmat(30.0, 1, nCond)];
    end

    if fitMode == "smoke"
        fitIDs = targetIDs(1);
        nStarts = 2;
        useParallel = false;
        makeDiagnosticPlots = false;
        maxIter = 120;
        maxFunEvals = 400;
    else
        fitIDs = targetIDs;
        nStarts = 24;
        useParallel = true;
        makeDiagnosticPlots = true;
        maxIter = 800;
        maxFunEvals = 2500;
    end

    % A recorded seed makes the multistart design reproducible.
    rngSeed = 20260711;
    rng(rngSeed, 'twister');
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
            warning('POPCDM:ParallelPoolUnavailable', '%s', sprintf( ...
                ['Parallel pool could not be started. ' ...
                 'Falling back to serial fitting.\n%s'], ME.message));
            useParallel = false;
        end
    end

    fitResults = struct();
    allParticipantFits = table();
    singleTerResults = struct([]);
    singleTerAllParticipantFits = table();

    % Match JPCDM's nested warm-start procedure. A previous one-ter POPCDM
    % fit can be saved under the filename below; its ter is copied into all
    % three color groups, making it an exact nested starting model.
    functionFolder = fileparts(mfilename('fullpath'));
    if freeParameter == "kappa"
        legacyFitFile = fullfile(functionFolder, ...
            'pop_fit_freeKappa_groupedVnorm_results.mat');
        legacyField = 'fitResultKappaCond';
    else
        legacyFitFile = fullfile(functionFolder, ...
            'pop_fit_freeAlpha_groupedVnorm_results.mat');
        legacyField = 'fitResultAlphaCond';
    end

    legacyFits = [];
    if isfile(legacyFitFile)
        legacyData = load(legacyFitFile,legacyField);
        legacyFits = legacyData.(legacyField);
        singleTerResults = legacyFits;
        for legacyResult = legacyFits
            if isfield(legacyResult,'fitSummary')
                singleTerAllParticipantFits = ...
                    [singleTerAllParticipantFits; ...
                    legacyResult.fitSummary]; %#ok<AGROW>
            end
        end
        fprintf('Using nested warm starts from %s\n',legacyFitFile);
    else
        fprintf(['No previous one-ter POPCDM result file was found. ' ...
            'A restricted one-ter warm start will be fitted internally.\n']);
    end

    for p = 1:numel(fitIDs)
        uid = fitIDs(p);
        dp = d(d.uid == uid, :);
        dataByCond = prepare_condition_data(dp, nCond);

        fprintf('\n==============================\n');
        fprintf('Fitting POPCDM %s for participant %s (%d trials)\n', ...
            model.shortName, uid, height(dp));
        fprintf('==============================\n');

        Qstarts = lb + rand(nStarts, numel(lb)) .* (ub - lb);
        usedLegacyWarmStart = false;
        usedInternalRestrictedWarmStart = false;
        restrictedBaselineNLL = NaN;
        warmQ = [];
        if ~isempty(legacyFits)
            legacyIdx = find(string({legacyFits.uid})==uid,1);
            if ~isempty(legacyIdx) && ...
                    size(legacyFits(legacyIdx).allQfit,1)>=nStarts
                oldQ = legacyFits(legacyIdx).Qfit;
                warmQ = [oldQ(1:6),repmat(oldQ(7),1,3),oldQ(8:end)];
                warmQ = min(max(warmQ,lb),ub);
                usedLegacyWarmStart = true;
            elseif ~isempty(legacyIdx)
                fprintf(['Saved one-ter fit for %s used fewer starts than ' ...
                    'this run; refitting its baseline.\n'],uid);
            end
        end

        if isempty(warmQ)
            [warmQ,restrictedBaselineNLL,restrictedDetails] = ...
                fit_restricted_one_ter( ...
                freeParameter,dataByCond,condLevels,eta2Fixed,stFixed, ...
                nw,h,tmax,lb,ub,options,useParallel,nStarts);
            usedInternalRestrictedWarmStart = true;
            fprintf('Internal one-ter baseline NLL for %s: %.4f\n', ...
                uid,restrictedBaselineNLL);

            [singleResult,~] = ...
                package_single_ter_result(uid,restrictedDetails, ...
                freeParameter,condLevels,eta2Fixed,stFixed,lb,ub);
            if isempty(singleTerResults)
                savedIdx = [];
            else
                savedIdx = find(string({singleTerResults.uid})==uid,1);
            end
            if isempty(savedIdx)
                if isempty(singleTerResults)
                    singleTerResults = singleResult;
                else
                    singleTerResults(end+1) = singleResult; %#ok<AGROW>
                end
            else
                singleTerResults(savedIdx) = singleResult;
            end

            % Rebuild the combined table after replacement so resumed runs
            % cannot retain duplicate rows for the same participant.
            singleTerAllParticipantFits = table();
            for savedResult = singleTerResults
                if isfield(savedResult,'fitSummary')
                    singleTerAllParticipantFits = ...
                        [singleTerAllParticipantFits; ...
                        savedResult.fitSummary]; %#ok<AGROW>
                end
            end

            % Save a checkpoint after each participant so the expensive
            % one-ter stage survives interruption and is reusable later.
            save_single_ter_results(legacyFitFile,freeParameter, ...
                singleTerResults,singleTerAllParticipantFits,condLevels, ...
                targetIDs,eta2Fixed,stFixed,nw,h,tmax,nStarts,rngSeed,lb,ub);
        end

        Qstarts(1,:) = warmQ;
        nLocalStarts = min(7,nStarts-1);
        if nLocalStarts > 0
            qWarm = p_to_q(warmQ,lb,ub);
            localQ = qWarm + 0.35*randn(nLocalStarts,numel(lb));
            Qstarts(2:1+nLocalStarts,:) = q_to_p(localQ,lb,ub);
        end

        allQfit = zeros(nStarts, numel(lb));
        allNLL = inf(nStarts, 1);
        allStartNLL = inf(nStarts, 1);
        allRetainedStart = false(nStarts, 1);
        allExitflag = zeros(nStarts, 1);
        allIterations = zeros(nStarts, 1);
        allFuncCount = zeros(nStarts, 1);

        evalTimer = tic;
        testNLL = evaluate_model(Qstarts(1,:), freeParameter, ...
            dataByCond, condLevels, eta2Fixed, stFixed, nw, h, tmax);
        oneEvalTime = toc(evalTimer);
        fprintf('Initial test NLL: %.4f; one objective evaluation takes %.3f s.\n', ...
            testNLL, oneEvalTime);
        fprintf('Worst-case configured evaluations per start: %d.\n', maxFunEvals);

        fitTimer = tic;
        if useParallel
            fprintf('Fitting %d starts in parallel using %d workers...\n', ...
                nStarts, nWorkers);
            parfor s = 1:nStarts
                startNLL = evaluate_model(Qstarts(s,:),freeParameter, ...
                    dataByCond,condLevels,eta2Fixed,stFixed,nw,h,tmax);
                qstart = p_to_q(Qstarts(s,:), lb, ub);
                obj = @(q) evaluate_model(q_to_p(q, lb, ub), ...
                    freeParameter, dataByCond, condLevels, eta2Fixed, ...
                    stFixed, nw, h, tmax);
                [qfit,~,exitflag,optimOutput] = fminsearch(obj, qstart, options);
                fittedQ = q_to_p(qfit,lb,ub);
                fittedNLL = evaluate_model(fittedQ,freeParameter, ...
                    dataByCond, condLevels, eta2Fixed, stFixed, nw, h, tmax);
                allStartNLL(s) = startNLL;
                if startNLL < fittedNLL
                    allQfit(s,:) = Qstarts(s,:);
                    allNLL(s) = startNLL;
                    allRetainedStart(s) = true;
                else
                    allQfit(s,:) = fittedQ;
                    allNLL(s) = fittedNLL;
                end
                allExitflag(s) = exitflag;
                allIterations(s) = optimOutput.iterations;
                allFuncCount(s) = optimOutput.funcCount;
            end
        else
            for s = 1:nStarts
                fprintf('Fitting %s start %d of %d...\n', uid, s, nStarts);
                startNLL = evaluate_model(Qstarts(s,:),freeParameter, ...
                    dataByCond,condLevels,eta2Fixed,stFixed,nw,h,tmax);
                qstart = p_to_q(Qstarts(s,:), lb, ub);
                obj = @(q) evaluate_model(q_to_p(q, lb, ub), ...
                    freeParameter, dataByCond, condLevels, eta2Fixed, ...
                    stFixed, nw, h, tmax);
                [qfit,~,exitflag,optimOutput] = fminsearch(obj, qstart, options);
                fittedQ = q_to_p(qfit,lb,ub);
                fittedNLL = evaluate_model(fittedQ,freeParameter, ...
                    dataByCond, condLevels, eta2Fixed, stFixed, nw, h, tmax);
                allStartNLL(s) = startNLL;
                if startNLL < fittedNLL
                    allQfit(s,:) = Qstarts(s,:);
                    allNLL(s) = startNLL;
                    allRetainedStart(s) = true;
                else
                    allQfit(s,:) = fittedQ;
                    allNLL(s) = fittedNLL;
                end
                allExitflag(s) = exitflag;
                allIterations(s) = optimOutput.iterations;
                allFuncCount(s) = optimOutput.funcCount;
                fprintf(['%s start %d: NLL %.4f, %d iterations, ' ...
                    '%d evaluations, exitflag %d\n'], uid, s, allNLL(s), ...
                    allIterations(s), allFuncCount(s), allExitflag(s));
            end
        end

        if useParallel
            for s = 1:nStarts
                fprintf(['%s start %d: NLL %.4f, %d iterations, ' ...
                    '%d evaluations, exitflag %d\n'], uid, s, allNLL(s), ...
                    allIterations(s), allFuncCount(s), allExitflag(s));
            end
        end

        [bestNLL, bestIdx] = min(allNLL);
        Qfit = allQfit(bestIdx,:);
        elapsedSeconds = toc(fitTimer);

        fprintf('\nFinished %s for %s in %.1f minutes.\n', ...
            model.name, uid, elapsedSeconds / 60);
        fprintf('Best start index: %d\nBest NLL: %.4f\n', bestIdx, bestNLL);

        fitSummary = table(repmat(uid, numel(model.paramNames), 1), ...
            model.paramNames(:), Qfit(:), lb(:), ub(:), ...
            'VariableNames', ...
            {'uid','Parameter','Estimate','LowerBound','UpperBound'});
        fprintf('\nAll 18 optimized parameters for %s:\n', uid);
        disp(fitSummary(:, ["Parameter","Estimate","LowerBound","UpperBound"]));

        fixedParameterSummary = table( ...
            ["eta2"; "sigma"; "st"], ...
            [eta2Fixed; 1.0; stFixed], ...
            'VariableNames', {'Parameter','Value'});
        fprintf('Fixed POPCDM parameters for %s:\n', uid);
        disp(fixedParameterSummary);

        condFit = build_condition_fit(Qfit, freeParameter, ...
            condLevels, eta2Fixed, stFixed);
        condFit.uid = repmat(uid, height(condFit), 1);
        condFit = movevars(condFit, "uid", "Before", "Cond");
        fprintf('Full condition-level POPCDM parameters for %s:\n', uid);
        disp(condFit);

        fitResults(p).uid = uid;
        fitResults(p).Qfit = Qfit;
        fitResults(p).bestNLL = bestNLL;
        fitResults(p).bestIdx = bestIdx;
        fitResults(p).allQfit = allQfit;
        fitResults(p).allNLL = allNLL;
        fitResults(p).allStartNLL = allStartNLL;
        fitResults(p).allRetainedStart = allRetainedStart;
        fitResults(p).allExitflag = allExitflag;
        fitResults(p).allIterations = allIterations;
        fitResults(p).allFuncCount = allFuncCount;
        fitResults(p).paramNames = model.paramNames;
        fitResults(p).fitSummary = fitSummary;
        fitResults(p).fixedParameterSummary = fixedParameterSummary;
        fitResults(p).condFit = condFit;
        fitResults(p).eta2Fixed = eta2Fixed;
        fitResults(p).stFixed = stFixed;
        fitResults(p).elapsedSeconds = elapsedSeconds;
        fitResults(p).usedLegacyWarmStart = usedLegacyWarmStart;
        fitResults(p).usedInternalRestrictedWarmStart = ...
            usedInternalRestrictedWarmStart;
        fitResults(p).restrictedBaselineNLL = restrictedBaselineNLL;
        fitResults(p).legacyFitFile = legacyFitFile;

        allParticipantFits = [allParticipantFits; fitSummary]; %#ok<AGROW>

        if makeDiagnosticPlots
            plot_participant_diagnostics( ...
                uid, dp, condFit, condLevels, nw, h, tmax, model.shortName);
        end
    end

    output.fitResults = fitResults;
    output.allParticipantFits = allParticipantFits;
    output.model = model;
    output.data = d;
    output.condLevels = condLevels;
    output.targetIDs = targetIDs;
    output.fitIDs = fitIDs;
    output.lb = lb;
    output.ub = ub;
    output.eta2Fixed = eta2Fixed;
    output.stFixed = stFixed;
    output.nw = nw;
    output.h = h;
    output.tmax = tmax;
    output.nStarts = nStarts;
    output.fitMode = fitMode;
    output.rngSeed = rngSeed;
    output.singleTerResults = singleTerResults;
    output.singleTerAllParticipantFits = singleTerAllParticipantFits;
    output.singleTerResultFile = legacyFitFile;
end

function nll = evaluate_model(Q, freeParameter, dataByCond, condLevels, ...
        eta2Fixed, stFixed, nw, h, tmax)
    if freeParameter == "kappa"
        nll = popcdm_nll_free_kappa_prepared(Q, dataByCond, condLevels, ...
            eta2Fixed, stFixed, nw, h, tmax);
    else
        nll = popcdm_nll_free_alpha_prepared(Q, dataByCond, condLevels, ...
            eta2Fixed, stFixed, nw, h, tmax);
    end
end

function [warmQ,bestRestrictedNLL,details] = fit_restricted_one_ter( ...
        freeParameter,dataByCond,condLevels,eta2Fixed,stFixed,nw,h,tmax, ...
        lb,ub,options,useParallel,nStarts)
% Fit the nested 16-parameter model when no saved POPCDM fit is available.
% R = [first six shared/grouped parameters, one ter, nine condition values].

    restrictedLb = [lb(1:6),lb(7),lb(10:end)];
    restrictedUb = [ub(1:6),ub(7),ub(10:end)];
    % Use the same number of starts as the main fit, matching the effort
    % used to obtain JPCDM's saved one-ter baseline.
    nRestrictedStarts = nStarts;
    restrictedStarts = restrictedLb + ...
        rand(nRestrictedStarts,numel(restrictedLb)).*(restrictedUb-restrictedLb);

    % Include one scientifically plausible deterministic start rather than
    % relying exclusively on broad uniform draws.
    if freeParameter=="kappa"
        heuristic = [3,3,3,0.5,1,1,0.3,repmat(10,1,numel(condLevels))];
    else
        heuristic = [3,3,3,0.5,10,1,0.3,ones(1,numel(condLevels))];
    end
    restrictedStarts(1,:) = min(max(heuristic,restrictedLb),restrictedUb);

    restrictedFits = zeros(size(restrictedStarts));
    restrictedNLL = inf(nRestrictedStarts,1);
    restrictedStartNLL = inf(nRestrictedStarts,1);
    restrictedExitflag = zeros(nRestrictedStarts,1);
    restrictedIterations = zeros(nRestrictedStarts,1);
    restrictedFuncCount = zeros(nRestrictedStarts,1);
    restrictedRetainedStart = false(nRestrictedStarts,1);

    if useParallel
        parfor s = 1:nRestrictedStarts
            rStart = restrictedStarts(s,:);
            qStart = p_to_q(rStart,restrictedLb,restrictedUb);
            obj = @(q) restricted_objective(q_to_p( ...
                q,restrictedLb,restrictedUb),freeParameter,dataByCond, ...
                condLevels,eta2Fixed,stFixed,nw,h,tmax);
            [qFit,~,exitflag,optimOutput] = fminsearch(obj,qStart,options);
            rFit = q_to_p(qFit,restrictedLb,restrictedUb);
            startNLL = restricted_objective(rStart,freeParameter,dataByCond, ...
                condLevels,eta2Fixed,stFixed,nw,h,tmax);
            fitNLL = restricted_objective(rFit,freeParameter,dataByCond, ...
                condLevels,eta2Fixed,stFixed,nw,h,tmax);
            restrictedStartNLL(s) = startNLL;
            if startNLL < fitNLL
                restrictedFits(s,:) = rStart;
                restrictedNLL(s) = startNLL;
                restrictedRetainedStart(s) = true;
            else
                restrictedFits(s,:) = rFit;
                restrictedNLL(s) = fitNLL;
            end
            restrictedExitflag(s) = exitflag;
            restrictedIterations(s) = optimOutput.iterations;
            restrictedFuncCount(s) = optimOutput.funcCount;
        end
    else
        for s = 1:nRestrictedStarts
            rStart = restrictedStarts(s,:);
            qStart = p_to_q(rStart,restrictedLb,restrictedUb);
            obj = @(q) restricted_objective(q_to_p( ...
                q,restrictedLb,restrictedUb),freeParameter,dataByCond, ...
                condLevels,eta2Fixed,stFixed,nw,h,tmax);
            [qFit,~,exitflag,optimOutput] = fminsearch(obj,qStart,options);
            rFit = q_to_p(qFit,restrictedLb,restrictedUb);
            startNLL = restricted_objective(rStart,freeParameter,dataByCond, ...
                condLevels,eta2Fixed,stFixed,nw,h,tmax);
            fitNLL = restricted_objective(rFit,freeParameter,dataByCond, ...
                condLevels,eta2Fixed,stFixed,nw,h,tmax);
            restrictedStartNLL(s) = startNLL;
            if startNLL < fitNLL
                restrictedFits(s,:) = rStart;
                restrictedNLL(s) = startNLL;
                restrictedRetainedStart(s) = true;
            else
                restrictedFits(s,:) = rFit;
                restrictedNLL(s) = fitNLL;
            end
            restrictedExitflag(s) = exitflag;
            restrictedIterations(s) = optimOutput.iterations;
            restrictedFuncCount(s) = optimOutput.funcCount;
        end
    end

    [bestRestrictedNLL,bestIdx] = min(restrictedNLL);
    bestR = restrictedFits(bestIdx,:);
    warmQ = [bestR(1:6),repmat(bestR(7),1,3),bestR(8:end)];

    details.bestR = bestR;
    details.bestIdx = bestIdx;
    details.bestNLL = bestRestrictedNLL;
    details.allRfit = restrictedFits;
    details.allNLL = restrictedNLL;
    details.allStarts = restrictedStarts;
    details.allStartNLL = restrictedStartNLL;
    details.allRetainedStart = restrictedRetainedStart;
    details.allExitflag = restrictedExitflag;
    details.allIterations = restrictedIterations;
    details.allFuncCount = restrictedFuncCount;
    details.lb = restrictedLb;
    details.ub = restrictedUb;
end

function nll = restricted_objective(R,freeParameter,dataByCond,condLevels, ...
        eta2Fixed,stFixed,nw,h,tmax)
    Q = [R(1:6),repmat(R(7),1,3),R(8:end)];
    nll = evaluate_model(Q,freeParameter,dataByCond,condLevels, ...
        eta2Fixed,stFixed,nw,h,tmax);
end

function [result,fitSummary] = package_single_ter_result( ...
        uid,details,freeParameter,condLevels,eta2Fixed,stFixed,lb,ub)
    if freeParameter=="kappa"
        paramNames = ["vnormBase","vnormNR","vnormR","eta1", ...
            "alpha","a","ter","kappa_"+condLevels];
    else
        paramNames = ["vnormBase","vnormNR","vnormR","eta1", ...
            "kappa","a","ter","alpha_"+condLevels];
    end

    restrictedLb = [lb(1:6),lb(7),lb(10:end)];
    restrictedUb = [ub(1:6),ub(7),ub(10:end)];
    bestR = details.bestR;
    fitSummary = table(repmat(uid,numel(paramNames),1), ...
        paramNames(:),bestR(:),restrictedLb(:),restrictedUb(:), ...
        'VariableNames', ...
        {'uid','Parameter','Estimate','LowerBound','UpperBound'});

    expandedQ = [bestR(1:6),repmat(bestR(7),1,3),bestR(8:end)];
    condFit = build_condition_fit( ...
        expandedQ,freeParameter,condLevels,eta2Fixed,stFixed);
    condFit.uid = repmat(uid,height(condFit),1);
    condFit = movevars(condFit,"uid","Before","Cond");

    result.uid = uid;
    result.Qfit = bestR;
    result.bestNLL = details.bestNLL;
    result.bestIdx = details.bestIdx;
    result.allQfit = details.allRfit;
    result.allNLL = details.allNLL;
    result.allStarts = details.allStarts;
    result.allStartNLL = details.allStartNLL;
    result.allRetainedStart = details.allRetainedStart;
    result.allExitflag = details.allExitflag;
    result.allIterations = details.allIterations;
    result.allFuncCount = details.allFuncCount;
    result.paramNames = paramNames;
    result.fitSummary = fitSummary;
    result.condFit = condFit;
    result.eta2Fixed = eta2Fixed;
    result.stFixed = stFixed;
end

function save_single_ter_results(resultFile,freeParameter,fitResults, ...
        allParticipantFits,condLevels,targetIDs,eta2Fixed,stFixed,nw,h, ...
        tmax,nStarts,rngSeed,fullLb,fullUb)
    lb = [fullLb(1:6),fullLb(7),fullLb(10:end)];
    ub = [fullUb(1:6),fullUb(7),fullUb(10:end)];

    if freeParameter=="kappa"
        fitResultKappaCond = fitResults;
        modelKappaCond.name = "POPCDM_FreeKappa_GroupedVnorm_OneTer";
        modelKappaCond.paramNames = fitResults(end).paramNames;
        save(resultFile,'fitResultKappaCond','allParticipantFits', ...
            'modelKappaCond','condLevels','targetIDs','lb','ub', ...
            'eta2Fixed','stFixed','nw','h','tmax','nStarts','rngSeed');
    else
        fitResultAlphaCond = fitResults;
        modelAlphaCond.name = "POPCDM_FreeAlpha_GroupedVnorm_OneTer";
        modelAlphaCond.paramNames = fitResults(end).paramNames;
        save(resultFile,'fitResultAlphaCond','allParticipantFits', ...
            'modelAlphaCond','condLevels','targetIDs','lb','ub', ...
            'eta2Fixed','stFixed','nw','h','tmax','nStarts','rngSeed');
    end
    fprintf('Saved one-ter POPCDM checkpoint: %s\n',resultFile);
end

function dataByCond = prepare_condition_data(dp, nCond)
    dataByCond = cell(nCond, 1);
    for c = 1:nCond
        dc = dp(dp.condIdx == c, :);
        dataByCond{c}.rt = dc.rt;
        dataByCond{c}.rAngle = dc.rAngle;
    end
end

function condFit = build_condition_fit( ...
        Qfit, freeParameter, condLevels, eta2Fixed, stFixed)
    nCond = numel(condLevels);
    vnormByCond = grouped_vnorm_vector(Qfit(1:3), condLevels);
    eta1 = Qfit(4);
    a = Qfit(6);
    terByCond = color_group_vector(Qfit(7:9), condLevels);

    if freeParameter == "kappa"
        alpha = repmat(Qfit(5), nCond, 1);
        kappa = Qfit(10:end).';
    else
        kappa = repmat(Qfit(5), nCond, 1);
        alpha = Qfit(10:end).';
    end

    vnormGroup = strings(nCond, 1);
    vnormGroup(ismember(condLevels, ["S2C2NR","S4C4NR","S6C6NR"])) = "Base";
    vnormGroup(ismember(condLevels, ["S4C2NR","S6C2NR","S6C4NR"])) = "NR";
    vnormGroup(ismember(condLevels, ["S4C2R","S6C2R","S6C4R"])) = "R";

    condFit = table(condLevels(:), vnormGroup, vnormByCond, ...
        repmat(eta1, nCond, 1), repmat(eta2Fixed, nCond, 1), ...
        repmat(a, nCond, 1), alpha, kappa, ...
        terByCond, repmat(stFixed, nCond, 1), ...
        'VariableNames', {'Cond','VnormGroup','Vnorm','Eta1','Eta2', ...
                          'A','Alpha','Kappa','Ter','St'});
end

function vnormByCond = grouped_vnorm_vector(vnorms, condLevels)
    vnormByCond = nan(numel(condLevels), 1);
    vnormByCond(ismember(condLevels, ["S2C2NR","S4C4NR","S6C6NR"])) = vnorms(1);
    vnormByCond(ismember(condLevels, ["S4C2NR","S6C2NR","S6C4NR"])) = vnorms(2);
    vnormByCond(ismember(condLevels, ["S4C2R","S6C2R","S6C4R"])) = vnorms(3);
end

function valuesByCond = color_group_vector(groupValues, condLevels)
    valuesByCond = nan(numel(condLevels), 1);
    valuesByCond(contains(condLevels, "C2")) = groupValues(1);
    valuesByCond(contains(condLevels, "C4")) = groupValues(2);
    valuesByCond(contains(condLevels, "C6")) = groupValues(3);
end

function plot_participant_diagnostics( ...
        uid, dp, condFit, condLevels, nw, h, tmax, modelShortName)
    nCond = numel(condLevels);
    thetaDeg = cell(nCond, 1);
    angleDensityDeg = cell(nCond, 1);
    modelT = cell(nCond, 1);
    rtDensity = cell(nCond, 1);
    angleEdges = -180:5:180;    % 72 angle bins
    rtEdges = 0.3:0.025:3.0;    % 108 RT bins over the retained data range

    for c = 1:nCond
        P = [condFit.Vnorm(c), condFit.Eta1(c), condFit.Eta2(c), ...
             condFit.A(c), condFit.Alpha(c), condFit.Kappa(c), ...
             condFit.Ter(c), condFit.St(c)];
        [T, Gt, Theta] = popcdm2(P, nw, h, tmax);

        % Derive both plotted marginals from the same normalized 50 x 300
        % interior joint density used by popcdm_nll_arrays.
        tInterior = T(1:end-1);
        gtInterior = max(Gt(:,1:end-1),0);
        dtheta = Theta(2)-Theta(1);
        dt = tInterior(2)-tInterior(1);
        retainedTime = tInterior>=0.3 & tInterior<=3.0;
        gtSelected = gtInterior(:,retainedTime);
        gtSelected = gtSelected/(sum(gtSelected,'all')*dtheta*dt);

        % Close the angle curve only for plotting.
        thetaDeg{c} = [Theta, pi] * 180 / pi;
        angleDensityRad = sum(gtSelected,2)*dt;
        angleDensityDeg{c} = [angleDensityRad;angleDensityRad(1)].' * pi/180;

        % Match the 300-column likelihood support in diagnostics.
        modelT{c} = tInterior(retainedTime);
        rtDensity{c} = sum(gtSelected,1)*dtheta;
    end

    figure('Name', char(uid + " POPCDM " + modelShortName + " angle diagnostics"));
    tiledlayout(3, 3);
    sgtitle(uid + " POPCDM " + modelShortName + " response-error distributions");
    for c = 1:nCond
        dc = dp(dp.condIdx == c, :);
        nexttile;
        histogram(dc.rAngle * 180/pi, 'Normalization','pdf', ...
            'BinEdges',angleEdges, 'FaceColor',[0.25,0.45,1.00], ...
            'FaceAlpha',0.25, 'EdgeColor',[0.25,0.45,1.00]);
        hold on;
        plot(thetaDeg{c}, angleDensityDeg{c}, 'r-', 'LineWidth',2);
        title(condLevels(c), 'Interpreter','none');
        xlim([-180,180]);
        xlabel('Response error (deg)');
        ylabel('Density');
    end

    figure('Name', char(uid + " POPCDM " + modelShortName + " RT diagnostics"));
    tiledlayout(3, 3);
    sgtitle(uid + " POPCDM " + modelShortName + " RT distributions");
    for c = 1:nCond
        dc = dp(dp.condIdx == c, :);
        nexttile;
        histogram(dc.rt, 'Normalization','pdf', ...
            'BinEdges',rtEdges, 'FaceColor',[0.25,0.45,1.00], ...
            'FaceAlpha',0.25, 'EdgeColor',[0.25,0.45,1.00]);
        hold on;
        plot(modelT{c}, rtDensity{c}, 'r-', 'LineWidth',2);
        title(condLevels(c), 'Interpreter','none');
        xlim([0.3,tmax]);
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
