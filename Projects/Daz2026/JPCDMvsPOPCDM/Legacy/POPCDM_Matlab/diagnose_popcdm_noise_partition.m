function output = diagnose_popcdm_noise_partition(resultFile, outputDir)
%DIAGNOSE_POPCDM_NOISE_PARTITION Decompose angle noise across POP and CDM.
%
% Compares observed response errors with:
%   1. a standalone POP-only refit (shared kappa, 9 condition alphas),
%   2. the POP component from the saved joint H0a fit,
%   3. the CDM response kernel for a fixed drift direction at zero, and
%   4. the combined H0a POPCDM response prediction.
%
% Model angle marginals are conditioned on the fitted RT window, 0.3--3 s.
% Outputs CSV tables and one summary PNG per participant.

    arguments
        resultFile (1,1) string = fullfile('TheoryFits', ...
            'pop_theory_H0a_full_results.mat')
        outputDir (1,1) string = fullfile('Figures', 'NoisePartition')
    end

    thisDir = fileparts(mfilename('fullpath'));
    addpath(thisDir);
    if ~isfile(resultFile)
        resultFile = fullfile(thisDir, resultFile);
    end
    if ~isfolder(outputDir)
        outputDir = fullfile(thisDir, outputDir);
    end
    if ~isfile(resultFile)
        error('Saved H0a result file not found: %s', resultFile);
    end
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    saved = load(resultFile);
    fitResults = saved.fitResults;
    condLevels = string(saved.condLevels);
    nw = saved.nw;
    h = saved.h;
    tmax = saved.tmax;
    theta = -pi:(2*pi/nw):(pi-2*pi/nw);

    dataFile = fullfile('C:\Users\Yuda\Documents\GitHub\DazExperiments\Data', ...
        'Redundancy 2024', 'DazPreprocessed.csv');
    d = prepare_data(dataFile, string({fitResults.uid}), condLevels);

    rng(20260818, 'twister');
    rows = table();
    popOnlyParameters = table();
    for p = 1:numel(fitResults)
        uid = string(fitResults(p).uid);
        dp = d(d.uid == uid, :);
        [popAlpha, popKappa, popNLL] = fit_standalone_pop(dp, nw, numel(condLevels));
        popOnlyParameters = [popOnlyParameters; table( ...
            repmat(uid, numel(condLevels), 1), condLevels(:), popAlpha(:), ...
            repmat(popKappa, numel(condLevels), 1), ...
            repmat(popNLL, numel(condLevels), 1), ...
            'VariableNames', {'uid','Cond','Alpha','Kappa','TotalAngleNLL'})]; %#ok<AGROW>

        condFit = fitResults(p).condFit;
        for c = 1:numel(condLevels)
            dc = dp(dp.condIdx == c, :);
            observedP = empirical_grid_pmf(dc.rAngle, theta);
            standaloneP = pop_pmf(popAlpha(c), popKappa, nw);
            jointPopP = pop_pmf(condFit.Alpha(c), condFit.Kappa(c), nw);

            P8 = [condFit.Vnorm(c), condFit.Eta1(c), condFit.Eta2(c), ...
                condFit.A(c), condFit.Alpha(c), condFit.Kappa(c), ...
                condFit.Ter(c), condFit.St(c)];
            fixedCdmP = fixed_cdm_pmf(P8, nw, h, tmax);
            combinedP = combined_pmf(P8, nw, h, tmax);

            stageNames = ["Observed", "POP-only refit", "POP in H0a", ...
                "CDM fixed drift", "H0a POPCDM"];
            stageP = {observedP, standaloneP, jointPopP, fixedCdmP, combinedP};
            for s = 1:numel(stageNames)
                stats = angle_stats(theta, stageP{s});
                rows = [rows; table(uid, condLevels(c), stageNames(s), ...
                    height(dc), stats.circSDDeg, stats.meanAbsDeg, ...
                    stats.central, stats.shoulder, stats.tail, ...
                    'VariableNames', {'uid','Cond','Stage','nObs','CircSDDeg', ...
                    'MeanAbsDeg','CentralMass','ShoulderMass','TailMass'})]; %#ok<AGROW>
            end
        end
        make_summary_figure(rows(rows.uid == uid, :), condLevels, uid, outputDir);
        fprintf('Completed noise decomposition for %s (POP-only NLL %.3f).\n', ...
            uid, popNLL);
    end

    summaryFile = fullfile(outputDir, 'popcdm_noise_partition_summary.csv');
    parameterFile = fullfile(outputDir, 'pop_only_parameter_estimates.csv');
    writetable(rows, summaryFile);
    writetable(popOnlyParameters, parameterFile);

    aggregate = groupsummary(rows, 'Stage', 'mean', ...
        {'CircSDDeg','MeanAbsDeg','CentralMass','ShoulderMass','TailMass'});
    aggregateFile = fullfile(outputDir, 'popcdm_noise_partition_aggregate.csv');
    writetable(aggregate, aggregateFile);
    disp(aggregate);

    output.rows = rows;
    output.popOnlyParameters = popOnlyParameters;
    output.aggregate = aggregate;
    output.summaryFile = summaryFile;
    output.parameterFile = parameterFile;
    output.aggregateFile = aggregateFile;
    output.outputDir = outputDir;
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
    redundancyLabel = strings(height(d), 1);
    redundancyLabel(string(d.redundancy) == "Non-Redundant Cued") = "NR";
    redundancyLabel(redundancyLabel == "") = "R";
    d.Cond = "S" + string(nItems) + "C" + string(nColors) + redundancyLabel;
    [known, d.condIdx] = ismember(d.Cond, condLevels);
    if any(~known)
        error('Unexpected condition while preparing decomposition data.');
    end
    d.rAngle = d.response_error * pi / 180;
