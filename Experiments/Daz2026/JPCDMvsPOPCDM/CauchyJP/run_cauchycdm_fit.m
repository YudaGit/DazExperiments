function output = run_cauchycdm_fit(fitMode)
%RUN_CAUCHYCDM_FIT Fit nine-condition wrapped-Cauchy CDM H0.

    arguments
        fitMode (1,1) string {mustBeMember(fitMode,["smoke","full"])} = "full"
    end
    thisDir = fileparts(mfilename('fullpath'));
    addpath(thisDir);
    ensure_cauchycdm_mex;
    model = cauchycdm_model();
    targetIDs = ["AQ", "ES", "HC", "PG", "YL"];
    dataFile = fullfile('C:\Users\Yuda\Documents\GitHub\DazExperiments\Data', ...
        'Redundancy 2024', 'DazPreprocessed.csv');
    d = prepare_data(dataFile, targetIDs, model.condLevels);
    tmax = 3.0;
    rngSeed = 20260818;
    % Seven process workers are reliably available on this machine. This
    % changes only concurrency; all 16 scientific starts are retained.
    nWorkers = 7;
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

    resultsDir = fullfile(thisDir, 'CauchyFits');
    figuresDir = fullfile(thisDir, 'Figures', 'H0');
    if ~exist(resultsDir, 'dir'), mkdir(resultsDir); end
    if ~exist(figuresDir, 'dir'), mkdir(figuresDir); end
    outFile = fullfile(resultsDir, "cauchycdm_H0_" + fitMode + "_results.mat");
    fitResults = struct([]);
    comparisonRows = table();
    if isfile(outFile)
        previous = load(outFile, 'fitResults', 'comparisonRows', 'model');
        if ~isequal(previous.model.paramNames, model.paramNames) || ...
                ~isequal(previous.model.lb, model.lb) || ...
                ~isequal(previous.model.ub, model.ub)
            error('CauchyCDM:CheckpointMismatch', ...
                'Existing checkpoint uses a different parameter layout or bounds.');
        end
        fitResults = previous.fitResults;
        comparisonRows = previous.comparisonRows;
        fprintf('Resuming %s checkpoint with %d completed participant(s).\n', ...
            fitMode, numel(fitResults));
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
                [allP(s,:), allNLL(s), allExitflag(s), allIterations(s), ...
                    allFuncCount(s)] = fit_one(starts(s,:), model, ...
                    dataByCond, tmax, opts);
            end
        else
            for s = 1:nStarts
                [allP(s,:), allNLL(s), allExitflag(s), allIterations(s), ...
                    allFuncCount(s)] = fit_one(starts(s,:), model, ...
                    dataByCond, tmax, opts);
            end
        end
        elapsedSeconds = toc(timer);
        [bestNLL, bestIdx] = min(allNLL);
        Pfit = allP(bestIdx, :);
        condFit = cauchycdm_expand_P(Pfit, model);
        condFit.uid = repmat(uid, height(condFit), 1);
        condFit = movevars(condFit, 'uid', 'Before', 'Cond');
        nObs = height(dp);
        AIC = 2*bestNLL + 2*model.nFree;
        BIC = 2*bestNLL + model.nFree*log(nObs);
        fitSummary = table(model.paramNames(:), Pfit(:), model.lb(:), ...
            model.ub(:), 'VariableNames', ...
            {'Parameter','Estimate','LowerBound','UpperBound'});
        result = struct('uid',uid,'hypothesis',model.name,'Pfit',Pfit, ...
            'bestNLL',bestNLL,'AIC',AIC,'BIC',BIC,'nObs',nObs, ...
            'nFree',model.nFree,'bestIdx',bestIdx, ...
            'bestExitflag',allExitflag(bestIdx),'allP',allP, ...
            'allNLL',allNLL,'allExitflag',allExitflag, ...
            'allIterations',allIterations,'allFuncCount',allFuncCount, ...
            'fitSummary',fitSummary,'condFit',condFit, ...
            'elapsedSeconds',elapsedSeconds);
        if isempty(fitResults), fitResults = result; else, fitResults(end+1) = result; end %#ok<AGROW>
        comparisonRows = [comparisonRows; table(uid, nObs, model.nFree, ...
            bestNLL, AIC, BIC, allExitflag(bestIdx), elapsedSeconds, ...
            'VariableNames', {'uid','nObs','nFree','NLL','AIC','BIC', ...
            'bestExitflag','elapsedSeconds'})]; %#ok<AGROW>
        fprintf('%s H0: NLL %.4f, AIC %.2f, BIC %.2f, exit %d (%.1f min)\n', ...
            uid, bestNLL, AIC, BIC, allExitflag(bestIdx), elapsedSeconds/60);
        disp(fitSummary);
        if makePlots
            cauchycdm_diagnostics(uid, dp, condFit, model.condLevels, ...
                tmax, figuresDir);
        end
        save(outFile, 'fitResults','comparisonRows','model','fitMode','fitIDs', ...
            'targetIDs','tmax','nStarts','rngSeed','maxIter','maxFunEvals','tolerance');
        fprintf('Checkpoint saved: %s\n', outFile);
    end
    save(outFile, 'fitResults','comparisonRows','model','fitMode','fitIDs', ...
        'targetIDs','tmax','nStarts','rngSeed','maxIter','maxFunEvals','tolerance');
    output = struct('fitResults',fitResults,'comparisonRows',comparisonRows, ...
        'model',model,'data',d,'fitMode',fitMode,'outFile',outFile);
