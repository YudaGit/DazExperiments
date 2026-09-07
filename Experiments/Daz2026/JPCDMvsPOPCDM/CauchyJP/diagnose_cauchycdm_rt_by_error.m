function output = diagnose_cauchycdm_rt_by_error(resultFile, outputDir)
%DIAGNOSE_CAUCHYCDM_RT_BY_ERROR RT signatures by response-error region.
%
% For each participant and condition in the saved Cauchy H0 fit, compare
% observed and predicted RT within central, shoulder, and tail response
% error regions.
%
% Regions: central <= 15 deg, shoulder 15--45 deg, tail > 45 deg.

    arguments
        resultFile (1,1) string = fullfile('CauchyFits', ...
            'cauchycdm_H0_full_results.mat')
        outputDir (1,1) string = fullfile('Figures', 'RTByError')
    end

    thisDir = fileparts(mfilename('fullpath'));
    addpath(thisDir);
    ensure_cauchycdm_mex;
    if ~isfile(resultFile)
        resultFile = fullfile(thisDir, resultFile);
    end
    if ~isfolder(outputDir)
        outputDir = fullfile(thisDir, outputDir);
    end
    if ~isfile(resultFile)
        error('Saved Cauchy H0 result file not found: %s', resultFile);
    end
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    saved = load(resultFile);
    fitResults = saved.fitResults;
    model = saved.model;
    condLevels = string(model.condLevels);
    tmax = saved.tmax;
    dataFile = resolve_data_file(thisDir);
    d = prepare_data(dataFile, string({fitResults.uid}), condLevels);

    rtRows = table();
    regionNames = ["Central", "Shoulder", "Tail"];
    for p = 1:numel(fitResults)
        uid = string(fitResults(p).uid);
        dp = d(d.uid == uid, :);
        condFit = fitResults(p).condFit;
        for c = 1:numel(condLevels)
            dc = dp(dp.condIdx == c, :);
            P7 = [condFit.Vnorm(c), condFit.Eta1(c), condFit.Eta2(c), ...
                condFit.A(c), condFit.Kappa(c), condFit.Ter(c), ...
                condFit.St(c)];
            [T, Gt, theta] = cauchycdm2(P7, tmax);
            responseRegion = region_index(theta);
            observedRegion = region_index(dc.rAngle);
            h = T(2) - T(1);
            for r = 1:numel(regionNames)
                observedRT = dc.rt(observedRegion == r);
                observedStats = sample_rt_stats(observedRT);
                modelStats = model_rt_stats(T, Gt, responseRegion == r, h);
                rtRows = [rtRows; make_rt_row(uid, condLevels(c), ...
                    regionNames(r), "Observed", observedStats); ...
                    make_rt_row(uid, condLevels(c), regionNames(r), ...
                    "Cauchy H0", modelStats)]; %#ok<AGROW>
            end
        end
        make_rt_figure(rtRows(rtRows.uid == uid, :), condLevels, uid, outputDir);
        fprintf('Completed Cauchy RT/error diagnostic for %s.\n', uid);
    end

    rtFile = fullfile(outputDir, 'cauchycdm_rt_by_error_summary.csv');
    aggregateFile = fullfile(outputDir, 'cauchycdm_rt_by_error_aggregate.csv');
    writetable(rtRows, rtFile);
    rtAggregate = aggregate_rt(rtRows);
    writetable(rtAggregate, aggregateFile);
    disp(rtAggregate);

    output.rtRows = rtRows;
    output.rtAggregate = rtAggregate;
    output.summaryFile = rtFile;
    output.aggregateFile = aggregateFile;
    output.outputDir = outputDir;
    save(fullfile(outputDir, 'cauchycdm_rt_by_error_output.mat'), ...
        'rtRows', 'rtAggregate', 'resultFile');
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
    error('CauchyCDM:DataFileMissing', ...
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
    if any(~known)
        error('Unexpected condition while preparing Cauchy RT diagnostic data.');
    end
    d.rAngle = d.response_error * pi / 180;
    d.rt = d.response_RT / 1000;
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
    T = T(:).';
    Gt = max(Gt, 0);
    keep = T >= 0.3 & T <= 3.0;
    weights = sum(Gt(responseMask, keep), 1) * h;
    stats.mass = sum(weights);
    if stats.mass <= 0 || ~isfinite(stats.mass)
        stats.n = NaN;
        stats.mean = NaN;
        stats.q10 = NaN;
        stats.median = NaN;
        stats.q90 = NaN;
        return
    end
    weights = weights / stats.mass;
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

function make_rt_figure(rows, condLevels, uid, outputDir)
    regions = ["Central", "Shoulder", "Tail"];
    stages = ["Observed", "Cauchy H0"];
    f = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1450 850]);
    tiledlayout(3, 1, 'TileSpacing', 'compact');
    for region = 1:numel(regions)
        nexttile;
        hold on;
        for stage = 1:numel(stages)
            r = rows(rows.ErrorRegion == regions(region) & ...
                rows.Stage == stages(stage), :);
            [~, order] = ismember(condLevels, r.Cond);
            plot(1:numel(condLevels), r.MeanRT(order), '-o', ...
                'LineWidth', 1.8, 'DisplayName', stages(stage));
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
    sgtitle(uid + " Cauchy H0 RT conditional on response-error region");
    exportgraphics(f, fullfile(outputDir, uid + "_rt_by_error.png"), ...
        'Resolution', 160);
    close(f);
end
