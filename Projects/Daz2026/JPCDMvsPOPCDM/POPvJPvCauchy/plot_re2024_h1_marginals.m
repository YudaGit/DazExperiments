function output = plot_re2024_h1_marginals()
%PLOT_RE2024_H1_MARGINALS Compare H0, H1_vnorm, and H1_ter marginals.
%   Produces one 18-panel figure per participant. Each condition occupies
%   an adjacent pair: response-error PDF then RT PDF. Grey bars are data;
%   solid black is H0; dashed pink is H1_vnorm; dashed light blue is H1_ter.
%   All angle panels share limits, as do all RT panels, within a figure.

    thisDir = fileparts(mfilename('fullpath'));
    prepared = load(fullfile(thisDir, 'Re2024_POPvJPvCauchy_prepared.mat'), ...
        'Data', 'participantIDs', 'condLevels');
    participantIDs = string(prepared.participantIDs);
    condLevels = string(prepared.condLevels);
    outDir = fullfile(thisDir, 'Figures', 'Re2024_H1_marginals');
    if ~isfolder(outDir)
        mkdir(outDir);
    end

    routes = struct( ...
        'tag', {"H0", "H1_vnorm", "H1_ter"}, ...
        'folder', {"H0_kappaCell_sharedDecision", "H1_vnorm", "H1_ter"}, ...
        'pattern', {"H0_kappaCell_sharedDecision_*.mat", "H1_vnorm_*.mat", ...
                    "H1_ter_*.mat"}, ...
        'color', {[0 0 0], [0.88 0.27 0.52], [0.30 0.70 0.90]}, ...
        'lineStyle', {'-', '--', '--'});
    routeResults = cell(1, numel(routes));
    for r = 1:numel(routes)
        resultFile = local_one_result_file( ...
            fullfile(thisDir, 'TestFits', routes(r).folder), routes(r).pattern);
        routeResults{r} = load(resultFile, 'allResults');
    end

    angleEdges = linspace(-pi, pi, 51);
    rtEdges = linspace(0.3, 3.0, 51);
    figureFiles = strings(0, 1);
    for p = 1:numel(participantIDs)
        uid = participantIDs(p);
        predictions = local_predictions_for_participant(routeResults, uid);
        [angleYMax, rtYMax] = local_y_limits( ...
            prepared.Data(p, :), predictions, angleEdges, rtEdges, numel(condLevels));

        fig = figure('Color', 'w', 'Units', 'pixels', ...
            'Position', [40, 40, 1800, 1280], 'Visible', 'on');
        tiledlayout(fig, 3, 6, 'TileSpacing', 'compact', 'Padding', 'compact');
        for c = 1:numel(condLevels)
            data = prepared.Data{p, c};
            errorRadians = data(:, 2);
            rtSeconds = data(:, 3);

            nexttile;
            histogram(errorRadians, angleEdges, 'Normalization', 'pdf', ...
                'FaceColor', [0.72 0.72 0.72], 'EdgeColor', 'none');
            hold on;
            for r = 1:numel(routes)
                [theta, ptheta] = local_angle_pdf(predictions{r}, c);
                plot(theta, ptheta, 'Color', routes(r).color, ...
                    'LineStyle', routes(r).lineStyle, 'LineWidth', 1.7);
            end
            hold off;
            xlim([-pi, pi]);
            ylim([0, angleYMax]);
            xticks([-pi, 0, pi]);
            xticklabels({'-pi', '0', 'pi'});
            title(char(condLevels(c)), 'Interpreter', 'none');
            if c > 6
                xlabel('Response error (rad)');
            end
            if mod(c - 1, 3) == 0
                ylabel('PDF');
            end
            box off;

            nexttile;
            histogram(rtSeconds, rtEdges, 'Normalization', 'pdf', ...
                'FaceColor', [0.72 0.72 0.72], 'EdgeColor', 'none');
            hold on;
            for r = 1:numel(routes)
                [t, ft] = local_rt_pdf(predictions{r}, c);
                plot(t, ft, 'Color', routes(r).color, ...
                    'LineStyle', routes(r).lineStyle, 'LineWidth', 1.7);
            end
            hold off;
            xlim([0.3, 3.0]);
            ylim([0, rtYMax]);
            if c > 6
                xlabel('RT (s)');
            end
            if mod(c - 1, 3) == 0
                ylabel('PDF');
            end
            box off;
        end
        legend({'Data', 'H0', 'H1 vnorm', 'H1 Ter'}, ...
            'Orientation', 'horizontal', 'Box', 'off', ...
            'Position', [0.34, 0.005, 0.32, 0.025]);
        sgtitle(sprintf('%s: H0 and cellwise decision-component marginals', uid), ...
            'Interpreter', 'none');

        outputFile = fullfile(outDir, char(uid + "_H0_H1vnorm_H1ter_marginals.png"));
        exportgraphics(fig, outputFile, 'Resolution', 220);
        close(fig);
        figureFiles(end + 1, 1) = string(outputFile); %#ok<AGROW>
    end

    output = struct('outputDirectory', string(outDir), ...
        'figureFiles', figureFiles, 'participantIDs', participantIDs);
    fprintf('Saved %d marginal-comparison figures in:\n%s\n', ...
        numel(figureFiles), outDir);
