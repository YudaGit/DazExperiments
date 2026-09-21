function out = ka_scale24(scaleName)
%KA_SCALE24 Visualize individual kappa or rho colour-count scaling curves.
%   KA_SCALE24() plots raw kappa with positive beta curves. KA_SCALE24("rho")
%   plots rho = exp(-kappa) with negative beta curves. Both views retain
%   observed R and NR values without a redundancy correction.

    if nargin < 1 || isempty(scaleName)
        scaleName = "kappa";
    end
    scaleName = lower(string(scaleName));
    if ~isscalar(scaleName) || ~ismember(scaleName, ["kappa", "rho"])
        error('ka_scale24:UnknownScale', 'scaleName must be "kappa" or "rho".');
    end

    thisDir = fileparts(mfilename('fullpath'));
    csvFile = fullfile(thisDir, 'TestFits', 'H0_H1_parameter_comparison.csv');
    if ~isfile(csvFile)
        error('ka_scale24:MissingCsv', 'Cannot find %s.', csvFile);
    end

    raw = readcell(csvFile, 'Delimiter', ',');
    groupHeader = string(raw(1, :));
    kappaColumns = find(groupHeader == "kappa");
    if numel(kappaColumns) ~= 4
        error('ka_scale24:UnexpectedCsvLayout', ...
            'Expected exactly four kappa columns in the comparison CSV.');
    end

    routes = ["H0", "H1 eta", "H1 vnorm", "H1 Ter"];
    routeColors = [0.10, 0.10, 0.10; 0.85, 0.33, 0.10; ...
        0.00, 0.45, 0.74; 0.47, 0.67, 0.19];
    conditions = ["S2C2", "S4C2NR", "S4C2R", "S4C4", ...
        "S6C2NR", "S6C2R", "S6C4NR", "S6C4R", "S6C6"];
    colorCount = [2, 2, 2, 4, 2, 2, 4, 4, 6];
    xOffset = [0, -0.30, -0.15, 0, 0.15, 0.30, -0.12, 0.12, 0];
    if scaleName == "kappa"
        betaValues = [0.3, 0.4, 0.5, 0.6, 0.7];
        yLabel = "Cauchy kappa (dispersion)";
        filePrefix = "KappaScale_";
    else
        betaValues = [-0.3, -0.4, -0.5, -0.6, -0.7];
        yLabel = "rho = exp(-kappa)";
        filePrefix = "RhoScale_";
    end
    curveColors = repmat(linspace(0.72, 0.28, numel(betaValues))', 1, 3);

    participantIDs = string(raw(3:end, 1));
    participantIDs = participantIDs(~ismissing(participantIDs) & participantIDs ~= "");
    participantIDs = unique(participantIDs, 'stable');

    figureDir = fullfile(thisDir, 'Figures', 'KappaRhoScale_H0_H1');
    if ~exist(figureDir, 'dir')
        mkdir(figureDir);
    end
    outputFiles = strings(numel(participantIDs), 1);
    xCurve = linspace(1, 6, 200);

    for p = 1:numel(participantIDs)
        uid = participantIDs(p);
        participantRow = find(string(raw(:, 1)) == uid, 1);
        conditionRows = participantRow + (3:11);
        if conditionRows(end) > size(raw, 1)
            error('ka_scale24:MissingConditionRows', ...
                '%s does not contain all nine condition rows.', uid);
        end
        kappa = cell2mat(raw(conditionRows, kappaColumns));
        if scaleName == "kappa"
            observed = kappa;
        else
            observed = exp(-kappa);
        end
        curveValues = zeros(numel(xCurve), numel(betaValues), 4);
        for r = 1:4
            curveValues(:, :, r) = observed(1, r) * ...
                (xCurve(:) / 2) .^ betaValues;
        end
        allValues = [observed(:); curveValues(:)];
        yPad = 0.08 * range(allValues);
        if yPad == 0
            yPad = 0.01;
        end
        yLimits = [max(0, min(allValues) - yPad), max(allValues) + yPad];

        fig = figure('Color', 'w', 'Position', [80, 80, 1120, 800]);
        layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', ...
            'Padding', 'compact');
        title(layout, uid + ': observed ' + scaleName + ...
            ' and colour-count scaling curves');

        for r = 1:4
            ax = nexttile(layout, r);
            hold(ax, 'on');
            for b = 1:numel(betaValues)
                curve = observed(1, r) * (xCurve / 2) .^ betaValues(b);
                plot(ax, xCurve, curve, '--', 'Color', curveColors(b, :), ...
                    'LineWidth', 0.9, 'HandleVisibility', 'off');
            end
            scatter(ax, colorCount + xOffset, observed(:, r), 56, ...
                routeColors(r, :), 'filled', 'MarkerEdgeColor', 'k');
            for c = 1:numel(conditions)
                text(ax, colorCount(c) + xOffset(c), observed(c, r), ...
                    " " + conditions(c), 'FontSize', 7, ...
                    'Color', routeColors(r, :), 'VerticalAlignment', 'bottom');
            end
            hold(ax, 'off');
            xlim(ax, [0.8, 6.3]);
            ylim(ax, yLimits);
            xticks(ax, [1, 2, 4, 6]);
            xlabel(ax, 'Unique colour count');
            ylabel(ax, yLabel);
            title(ax, routes(r));
            grid(ax, 'on');
            box(ax, 'on');

            if r == 1
                curveHandles = gobjects(numel(betaValues), 1);
                hold(ax, 'on');
                for b = 1:numel(betaValues)
                    curveHandles(b) = plot(ax, nan, nan, '--', ...
                        'Color', curveColors(b, :), 'LineWidth', 0.9);
                end
                legend(ax, curveHandles, "beta = " + string(betaValues), ...
                    'Location', 'northwest');
                hold(ax, 'off');
            end
        end

        outputFiles(p) = fullfile(figureDir, filePrefix + uid + ".png");
        exportgraphics(fig, outputFiles(p), 'Resolution', 180);
    end

    out = struct('csvFile', csvFile, 'figureDir', figureDir, 'files', outputFiles);
end
