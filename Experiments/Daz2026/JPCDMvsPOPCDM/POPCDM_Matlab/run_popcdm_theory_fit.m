function output = run_popcdm_theory_fit(hypothesisNames, fitMode)
%RUN_POPCDM_THEORY_FIT Fit POPCDM theory hypotheses.
%   output = run_popcdm_theory_fit("H1", "full")
%   output = run_popcdm_theory_fit(["H0a","H0b"], "full")
%
% H0a: 1k 9a baseline. H0b: 1a 9k baseline.
% H1: H0a with 3-beta power-law alpha.
% Shared: 3 set-size vnorms (S2/S4/S6), singleton ter/eta1/a/st, eta2 = exp(-6).
% H0b and H1 warm-start from H0a (or legacy H3a files) when available.
%
% Uses Example Fitting Package Sel/Pvar/Pfix maps with MultiStart-style
% fmincon (interior-point) over 16 custom starts (parfor), MaxIter=2000,
% MaxFunEvals=20000 (full), tolerance-based stopping, 8 workers.

    arguments
        hypothesisNames (1,:) string = "H1"
        fitMode (1,1) string {mustBeMember(fitMode, ["smoke","full"])} = "full"
    end

    catalog = pop_theory_models();
    hypothesisNames = normalize_hypothesis_names(hypothesisNames);
    hypothesisNames = order_hypotheses_for_warmstart(hypothesisNames);

    targetIDs = ["AQ", "ES", "HC", "PG", "YL"];
    dataFile = fullfile('C:\Users\Yuda\Documents\GitHub\DazExperiments\Data', ...
        'Redundancy 2024', 'DazPreprocessed.csv');

    dAll = readtable(dataFile);
    dAll.uid = string(dAll.uid);
    d = dAll(ismember(dAll.uid, targetIDs), :);

    nBeforeMissingError = height(d);
    d = d(~ismissing(d.response_error), :);
    nMissingErrorRemoved = nBeforeMissingError - height(d);

    nBeforeRT = height(d);
    d = d(d.response_RT >= 300 & d.response_RT <= 3000, :);
    nRTRemoved = nBeforeRT - height(d);

    fprintf('Removed %d trials with missing response_error.\n', nMissingErrorRemoved);
    fprintf('Removed %d trials with response_RT < 300 ms or > 3000 ms.\n', nRTRemoved);
    fprintf('Remaining trials after filtering: %d.\n', height(d));

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

    condLevels = catalog.condLevels;
    [isKnownCond, condIdx] = ismember(d.Cond, condLevels);
    if any(~isKnownCond)
        error('Unexpected condition value found.');
    end
    d.condIdx = condIdx;

    nw = 50;
    tmax = 3.0;
    h = tmax / 300;
    nStarts = 16;
    nWorkers = 8;
    rngSeed = 20260810;
    optimName = "fmincon-multistart";

    if fitMode == "smoke"
        fitIDs = targetIDs(1);
        hypothesisNames = hypothesisNames(1);
        maxIter = 80;
        maxFunEvals = 500;
        optTol = 1e-4;
        stepTol = 1e-4;
        funTol = 1e-4;
        makeDiagnosticPlots = false;
    else
        fitIDs = targetIDs;
        maxIter = 2000;
        maxFunEvals = 20000;
        optTol = 1e-6;
        stepTol = 1e-6;
        funTol = 1e-6;
        makeDiagnosticPlots = true;
    end

    rng(rngSeed, 'twister');

    if ~local_has_fmincon()
        error('fmincon required. Install Optimization Toolbox.');
    end

    fprintf(['Optimizer: MultiStart-style fmincon (interior-point), ', ...
        '%d custom starts, MaxIter=%d, MaxFunEvals=%d.\n'], ...
        nStarts, maxIter, maxFunEvals);
    fprintf(['(Parallel MultiStart cannot use OutputFcn; running the same ', ...
        'local fmincon starts via parfor.)\n']);
    fprintf('Stopping tolerances: Optimality=%.1e Step=%.1e Function=%.1e\n', ...
        optTol, stepTol, funTol);

    opts = optimoptions('fmincon', ...
        'Display', 'off', ...
        'Algorithm', 'interior-point', ...
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
        warning('POPCDM:ParallelPoolUnavailable', '%s', sprintf( ...
            ['Parallel pool could not be started. Falling back to serial.\n%s'], ...
            ME.message));
        useParallel = false;
    end

    functionFolder = fileparts(mfilename('fullpath'));
    resultsFolder = fullfile(functionFolder, 'TheoryFits');
    if ~exist(resultsFolder, 'dir')
        mkdir(resultsFolder);
    end

    allModelResults = struct();
    comparisonRows = table();

    fprintf('Fixed eta2 = exp(-6) = %.6g\n', catalog.eta2Fixed);
    fprintf('\nTheory Sel maps (1 = free / Pvar, 0 = fixed / Pfix):\n');
    for hIdx = 1:numel(hypothesisNames)
        hypPreview = catalog.(char(hypothesisNames(hIdx)));
        fprintf('  %s (%d free): %s\n', ...
            hypPreview.name, hypPreview.nFree, ...
            strjoin(catalog.paramNames(hypPreview.Sel), ', '));
    end

    for hIdx = 1:numel(hypothesisNames)
        hypName = hypothesisNames(hIdx);
        if ~isfield(catalog, char(hypName))
            error('Unknown hypothesis %s. Use H0a, H0b, or H1.', hypName);
        end
        hyp = catalog.(char(hypName));
        hyp.freeNames = catalog.paramNames(hyp.Sel);

        fprintf('\n############################################################\n');
        fprintf('Hypothesis %s (%d free params): %s\n', ...
            hyp.name, hyp.nFree, hyp.description);
        fprintf('############################################################\n');

        fitResults = struct([]);
        for p = 1:numel(fitIDs)
            uid = fitIDs(p);
            dp = d(d.uid == uid, :);
            dataByCond = prepare_condition_data(dp, numel(condLevels));
            nObs = height(dp);

            fprintf('\n------------------------------\n');
            fprintf('Fitting %s for %s (%d trials, %d free params)\n', ...
                hyp.name, uid, nObs, hyp.nFree);
            fprintf('------------------------------\n');

            meta = struct();
            meta.hyp = hyp;
            meta.catalog = catalog;
            meta.nw = nw;
            meta.h = h;
            meta.tmax = tmax;

            Sel = hyp.Sel;
            Pfix = catalog.P0(~Sel);
            lbFree = catalog.lb(Sel);
            ubFree = catalog.ub(Sel);

            warmPvar = [];
            warmSource = "";
            warmLabel = "";
            if ismember(hyp.name, ["H0b", "H1"])
                [warmPfull, warmSource] = resolve_saved_fit( ...
                    uid, allModelResults, resultsFolder, fitMode, catalog, "H0a");
                if ~isempty(warmPfull)
                    warmPvar = nested_pvar_from_h0a(warmPfull, hyp, catalog);
                    warmPvar = min(max(warmPvar, lbFree), ubFree);
                    warmLabel = "H0a";
                end
            end

            starts = build_starts( ...
                catalog.P0, Sel, lbFree, ubFree, nStarts, warmPvar);
            if strlength(warmSource) > 0
                fprintf('Warm start from %s (%s).\n', warmLabel, warmSource);
            elseif ismember(hyp.name, ["H0b", "H1"])
                fprintf('No H0a warm start available; using catalog/random starts.\n');
            end

            testNLL = popcdm_nll_theory(starts(1,:), Pfix, Sel, dataByCond, meta);
            fprintf('Start-1 NLL before optimize: %.4f\n', testNLL);

            fitTimer = tic;
            [bestPvar, bestNLL, bestIdx, allPvar, allNLL, allStartNLL, ...
                allExitflag, allIterations, allFuncCount, msOutput] = ...
                fit_with_multistart( ...
                starts, Pfix, Sel, lbFree, ubFree, dataByCond, meta, ...
                opts, useParallel);
            elapsedSeconds = toc(fitTimer);

            nSuccess = sum(ismember(allExitflag, [1, 2]));
            nMaxIter = sum(allExitflag == 0);
            nMaxFun = sum(allExitflag == -1);
            fprintf('Multistart done: %d/%d local successes (exit 1/2), ', ...
                nSuccess, nStarts);
            fprintf('%d MaxIter, %d MaxFunEvals (%.1f min).\n', ...
                nMaxIter, nMaxFun, elapsedSeconds / 60);
            for s = 1:nStarts
                fprintf('  start %d: NLL %.4f (exit %d, iters %d, feval %d)\n', ...
                    s, allNLL(s), allExitflag(s), allIterations(s), allFuncCount(s));
            end

            Pfit = catalog.P0;
            Pfit(Sel) = bestPvar;
            Pfit(~Sel) = Pfix;

            condFit = pop_theory_expand_P(Pfit, hyp, catalog);
            condFit.uid = repmat(uid, height(condFit), 1);
            condFit = movevars(condFit, "uid", "Before", "Cond");

            nFree = hyp.nFree;
            AIC = 2 * nFree + 2 * bestNLL;
            BIC = nFree * log(nObs) + 2 * bestNLL;

            fitSummary = table( ...
                repmat(uid, nFree, 1), ...
                repmat(string(hyp.name), nFree, 1), ...
                hyp.freeNames(:), ...
                bestPvar(:), ...
                lbFree(:), ...
                ubFree(:), ...
                'VariableNames', ...
                {'uid', 'Hypothesis', 'Parameter', 'Estimate', 'LowerBound', 'UpperBound'});

            fprintf('\nBest %s / %s: start %d, NLL=%.4f, AIC=%.2f, BIC=%.2f (%.1f min)\n', ...
                hyp.name, uid, bestIdx, bestNLL, AIC, BIC, elapsedSeconds / 60);
            disp(fitSummary(:, ["Parameter", "Estimate", "LowerBound", "UpperBound"]));
            fprintf('Condition-level expanded parameters:\n');
            disp(condFit(:, ["Cond", "TrialKind", "Vnorm", "Eta2", "Alpha", ...
                "Kappa", "A2", "A1", "BetaUsed", "AlphaM"]));

            result = struct();
            result.uid = uid;
            result.hypothesis = hyp.name;
            result.optimizer = optimName;
            result.Pfit = Pfit;
            result.Pvar = bestPvar;
            result.Pfix = Pfix;
            result.Sel = Sel;
            result.bestNLL = bestNLL;
            result.AIC = AIC;
            result.BIC = BIC;
            result.nObs = nObs;
            result.nFree = nFree;
            result.bestIdx = bestIdx;
            result.bestExitflag = allExitflag(bestIdx);
            result.allPvar = allPvar;
            result.allNLL = allNLL;
            result.allStartNLL = allStartNLL;
            result.allExitflag = allExitflag;
            result.allIterations = allIterations;
            result.allFuncCount = allFuncCount;
            result.nLocalSuccess = nSuccess;
            result.msOutput = msOutput;
            result.fitSummary = fitSummary;
            result.condFit = condFit;
            result.elapsedSeconds = elapsedSeconds;
            result.paramNames = catalog.paramNames;
            result.freeNames = hyp.freeNames;

            if isempty(fitResults)
                fitResults = result;
            else
                fitResults(end + 1) = result; %#ok<AGROW>
            end

            comparisonRows = [comparisonRows; table( ...
                uid, string(hyp.name), nObs, nFree, bestNLL, AIC, BIC, ...
                allExitflag(bestIdx), nSuccess, ...
                'VariableNames', ...
                {'uid','Hypothesis','nObs','nFree','NLL','AIC','BIC', ...
                 'bestExitflag','nLocalSuccess'})]; %#ok<AGROW>

            if makeDiagnosticPlots
                plot_theory_diagnostics( ...
                    uid, dp, condFit, condLevels, nw, h, tmax, hyp.name);
            end
        end

        allModelResults.(char(hyp.name)) = fitResults;

        outFile = fullfile(resultsFolder, ...
            sprintf('pop_theory_%s_%s_results.mat', hyp.name, fitMode));
        save(outFile, 'fitResults', 'hyp', 'catalog', 'condLevels', ...
            'targetIDs', 'fitIDs', 'nw', 'h', 'tmax', 'nStarts', ...
            'rngSeed', 'fitMode', 'optimName', 'maxIter', 'maxFunEvals', ...
            'optTol', 'stepTol', 'funTol');
        fprintf('Saved %s\n', outFile);
    end

    fprintf('\n==================== Model comparison ====================\n');
    disp(comparisonRows);
    comparisonFile = fullfile(resultsFolder, ...
        sprintf('pop_theory_comparison_%s.mat', fitMode));
    save(comparisonFile, 'comparisonRows', 'allModelResults', ...
        'catalog', 'fitMode', 'rngSeed', 'optimName', ...
        'maxIter', 'maxFunEvals', 'optTol', 'stepTol', 'funTol');
    fprintf('Saved comparison table: %s\n', comparisonFile);

    output.comparisonRows = comparisonRows;
    output.allModelResults = allModelResults;
    output.catalog = catalog;
    output.data = d;
    output.condLevels = condLevels;
    output.fitIDs = fitIDs;
    output.nw = nw;
    output.h = h;
    output.tmax = tmax;
    output.nStarts = nStarts;
    output.fitMode = fitMode;
    output.rngSeed = rngSeed;
    output.optimizer = optimName;
    output.resultsFolder = resultsFolder;
end

function names = normalize_hypothesis_names(hypothesisNames)
    names = strings(size(hypothesisNames));
    for i = 1:numel(hypothesisNames)
        raw = upper(strtrim(hypothesisNames(i)));
        switch raw
            case {"H0A", "H3A", "H3"}
                names(i) = "H0a";
            case {"H0B", "H3B"}
                names(i) = "H0b";
            case {"H1", "1"}
                names(i) = "H1";
            otherwise
                error('Unknown hypothesis %s. Use H0a, H0b, or H1.', ...
                    hypothesisNames(i));
        end
    end
    names = unique(names, 'stable');
end

function names = order_hypotheses_for_warmstart(hypothesisNames)
    % Fit H0a before models that warm-start from it.
    names = hypothesisNames;
    isH0a = names == "H0a";
    isH0b = names == "H0b";
    isH1 = names == "H1";
    rest = names(~isH0a & ~isH0b & ~isH1);
    names = [names(isH0a), rest, names(isH0b), names(isH1)];
end

function [Pfull, source] = resolve_saved_fit( ...
        uid, allModelResults, resultsFolder, fitMode, catalog, hypName)
    Pfull = [];
    source = "";
    namesToTry = string(hypName);
    if hypName == "H0a"
        namesToTry = ["H0a", "H3a"];
    elseif hypName == "H0b"
        namesToTry = ["H0b", "H3b"];
    end

    for n = 1:numel(namesToTry)
        hypKey = char(namesToTry(n));
        if isfield(allModelResults, hypKey) && ~isempty(allModelResults.(hypKey))
            idx = find(string({allModelResults.(hypKey).uid}) == uid, 1);
            if ~isempty(idx)
                Pfull = allModelResults.(hypKey)(idx).Pfit;
                source = "this run";
                return
            end
        end

        candFiles = { ...
            fullfile(resultsFolder, sprintf('pop_theory_%s_%s_results.mat', hypKey, fitMode)), ...
            fullfile(resultsFolder, sprintf('pop_theory_%s_full_results.mat', hypKey))};
        for f = 1:numel(candFiles)
            if ~exist(candFiles{f}, 'file')
                continue
            end
            S = load(candFiles{f}, 'fitResults');
            if ~isfield(S, 'fitResults') || isempty(S.fitResults)
                continue
            end
            idx = find(string({S.fitResults.uid}) == uid, 1);
            if isempty(idx)
                continue
            end
            Pfull = S.fitResults(idx).Pfit;
            if numel(Pfull) ~= catalog.np
                warning('POPCDM:WarmLength', ...
                    'Saved %s Pfit length %d != catalog.np %d for %s; skipping.', ...
                    hypKey, numel(Pfull), catalog.np, uid);
                Pfull = [];
                continue
            end
            source = sprintf('file %s', candFiles{f});
            return
        end
    end
end

function Pvar = nested_pvar_from_h0a(P0a, hyp, catalog)
%NESTED_PVAR_FROM_H0A Map H0a (1k 9a) into H0b or H1 as a start.
    index = catalog.index;
    P = P0a(:)';
    if numel(P) ~= catalog.np
        error('H0a Pfit length mismatch for nested warm start.');
    end

    switch hyp.name
        case "H0b"
            P(index.kappaCond) = P(index.kappaShared);
            P(index.alphaShared) = median(P(index.alphaCond));
        case "H1"
            condFit = pop_theory_expand_P(P, catalog.H0a, catalog);
            isNc2 = catalog.design.nColors == 2;
            P(index.A2) = median(condFit.Alpha(isNc2));
        otherwise
    end

    P = min(max(P, catalog.lb), catalog.ub);
    Pvar = P(hyp.Sel);
end

function tf = local_has_fmincon()
    tf = false;
    try
        v = ver;
        if ~any(strcmp({v.Name}, 'Optimization Toolbox'))
            return
        end
        if isempty(which('fmincon'))
            return
        end
        opts = optimoptions('fmincon', 'Display', 'off', ...
            'MaxIterations', 1, 'MaxFunctionEvaluations', 5);
        fmincon(@(x) sum(x.^2), 0.5, [], [], [], [], 0, 1, [], opts);
        tf = true;
    catch
        tf = false;
    end
end

function [bestPvar, bestNLL, bestIdx, allPvar, allNLL, allStartNLL, ...
        allExitflag, allIterations, allFuncCount, msOutput] = ...
        fit_with_multistart(starts, Pfix, Sel, lbFree, ubFree, ...
        dataByCond, meta, opts, useParallel)
%FIT_WITH_MULTISTART MultiStart-equivalent: fmincon from each custom start.
%   MultiStart.UseParallel cannot record OutputFcn, so local solves are run
%   directly (parfor/for) with the same fmincon options and start set.

    nStarts = size(starts, 1);
    nFree = size(starts, 2);

    allStartNLL = inf(nStarts, 1);
    for s = 1:nStarts
        allStartNLL(s) = popcdm_nll_theory( ...
            starts(s, :), Pfix, Sel, dataByCond, meta);
    end

    allPvar = zeros(nStarts, nFree);
    allNLL = inf(nStarts, 1);
    allExitflag = zeros(nStarts, 1);
    allIterations = zeros(nStarts, 1);
    allFuncCount = zeros(nStarts, 1);

    if useParallel
        parfor s = 1:nStarts
            [allPvar(s, :), allNLL(s), allExitflag(s), ...
                allIterations(s), allFuncCount(s)] = fit_one_fmincon( ...
                starts(s, :), allStartNLL(s), Pfix, Sel, lbFree, ubFree, ...
                dataByCond, meta, opts);
        end
    else
        for s = 1:nStarts
            [allPvar(s, :), allNLL(s), allExitflag(s), ...
                allIterations(s), allFuncCount(s)] = fit_one_fmincon( ...
                starts(s, :), allStartNLL(s), Pfix, Sel, lbFree, ubFree, ...
                dataByCond, meta, opts);
        end
    end

    [bestNLL, bestIdx] = min(allNLL);
    bestPvar = allPvar(bestIdx, :);

    msOutput = struct();
    msOutput.method = 'fmincon-custom-multistart';
    msOutput.useParallel = useParallel;
    msOutput.localSolverTotal = nStarts;
    msOutput.localSolverSuccess = sum(ismember(allExitflag, [1, 2]));
    msOutput.funcCount = sum(allFuncCount);
end

function [PvarFit, nllFit, exitflag, iterations, funcCount] = ...
        fit_one_fmincon(Pvar0, startNLL, Pfix, Sel, lbFree, ubFree, ...
        dataByCond, meta, opts)
    try
        obj = @(pvar) popcdm_nll_theory(pvar, Pfix, Sel, dataByCond, meta);
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

function starts = build_starts(P0, Sel, lbFree, ubFree, nStarts, warmPvar)
    if nargin < 6
        warmPvar = [];
    end
    nFree = sum(Sel);
    starts = zeros(nStarts, nFree);

    % Start 1: nested H0 warm start if provided, else catalog defaults
    if ~isempty(warmPvar)
        starts(1, :) = min(max(warmPvar(:).', lbFree), ubFree);
    else
        starts(1, :) = min(max(P0(Sel), lbFree), ubFree);
    end

    % Remaining starts: uniform draws in free bounds
    for s = 2:nStarts
        u = rand(1, nFree);
        starts(s, :) = lbFree + u .* (ubFree - lbFree);
    end

    % Start 2: mild jitter around start 1 (warm or default)
    if nStarts >= 2
        jitter = starts(1, :) .* (1 + 0.25 * randn(1, nFree));
        starts(2, :) = min(max(jitter, lbFree), ubFree);
    end

    % Start 3: catalog defaults when start 1 was a warm start
    if nStarts >= 3 && ~isempty(warmPvar)
        starts(3, :) = min(max(P0(Sel), lbFree), ubFree);
    end
end

function dataByCond = prepare_condition_data(dp, nCond)
    dataByCond = cell(nCond, 1);
    for c = 1:nCond
        dc = dp(dp.condIdx == c, :);
        dataByCond{c}.rt = dc.rt;
        dataByCond{c}.rAngle = dc.rAngle;
    end
end

function plot_theory_diagnostics( ...
        uid, dp, condFit, condLevels, nw, h, tmax, hypName)
    nCond = numel(condLevels);
    thetaDeg = cell(nCond, 1);
    angleDensityDeg = cell(nCond, 1);
    modelT = cell(nCond, 1);
    rtDensity = cell(nCond, 1);
    angleEdges = -180:5:180;
    rtEdges = 0.3:0.025:3.0;

    for c = 1:nCond
        P = [condFit.Vnorm(c), condFit.Eta1(c), condFit.Eta2(c), ...
             condFit.A(c), condFit.Alpha(c), condFit.Kappa(c), ...
             condFit.Ter(c), condFit.St(c)];
        [T, Gt, Theta] = popcdm2(P, nw, h, tmax);
        tInterior = T(1:end-1);
        gtInterior = max(Gt(:,1:end-1), 0);
        dtheta = Theta(2) - Theta(1);
        dt = tInterior(2) - tInterior(1);
        retainedTime = tInterior >= 0.3 & tInterior <= 3.0;
        gtSelected = gtInterior(:, retainedTime);
        gtSelected = gtSelected / (sum(gtSelected, 'all') * dtheta * dt);

        thetaDeg{c} = [Theta, pi] * 180 / pi;
        angleDensityRad = sum(gtSelected, 2) * dt;
        angleDensityDeg{c} = [angleDensityRad; angleDensityRad(1)].' * pi / 180;
        modelT{c} = tInterior(retainedTime);
        rtDensity{c} = sum(gtSelected, 1) * dtheta;
    end

    figure('Name', char(uid + " POPCDM " + hypName + " angle diagnostics"));
    tiledlayout(3, 3);
    sgtitle(uid + " POPCDM " + hypName + " response-error distributions");
    for c = 1:nCond
        dc = dp(dp.condIdx == c, :);
        nexttile;
        histogram(dc.rAngle * 180/pi, 'Normalization', 'pdf', ...
            'BinEdges', angleEdges, 'FaceColor', [0.25, 0.45, 1.00], ...
            'FaceAlpha', 0.25, 'EdgeColor', [0.25, 0.45, 1.00]);
        hold on;
        plot(thetaDeg{c}, angleDensityDeg{c}, 'r-', 'LineWidth', 2);
        title(condLevels(c), 'Interpreter', 'none');
        xlim([-180, 180]);
        xlabel('Response error (deg)');
        ylabel('Density');
    end

    figure('Name', char(uid + " POPCDM " + hypName + " RT diagnostics"));
    tiledlayout(3, 3);
    sgtitle(uid + " POPCDM " + hypName + " RT distributions");
    for c = 1:nCond
        dc = dp(dp.condIdx == c, :);
        nexttile;
        histogram(dc.rt, 'Normalization', 'pdf', ...
            'BinEdges', rtEdges, 'FaceColor', [0.25, 0.45, 1.00], ...
            'FaceAlpha', 0.25, 'EdgeColor', [0.25, 0.45, 1.00]);
        hold on;
        plot(modelT{c}, rtDensity{c}, 'r-', 'LineWidth', 2);
        title(condLevels(c), 'Interpreter', 'none');
        xlim([0.3, tmax]);
        xlabel('RT (s)');
        ylabel('Density');
    end
end
