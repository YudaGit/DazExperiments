function output = plot_re2024_besth1_h2ts_marginals()
%PLOT_RE2024_BESTH1_H2TS_MARGINALS Compare each best H1 with H2_tsensitive.
%   Exports one 18-panel figure per participant: observed PDFs in grey,
%   the participant's BIC-leading H1 in black, and H2_tsensitive in green.

    thisDir = fileparts(mfilename('fullpath'));
    prepared = load(fullfile(thisDir, 'Re2024_POPvJPvCauchy_prepared.mat'), ...
        'Data', 'participantIDs', 'condLevels');
    participantIDs = string(prepared.participantIDs);
    condLevels = string(prepared.condLevels);
    outDir = fullfile(thisDir, 'Figures', 'Re2024_BestH1_H2ts_marginals');
    if ~isfolder(outDir)
        mkdir(outDir);
    end

    bestH1 = struct( ...
        'uid', {"AQ", "ES", "HC", "PG", "YL"}, ...
        'tag', {"H1_ter", "H1_vnorm", "H1_ter", "H1_ter", "H1_vnorm"}, ...
        'folder', {"H1_ter", "H1_vnorm", "H1_ter", "H1_ter", "H1_vnorm"}, ...
        'pattern', {"H1_ter_*.mat", "H1_vnorm_*.mat", "H1_ter_*.mat", ...
                    "H1_ter_*.mat", "H1_vnorm_*.mat"});
    h2File = local_one_result_file(fullfile(thisDir, 'TestFits', 'H2_tsensitive'), ...
        'H2_tsensitive_*.mat');
    h2Loaded = load(h2File, 'allResults');
    angleEdges = linspace(-pi, pi, 51);
    rtEdges = linspace(0.3, 3.0, 51);
    figureFiles = strings(0, 1);

    for p = 1:numel(participantIDs)
        uid = participantIDs(p);
        routeIndex = find(string({bestH1.uid}) == uid, 1);
        h1File = local_one_result_file( ...
            fullfile(thisDir, 'TestFits', bestH1(routeIndex).folder), ...
            bestH1(routeIndex).pattern);
        h1Loaded = load(h1File, 'allResults');
        fieldName = matlab.lang.makeValidName(char(uid + "_cauchy"));
        h1Pred = local_prediction(h1Loaded.allResults, fieldName, uid, bestH1(routeIndex).tag);
        h2Pred = local_prediction(h2Loaded.allResults, fieldName, uid, "H2_tsensitive");
        [angleYMax, rtYMax] = local_y_limits( ...
            prepared.Data(p, :), {h1Pred, h2Pred}, angleEdges, rtEdges, numel(condLevels));

        fig = figure('Color', 'w', 'Units', 'pixels', ...
            'Position', [40, 40, 1800, 1280]);
        tiledlayout(fig, 3, 6, 'TileSpacing', 'compact', 'Padding', 'compact');
        for c = 1:numel(condLevels)
            data = prepared.Data{p, c};
            nexttile;
            histogram(data(:, 2), angleEdges, 'Normalization', 'pdf', ...
                'FaceColor', [0.72 0.72 0.72], 'EdgeColor', 'none');
            hold on;
            [theta, ptheta] = local_angle_pdf(h1Pred, c);
            plot(theta, ptheta, 'k-', 'LineWidth', 1.7);
            [theta, ptheta] = local_angle_pdf(h2Pred, c);
            plot(theta, ptheta, '--', 'Color', [0.10 0.55 0.32], 'LineWidth', 1.7);
            hold off;
            xlim([-pi, pi]); ylim([0, angleYMax]);
            xticks([-pi, 0, pi]); xticklabels({'-pi', '0', 'pi'});
            title(char(condLevels(c)), 'Interpreter', 'none');
            if c > 6, xlabel('Response error (rad)'); end
            if mod(c - 1, 3) == 0, ylabel('PDF'); end
            box off;

            nexttile;
            histogram(data(:, 3), rtEdges, 'Normalization', 'pdf', ...
                'FaceColor', [0.72 0.72 0.72], 'EdgeColor', 'none');
            hold on;
            [t, ft] = local_rt_pdf(h1Pred, c);
            plot(t, ft, 'k-', 'LineWidth', 1.7);
            [t, ft] = local_rt_pdf(h2Pred, c);
            plot(t, ft, '--', 'Color', [0.10 0.55 0.32], 'LineWidth', 1.7);
            hold off;
            xlim([0.3, 3.0]); ylim([0, rtYMax]);
            if c > 6, xlabel('RT (s)'); end
            if mod(c - 1, 3) == 0, ylabel('PDF'); end
            box off;
        end
        legend({'Data', bestH1(routeIndex).tag, 'H2 tsensitive'}, ...
            'Orientation', 'horizontal', 'Box', 'off', ...
            'Position', [0.35, 0.005, 0.30, 0.025]);
        sgtitle(sprintf('%s: best H1 versus H2 tsensitive marginals', uid), ...
            'Interpreter', 'none');
        outputFile = fullfile(outDir, char(uid + "_bestH1_vs_H2tsensitive_marginals.png"));
        exportgraphics(fig, outputFile, 'Resolution', 220);
        close(fig);
        figureFiles(end + 1, 1) = string(outputFile); %#ok<AGROW>
    end
    output = struct('outputDirectory', string(outDir), 'figureFiles', figureFiles);
    fprintf('Saved %d best-H1/H2 marginal figures in:\n%s\n', numel(figureFiles), outDir);
end

function Pred = local_prediction(allResults, fieldName, uid, tag)
    if ~isfield(allResults, fieldName) || isempty(allResults.(fieldName).Pred)
        error('plot_re2024_besth1_h2ts_marginals:MissingPredictions', ...
            '%s predictions are missing for %s.', tag, uid);
    end
    Pred = allResults.(fieldName).Pred;
end

function [angleYMax, rtYMax] = local_y_limits(dataByCond, predictions, angleEdges, rtEdges, nCond)
    angleYMax = 0; rtYMax = 0;
    for c = 1:nCond
        angleYMax = max(angleYMax, max(histcounts(dataByCond{c}(:, 2), angleEdges, 'Normalization', 'pdf')));
        rtYMax = max(rtYMax, max(histcounts(dataByCond{c}(:, 3), rtEdges, 'Normalization', 'pdf')));
        for r = 1:numel(predictions)
            [~, ptheta] = local_angle_pdf(predictions{r}, c);
            [~, ft] = local_rt_pdf(predictions{r}, c);
            angleYMax = max(angleYMax, max(ptheta));
            rtYMax = max(rtYMax, max(ft));
        end
    end
    angleYMax = 1.08 * angleYMax; rtYMax = 1.08 * rtYMax;
end

function [theta, ptheta] = local_angle_pdf(Pred, conditionIndex)
    values = Pred{1}{2, conditionIndex};
    theta = values(1, 1:end - 1); ptheta = values(2, 1:end - 1);
end

function [t, ft] = local_rt_pdf(Pred, conditionIndex)
    values = Pred{1}{1, conditionIndex};
    t = values(1, :); ft = values(2, :);
end

function resultFile = local_one_result_file(fitDir, pattern)
    files = dir(fullfile(fitDir, pattern));
    files = files(~startsWith({files.name}, 'checkpoint_'));
    if numel(files) ~= 1
        error('plot_re2024_besth1_h2ts_marginals:ResultFile', ...
            'Expected one aggregate result matching %s in %s; found %d.', ...
            pattern, fitDir, numel(files));
    end
    resultFile = fullfile(files(1).folder, files(1).name);
end