end

function [alpha, kappa, bestNLL] = fit_standalone_pop(dp, nw, nCond)
    lb = [0.01 * ones(1, nCond), 0.01];
    ub = [300 * ones(1, nCond), 30];
    starts = zeros(16, nCond + 1);
    starts(1, :) = [20 * ones(1, nCond), 15];
    for s = 2:size(starts, 1)
        starts(s, :) = lb + rand(1, nCond + 1) .* (ub - lb);
    end
    opts = optimset('Display', 'off', 'MaxIter', 3000, ...
        'MaxFunEvals', 30000, 'TolX', 1e-8, 'TolFun', 1e-8);
    bestNLL = inf;
    bestP = starts(1, :);
    for s = 1:size(starts, 1)
        z0 = bounded_to_unconstrained(starts(s, :), lb, ub);
        [z, nll] = fminsearch(@(x) standalone_pop_nll( ...
            unconstrained_to_bounded(x, lb, ub), dp, nw, nCond), z0, opts);
        p = unconstrained_to_bounded(z, lb, ub);
        if nll < bestNLL
            bestNLL = nll;
            bestP = p;
        end
    end
    alpha = bestP(1:nCond);
    kappa = bestP(end);
end

function z = bounded_to_unconstrained(p, lb, ub)
    q = (p - lb) ./ (ub - lb);
    q = min(max(q, 1e-10), 1 - 1e-10);
    z = log(q ./ (1 - q));
end

function p = unconstrained_to_bounded(z, lb, ub)
    q = 1 ./ (1 + exp(-z));
    p = lb + (ub - lb) .* q;
end

function nll = standalone_pop_nll(P, dp, nw, nCond)
    theta = -pi:(2*pi/nw):(pi-2*pi/nw);
    thetaClosed = [theta, pi];
    nll = 0;
    for c = 1:nCond
        angles = dp.rAngle(dp.condIdx == c);
        pmf = pop_pmf(P(c), P(end), nw);
        density = pmf / (2*pi/nw);
        like = interp1(thetaClosed, [density, density(1)], angles, ...
            'linear', 1e-12);
        nll = nll - sum(log(max(like, 1e-12)));
    end
