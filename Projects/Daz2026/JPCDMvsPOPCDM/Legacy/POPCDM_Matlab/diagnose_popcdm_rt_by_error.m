function output = diagnose_popcdm_rt_by_error(resultFile, outputDir)
%DIAGNOSE_POPCDM_RT_BY_ERROR RT signatures and latent-direction attribution.
%
% For each H0a participant and condition, this diagnostic:
%   1. compares observed and predicted RT within central, shoulder, and tail
%      response-error regions; and
%   2. decomposes predicted responses by the region of the latent POP drift
%      direction that entered the CDM.
%
% Regions: central <= 15 deg, shoulder 15--45 deg, tail > 45 deg.

    arguments
        resultFile (1,1) string = fullfile('TheoryFits', ...
            'pop_theory_H0a_full_results.mat')
        outputDir (1,1) string = fullfile('Figures', 'RTByError')
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
    dataFile = fullfile('C:\Users\Yuda\Documents\GitHub\DazExperiments\Data', ...
        'Redundancy 2024', 'DazPreprocessed.csv');
    d = prepare_data(dataFile, string({fitResults.uid}), condLevels);

    rtRows = table();
    attributionRows = table();
    validationRows = table();
    for p = 1:numel(fitResults)
        uid = string(fitResults(p).uid);
        dp = d(d.uid == uid, :);
        condFit = fitResults(p).condFit;
        for c = 1:numel(condLevels)
            dc = dp(dp.condIdx == c, :);
            P8 = [condFit.Vnorm(c), condFit.Eta1(c), condFit.Eta2(c), ...
                condFit.A(c), condFit.Alpha(c), condFit.Kappa(c), ...
                condFit.Ter(c), condFit.St(c)];
            [T, Gt, theta, sourceMass, maxAbsDifference] = ...
                decomposed_joint_density(P8, nw, h, tmax);
            validationRows = [validationRows; table(uid, condLevels(c), ...
                maxAbsDifference, 'VariableNames', ...
                {'uid','Cond','MaxAbsJointDifference'})]; %#ok<AGROW>

            regionNames = ["Central", "Shoulder", "Tail"];
            responseRegion = region_index(theta);
            observedRegion = region_index(dc.rAngle);
            for r = 1:numel(regionNames)
                observedRT = dc.rt(observedRegion == r);
                observedStats = sample_rt_stats(observedRT);
                modelStats = model_rt_stats(T, Gt, responseRegion == r, h);
                rtRows = [rtRows; make_rt_row(uid, condLevels(c), ...
                    regionNames(r), "Observed", observedStats); ...
                    make_rt_row(uid, condLevels(c), regionNames(r), ...
                    "H0a POPCDM", modelStats)]; %#ok<AGROW>

                responseMass = sum(sourceMass(:, r));
                for latent = 1:numel(regionNames)
                    posterior = sourceMass(latent, r) / responseMass;
                    attributionRows = [attributionRows; table(uid, ...
                        condLevels(c), regionNames(r), regionNames(latent), ...
                        sourceMass(latent, r), responseMass, posterior, ...
                        'VariableNames', {'uid','Cond','ResponseRegion', ...
                        'LatentPOPRegion','JointMass','ResponseMass', ...
                        'PosteriorGivenResponse'})]; %#ok<AGROW>
                end
            end
        end
        make_rt_figure(rtRows(rtRows.uid == uid, :), condLevels, uid, outputDir);
        fprintf('Completed RT/error decomposition for %s.\n', uid);
    end

    rtFile = fullfile(outputDir, 'popcdm_rt_by_error_summary.csv');
    attributionFile = fullfile(outputDir, 'popcdm_latent_response_attribution.csv');
    validationFile = fullfile(outputDir, 'popcdm_decomposition_validation.csv');
    writetable(rtRows, rtFile);
    writetable(attributionRows, attributionFile);
    writetable(validationRows, validationFile);

    rtAggregate = aggregate_rt(rtRows);
    attributionAggregate = aggregate_attribution(attributionRows);
    rtAggregateFile = fullfile(outputDir, 'popcdm_rt_by_error_aggregate.csv');
    attributionAggregateFile = fullfile(outputDir, ...
        'popcdm_latent_response_attribution_aggregate.csv');
    writetable(rtAggregate, rtAggregateFile);
    writetable(attributionAggregate, attributionAggregateFile);
    disp(rtAggregate);
    disp(attributionAggregate);

    output.rtRows = rtRows;
    output.attributionRows = attributionRows;
    output.validationRows = validationRows;
    output.rtAggregate = rtAggregate;
    output.attributionAggregate = attributionAggregate;
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
        error('Unexpected condition while preparing RT diagnostic data.');
    end
    d.rAngle = d.response_error * pi / 180;
    d.rt = d.response_RT / 1000;
