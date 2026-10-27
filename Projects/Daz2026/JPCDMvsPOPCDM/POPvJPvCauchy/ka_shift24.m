function out = ka_shift24()
%KA_SHIFT24 Plot kappa changes after freeing one decision-stage component.
%   Uses the H0/H1 parameter-comparison CSV.  Each participant's figure
%   compares H0 cellwise kappa (x-axis) with its H1_eta, H1_vnorm, and
%   H1_ter counterparts (y-axis).  The dashed diagonal means no shift.

    thisDir = fileparts(mfilename('fullpath'));
    csvFile = fullfile(thisDir, 'TestFits', 'H0_H1_parameter_comparison.csv');
    if ~isfile(csvFile)
        error('ka_shift24:MissingCsv', 'Cannot find %s.', csvFile);
    end

    raw = readcell(csvFile, 'Delimiter', ',');
    groupHeader = string(raw(1, :));
    kappaColumns = find(groupHeader == "kappa");
    if numel(kappaColumns) ~= 4
        error('ka_shift24:UnexpectedCsvLayout', ...
            'Expected exactly four kappa columns in the comparison CSV.');
    end

    participantIDs = string(raw(3:end, 1));
    participantIDs = participantIDs(~ismissing(participantIDs) & participantIDs ~= "");
    participantIDs = unique(participantIDs, 'stable');

    figureDir = fullfile(thisDir, 'Figures', 'KappaShift_H0_H1');
    if ~exist(figureDir, 'dir')
        mkdir(figureDir);
    end

    conditionLabels = ["S2C2", "S4C2NR", "S4C2R", "S4C4", ...
        "S6C2NR", "S6C2R", "S6C4NR", "S6C4R", "S6C6"];
    colors = [0.85, 0.33, 0.10; 0.00, 0.45, 0.74; 0.47, 0.67, 0.19];
    routeLabels = ["H1 eta", "H1 vnorm", "H1 Ter"];
    outputFiles = strings(numel(participantIDs), 1);

    for p = 1:numel(participantIDs)
        uid = participantIDs(p);
        participantRow = find(string(raw(:, 1)) == uid, 1);
        % Each CSV block is participant divider, NLL, BIC, then nine cells.
        conditionRows = participantRow + (3:11);
        if conditionRows(end) > size(raw, 1)
            error('ka_shift24:MissingConditionRows', ...
                '%s does not contain all nine condition rows.', uid);
        end

        kappa = cell2mat(raw(conditionRows, kappaColumns));
        h0 = kappa(:, 1);
        allValues = kappa(:);
        axisPad = 0.10 * range(allValues);
        if axisPad == 0
            axisPad = 0.01;
        end
        axisLimits = [min(allValues) - axisPad, max(allValues) + axisPad];

        fig = figure('Color', 'w', 'Position', [100, 100, 1320, 460]);
        layout = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', ...
            'Padding', 'compact');
        title(layout, uid + ': kappa shifts after freeing decision parameters');
        for r = 2:4
            ax = nexttile(layout, r - 1);
            hold(ax, 'on');
            plot(ax, axisLimits, axisLimits, 'k--', 'LineWidth', 1.2, ...
                'DisplayName', 'No kappa shift');
            scatter(ax, h0, kappa(:, r), 68, colors(r - 1, :), 'filled', ...
                'MarkerEdgeColor', 'k', 'DisplayName', routeLabels(r - 1));
            for c = 1:numel(conditionLabels)
                text(ax, h0(c), kappa(c, r), "  " + conditionLabels(c), ...
                    'FontSize', 8, 'Color', colors(r - 1, :), ...
                    'VerticalAlignment', 'middle');
            end
            hold(ax, 'off');
            xlim(ax, axisLimits);
            ylim(ax, axisLimits);
            axis(ax, 'square');
            grid(ax, 'on');
            box(ax, 'on');
            xlabel(ax, 'H0 kappa');
            if r == 2
                ylabel(ax, 'H1 kappa');
            end
            title(ax, routeLabels(r - 1));
        end

        outputFiles(p) = fullfile(figureDir, "KappaShift_" + uid + ".png");
        exportgraphics(fig, outputFiles(p), 'Resolution', 180);
    end

    out = struct();
    out.csvFile = csvFile;
    out.figureDir = figureDir;
    out.files = outputFiles;
end
