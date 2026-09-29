function output = assess_h1_rt_parameter_contrasts()
%ASSESS_H1_RT_PARAMETER_CONTRASTS Audit eta, vnorm, and Ter H1 flexibility.
%   Reports H1-minus-H0 displacements, matched R-minus-NR contrasts, and
%   largest within-route displacement. Parameter scales remain separate.

    thisDir = fileparts(mfilename('fullpath'));
    raw = readcell(fullfile(thisDir, 'TestFits', 'H0_H1_parameter_comparison.csv'));
    parameterHeader = string(raw(1, :));
    routeHeader = string(raw(2, :));
    participants = ["AQ", "ES", "HC", "PG", "YL"];
    conditions = ["S2C2", "S4C2NR", "S4C2R", "S4C4", ...
        "S6C2NR", "S6C2R", "S6C4NR", "S6C4R", "S6C6"];
    pairNames = ["S4C2", "S6C2", "S6C4"];
    pairNR = ["S4C2NR", "S6C2NR", "S6C4NR"];
    pairR = ["S4C2R", "S6C2R", "S6C4R"];
    parameterNames = ["eta", "vnorm", "Ter"];
    h1Routes = ["c_eta", "c_vnorm", "c_ter"];

    baseColumns = zeros(1, numel(parameterNames));
    h1Columns = zeros(1, numel(parameterNames));
    for q = 1:numel(parameterNames)
        baseColumns(q) = local_column(parameterHeader, routeHeader, parameterNames(q), "Base");
        h1Columns(q) = local_column(parameterHeader, routeHeader, parameterNames(q), h1Routes(q));
    end

    nParticipant = numel(participants);
    nCondition = numel(conditions);
    nParameter = numel(parameterNames);
    base = nan(nParticipant, nCondition, nParameter);
    h1 = nan(nParticipant, nCondition, nParameter);
    for p = 1:nParticipant
        participantRow = find(string(raw(:, 1)) == participants(p), 1, 'first');
        participantEnd = local_participant_end(raw, participantRow);
        for c = 1:nCondition
            dataRow = local_condition_row(raw, participantRow, participantEnd, conditions(c));
            base(p, c, :) = cell2mat(raw(dataRow, baseColumns));
            h1(p, c, :) = cell2mat(raw(dataRow, h1Columns));
        end
    end

    displacement = local_displacements(base, h1, participants, conditions, parameterNames);
    matched = local_matched(base, h1, participants, conditions, parameterNames, pairNames, pairNR, pairR);
    largest = local_largest(base, h1, participants, conditions, parameterNames);

    outDir = fullfile(thisDir, 'Figures', 'H2_RT_factor_diagnostics');
    if ~isfolder(outDir), mkdir(outDir); end
    displacementFile = fullfile(thisDir, 'TestFits', 'H2_RT_parameter_displacements.csv');
    matchedFile = fullfile(thisDir, 'TestFits', 'H2_RT_matched_R_NR_contrasts.csv');
    largestFile = fullfile(thisDir, 'TestFits', 'H2_RT_largest_parameter_displacements.csv');
    writetable(displacement, displacementFile);
    writetable(matched, matchedFile);
    writetable(largest, largestFile);

    displacementFigure = fullfile(outDir, 'H1_parameter_displacements_from_H0.png');
    local_plot_displacements(base, h1, participants, conditions, parameterNames, displacementFigure);
    contrastFigure = fullfile(outDir, 'H1_matched_R_NR_contrasts.png');
    local_plot_matched(matched, participants, pairNames, parameterNames, contrastFigure);

    output = struct('displacements', displacement, 'matchedContrasts', matched, ...
        'largestDisplacements', largest, 'displacementFile', string(displacementFile), ...
        'matchedFile', string(matchedFile), 'largestFile', string(largestFile), ...
        'displacementFigure', string(displacementFigure), 'contrastFigure', string(contrastFigure));
    disp(largest);
end