end

function [T, Gt, theta, sourceMass, maxAbsDifference] = ...
        decomposed_joint_density(P8, nw, h, tmax)
    w = 2*pi/nw;
    theta = -pi:w:(pi-w);
    pang = pop_pmf(P8(5), P8(6), nw);

    v1 = P8(1) * cos(theta(1));
    v2 = P8(1) * sin(theta(1));
    [Tdecision, canonicalGt] = cdm( ...
        [v1, v2, P8(2), P8(3), 1, P8(4)], nw, h, tmax);
    [T, ~] = add_nondecision_time( ...
        Tdecision, zeros(size(canonicalGt)), P8(7), P8(8), h);

    nTime = numel(T);
    components = zeros(nw, nTime, nw);
    for latent = 1:nw
        component = pang(latent) * circshift(canonicalGt, latent-1, 1);
        [~, components(:, :, latent)] = add_nondecision_time( ...
            Tdecision, component, P8(7), P8(8), h);
    end
    decomposedGt = sum(components, 3);
    [Tfull, Gt, thetaFull] = popcdm2(P8, nw, h, tmax);
    if max(abs(Tfull - T)) > 1e-12 || max(abs(thetaFull - theta)) > 1e-12
        error('Decomposition grid does not match popcdm2.');
    end
    maxAbsDifference = max(abs(decomposedGt - Gt), [], 'all');

    timeKeep = T(1:end-1) >= 0.3 & T(1:end-1) <= 3.0;
    responseRegion = region_index(theta);
    latentRegion = region_index(theta);
    sourceMass = zeros(3, 3);
    positiveComponents = max(components(:, 1:end-1, :), 0);
    totalMass = sum(positiveComponents(:, timeKeep, :), 'all') * w * h;
    for latent = 1:3
        latentBins = latentRegion == latent;
        for response = 1:3
            responseBins = responseRegion == response;
            block = positiveComponents(responseBins, timeKeep, latentBins);
            sourceMass(latent, response) = sum(block, 'all') * w * h / totalMass;
        end
    end
end

function p = pop_pmf(alpha, kappa, nw)
    gamma = 0.5772156649;
    theta = -pi:(2*pi/nw):(pi-2*pi/nw);
    vm = exp(kappa*cos(theta));
    vm = vm / (2*pi*besseli(0, kappa));
    p = gamma + alpha*vm;
    p = p / sum(p);
end

function [T, Gt] = add_nondecision_time(T, Gta, ter, st, h)
    T = T + ter + st/2;
    if st > 2*h
        m = round(st/h);
        kernel = ones(1, m) / m;
        Gt = zeros(size(Gta));
        for i = 1:size(Gta, 1)
            row = conv(Gta(i, :), kernel);
            Gt(i, :) = row(1:numel(T));
        end
    else
        Gt = Gta;
    end
end

function region = region_index(angle)
    absDeg = abs(angle) * 180/pi;
    region = ones(size(angle));
    region(absDeg > 15 & absDeg <= 45) = 2;
    region(absDeg > 45) = 3;
end

function stats = sample_rt_stats(rt)
    stats.n = numel(rt);
    stats.mass = NaN;
    if isempty(rt)
        stats.mean = NaN;
        stats.q10 = NaN;
        stats.median = NaN;
        stats.q90 = NaN;
        return
    end
    stats.mean = mean(rt);
    q = prctile(rt, [10, 50, 90]);
    stats.q10 = q(1);
    stats.median = q(2);
    stats.q90 = q(3);
