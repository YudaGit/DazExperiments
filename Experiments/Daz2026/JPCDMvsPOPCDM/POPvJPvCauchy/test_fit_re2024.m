function output = test_fit_re2024(requestedModels)
%TEST_FIT_RE2024 Fit test POP/JP/Cauchy wrappers to Re2024 participants.
%   Uses fmincon with 10 custom starts and an 8-worker parpool, following
%   the earlier POP/Cauchy fitting workflow.
%
%   output = TEST_FIT_RE2024(["pop","jp","jpcau"]) fits only the requested
%   model routes. Available names are "pop", "jp", "jpcau", and "cauchy".

    if nargin < 1 || isempty(requestedModels)
        requestedModels = ["pop", "jp", "jpcau"];
    end
    requestedModels = string(requestedModels);

    thisDir = fileparts(mfilename('fullpath'));
    addpath(thisDir, '-begin');

    build_test_mex();

    [DataAll, condLevels, d, participantIDs, trialCounts, preparedDataFile] = ...
        prepareRe2024Data([], ["AQ", "ES", "HC", "PG", "YL"], true);

    nWorkers = 8;
    nStarts = 10;
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
        useParallel = true;
    catch ME
        warning('test_fit_re2024:ParallelUnavailable', ...
            'Parallel pool unavailable; falling back to serial. %s', ME.message);
        useParallel = false;
    end

    catalogs = local_model_catalogs(condLevels);
    modelNames = cellstr(requestedModels(:));
    availableModels = string(fieldnames(catalogs));
    unknownModels = setdiff(requestedModels, availableModels);
    if ~isempty(unknownModels)
        error('test_fit_re2024:UnknownModel', ...
            'Unknown model(s): %s. Available models: %s.', ...
            strjoin(unknownModels, ', '), strjoin(availableModels, ', '));
    end

    resultsDir = fullfile(thisDir, 'TestFits');
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

            starts = local_build_starts(Pvar0, lbFree, ubFree, nStarts);
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
            [bestObj, ll2, qaic, qbic, Pred] = fitFunc(bestPvar, Pfix, cat.Sel, Data, 0);
            Pfit = zeros(1, cat.np);
            Pfit(cat.Sel) = bestPvar;
            Pfit(~cat.Sel) = Pfix;
            boundary = local_boundary_report(Pfit, cat.lb, cat.ub, cat.paramNames);

            result = struct();
            result.uid = uid;
            result.modelName = modelName;
            result.Pfit = Pfit;
            result.Pvar = bestPvar;
            result.Pfix = Pfix;
            result.Sel = cat.Sel;
            result.paramNames = cat.paramNames;
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
                'trialCounts', 'preparedDataFile', 'nStarts', 'nWorkers', 'opts');

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
        "test_fit_re2024_" + string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')) + ".mat");
    save(outFile, 'allResults', 'rows', 'condLevels', 'participantIDs', ...
        'trialCounts', 'd', 'preparedDataFile', 'nStarts', 'nWorkers', 'opts');
    writetable(rows, fullfile(resultsDir, 'test_fit_re2024_summary.csv'));

    output = struct();
    output.resultsFile = outFile;
    output.summary = rows;
    output.allResults = allResults;
end

function catalogs = local_model_catalogs(condLevels)
    nCond = numel(condLevels);
    setNames = ["S2", "S4", "S6"];

    popNames = ["vnorm" + setNames, "kappa", "xi_" + condLevels, ...
        "eta", "a", "Ter", "st"];
    popP0 = [6, 6, 6, 15, 0.08 * ones(1, nCond), 0.5, 6, 0.25, 0.2];
    popLb = [2 * ones(1, 3), 0.01, 0.0001 * ones(1, nCond), 0.02, 2, 0, 0];
    popUb = [12 * ones(1, 3), 80, 5 * ones(1, nCond), 8, 12, 1, 0.7];
    popSel = true(1, numel(popP0));

    cauNames = ["vnorm" + setNames, "kappa_" + condLevels, ...
        "eta", "a", "Ter", "st"];
    cauP0 = [6, 6, 6, 8 * ones(1, nCond), 0.5, 6, 0.25, 0.2];
    cauLb = [2 * ones(1, 3), 0.001 * ones(1, nCond), 0.02, 2, 0, 0];
    cauUb = [12 * ones(1, 3), 80 * ones(1, nCond), 8, 12, 1, 0.7];
    cauSel = true(1, numel(cauP0));

    jpNames = ["vnorm" + setNames, "kappa_" + condLevels, ...
        "eta", "a", "Ter", "st", "psi"];
    jpP0 = [6, 6, 6, 8 * ones(1, nCond), 0.5, 6, 0.25, 0.2, -1];
    jpLb = [2 * ones(1, 3), 0.001 * ones(1, nCond), 0.02, 2, 0, 0, -1.95];
    jpUb = [12 * ones(1, 3), 80 * ones(1, nCond), 8, 12, 1, 0.7, 0.95];
    jpSel = true(1, numel(jpP0));

    jpcauNames = ["vnorm" + setNames, "kappa_" + condLevels, ...
        "eta", "a", "Ter", "st"];
    jpcauP0 = [6, 6, 6, 8 * ones(1, nCond), 0.5, 6, 0.25, 0.2];
    jpcauLb = [2 * ones(1, 3), 0.001 * ones(1, nCond), 0.02, 2, 0, 0];
    jpcauUb = [12 * ones(1, 3), 80 * ones(1, nCond), 8, 12, 1, 0.7];
    jpcauSel = true(1, numel(jpcauP0));

    catalogs.pop = local_catalog(@test_ylpop, popNames, popP0, popLb, popUb, popSel);
    catalogs.jp = local_catalog(@test_yljp, jpNames, jpP0, jpLb, jpUb, jpSel);
    catalogs.jpcau = local_catalog(@test_yljpcau, jpcauNames, jpcauP0, jpcauLb, jpcauUb, jpcauSel);
    catalogs.cauchy = local_catalog(@test_ylcauchy, cauNames, cauP0, cauLb, cauUb, cauSel);
end

function cat = local_catalog(fitFunc, paramNames, P0, lb, ub, Sel)
    cat.fitFunc = fitFunc;
    cat.paramNames = paramNames;
    cat.P0 = P0;
    cat.lb = lb;
    cat.ub = ub;
    cat.Sel = Sel;
    cat.np = numel(P0);
end

function starts = local_build_starts(Pvar0, lbFree, ubFree, nStarts)
    nFree = numel(Pvar0);
    starts = zeros(nStarts, nFree);
    starts(1, :) = min(max(Pvar0, lbFree), ubFree);
    for s = 2:nStarts
        u = rand(1, nFree);
        starts(s, :) = lbFree + u .* (ubFree - lbFree);
    end
    if nStarts >= 2
        jitter = starts(1, :) .* (1 + 0.25 * randn(1, nFree));
        starts(2, :) = min(max(jitter, lbFree), ubFree);
    end
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
