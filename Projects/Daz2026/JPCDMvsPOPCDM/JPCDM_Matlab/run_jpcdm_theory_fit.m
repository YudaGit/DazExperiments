function output = run_jpcdm_theory_fit(hypothesis, fitMode)
%RUN_JPCDM_THEORY_FIT Fit current comparable JP-CDM H0a/H0b models.

    arguments
        hypothesis (1,1) string {mustBeMember(hypothesis, ["H0a","H0b"])} = "H0a"
        fitMode (1,1) string {mustBeMember(fitMode, ["smoke","full"])} = "full"
    end
    thisDir = fileparts(mfilename('fullpath'));
    addpath(thisDir);
    ensure_jpcdm_mex;
    model = jpcdm_model(hypothesis);
    targetIDs = ["AQ", "ES", "HC", "PG", "YL"];
    dataFile = resolve_data_file(thisDir);
    d = prepare_data(dataFile, targetIDs, model.condLevels);
    tmax = 3.0;
    rngSeed = 20260821;
    nWorkers = 8;
    if fitMode == "smoke"
        fitIDs = targetIDs(1);
        nStarts = 2;
        maxIter = 12;
        maxFunEvals = 300;
        tolerance = 1e-4;
        makePlots = false;
    else
        fitIDs = targetIDs;
        nStarts = 16;
        maxIter = 2000;
        maxFunEvals = 20000;
        tolerance = 1e-6;
        makePlots = true;
    end
    opts = optimoptions('fmincon', 'Display', 'off', ...
        'Algorithm', 'interior-point', 'MaxIterations', maxIter, ...
        'MaxFunctionEvaluations', maxFunEvals, ...
        'OptimalityTolerance', tolerance, 'StepTolerance', tolerance, ...
        'FunctionTolerance', tolerance);
    rng(rngSeed, 'twister');
    useParallel = start_parallel_pool(nWorkers);

    resultsDir = fullfile(thisDir, 'JPFits');
    figuresDir = fullfile(thisDir, 'Figures', hypothesis);
    if ~exist(resultsDir, 'dir'), mkdir(resultsDir); end
    if ~exist(figuresDir, 'dir'), mkdir(figuresDir); end
    outFile = fullfile(resultsDir, "jpcdm_" + hypothesis + "_" + ...
        fitMode + "_results.mat");
    fitResults = struct([]);
    comparisonRows = table();
    diagnosticSummary = table();
    if isfile(outFile)
        previous = load(outFile, 'fitResults', 'comparisonRows', ...
            'diagnosticSummary', 'model');
        if ~isequal(previous.model.paramNames, model.paramNames) || ...
                ~isequal(previous.model.lb, model.lb) || ...
                ~isequal(previous.model.ub, model.ub)
            error('JPCDM:CheckpointMismatch', ...
                'Existing checkpoint uses a different parameter layout or bounds.');
        end
        fitResults = previous.fitResults;
        comparisonRows = previous.comparisonRows;
        if isfield(previous, 'diagnosticSummary')
            diagnosticSummary = previous.diagnosticSummary;
        end
        fprintf('Resuming %s %s checkpoint with %d completed participant(s).\n', ...
            hypothesis, fitMode, numel(fitResults));
    end

    for p = 1:numel(fitIDs)
        uid = fitIDs(p);
        if ~isempty(fitResults) && any(string({fitResults.uid}) == uid)
            fprintf('Skipping completed participant %s.\n', uid);
            continue
        end
        dp = d(d.uid == uid, :);
        dataByCond = prepare_condition_data(dp, numel(model.condLevels));
        starts = build_starts(model.P0, model.lb, model.ub, nStarts);
        allP = zeros(nStarts, model.nFree);
        allNLL = inf(nStarts, 1);
        allExitflag = zeros(nStarts, 1);
        allIterations = zeros(nStarts, 1);
        allFuncCount = zeros(nStarts, 1);
        timer = tic;
        if useParallel
            parfor s = 1:nStarts
                [allP(s,:), allNLL(s), allExitflag(s), ...
                    allIterations(s), allFuncCount(s)] = fit_one( ...
                    starts(s,:), model, dataByCond, tmax, opts);
            end
        else
            for s = 1:nStarts
                [allP(s,:), allNLL(s), allExitflag(s), ...
                    allIterations(s), allFuncCount(s)] = fit_one( ...
                    starts(s,:), model, dataByCond, tmax, opts);
            end
        end
        elapsedSeconds = toc(timer);
        [bestNLL, bestIdx] = min(allNLL);
        Pfit = allP(bestIdx, :);
        condFit = jpcdm_expand_P(Pfit, model);
        condFit.uid = repmat(uid, height(condFit), 1);
        condFit = movevars(condFit, 'uid', 'Before', 'Cond');
        nObs = height(dp);
        AIC = 2*bestNLL + 2*model.nFree;
        BIC = 2*bestNLL + model.nFree*log(nObs);
        fitSummary = table(model.paramNames(:), Pfit(:), model.lb(:), ...
            model.ub(:), 'VariableNames', ...
            {'Parameter','Estimate','LowerBound','UpperBound'});
        result = struct('uid', uid, 'hypothesis', model.name, ...
            'Pfit', Pfit, 'bestNLL', bestNLL, 'AIC', AIC, 'BIC', BIC, ...
            'nObs', nObs, 'nFree', model.nFree, 'bestIdx', bestIdx, ...
            'bestExitflag', allExitflag(bestIdx), 'allP', allP, ...
            'allNLL', allNLL, 'allExitflag', allExitflag, ...
            'allIterations', allIterations, 'allFuncCount', allFuncCount, ...
            'fitSummary', fitSummary, 'condFit', condFit, ...
            'elapsedSeconds', elapsedSeconds);
        if isempty(fitResults), fitResults = result; else, fitResults(end+1) = result; end %#ok<AGROW>
        comparisonRows = [comparisonRows; table(uid, nObs, model.nFree, ...
            bestNLL, AIC, BIC, allExitflag(bestIdx), elapsedSeconds, ...
            'VariableNames', {'uid','nObs','nFree','NLL','AIC','BIC', ...
            'bestExitflag','elapsedSeconds'})]; %#ok<AGROW>
        fprintf('%s %s: NLL %.4f, AIC %.2f, BIC %.2f, exit %d (%.1f min)\n', ...
            uid, hypothesis, bestNLL, AIC, BIC, allExitflag(bestIdx), ...
            elapsedSeconds/60);
        disp(fitSummary);
        save(outFile, 'fitResults', 'comparisonRows', 'diagnosticSummary', ...
            'model', 'fitMode', 'fitIDs', 'targetIDs', 'tmax', 'nStarts', ...
            'rngSeed', 'maxIter', 'maxFunEvals', 'tolerance');
        if makePlots
            rows = jpcdm_diagnostics(uid, dp, condFit, model.condLevels, ...
                tmax, figuresDir, hypothesis);
            diagnosticSummary = [diagnosticSummary; summarize_diagnostics(rows)]; %#ok<AGROW>
        end
        save(outFile, 'fitResults', 'comparisonRows', 'diagnosticSummary', ...
            'model', 'fitMode', 'fitIDs', 'targetIDs', 'tmax', 'nStarts', ...
            'rngSeed', 'maxIter', 'maxFunEvals', 'tolerance');
        fprintf('Checkpoint saved: %s\n', outFile);
    end
    if ~isempty(comparisonRows)
        writetable(comparisonRows, fullfile(resultsDir, ...
            "jpcdm_" + hypothesis + "_" + fitMode + "_comparison.csv"));
    end
    if ~isempty(diagnosticSummary)
        writetable(diagnosticSummary, fullfile(resultsDir, ...
            "jpcdm_" + hypothesis + "_" + fitMode + "_diagnostic_summary.csv"));
    end
    if ~isempty(fitResults)
        auditRows = make_fit_audit(fitResults, model);
        writetable(auditRows, fullfile(resultsDir, ...
            "jpcdm_" + hypothesis + "_" + fitMode + "_fit_audit.csv"));
    else
        auditRows = table();
    end
    save(outFile, 'fitResults', 'comparisonRows', 'diagnosticSummary', ...
        'auditRows', 'model', 'fitMode', 'fitIDs', 'targetIDs', 'tmax', ...
        'nStarts', 'rngSeed', 'maxIter', 'maxFunEvals', 'tolerance');
    output = struct('fitResults', fitResults, ...
        'comparisonRows', comparisonRows, ...
        'diagnosticSummary', diagnosticSummary, 'auditRows', auditRows, ...
        'model', model, 'data', d, 'fitMode', fitMode, 'outFile', outFile);
