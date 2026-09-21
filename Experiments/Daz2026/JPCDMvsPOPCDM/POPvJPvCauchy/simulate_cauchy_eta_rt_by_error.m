function output = simulate_cauchy_eta_rt_by_error(resultFile, uid, condName, etaGrid)
%SIMULATE_CAUCHY_ETA_RT_BY_ERROR Inspect eta's RT-by-error consequences.
%   This is a pre-fit sensitivity diagnostic. It holds one fitted
%   H1_vnorm_sn Cauchy
%   parameter vector fixed, varies only radial drift variability (eta), and
%   reproduces the wrapper's timing convolution and RT-window normalization.
%
%   simulate_cauchy_eta_rt_by_error
%   simulate_cauchy_eta_rt_by_error([], "ES", "S6C4NR", [0.02 .1 .5 1 2 4])

    thisDir = fileparts(mfilename('fullpath'));
    if nargin < 1 || isempty(resultFile)
        resultFile = fullfile(thisDir, 'TestFits', 'H1_vnorm_sn', ...
            'H1_vnorm_sn_20260914_114254.mat');
    end
    if nargin < 2 || isempty(uid)
        uid = "ES";
    end
    if nargin < 3 || isempty(condName)
        condName = "S6C4NR";
    end
    if nargin < 4 || isempty(etaGrid)
        etaGrid = [0.02, 0.05, 0.10, 0.25, 0.50, 1, 2, 4];
    end

    uid = string(uid);
    condName = string(condName);
    etaGrid = etaGrid(:)';
    if any(etaGrid <= 0)
        error('simulate_cauchy_eta_rt_by_error:InvalidEta', ...
            'Every eta value must be positive.');
    end

    addpath(thisDir, '-begin');
    build_test_mex();

    loaded = load(resultFile, 'allResults', 'condLevels');
    fieldName = matlab.lang.makeValidName(char(uid + "_cauchy"));
    if ~isfield(loaded.allResults, fieldName)
        error('simulate_cauchy_eta_rt_by_error:MissingResult', ...
            'No Cauchy result for %s in %s.', uid, resultFile);
    end
    result = loaded.allResults.(fieldName);
    condLevels = string(loaded.condLevels);
    condIdx = find(condLevels == condName, 1);
    if isempty(condIdx)
        error('simulate_cauchy_eta_rt_by_error:UnknownCondition', ...
            'Condition %s is absent from the saved result.', condName);
    end

    p = result.Pfit;
    vnorm = p(1:3);
    kappa = p(4:12);
    a = p(14);
    Ter = p(15);
    st = p(16);
    setIndexByCond = [1, 2, 2, 2, 3, 3, 3, 3, 3];
    v = vnorm(setIndexByCond(condIdx));
    kappaMu = kappa(condIdx);

    meta = struct('tmax', 3.0, 'rtMin', 0.3, 'noise', 1e-12, ...
        'nw', 50, 'sz', 300);
    nEta = numel(etaGrid);
    thetaDeg = [];
    conditionalMean = [];
    centralMean = zeros(nEta, 1);
    shoulderMean = zeros(nEta, 1);
    tailMean = zeros(nEta, 1);
    centralMedian = zeros(nEta, 1);
    tailMedian = zeros(nEta, 1);

    for i = 1:nEta
        [t, gt, theta] = local_cauchy_density(v, kappaMu, etaGrid(i), ...
            a, Ter, st, meta);
        theta = theta(1:meta.nw);
        gtm = gt(1:meta.nw, :);
        if isempty(thetaDeg)
            thetaDeg = theta * 180 / pi;
            conditionalMean = zeros(nEta, numel(theta));
        end

        conditionalMean(i, :) = local_mean_by_angle(gtm, t);
        absDeg = abs(thetaDeg);
        [centralMean(i), centralMedian(i)] = local_region_rt(gtm, t, absDeg <= 15);
        [shoulderMean(i), ~] = local_region_rt(gtm, t, absDeg > 15 & absDeg <= 45);
        [tailMean(i), tailMedian(i)] = local_region_rt(gtm, t, absDeg > 45);
    end

    summary = table(etaGrid', centralMean, shoulderMean, tailMean, ...
        tailMean - centralMean, centralMedian, tailMedian, ...
        tailMedian - centralMedian, ...
        'VariableNames', {'eta', 'centralMeanRT', 'shoulderMeanRT', 'tailMeanRT', ...
        'tailMinusCentralMean', 'centralMedianRT', 'tailMedianRT', ...
        'tailMinusCentralMedian'});

    f = figure('Color', 'w', 'Name', uid + " Cauchy eta sensitivity");
    tiledlayout(f, 1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

    nexttile;
    hold on;
    cmap = parula(nEta);
    for i = 1:nEta
        plot(thetaDeg, conditionalMean(i, :), 'LineWidth', 1.4, ...
            'Color', cmap(i, :), 'DisplayName', sprintf('eta = %.2g', etaGrid(i)));
    end
    xline(-45, ':k'); xline(45, ':k');
    xlabel('Response error (degrees)');
    ylabel('Predicted conditional mean RT (s)');
    title(condName + ": RT conditional on signed error");
    legend('Location', 'best');
    grid on;

    nexttile;
    plot(etaGrid, summary.tailMinusCentralMean, '-o', 'LineWidth', 1.5, ...
        'DisplayName', 'Mean RT');
    hold on;
    plot(etaGrid, summary.tailMinusCentralMedian, '-s', 'LineWidth', 1.5, ...
        'DisplayName', 'Median RT');
    yline(0, ':k');
    xlabel('Radial drift variability, eta');
    ylabel('Tail minus central RT (s)');
    title('|Error| > 45 degrees versus |error| <= 15 degrees');
    legend('Location', 'best');
    grid on;

    fprintf('\nCauchy eta sensitivity: %s / %s\n', uid, condName);
    fprintf('Held fixed: vnorm %.4f, kappa_mu %.4f, a %.4f, Ter %.4f, st %.4f\n', ...
        v, kappaMu, a, Ter, st);
    disp(summary);

    output = struct('uid', uid, 'condition', condName, 'resultFile', resultFile, ...
        'fixedParameters', struct('vnorm', v, 'kappaMu', kappaMu, 'a', a, ...
        'Ter', Ter, 'st', st), 'summary', summary, 'thetaDeg', thetaDeg, ...
        'conditionalMeanRT', conditionalMean, 'figure', f);
end

function [t, gt, theta] = local_cauchy_density(vnorm, kappaMu, eta, a, Ter, st, meta)
    h = meta.tmax / meta.sz;
    w = 2 * pi / meta.nw;
    % This MEX requires all five outputs, matching test_ylcauchy exactly.
    [t, gt, theta, ~, ~] = vcau300rot([vnorm, kappaMu, eta, 0, 1, a], ...
        meta.tmax, meta.noise);
    gt = max(gt, 1e-9);
    t = t + Ter + st / 2;
    if st > 2 * h
        h = t(2) - t(1);
        m = round(st / h);
        kernel = ones(1, m) / m;
        for i = 1:(meta.nw + 1)
            gti = conv(gt(i, :), kernel);
            gt(i, :) = gti(1:numel(t));
        end
    end
    keep = t >= meta.rtMin & t <= meta.tmax;
    totalMass = sum(gt(1:meta.nw, keep), 'all') * w * h;
    if totalMass <= 0
        error('simulate_cauchy_eta_rt_by_error:ZeroMass', ...
            'The simulated density has no mass in the fitted RT window.');
    end
    gt = gt / totalMass;
end

function means = local_mean_by_angle(gtm, t)
    means = sum(gtm .* t, 2)' ./ sum(gtm, 2)';
end

function [meanRt, medianRt] = local_region_rt(gtm, t, angleMask)
    region = gtm(angleMask, :);
    timeMass = sum(region, 1);
    totalMass = sum(timeMass);
    meanRt = sum(timeMass .* t) / totalMass;
    cdf = cumsum(timeMass) / totalMass;
    medianRt = interp1(cdf, t, 0.5, 'linear', 'extrap');
end