end

function d = prepare_data(dataFile, targetIDs, condLevels)
    d = readtable(dataFile);
    d.uid = string(d.uid);
    d = d(ismember(d.uid, targetIDs), :);
    d = d(~ismissing(d.response_error), :);
    d = d(d.response_RT >= 300 & d.response_RT <= 3000, :);
    nItems = nan(height(d),1);
    nItems(string(d.num_items)=="Two Items")=2;
    nItems(string(d.num_items)=="Four Items")=4;
    nItems(string(d.num_items)=="Six Items")=6;
    nColors = nan(height(d),1);
    nColors(string(d.ColorN)=="One Color")=1;
    nColors(string(d.ColorN)=="Two Colors")=2;
    nColors(string(d.ColorN)=="Four Colors")=4;
    nColors(string(d.ColorN)=="Six Colors")=6;
    red = strings(height(d),1);
    red(string(d.redundancy)=="Non-Redundant Cued")="NR";
    red(red=="")="R";
    d.Cond="S"+string(nItems)+"C"+string(nColors)+red;
    [known,d.condIdx]=ismember(d.Cond,condLevels);
    if any(~known), error('Unexpected condition in data.'); end
    d.rAngle=d.response_error*pi/180;
    d.rt=d.response_RT/1000;
end

function dataByCond = prepare_condition_data(dp,nCond)
    dataByCond=cell(nCond,1);
    for c=1:nCond
        dc=dp(dp.condIdx==c,:);
        dataByCond{c}=struct('rt',dc.rt,'rAngle',dc.rAngle);
    end
end

function starts = build_starts(P0,lb,ub,nStarts)
    starts=zeros(nStarts,numel(P0));
    starts(1,:)=P0;
    for s=2:nStarts, starts(s,:)=lb+rand(size(lb)).*(ub-lb); end
    if nStarts>=2
        starts(2,:)=min(max(P0.*(1+0.25*randn(size(P0))),lb),ub);
    end
end

function useParallel = start_parallel_pool(nWorkers)
    useParallel=false;
    if exist('gcp','file')~=2
        warning('CauchyCDM:ParallelUnavailable', ...
            ['Parallel Computing Toolbox is not installed. Multistart fits ', ...
             'will run serially.']);
        return
    end
    try
        pool=gcp('nocreate');
        if isempty(pool)||pool.NumWorkers~=nWorkers
            if ~isempty(pool), delete(pool); end
            parpool('local',nWorkers);
        end
        useParallel=true;
    catch ME
        warning('CauchyCDM:ParallelUnavailable','%s',ME.message);
    end
end

function [P,nll,exitflag,iterations,funcCount] = ...
        fit_one(P0,model,dataByCond,tmax,opts)
    objective=@(x)cauchycdm_nll(x,dataByCond,model,tmax);
    [P,nll,exitflag,out]=fmincon(objective,P0,[],[],[],[], ...
        model.lb,model.ub,[],opts);
    iterations=out.iterations;
    funcCount=out.funcCount;
end