end

function dataFile = resolve_data_file(thisDir)
    candidates = [ ...
        string(fullfile('C:\Users\Yuda\Documents\GitHub\DazExperiments\Data', ...
            'Redundancy 2024', 'DazPreprocessed.csv')), ...
        string(fullfile('/Users/prefabteam_ysl/Documents/GitHub/DazExperiments/Data', ...
            'Redundancy 2024', 'DazPreprocessed.csv')), ...
        string(fullfile('/Users/prefabteam_ysl/Documents/GitHub/DazExperiments/Data', ...
            'Redundancy 2024', 'Modelling', 'POPCDM', ...
            'DazPreprocessed.csv')), ...
        string(fullfile(thisDir, '..', '..', '..', 'Data', ...
            'Redundancy 2024', 'DazPreprocessed.csv')), ...
        string(fullfile(thisDir, '..', '..', '..', 'Data', ...
            'Redundancy 2024', 'Modelling', 'POPCDM', ...
            'DazPreprocessed.csv'))];
    for i = 1:numel(candidates)
        if isfile(candidates(i))
            dataFile = candidates(i);
            return
        end
    end
    error('JPCDM:DataFileMissing', ...
        'Could not locate DazPreprocessed.csv. Checked: %s', ...
        strjoin(candidates, newline));
