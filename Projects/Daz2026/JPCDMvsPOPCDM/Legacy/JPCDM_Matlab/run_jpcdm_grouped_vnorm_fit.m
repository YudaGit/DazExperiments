function output = run_jpcdm_grouped_vnorm_fit(freeParameter, fitMode)
%RUN_JPCDM_GROUPED_VNORM_FIT Participant-level JPCDM comparison fits.
%   "kappa" fits 9k3v; "psi" fits 9p3v.
%
% This runner mirrors run_popcdm_grouped_vnorm_fit: identical data
% preparation, condition order, three vnorm groups, three color-group ter
% parameters, fixed st, multistart settings, random seed, result structure,
% and diagnostic layout.

    arguments
        freeParameter (1,1) string {mustBeMember(freeParameter, ["kappa","psi"])}
        fitMode (1,1) string {mustBeMember(fitMode, ["smoke","full"])} = "full"
    end

    targetIDs = ["AQ", "ES", "HC", "PG", "YL"];
    dataFile = ['/Users/prefabteam_ysl/Documents/GitHub/DazExperiments/Data/' ...
        'Redundancy 2024/Modelling/POPCDM/DazPreprocessed.csv'];

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

    if any(isnan(nItems)) || any(isnan(nColors))
        error('Unexpected num_items or ColorN value while creating Cond.');
    end

    redundancyLabel = strings(height(d), 1);
    redundancyLabel(redundancyText == "Non-Redundant Cued") = "NR";
    redundancyLabel(redundancyLabel == "") = "R";

    d.rAngle = d.response_error * pi / 180;
    d.rt = d.response_RT / 1000;
    d.Cond = "S" + string(nItems) + "C" + string(nColors) + redundancyLabel;
    d.RedunN = nItems - nColors + 1;
    d = movevars(d, ["Cond", "RedunN"], "After", "redundancy");

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

    tmax = 3.0;
    stFixed = 0.20;
    etaTangentialEffective = 0.02;
    nCond = numel(condLevels);

    % Both JPCDM specifications have the same 18-parameter structure as
    % their POPCDM counterparts.
    if freeParameter == "kappa"
        model.name = "JPCDM_FreeKappa_GroupedVnorm";
        model.shortName = "9k3v";
        model.paramNames = ["vnormBase", "vnormNR", "vnormR", ...
            "eta", "psi", "a", "terC2", "terC4", "terC6", ...
            "kappa_" + condLevels];
        lb = [0.01,0.01,0.01,0.02,-1.00,0.10,0.00,0.00,0.00, ...
              repmat(0.01,1,nCond)];
        ub = [20.0,20.0,20.0,8.00,1.00,8.00,1.00,1.00,1.00, ...
              repmat(30.0,1,nCond)];
    else
        model.name = "JPCDM_FreePsi_GroupedVnorm";
        model.shortName = "9p3v";
        model.paramNames = ["vnormBase", "vnormNR", "vnormR", ...
            "eta", "kappa", "a", "terC2", "terC4", "terC6", ...
            "psi_" + condLevels];
        lb = [0.01,0.01,0.01,0.02,0.01,0.10,0.00,0.00,0.00, ...
              repmat(-1.00,1,nCond)];
        ub = [20.0,20.0,20.0,8.00,30.0,8.00,1.00,1.00,1.00, ...
              ones(1,nCond)];
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

    rngSeed = 20260711;
    rng(rngSeed, 'twister');
    nWorkers = 8;
    options = optimset('Display','off', 'MaxIter',maxIter, ...
        'MaxFunEvals',maxFunEvals, 'TolX',1e-5, 'TolFun',1e-5);

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
            warning('JPCDM:ParallelPoolUnavailable', '%s', sprintf( ...
                ['Parallel pool could not be started. ' ...
                 'Falling back to serial fitting.\n%s'], ME.message));
            useParallel = false;
        end
    end

    fitResults = struct();
    allParticipantFits = table();

    % The three-ter model nests the previous one-ter model exactly. Use the
    % previous participant optimum as a guaranteed baseline by copying its
    % single ter estimate into terC2, terC4, and terC6. Several additional
    % starts are placed near that solution; the remaining starts stay global.
    if freeParameter == "kappa"
        legacyFitFile = ['/Users/prefabteam_ysl/Documents/GitHub/' ...
            'DazExperiments/Models/CDM/JPCDM_Matlab/' ...
            'jp_fit_freeKappa_groupedVnorm_results.mat'];
        legacyField = 'fitResultKappaCond';
    else
        legacyFitFile = ['/Users/prefabteam_ysl/Documents/GitHub/' ...
            'DazExperiments/Models/CDM/JPCDM_Matlab/' ...
            'jp_fit_freePsi_groupedVnorm_results.mat'];
        legacyField = 'fitResultPsiCond';
    end

    legacyFits = [];
    if isfile(legacyFitFile)
        legacyData = load(legacyFitFile, legacyField);
        legacyFits = legacyData.(legacyField);
        fprintf('Using nested warm starts from %s\n', legacyFitFile);
    else
        warning('JPCDM:LegacyWarmStartMissing', ...
            ['Previous one-ter result file was not found. The fit will use ' ...
             'global random starts only: %s'], legacyFitFile);
    end

    for p = 1:numel(fitIDs)
        uid = fitIDs(p);
        dp = d(d.uid == uid, :);
        dataByCond = prepare_condition_data(dp, nCond);

        fprintf('\n==============================\n');
        fprintf('Fitting JPCDM %s for participant %s (%d trials)\n', ...
            model.shortName, uid, height(dp));
        fprintf('==============================\n');

        Qstarts = lb + rand(nStarts, numel(lb)) .* (ub - lb);
        usedLegacyWarmStart = false;
        if ~isempty(legacyFits)
            legacyIdx = find(string({legacyFits.uid}) == uid, 1);
            if ~isempty(legacyIdx)
                oldQ = legacyFits(legacyIdx).Qfit;
                warmQ = [oldQ(1:6), repmat(oldQ(7),1,3), oldQ(8:end)];
                warmQ = min(max(warmQ,lb),ub);
                Qstarts(1,:) = warmQ;
                usedLegacyWarmStart = true;

                % Local starts let the three ter values separate gradually
                % from their common previous estimate.
                nLocalStarts = min(7,nStarts-1);
                if nLocalStarts > 0
                    qWarm = p_to_q(warmQ,lb,ub);
                    localQ = qWarm + 0.35*randn(nLocalStarts,numel(lb));
                    Qstarts(2:1+nLocalStarts,:) = q_to_p(localQ,lb,ub);
                end
            end
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
            dataByCond, condLevels, stFixed, tmax);
        oneEvalTime = toc(evalTimer);
        fprintf('Initial test NLL: %.4f; one objective evaluation takes %.3f s.\n', ...
            testNLL, oneEvalTime);
        fprintf('Worst-case configured evaluations per start: %d.\n', maxFunEvals);

        fitTimer = tic;
        if useParallel
            fprintf('Fitting %d starts in parallel using %d workers...\n', ...
                nStarts, nWorkers);
            parfor s = 1:nStarts
                startNLL = evaluate_model(Qstarts(s,:), freeParameter, ...
                    dataByCond, condLevels, stFixed, tmax);
                qstart = p_to_q(Qstarts(s,:), lb, ub);
                obj = @(q) evaluate_model(q_to_p(q,lb,ub), freeParameter, ...
                    dataByCond, condLevels, stFixed, tmax);
                [qfit,~,exitflag,optimOutput] = fminsearch(obj, qstart, options);
                fittedQ = q_to_p(qfit, lb, ub);
                fittedNLL = evaluate_model(fittedQ, freeParameter, ...
                    dataByCond, condLevels, stFixed, tmax);
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
                startNLL = evaluate_model(Qstarts(s,:), freeParameter, ...
                    dataByCond, condLevels, stFixed, tmax);
                qstart = p_to_q(Qstarts(s,:), lb, ub);
                obj = @(q) evaluate_model(q_to_p(q,lb,ub), freeParameter, ...
                    dataByCond, condLevels, stFixed, tmax);
                [qfit,~,exitflag,optimOutput] = fminsearch(obj, qstart, options);
                fittedQ = q_to_p(qfit, lb, ub);
                fittedNLL = evaluate_model(fittedQ, freeParameter, ...
                    dataByCond, condLevels, stFixed, tmax);
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
            model.name, uid, elapsedSeconds/60);
        fprintf('Best start index: %d\nBest NLL: %.4f\n', bestIdx, bestNLL);

        fitSummary = table(repmat(uid,numel(model.paramNames),1), ...
            model.paramNames(:), Qfit(:), lb(:), ub(:), ...
            'VariableNames', ...
            {'uid','Parameter','Estimate','LowerBound','UpperBound'});
        fprintf('\nAll 18 optimized parameters for %s:\n', uid);
        disp(fitSummary(:, ["Parameter","Estimate","LowerBound","UpperBound"]));

        fixedParameterSummary = table( ...
            ["etaTangentialEffective"; "sigma"; "phi"; "st"], ...
            [etaTangentialEffective; 1.0; 0.0; stFixed], ...
            'VariableNames', {'Parameter','Value'});
        fprintf('Fixed JPCDM parameters for %s:\n', uid);
        disp(fixedParameterSummary);

        condFit = build_condition_fit(Qfit, freeParameter, condLevels, ...
            etaTangentialEffective, stFixed);
        condFit.uid = repmat(uid, height(condFit), 1);
        condFit = movevars(condFit, "uid", "Before", "Cond");
        fprintf('Full condition-level JPCDM parameters for %s:\n', uid);
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
        fitResults(p).etaTangentialEffective = etaTangentialEffective;
        fitResults(p).stFixed = stFixed;
        fitResults(p).elapsedSeconds = elapsedSeconds;
        fitResults(p).usedLegacyWarmStart = usedLegacyWarmStart;
        fitResults(p).legacyFitFile = legacyFitFile;
        allParticipantFits = [allParticipantFits; fitSummary]; %#ok<AGROW>

        if makeDiagnosticPlots
            plot_participant_diagnostics( ...
                uid, dp, condFit, condLevels, tmax, model.shortName);
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
    output.etaTangentialEffective = etaTangentialEffective;
    output.stFixed = stFixed;
    output.tmax = tmax;
    output.nStarts = nStarts;
    output.fitMode = fitMode;
    output.rngSeed = rngSeed;
