function output = plot_re2024_rt_regions_by_participant()
%PLOT_RE2024_RT_REGIONS_BY_PARTICIPANT Plot median RT by error region.
%   Produces one figure per participant. Conditions use one pooled ordering
%   (lowest to highest tail-response proportion); each x label also reports
%   that participant's own tail-response percentage for the condition.

    thisDir = fileparts(mfilename('fullpath'));
    dataFile = fullfile(thisDir, 'Re2024_POPvJPvCauchy_prepared.mat');
    outDir = fullfile(thisDir, 'Figures', 'Re2024_RT_regions');
    if ~isfolder(outDir)
        mkdir(outDir);
    end

    loaded = load(dataFile, 'Data', 'participantIDs', 'condLevels');
    Data = loaded.Data;
    uids = string(loaded.participantIDs);
    condLevels = string(loaded.condLevels);

    absErrorDeg = cellfun(@(d) abs(d(:, 2)) * 180 / pi, Data, ...
        'UniformOutput', false);
    tailProp = cellfun(@(e) mean(e > 45), absErrorDeg);
    pooledTailProp = mean(tailProp, 1, 'omitnan');
    [~, order] = sort(pooledTailProp, 'ascend');

    regionNames = ["Central: |error| <= 15 deg", ...
        "Shoulder: 15 < |error| <= 45 deg", "Tail: |error| > 45 deg"];
    regionColors = [0.10 0.35 0.70; 0.85 0.40 0.05; 0.25 0.60 0.30];
    regionMasks = {@(e) e <= 15, @(e) e > 15 & e <= 45, @(e) e > 45};
    nUid = numel(uids);
    nCond = numel(condLevels);
    medianRTms = nan(nUid, nCond, numel(regionNames));

    for u = 1:nUid
        for c = 1:nCond
            d = Data{u, c};
            e = abs(d(:, 2)) * 180 / pi;
            rtMs = d(:, 3) * 1000;
            for r = 1:numel(regionNames)
                values = rtMs(regionMasks{r}(e));
                if ~isempty(values)
                    medianRTms(u, c, r) = median(values);
                end
            end
        end
    end

    figures = gobjects(nUid, 1);
    for u = 1:nUid
        f = figure('Color', 'w', 'Name', char(uids(u) + " RT by error region"), ...
            'Position', [100, 100, 1180, 620]);
        figures(u) = f;
        ax = axes(f);
        hold(ax, 'on');
        x = 1:nCond;
        for r = 1:numel(regionNames)
            plot(ax, x, squeeze(medianRTms(u, order, r)), '-o', ...
                'Color', regionColors(r, :), 'LineWidth', 1.8, ...
                'MarkerFaceColor', regionColors(r, :), 'MarkerSize', 6, ...
                'DisplayName', regionNames(r));
        end
        % MATLAB splits newline tick labels on some graphics backends. Use
        % separate text objects so every tick always gets its own two lines.
        set(ax, 'XTick', x, 'XTickLabel', []);
        xlim(ax, [0.7, nCond + 0.3]);
        ylabel(ax, 'Median RT (ms)');
        title(ax, sprintf('%s: Median RT by response-error region', uids(u)));
        grid(ax, 'on');
        legend(ax, 'Location', 'northwest');
        ylim(ax, 'padded');
        yLimits = ylim(ax);
        labelY = yLimits(1) - 0.09 * range(yLimits);
        for j = 1:nCond
            text(ax, j, labelY, {char(condLevels(order(j))), ...
                sprintf('tail %.1f%%', 100 * tailProp(u, order(j)))}, ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
                'Interpreter', 'none', 'Clipping', 'off', 'FontSize', 9);
        end
        ax.Position(2) = 0.22;
        ax.Position(4) = 0.68;

        exportgraphics(f, fullfile(outDir, char(uids(u) + "_rt_by_error_region.png")), ...
            'Resolution', 220);
    end

    orderTable = table(condLevels(order)', 100 * pooledTailProp(order)', ...
        'VariableNames', {'condition', 'pooledTailPercent'});
    fprintf('\nCondition ordering used by every figure (pooled tail proportion):\n');
    disp(orderTable);
    fprintf('Saved five PNG files in:\n%s\n', outDir);

    output = struct('figures', figures, 'medianRTms', medianRTms, ...
        'tailProportion', tailProp, 'pooledTailProportion', pooledTailProp, ...
        'conditionOrder', order, 'conditionOrderTable', orderTable, ...
        'outputDirectory', outDir);
end