end

function d = prepare_data(dataFile, targetIDs, condLevels)
    d = readtable(dataFile);
    d.uid = string(d.uid);
    d = d(ismember(d.uid, targetIDs), :);
    d = d(~ismissing(d.response_error), :);
    d = d(d.response_RT >= 300 & d.response_RT <= 3000, :);
    nItems = nan(height(d), 1);
    nItems(string(d.num_items) == "Two Items") = 2;
    nItems(string(d.num_items) == "Four Items") = 4;
    nItems(string(d.num_items) == "Six Items") = 6;
    nColors = nan(height(d), 1);
    nColors(string(d.ColorN) == "One Color") = 1;
    nColors(string(d.ColorN) == "Two Colors") = 2;
    nColors(string(d.ColorN) == "Four Colors") = 4;
    nColors(string(d.ColorN) == "Six Colors") = 6;
    red = strings(height(d), 1);
    red(string(d.redundancy) == "Non-Redundant Cued") = "NR";
    red(red == "") = "R";
    d.Cond = "S" + string(nItems) + "C" + string(nColors) + red;
    [known, d.condIdx] = ismember(d.Cond, condLevels);
    if any(~known), error('Unexpected condition in data.'); end
    d.rAngle = d.response_error*pi/180;
    d.rt = d.response_RT/1000;
end

function dataByCond = prepare_condition_data(dp, nCond)
    dataByCond = cell(nCond, 1);
    for c = 1:nCond
        dc = dp(dp.condIdx == c, :);
        dataByCond{c} = struct('rt', dc.rt, 'rAngle', dc.rAngle);
    end
end

function starts = build_starts(P0, lb, ub, nStarts)
    starts = zeros(nStarts, numel(P0));
    starts(1, :) = P0;
    for s = 2:nStarts
        starts(s, :) = lb + rand(size(lb)).*(ub-lb);
    end
    if nStarts >= 2
        starts(2, :) = min(max(P0.*(1 + 0.25*randn(size(P0))), lb), ub);
    end
end

function useParallel = start_parallel_pool(nWorkers)
    useParallel = false;
    if exist('gcp', 'file') ~= 2
        warning('JPCDM:ParallelUnavailable', ...
            ['Parallel Computing Toolbox is not installed. Multistart ', ...
             'fits will run serially.']);
        return
    end
    try
        pool = gcp('nocreate');
        if isempty(pool) || pool.NumWorkers ~= nWorkers
            if ~isempty(pool), delete(pool); end
            parpool('local', nWorkers);
        end
        useParallel = true;
    catch ME
        warning('JPCDM:ParallelUnavailable', '%s', ME.message);
    end
end

function [P, nll, exitflag, iterations, funcCount] = ...
        fit_one(P0, model, dataByCond, tmax, opts)
    objective = @(x) jpcdm_nll(x, dataByCond, model, tmax);
    [P, nll, exitflag, out] = fmincon(objective, P0, [], [], [], [], ...
        model.lb, model.ub, [], opts);
    iterations = out.iterations;
    funcCount = out.funcCount;
end

function summaryRows = summarize_diagnostics(rows)
    err = rows;
    err.AbsError = abs(err.Model - err.Observed);
    summaryRows = groupsummary(err, {'uid','Measure'}, {'mean','max'}, 'AbsError');
    summaryRows.Properties.VariableNames{'mean_AbsError'} = 'MAE';
    summaryRows.Properties.VariableNames{'max_AbsError'} = 'MaxAbsError';
end

function auditRows = make_fit_audit(fitResults, model)
    auditRows = table();
    for i = 1:numel(fitResults)
        r = fitResults(i);
        sortedNLL = sort(r.allNLL(:));
        if numel(sortedNLL) >= 2
            secondGap = sortedNLL(2) - sortedNLL(1);
        else
            secondGap = NaN;
        end
        within1 = sum(r.allNLL(:) <= r.bestNLL + 1);
        converged = sum(r.allExitflag(:) > 0);
        failed = sum(r.allExitflag(:) <= 0);
        maxIter = max(r.allIterations(:));
        distLower = r.Pfit(:).' - model.lb(:).';
        distUpper = model.ub(:).' - r.Pfit(:).';
        [minNormDist, idx] = min(min(distLower, distUpper) ./ ...
            max(model.ub(:).' - model.lb(:).', eps));
        nearestParam = model.paramNames(idx);
        auditRows = [auditRows; table(r.uid, r.bestNLL, secondGap, ...
            within1, converged, failed, maxIter, nearestParam, minNormDist, ...
            'VariableNames', {'uid','bestNLL','secondGap','within1', ...
            'converged','failed','maxIter','nearestParam','minNormDist'})]; %#ok<AGROW>
    end
end