end

function nll = evaluate_model( ...
        Q, freeParameter, dataByCond, condLevels, stFixed, tmax)
    if freeParameter == "kappa"
        nll = jpcdm_nll_free_kappa_prepared( ...
            Q, dataByCond, condLevels, stFixed, tmax);
    else
        nll = jpcdm_nll_free_psi_prepared( ...
            Q, dataByCond, condLevels, stFixed, tmax);
    end
end

function dataByCond = prepare_condition_data(dp, nCond)
    dataByCond = cell(nCond,1);
    for c = 1:nCond
        dc = dp(dp.condIdx == c,:);
        dataByCond{c}.rt = dc.rt;
        dataByCond{c}.rAngle = dc.rAngle;
    end
end

function condFit = build_condition_fit(Qfit, freeParameter, condLevels, ...
        etaTangentialEffective, stFixed)
    nCond = numel(condLevels);
    vnormByCond = grouped_vnorm_vector(Qfit(1:3), condLevels);
    eta = Qfit(4);
    a = Qfit(6);
    terByCond = color_group_vector(Qfit(7:9), condLevels);

    if freeParameter == "kappa"
        psi = repmat(Qfit(5), nCond, 1);
        kappa = Qfit(10:end).';
    else
        kappa = repmat(Qfit(5), nCond, 1);
        psi = Qfit(10:end).';
    end

    vnormGroup = strings(nCond,1);
    vnormGroup(ismember(condLevels, ["S2C2NR","S4C4NR","S6C6NR"])) = "Base";
    vnormGroup(ismember(condLevels, ["S4C2NR","S6C2NR","S6C4NR"])) = "NR";
    vnormGroup(ismember(condLevels, ["S4C2R","S6C2R","S6C4R"])) = "R";

    condFit = table(condLevels(:), vnormGroup, vnormByCond, kappa, ...
        repmat(eta,nCond,1), repmat(etaTangentialEffective,nCond,1), ...
        psi, repmat(a,nCond,1), terByCond, ...
        repmat(stFixed,nCond,1), ...
        'VariableNames', ...
        {'Cond','VnormGroup','Vnorm','Kappa','EtaRadial', ...
         'EtaTangential','Psi','A','Ter','St'});