function out = local_displacements(base, h1, participants, conditions, parameters)
    n = numel(participants) * numel(conditions) * numel(parameters);
    participant = strings(n, 1); condition = strings(n, 1); parameter = strings(n, 1);
    h0Value = nan(n, 1); h1Value = nan(n, 1); h1MinusH0 = nan(n, 1); row = 0;
    for p = 1:numel(participants)
        for q = 1:numel(parameters)
            for c = 1:numel(conditions)
                row = row + 1;
                participant(row) = participants(p); condition(row) = conditions(c); parameter(row) = parameters(q);
                h0Value(row) = base(p, c, q); h1Value(row) = h1(p, c, q);
                h1MinusH0(row) = h1Value(row) - h0Value(row);
            end
        end
    end
    out = table(participant, condition, parameter, h0Value, h1Value, h1MinusH0);
end

function out = local_matched(~, h1, participants, conditions, parameters, pairNames, pairNR, pairR)
    n = numel(participants) * numel(pairNames);
    participant = strings(n, 1); pair = strings(n, 1); values = nan(n, 3 * numel(parameters)); row = 0;
    names = strings(1, 3 * numel(parameters));
    for q = 1:numel(parameters)
        names(3*q-2:3*q) = [parameters(q) + "_NR", parameters(q) + "_R", parameters(q) + "_R_minus_NR"];
    end
    for p = 1:numel(participants)
        for j = 1:numel(pairNames)
            row = row + 1; participant(row) = participants(p); pair(row) = pairNames(j);
            nr = find(conditions == pairNR(j), 1); r = find(conditions == pairR(j), 1);
            for q = 1:numel(parameters)
                nrValue = h1(p, nr, q); rValue = h1(p, r, q);
                values(row, 3*q-2:3*q) = [nrValue, rValue, rValue - nrValue];
            end
        end
    end
    out = [table(participant, pair), array2table(values, 'VariableNames', cellstr(names))];
end

function out = local_largest(base, h1, participants, conditions, parameters)
    n = numel(participants) * numel(parameters);
    participant = strings(n, 1); parameter = strings(n, 1); h0Value = nan(n, 1);
    minValue = nan(n, 1); minCondition = strings(n, 1); maxValue = nan(n, 1); maxCondition = strings(n, 1);
    conditionRange = nan(n, 1); largestSignedDisplacement = nan(n, 1); largestDisplacementCondition = strings(n, 1); row = 0;
    for p = 1:numel(participants)
        for q = 1:numel(parameters)
            row = row + 1; values = squeeze(h1(p, :, q)); h0 = base(p, 1, q); delta = values - h0;
            [minValue(row), minIndex] = min(values); [maxValue(row), maxIndex] = max(values); [~, maxDeltaIndex] = max(abs(delta));
            participant(row) = participants(p); parameter(row) = parameters(q); h0Value(row) = h0;
            minCondition(row) = conditions(minIndex); maxCondition(row) = conditions(maxIndex);
            conditionRange(row) = maxValue(row) - minValue(row);
            largestSignedDisplacement(row) = delta(maxDeltaIndex); largestDisplacementCondition(row) = conditions(maxDeltaIndex);
        end
    end
    out = table(participant, parameter, h0Value, minValue, minCondition, maxValue, maxCondition, ...
        conditionRange, largestSignedDisplacement, largestDisplacementCondition);
end

