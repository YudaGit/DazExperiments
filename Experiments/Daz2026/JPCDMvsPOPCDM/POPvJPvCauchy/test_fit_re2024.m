function output = test_fit_re2024(hypothesis, requestedModels, runLabel, warmStartFile, requestedParticipants)
%TEST_FIT_RE2024 Fit named team-Cauchy hypothesis variants to Re2024.
%   Uses fmincon with an 8-worker parpool. H0 uses 10 starts; H1 and
%   legacy diagnostic routes use 24 starts.
%
%   output = TEST_FIT_RE2024() fits H0: cellwise kappa_mu with one shared
%   vnorm, eta, a, Ter, and st.
%
%   H1_ETA, H1_VNORM, and H1_TER make eta, vnorm, or Ter cellwise while
%   retaining cellwise kappa_mu. H1_VNORM_SN is the set-size-vnorm model.
%   LEGACY_ETA_CELL_VNORM_SN preserves the earlier cellwise-eta result.
%
%   For a nested route refit, provide an H0 aggregate result file and, if
%   needed, one participant. Its H0 solution becomes an exact H1 start:
%   TEST_FIT_RE2024("H1_ETA", "cauchy", "H1_eta_YL", h0File, "YL")

    if nargin < 1 || isempty(hypothesis)
        hypothesis = "H0";
    end
    hypothesis = upper(string(hypothesis));
    validHypotheses = ["H0", "H1_ETA", "H1_VNORM", "H1_TER", ...
        "H1_VNORM_SN", "LEGACY_ETA_CELL_VNORM_SN"];
    if ~isscalar(hypothesis) || ~ismember(hypothesis, validHypotheses)
        error('test_fit_re2024:UnknownHypothesis', ...
            'Unknown hypothesis: %s.', hypothesis);
    end
    if nargin < 2 || isempty(requestedModels)
        requestedModels = "cauchy";
    end
    requestedModels = string(requestedModels);
    if nargin < 3 || isempty(runLabel)
        switch hypothesis
            case "H0"
                runLabel = "H0_kappaCell_sharedDecision";
            case "H1_ETA"
                runLabel = "H1_eta";
            case "H1_VNORM"
                runLabel = "H1_vnorm";
            case "H1_TER"
                runLabel = "H1_ter";
            case "H1_VNORM_SN"
                runLabel = "H1_vnorm_sn";
            case "LEGACY_ETA_CELL_VNORM_SN"
                runLabel = "Legacy_etaCell_vnormSN";
            otherwise
                error('test_fit_re2024:UnknownHypothesis', 'Unknown hypothesis.');
        end
    end
    if nargin < 4 || isempty(warmStartFile)
        warmStartFile = "";
    end
    warmStartFile = string(warmStartFile);
    if ~isscalar(warmStartFile)
        error('test_fit_re2024:InvalidWarmStartFile', ...
            'warmStartFile must be one path or empty.');
    end
    runLabel = string(runLabel);
    if ~isscalar(runLabel) || strlength(runLabel) == 0
        error('test_fit_re2024:InvalidRunLabel', ...
            'runLabel must be one non-empty string.');
    end

    thisDir = fileparts(mfilename('fullpath'));
    addpath(thisDir, '-begin');

    % A persistent MATLAB session can retain an earlier helper definition.
    % Reload the two files that define and consume the parameter layout before
    % constructing this run's catalogue.
    rehash;
    clear re2024_cauchy_hypothesis_spec test_ylcauchy

    build_test_mex();

    [DataAll, condLevels, d, participantIDs, trialCounts, preparedDataFile] = ...
        prepareRe2024Data([], ["AQ", "ES", "HC", "PG", "YL"], true);

    if nargin >= 5 && ~isempty(requestedParticipants)
        requestedParticipants = string(requestedParticipants);
        keepParticipant = ismember(participantIDs, requestedParticipants);
        if ~any(keepParticipant) || any(~ismember(requestedParticipants, participantIDs))
            error('test_fit_re2024:UnknownParticipant', ...
                'requestedParticipants must be drawn from: %s.', ...
                strjoin(participantIDs, ', '));
        end
        DataAll = DataAll(keepParticipant, :);
        participantIDs = participantIDs(keepParticipant);
        trialCounts = trialCounts(keepParticipant, :);
    end

    warmStartResults = struct();
    if strlength(warmStartFile) > 0
        if ~isfile(warmStartFile)
            error('test_fit_re2024:WarmStartFileMissing', ...
                'Cannot find warm-start file: %s.', warmStartFile);
        end
        warmLoaded = load(warmStartFile, 'allResults');
        if ~isfield(warmLoaded, 'allResults')
            error('test_fit_re2024:InvalidWarmStartFile', ...
                'warmStartFile must contain allResults.');
        end
        warmStartResults = warmLoaded.allResults;
    end

    nWorkers = 8;
    nStarts = 10;
    if hypothesis ~= "H0"
        nStarts = 24;
    end
    maxIter = 2000;
    maxFunEvals = 100000;
    optTol = 1e-6;
    stepTol = 1e-8;
    funTol = 1e-6;

    opts = optimoptions('fmincon', ...
        'Algorithm', 'interior-point', ...
        'Display', 'iter', ...
        'MaxIterations', maxIter, ...
        'MaxFunctionEvaluations', maxFunEvals, ...
        'OptimalityTolerance', optTol, ...
        'StepTolerance', stepTol, ...
        'FunctionTolerance', funTol, ...
        'SpecifyObjectiveGradient', false);

    try
        pool = gcp('nocreate');
        if isempty(pool) || pool.NumWorkers ~= nWorkers
            if ~isempty(pool)
                delete(pool);
            end
            parpool('local', nWorkers);
        end
        % Workers can likewise retain an old parameter-layout helper from a
        % previous fit in the same pool.  Clear cached functions before parfor
        % starts load the current files.  This is preventive only: retain the
        % parallel pool if a MATLAB release does not support pctRunOnAll.
        try
            pctRunOnAll clear functions
            pctRunOnAll rehash
        catch ME
            warning('test_fit_re2024:WorkerFunctionRefreshFailed', ...
                'Workers will refresh functions on demand. %s', ME.message);
        end
        useParallel = true;
    catch ME
        warning('test_fit_re2024:ParallelUnavailable', ...
            'Parallel pool unavailable; falling back to serial. %s', ME.message);
        useParallel = false;
    end

    catalogs = local_model_catalogs(condLevels, hypothesis);
    layoutVersion = catalogs.cauchy.layoutVersion;
    modelNames = cellstr(requestedModels(:));
    availableModels = string(fieldnames(catalogs));
    unknownModels = setdiff(requestedModels, availableModels);
    if ~isempty(unknownModels)
        error('test_fit_re2024:UnknownModel', ...
            'Unknown model(s): %s. Available models: %s.', ...
            strjoin(unknownModels, ', '), strjoin(availableModels, ', '));
    end

    resultsDir = fullfile(thisDir, 'TestFits', char(runLabel));
    if ~exist(resultsDir, 'dir')
        mkdir(resultsDir);
    end

    rows = table();
    allResults = struct();

    rng(20260901);
    totalJobs = numel(participantIDs) * numel(modelNames);
    jobCounter = 0;
    for p = 1:numel(participantIDs)
        uid = participantIDs(p);
        Data = DataAll(p, :);

        fprintf('\n============================================================\n');
        fprintf('Participant %s\n', uid);
        fprintf('============================================================\n');

        for m = 1:numel(modelNames)
            jobCounter = jobCounter + 1;
            modelName = string(modelNames{m});
            cat = catalogs.(modelNames{m});
            Pfix = cat.P0(~cat.Sel);
            Pvar0 = cat.P0(cat.Sel);
            lbFree = cat.lb(cat.Sel);
            ubFree = cat.ub(cat.Sel);

            warmStart = local_warm_start(cat, hypothesis, warmStartResults, ...
                uid, modelName);
            starts = local_build_starts(Pvar0, lbFree, ubFree, nStarts, warmStart);
            fitFunc = cat.fitFunc;

            jobTimer = tic;
            fprintf('\n[%d/%d] Preparing %s / %s with %d starts...\n', ...
                jobCounter, totalJobs, uid, modelName, nStarts);

            startNLL = zeros(nStarts, 1);
            for s = 1:nStarts
                fprintf('  Evaluating start %02d/%02d before optimization...\n', s, nStarts);
                startNLL(s) = fitFunc(starts(s, :), Pfix, cat.Sel, Data, 0);
                fprintf('    start %02d initial NLL %.4f\n', s, startNLL(s));
            end

            fprintf('\n%s / %s: %d free parameters, start-1 NLL %.4f\n', ...
                uid, modelName, sum(cat.Sel), startNLL(1));

            [allPvar, allNLL, allExitflag, allIterations, allFuncCount] = ...
                local_fit_starts(fitFunc, starts, startNLL, Pfix, cat.Sel, ...
                lbFree, ubFree, Data, opts, useParallel, uid, modelName);

            [bestNLL, bestIdx] = min(allNLL);
            bestPvar = allPvar(bestIdx, :);
            if any(bestPvar < lbFree - 1e-10) || any(bestPvar > ubFree + 1e-10)
                error('test_fit_re2024:BoundViolationAfterOptimization', ...
                    ['%s / %s returned a vector outside the exact bounds ', ...
                     'passed to fmincon.'], uid, modelName);
            end
            [bestObj, ll2, qaic, qbic, Pred] = fitFunc(bestPvar, Pfix, cat.Sel, Data, 0);
            Pfit = zeros(1, cat.np);
            Pfit(cat.Sel) = bestPvar;
            Pfit(~cat.Sel) = Pfix;
            boundary = local_boundary_report(Pfit, cat.lb, cat.ub, cat.paramNames);

            result = struct();
            result.uid = uid;
            result.modelName = modelName;
            result.hypothesis = hypothesis;
            result.layoutVersion = cat.layoutVersion;
            result.warmStartFile = warmStartFile;
            result.Pfit = Pfit;
            result.Pvar = bestPvar;
            result.Pfix = Pfix;
            result.Sel = cat.Sel;
            result.paramNames = cat.paramNames;
            % Preserve the runtime catalogue used for this fit.  This makes
            % parameter-order and bound audits possible from the MAT file.
            result.catalogP0 = cat.P0;
            result.catalogLB = cat.lb;
            result.catalogUB = cat.ub;
            result.bestNLL = bestNLL;
            result.bestObj = bestObj;
            result.ll2 = ll2;
            result.qaic = qaic;
            result.qbic = qbic;
            result.Pred = Pred;
            result.allPvar = allPvar;
            result.allNLL = allNLL;
            result.allStartNLL = startNLL;
            result.allExitflag = allExitflag;
            result.allIterations = allIterations;
            result.allFuncCount = allFuncCount;
            result.boundary = boundary;
            fieldName = matlab.lang.makeValidName(char(uid + "_" + modelName));
            allResults.(fieldName) = result;
            checkpointFile = fullfile(resultsDir, ...
                "checkpoint_" + string(uid) + "_" + modelName + ".mat");
            save(checkpointFile, 'result', 'condLevels', 'participantIDs', ...
                'trialCounts', 'preparedDataFile', 'nStarts', 'nWorkers', ...
                'opts', 'runLabel', 'hypothesis', 'warmStartFile');

            boundaryText = "";
            if ~isempty(boundary)
                boundaryText = strjoin(boundary, ', ');
            end

            rows = [rows; table(uid, modelName, sum(cat.Sel), bestIdx, ...
                bestNLL, ll2, qaic, qbic, ...
                sum(ismember(allExitflag, [1, 2])), boundaryText, ...
                'VariableNames', {'uid', 'model', 'nFree', 'bestStart', ...
                'NLL', 'minus2LL', 'AIC', 'BIC', 'nSuccess', 'boundaryParams'})]; %#ok<AGROW>

            fprintf('Best %s / %s: start %d, NLL %.4f, AIC %.2f, BIC %.2f\n', ...
                uid, modelName, bestIdx, bestNLL, qaic, qbic);
            fprintf('Saved checkpoint to %s.\n', checkpointFile);
            fprintf('Completed %s / %s in %.1f min.\n', ...
                uid, modelName, toc(jobTimer) / 60);
            if isempty(boundary)
                fprintf('No fitted parameters within 1%% of bounds.\n');
            else
                fprintf('Near-boundary parameters: %s\n', strjoin(boundary, ', '));
            end
        end
    end

    outFile = fullfile(resultsDir, ...
        runLabel + "_" + string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')) + ".mat");
    save(outFile, 'allResults', 'rows', 'condLevels', 'participantIDs', ...
        'trialCounts', 'd', 'preparedDataFile', 'nStarts', 'nWorkers', ...
                'opts', 'runLabel', 'hypothesis', 'warmStartFile', 'layoutVersion');
    writetable(rows, fullfile(resultsDir, char(runLabel + "_summary.csv")));

    output = struct();
    output.resultsFile = outFile;
    output.summary = rows;
    output.allResults = allResults;
    output.layoutVersion = layoutVersion;
end

function catalogs = local_model_catalogs(condLevels, hypothesis)
    spec = re2024_cauchy_hypothesis_spec(hypothesis, condLevels);
    catalogs = struct();
    catalogs.cauchy = local_catalog( ...
        @(varargin) test_ylcauchy(varargin{:}, spec), ...
        spec.paramNames, spec.P0, spec.lb, spec.ub, true(size(spec.P0)), ...
        spec.layoutVersion);
end

function cat = local_catalog(fitFunc, paramNames, P0, lb, ub, Sel, layoutVersion)
    cat.fitFunc = fitFunc;
    cat.paramNames = paramNames;
    cat.P0 = P0;
    cat.lb = lb;
    cat.ub = ub;
    cat.Sel = Sel;
    cat.np = numel(P0);
    cat.layoutVersion = layoutVersion;
end

function starts = local_build_starts(Pvar0, lbFree, ubFree, nStarts, warmStart)
    if nargin < 5
        warmStart = [];
    end
    nFree = numel(Pvar0);
    starts = zeros(nStarts, nFree);
    starts(1, :) = min(max(Pvar0, lbFree), ubFree);
    if ~isempty(warmStart)
        starts(1, :) = min(max(warmStart, lbFree), ubFree);
    end

    nLocal = min(5, nStarts);
    for s = 2:nLocal
        jitter = starts(1, :) .* (1 + 0.25 * randn(1, nFree));
        starts(s, :) = min(max(jitter, lbFree), ubFree);
    end
    for s = (nLocal + 1):nStarts
        u = rand(1, nFree);
        starts(s, :) = lbFree + u .* (ubFree - lbFree);
    end
end

function warmStart = local_warm_start(cat, hypothesis, warmStartResults, uid, modelName)
    warmStart = [];
    if hypothesis == "H0" || isempty(fieldnames(warmStartResults))
        return
    end

    fieldName = matlab.lang.makeValidName(char(uid + "_" + modelName));
    if ~isfield(warmStartResults, fieldName)
        warning('test_fit_re2024:WarmStartMissing', ...
            'No H0 result for %s in the supplied warm-start file.', fieldName);
        return
    end
    source = warmStartResults.(fieldName);
    sourceNames = string(source.paramNames);
    sourceP = source.Pfit;
    targetP = cat.P0;

    for i = 1:numel(cat.paramNames)
        targetName = cat.paramNames(i);
        sourceIndex = find(sourceNames == targetName, 1);
        if isempty(sourceIndex) && (startsWith(targetName, "eta_") || ...
                startsWith(targetName, "vnorm_") || startsWith(targetName, "Ter_"))
            sourceIndex = find(sourceNames == extractBefore(targetName, "_"), 1);
        end
        if isempty(sourceIndex) && startsWith(targetName, "vnormS")
            sourceIndex = find(sourceNames == "vnorm", 1);
        end
        if isempty(sourceIndex)
            error('test_fit_re2024:WarmStartMappingFailed', ...
                'Cannot map H0 parameter %s into %s.', targetName, hypothesis);
        end
        targetP(i) = sourceP(sourceIndex);
    end
    warmStart = targetP(cat.Sel);
end

function [allPvar, allNLL, allExitflag, allIterations, allFuncCount] = ...
        local_fit_starts(fitFunc, starts, startNLL, Pfix, Sel, lbFree, ubFree, ...
        Data, opts, useParallel, uid, modelName)
    nStarts = size(starts, 1);
    nFree = size(starts, 2);
    allPvar = zeros(nStarts, nFree);
    allNLL = inf(nStarts, 1);
    allExitflag = zeros(nStarts, 1);
    allIterations = zeros(nStarts, 1);
    allFuncCount = zeros(nStarts, 1);

    if useParallel
        fprintf('  Launching %d parallel fmincon starts for %s / %s...\n', ...
            nStarts, uid, modelName);
        parfor s = 1:nStarts
            [allPvar(s, :), allNLL(s), allExitflag(s), ...
                allIterations(s), allFuncCount(s)] = local_fit_one( ...
                fitFunc, starts(s, :), startNLL(s), Pfix, Sel, ...
                lbFree, ubFree, Data, opts);
        end
        fprintf('  Parallel starts returned for %s / %s.\n', uid, modelName);
    else
        for s = 1:nStarts
            startTimer = tic;
            fprintf('  Optimizing start %02d/%02d for %s / %s...\n', ...
                s, nStarts, uid, modelName);
            [allPvar(s, :), allNLL(s), allExitflag(s), ...
                allIterations(s), allFuncCount(s)] = local_fit_one( ...
                fitFunc, starts(s, :), startNLL(s), Pfix, Sel, ...
                lbFree, ubFree, Data, opts);
            fprintf(['    done start %02d/%02d: NLL %.4f, exit %d, ', ...
                'iters %d, fevals %d, %.1f min\n'], ...
                s, nStarts, allNLL(s), allExitflag(s), ...
                allIterations(s), allFuncCount(s), toc(startTimer) / 60);
        end
    end

    for s = 1:nStarts
        fprintf('  start %02d summary: initial %.4f -> final %.4f, exit %d, iters %d, fevals %d\n', ...
            s, startNLL(s), allNLL(s), allExitflag(s), ...
            allIterations(s), allFuncCount(s));
    end
end

function [PvarFit, nllFit, exitflag, iterations, funcCount] = local_fit_one( ...
        fitFunc, Pvar0, startNLL, Pfix, Sel, lbFree, ubFree, Data, opts)
    obj = @(pvar) fitFunc(pvar, Pfix, Sel, Data, 0);
    try
        [PvarFit, nllFit, exitflag, optimOut] = fmincon( ...
            obj, Pvar0, [], [], [], [], lbFree, ubFree, [], opts);
        iterations = optimOut.iterations;
        funcCount = optimOut.funcCount;
    catch
        PvarFit = Pvar0;
        nllFit = startNLL;
        exitflag = -999;
        iterations = 0;
        funcCount = 0;
    end
    if ~(isfinite(nllFit)) || nllFit > startNLL
        PvarFit = Pvar0;
        nllFit = startNLL;
    end
end

function boundary = local_boundary_report(P, lb, ub, paramNames)
    span = ub - lb;
    near = (P - lb) <= 0.01 * span | (ub - P) <= 0.01 * span;
    boundary = paramNames(near);
end