end

function valuesByCond = grouped_vnorm_vector(groupValues, condLevels)
    valuesByCond = nan(numel(condLevels),1);
    valuesByCond(ismember(condLevels, ["S2C2NR","S4C4NR","S6C6NR"])) = groupValues(1);
    valuesByCond(ismember(condLevels, ["S4C2NR","S6C2NR","S6C4NR"])) = groupValues(2);
    valuesByCond(ismember(condLevels, ["S4C2R","S6C2R","S6C4R"])) = groupValues(3);
end

function valuesByCond = color_group_vector(groupValues, condLevels)
    valuesByCond = nan(numel(condLevels),1);
    valuesByCond(contains(condLevels,"C2")) = groupValues(1);
    valuesByCond(contains(condLevels,"C4")) = groupValues(2);
    valuesByCond(contains(condLevels,"C6")) = groupValues(3);
end

function plot_participant_diagnostics( ...
        uid, dp, condFit, condLevels, tmax, modelShortName)
    nCond = numel(condLevels);
    thetaDeg = cell(nCond,1);
    angleDensityDeg = cell(nCond,1);
    modelT = cell(nCond,1);
    rtDensity = cell(nCond,1);
    angleEdges = -180:5:180;    % 72 angle bins
    rtEdges = 0.3:0.025:3.0;    % 108 RT bins over the retained data range

    for c = 1:nCond
        P = [condFit.Vnorm(c), condFit.Kappa(c), condFit.EtaRadial(c), ...
             condFit.Psi(c), condFit.A(c), condFit.Ter(c), condFit.St(c)];
        [T,Gt,Theta] = jpcdm1(P,tmax);

        % Derive both plotted marginals from the same normalized 50 x 300
        % joint density used by jpcdm_nll_arrays. This prevents raw model
        % mass or the separately calculated Ptheta output from distorting
        % visual fit diagnostics.
        thetaOpen = Theta(1:end-1);
        gtOpen = max(Gt(1:end-1,:),0);
        dtheta = thetaOpen(2)-thetaOpen(1);
        dt = T(2)-T(1);
        retainedTime = T>=0.3 & T<=3.0;
        gtSelected = gtOpen(:,retainedTime);
        gtSelected = gtSelected/(sum(gtSelected,'all')*dtheta*dt);

        thetaDeg{c} = [thetaOpen,pi] * 180/pi;
        angleDensityRad = sum(gtSelected,2)*dt;
        angleDensityDeg{c} = [angleDensityRad;angleDensityRad(1)].' * pi/180;
        modelT{c} = T(retainedTime);
        rtDensity{c} = sum(gtSelected,1)*dtheta;
    end

    figure('Name',char(uid+" JPCDM "+modelShortName+" angle diagnostics"));
    tiledlayout(3,3);
    sgtitle(uid+" JPCDM "+modelShortName+" response-error distributions");
    for c = 1:nCond
        dc = dp(dp.condIdx==c,:);
        nexttile;
        histogram(dc.rAngle*180/pi, 'Normalization','pdf', ...
            'BinEdges',angleEdges, 'FaceColor',[0.25,0.45,1.00], ...
            'FaceAlpha',0.25, 'EdgeColor',[0.25,0.45,1.00]);
        hold on;
        plot(thetaDeg{c},angleDensityDeg{c},'r-','LineWidth',2);
        title(condLevels(c),'Interpreter','none');
        xlim([-180,180]);
        xlabel('Response error (deg)');
        ylabel('Density');
    end

    figure('Name',char(uid+" JPCDM "+modelShortName+" RT diagnostics"));
    tiledlayout(3,3);
    sgtitle(uid+" JPCDM "+modelShortName+" RT distributions");
    for c = 1:nCond
        dc = dp(dp.condIdx==c,:);
        nexttile;
        histogram(dc.rt, 'Normalization','pdf', ...
            'BinEdges',rtEdges, 'FaceColor',[0.25,0.45,1.00], ...
            'FaceAlpha',0.25, 'EdgeColor',[0.25,0.45,1.00]);
        hold on;
        plot(modelT{c},rtDensity{c},'r-','LineWidth',2);
        title(condLevels(c),'Interpreter','none');
        xlim([0.3,tmax]);
        xlabel('RT (s)');
        ylabel('Density');
    end
end

function q = p_to_q(P,lb,ub)
    z = (P-lb)./(ub-lb);
    z = min(max(z,1e-9),1-1e-9);
    q = log(z./(1-z));
end

function P = q_to_p(q,lb,ub)
    z = 1./(1+exp(-q));
    P = lb+(ub-lb).*z;
end