function local_plot_displacements(base, h1, participants, conditions, parameters, outputFile)
    limits = zeros(1, numel(parameters));
    for q = 1:numel(parameters), limits(q) = max(abs(h1(:, :, q) - base(:, :, q)), [], 'all'); end
    fig = figure('Color', 'w', 'Units', 'pixels', 'Position', [50, 30, 1600, 1450]);
    tiledlayout(fig, numel(participants), numel(parameters), 'TileSpacing', 'compact', 'Padding', 'compact');
    for p = 1:numel(participants)
        for q = 1:numel(parameters)
            nexttile; delta = squeeze(h1(p, :, q) - base(p, :, q));
            yline(0, 'Color', [0.35 0.35 0.35]); hold on;
            plot(1:numel(conditions), delta, '-o', 'Color', [0.15 0.15 0.15], 'MarkerFaceColor', [0.88 0.27 0.52], 'LineWidth', 1.2); hold off;
            xlim([0.5, numel(conditions) + 0.5]); ylim(1.08 * [-limits(q), limits(q)]);
            xticks(1:numel(conditions)); xticklabels(conditions); xtickangle(45); box off;
            if p == 1, title("H1 " + parameters(q) + " minus H0", 'Interpreter', 'none'); end
            if q == 1, ylabel(participants(p)); end
        end
    end
    sgtitle('Condition-specific displacement from shared H0 parameter', 'Interpreter', 'none');
    exportgraphics(fig, outputFile, 'Resolution', 220); close(fig);
end

function local_plot_matched(matched, participants, pairs, parameters, outputFile)
    fig = figure('Color', 'w', 'Units', 'pixels', 'Position', [70, 80, 1500, 500]);
    tiledlayout(fig, 1, numel(parameters), 'TileSpacing', 'compact', 'Padding', 'compact');
    for q = 1:numel(parameters)
        values = nan(numel(participants), numel(pairs)); column = parameters(q) + "_R_minus_NR";
        for p = 1:numel(participants)
            for j = 1:numel(pairs)
                values(p, j) = matched.(column)(matched.participant == participants(p) & matched.pair == pairs(j));
            end
        end
        limit = max(abs(values), [], 'all'); if limit == 0, limit = 1; end
        imagesc(values, [-limit, limit]); axis tight; set(gca, 'YDir', 'normal', ...
            'XTick', 1:numel(pairs), 'XTickLabel', pairs, 'YTick', 1:numel(participants), 'YTickLabel', participants);
        xlabel('Matched set size / colour count'); ylabel('Participant'); title("H1 " + parameters(q) + ": R minus NR", 'Interpreter', 'none');
        colormap(gca, local_diverging_colormap()); cb = colorbar; cb.Label.String = char(parameters(q) + " difference");
        for p = 1:size(values, 1)
            for j = 1:size(values, 2), text(j, p, sprintf('%+.2f', values(p, j)), 'HorizontalAlignment', 'center', 'FontWeight', 'bold'); end
        end
    end
    sgtitle('Matched R-minus-NR contrasts within each saturated H1 route', 'Interpreter', 'none');
    exportgraphics(fig, outputFile, 'Resolution', 220); close(fig);
end

function column = local_column(parameterHeader, routeHeader, parameter, route)
    column = find(parameterHeader == parameter & routeHeader == route, 1, 'first');
    if isempty(column), error('assess_h1_rt_parameter_contrasts:MissingColumn', 'Missing %s / %s.', parameter, route); end
end

function participantEnd = local_participant_end(raw, participantRow)
    laterRows = participantRow + 1:size(raw, 1); names = string(raw(laterRows, 1));
    next = find(~ismissing(names) & strlength(names) > 0, 1, 'first');
    if isempty(next), participantEnd = size(raw, 1); else, participantEnd = laterRows(next) - 1; end
end

function row = local_condition_row(raw, firstRow, lastRow, condition)
    row = find(string(raw(firstRow:lastRow, 2)) == condition, 1, 'first');
    if isempty(row), error('assess_h1_rt_parameter_contrasts:MissingCondition', 'Missing %s.', condition); end
    row = firstRow + row - 1;
end

function colors = local_diverging_colormap()
    blue = [0.28 0.55 0.85]; white = [1 1 1]; red = [0.88 0.35 0.42]; n = 128;
    colors = [linspace(blue(1), white(1), n/2)', linspace(blue(2), white(2), n/2)', linspace(blue(3), white(3), n/2)'; ...
              linspace(white(1), red(1), n/2)', linspace(white(2), red(2), n/2)', linspace(white(3), red(3), n/2)'];
end