end

function p = pop_pmf(alpha, kappa, nw)
    gamma = 0.5772156649;
    theta = -pi:(2*pi/nw):(pi-2*pi/nw);
    vm = exp(kappa * cos(theta));
    vm = vm / (2*pi*besseli(0, kappa));
    p = gamma + alpha * vm;
    p = p / sum(p);
end

function p = fixed_cdm_pmf(P8, nw, h, tmax)
    [T, Gt] = cdm([P8(1), 0, P8(2), P8(3), 1, P8(4)], nw, h, tmax);
    [T, Gt] = add_nondecision_time(T, Gt, P8(7), P8(8), h);
    p = selected_angle_pmf(T, Gt, h);
end

function p = combined_pmf(P8, nw, h, tmax)
    [T, Gt] = popcdm2(P8, nw, h, tmax);
    p = selected_angle_pmf(T, Gt, h);
end

function [T, Gt] = add_nondecision_time(T, Gta, ter, st, h)
    T = T + ter + st / 2;
    if st > 2*h
        m = round(st / h);
        Gt = zeros(size(Gta));
        kernel = ones(1, m) / m;
        for i = 1:size(Gta, 1)
            row = conv(Gta(i, :), kernel);
            Gt(i, :) = row(1:numel(T));
        end
    else
        Gt = Gta;
    end
end

function p = selected_angle_pmf(T, Gt, h)
    T = T(1:end-1);
    Gt = max(Gt(:, 1:end-1), 0);
    keep = T >= 0.3 & T <= 3.0;
    p = sum(Gt(:, keep), 2).' * h;
    p = p / sum(p);
end

function p = empirical_grid_pmf(angles, theta)
    w = theta(2) - theta(1);
    wrapped = mod(angles + pi, 2*pi) - pi;
    binIndex = mod(round((wrapped + pi) / w), numel(theta)) + 1;
    p = accumarray(binIndex(:), 1, [numel(theta), 1]).';
    p = p / sum(p);
end

function stats = angle_stats(theta, p)
    p = p(:).' / sum(p);
    absDeg = abs(theta) * 180/pi;
    R = abs(sum(p .* exp(1i*theta)));
    stats.circSDDeg = sqrt(-2*log(max(R, realmin))) * 180/pi;
    stats.meanAbsDeg = sum(p .* absDeg);
    stats.central = sum(p(absDeg <= 15));
    stats.shoulder = sum(p(absDeg > 15 & absDeg <= 45));
    stats.tail = sum(p(absDeg > 45));
end

function make_summary_figure(rows, condLevels, uid, outputDir)
    stages = ["Observed", "POP-only refit", "POP in H0a", ...
        "CDM fixed drift", "H0a POPCDM"];
    metrics = ["CentralMass", "ShoulderMass", "TailMass"];
    labels = ["Central |error| <= 15 deg", "Shoulder 15--45 deg", ...
        "Tail |error| > 45 deg"];
    f = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1450 800]);
    tiledlayout(3, 1, 'TileSpacing', 'compact');
    colors = lines(numel(stages));
    for m = 1:numel(metrics)
        nexttile;
        hold on;
        for s = 1:numel(stages)
            rs = rows(rows.Stage == stages(s), :);
            [~, order] = ismember(condLevels, rs.Cond);
            plot(1:numel(condLevels), rs.(metrics(m))(order), '-o', ...
                'LineWidth', 1.5, 'Color', colors(s, :), ...
                'DisplayName', stages(s));
        end
        hold off;
        ylim([0, 1]);
        xlim([1, numel(condLevels)]);
        xticks(1:numel(condLevels));
        xticklabels(condLevels);
        ylabel('Probability');
        title(labels(m));
        grid on;
        if m == 1
            legend('Location', 'eastoutside');
        end
    end
    sgtitle(uid + " H0a noise-stage decomposition");
    exportgraphics(f, fullfile(outputDir, uid + "_noise_partition.png"), ...
        'Resolution', 160);
    close(f);
end