end

function stats = model_rt_stats(T, Gt, responseMask, h)
    T = T(1:end-1);
    Gt = max(Gt(:, 1:end-1), 0);
    keep = T >= 0.3 & T <= 3.0;
    weights = sum(Gt(responseMask, keep), 1) * h;
    stats.mass = sum(weights);
    weights = weights / sum(weights);
    selectedT = T(keep);
    stats.n = NaN;
    stats.mean = sum(weights .* selectedT);
    stats.q10 = weighted_quantile(selectedT, weights, 0.10);
    stats.median = weighted_quantile(selectedT, weights, 0.50);
    stats.q90 = weighted_quantile(selectedT, weights, 0.90);
end

function value = weighted_quantile(x, weights, probability)
    cdf = cumsum(weights) / sum(weights);
    idx = find(cdf >= probability, 1, 'first');
    value = x(idx);
end

function row = make_rt_row(uid, cond, region, stage, stats)
    row = table(uid, cond, region, stage, stats.n, stats.mass, stats.mean, ...
        stats.q10, stats.median, stats.q90, 'VariableNames', ...
        {'uid','Cond','ErrorRegion','Stage','nObs','ModelMass','MeanRT', ...
        'Q10RT','MedianRT','Q90RT'});
end

function aggregate = aggregate_rt(rows)
    keys = unique(rows(:, {'Stage','ErrorRegion'}), 'rows', 'stable');
    aggregate = table();
    for i = 1:height(keys)
        selected = rows.Stage == keys.Stage(i) & ...
            rows.ErrorRegion == keys.ErrorRegion(i);
        r = rows(selected, :);
        aggregate = [aggregate; table(keys.Stage(i), keys.ErrorRegion(i), ...
            mean(r.MeanRT, 'omitnan'), mean(r.MedianRT, 'omitnan'), ...
            mean(r.Q10RT, 'omitnan'), mean(r.Q90RT, 'omitnan'), ...
            'VariableNames', {'Stage','ErrorRegion','MeanRT','MedianRT', ...
            'Q10RT','Q90RT'})]; %#ok<AGROW>
    end
end

function aggregate = aggregate_attribution(rows)
    keys = unique(rows(:, {'ResponseRegion','LatentPOPRegion'}), ...
        'rows', 'stable');
    aggregate = table();
    for i = 1:height(keys)
        selected = rows.ResponseRegion == keys.ResponseRegion(i) & ...
            rows.LatentPOPRegion == keys.LatentPOPRegion(i);
        r = rows(selected, :);
        pooledPosterior = sum(r.JointMass) / sum(r.ResponseMass);
        aggregate = [aggregate; table(keys.ResponseRegion(i), ...
            keys.LatentPOPRegion(i), pooledPosterior, ...
            'VariableNames', {'ResponseRegion','LatentPOPRegion', ...
            'PosteriorGivenResponse'})]; %#ok<AGROW>
    end
end

function make_rt_figure(rows, condLevels, uid, outputDir)
    regions = ["Central", "Shoulder", "Tail"];
    stages = ["Observed", "H0a POPCDM"];
    f = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1450 850]);
    tiledlayout(3, 1, 'TileSpacing', 'compact');
    for region = 1:numel(regions)
        nexttile;
        hold on;
        for stage = 1:numel(stages)
            r = rows(rows.ErrorRegion == regions(region) & ...
                rows.Stage == stages(stage), :);
            [~, order] = ismember(condLevels, r.Cond);
            plot(1:numel(condLevels), r.MeanRT(order), '-o', 'LineWidth', 1.8, ...
                'DisplayName', stages(stage));
        end
        hold off;
        xlim([1, numel(condLevels)]);
        xticks(1:numel(condLevels));
        xticklabels(condLevels);
        ylabel('Mean RT (s)');
        title(regions(region) + " response errors");
        grid on;
        if region == 1
            legend('Location', 'eastoutside');
        end
    end
    sgtitle(uid + " H0a RT conditional on response-error region");
    exportgraphics(f, fullfile(outputDir, uid + "_rt_by_error.png"), ...
        'Resolution', 160);
    close(f);
end