end

function predictions = local_predictions_for_participant(routeResults, uid)
    predictions = cell(1, numel(routeResults));
    fieldName = matlab.lang.makeValidName(char(uid + "_cauchy"));
    for r = 1:numel(routeResults)
        if ~isfield(routeResults{r}.allResults, fieldName)
            error('plot_re2024_h1_marginals:MissingParticipant', ...
                '%s is missing from one saved aggregate result.', uid);
        end
        result = routeResults{r}.allResults.(fieldName);
        if ~isfield(result, 'Pred') || isempty(result.Pred)
            error('plot_re2024_h1_marginals:MissingPredictions', ...
                '%s has no saved predictions.', uid);
        end
        predictions{r} = result.Pred;
    end
end

function [angleYMax, rtYMax] = local_y_limits(dataByCond, predictions, angleEdges, rtEdges, nCond)
    angleYMax = 0;
    rtYMax = 0;
    for c = 1:nCond
        angleCounts = histcounts(dataByCond{c}(:, 2), angleEdges, 'Normalization', 'pdf');
        rtCounts = histcounts(dataByCond{c}(:, 3), rtEdges, 'Normalization', 'pdf');
        angleYMax = max(angleYMax, max(angleCounts));
        rtYMax = max(rtYMax, max(rtCounts));
        for r = 1:numel(predictions)
            [~, ptheta] = local_angle_pdf(predictions{r}, c);
            [~, ft] = local_rt_pdf(predictions{r}, c);
            angleYMax = max(angleYMax, max(ptheta));
            rtYMax = max(rtYMax, max(ft));
        end
    end
    angleYMax = 1.08 * angleYMax;
    rtYMax = 1.08 * rtYMax;
end

function [theta, ptheta] = local_angle_pdf(Pred, conditionIndex)
    anglePrediction = Pred{1}{2, conditionIndex};
    theta = anglePrediction(1, :);
    ptheta = anglePrediction(2, :);
    theta = theta(1:end - 1);
    ptheta = ptheta(1:end - 1);
end

function [t, ft] = local_rt_pdf(Pred, conditionIndex)
    rtPrediction = Pred{1}{1, conditionIndex};
    t = rtPrediction(1, :);
    ft = rtPrediction(2, :);
end

function resultFile = local_one_result_file(fitDir, pattern)
    files = dir(fullfile(fitDir, pattern));
    files = files(~startsWith({files.name}, 'checkpoint_'));
    if numel(files) ~= 1
        error('plot_re2024_h1_marginals:ResultFile', ...
            'Expected one aggregate result matching %s in %s; found %d.', ...
            pattern, fitDir, numel(files));
    end
    resultFile = fullfile(files(1).folder, files(1).name);
end
