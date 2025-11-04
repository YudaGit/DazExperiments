%% S1 data analyses – per-participant descriptive panels (medians + boot CIs)
clear; clc; rng(1);     % reproducible bootstrap

%% --------------------- LOAD & COMBINE ALL SESSIONS ---------------------
filePattern = 'EncodingData_*.mat';
files = dir(filePattern);
if isempty(files)
    error('No files found matching pattern: %s', filePattern);
end

% Load newest last (helps if duplicates exist)
[~, ix] = sort([files.datenum]);
files = files(ix);

allT = cell(numel(files),1);

for i = 1:numel(files)
    fname = files(i).name;

    % Parse ID and session from filename, e.g.: EncodingData_AL_sess1_...
    tok = regexp(fname, '^EncodingData_([A-Za-z]+)_sess(\d+)_', 'tokens', 'once');
    if isempty(tok)
        warning('Skipping file with unexpected name: %s', fname);
        continue
    end
    pid   = upper(tok{1});         % standardize case (hc->HC, etc.)
    sessN = str2double(tok{2});

    S = load(fname);
    fns = fieldnames(S);

    % Choose a table-like payload
    V = [];
    if numel(fns) == 1
        V = S.(fns{1});
    else
        % Prefer a table if present
        for k = 1:numel(fns)
            if istable(S.(fns{k}))
                V = S.(fns{k});
                break
            end
        end
        % Otherwise accept a struct array and convert
        if isempty(V)
            for k = 1:numel(fns)
                if isstruct(S.(fns{k})) && isvector(S.(fns{k}))
                    try
                        V = struct2table(S.(fns{k}));
                        break
                    catch
                        % keep searching
                    end
                end
            end
        end
    end

    if isempty(V)
        warning('File %s: no usable table/struct to combine. Skipping.', fname);
        continue
    end
    if isstruct(V), V = struct2table(V); end
    if ~istable(V), error('File %s: payload is not table/struct.', fname); end

    % Add/override ID & Session from filename (fixes "hc"→"HC")
    V.ID = repmat(string(pid), height(V), 1);
    V.Session = repmat(sessN, height(V), 1);

    allT{i} = V;
end

allT = allT(~cellfun('isempty', allT));
if isempty(allT)
    error('No usable data tables found.');
end
dataAll = vertcat(allT{:});

% Enforce useful types
dataAll.ID      = categorical(dataAll.ID);
dataAll.Session = double(dataAll.Session);

% Robust intake summary (works across MATLAB versions)
ct = varfun(@numel, dataAll, ...
    'InputVariables', 'Session', ...
    'GroupingVariables', {'ID','Session'});
if any(strcmp(ct.Properties.VariableNames,'numel_Session'))
    ct.Properties.VariableNames{'numel_Session'} = 'N';
end
disp(ct);

%% ---------------------------- CLEAN & PREP -----------------------------
% Keep a raw copy
dataAll_raw = dataAll;

% Basic hygiene: drop NaN RT, then >2500ms
n0 = height(dataAll);
nNaN_RT = sum(isnan(dataAll.ResponseTime));
dataAll = dataAll(~isnan(dataAll.ResponseTime), :);

nHigh = sum(dataAll.ResponseTime > 2500);
dataAll = dataAll(dataAll.ResponseTime <= 2500, :);

fprintf('Trials: %d total | %d dropped (NaN RT) | %d dropped (>2500 ms) | %d remain\n', ...
    n0, nNaN_RT, nHigh, height(dataAll));

% Normalize categories
% Grouping → "Grouped"/"Separated" (tolerate "Separate")
gstr = upper(string(dataAll.Grouping));
gstr(gstr=="SEPARATE")  = "SEPARATED";
gstr(gstr=="SEPARATED") = "SEPARATED";
gstr(gstr=="GROUPED")   = "GROUPED";
gstr2 = strings(size(gstr));
gstr2(gstr=="GROUPED")   = "Grouped";
gstr2(gstr=="SEPARATED") = "Separated";
grouping = categorical(gstr2);

% CueType → "R"/"NR"
cstr = upper(string(dataAll.CueType));
cstr = regexprep(cstr, '^\s*REDUNDANT\s*$', 'R', 'ignorecase');
cstr = regexprep(cstr, '^\s*NON[-\s]?REDUNDANT\s*$', 'NR', 'ignorecase');
cueType = categorical(cstr);

% Scalars
presDur   = dataAll.PresDur;
RT        = dataAll.ResponseTime;
precision = dataAll.Precision;  % angles in degrees (0..360) unless noted

% Force desired category orders where present
ordG = {'Grouped','Separated'};
ordG = ordG(ismember(ordG, categories(grouping)));
if ~isempty(ordG), grouping = reordercats(grouping, ordG); end

ordC = {'R','NR'};
ordC = ordC(ismember(ordC, categories(cueType)));
if ~isempty(ordC), cueType = reordercats(cueType, ordC); end

% Levels
presDurs = unique(presDur); presDurs = sort(presDurs);
IDs      = categories(categorical(dataAll.ID));  % cell array of char
IDs      = sort(IDs);                             % alphabetical

% Flags
isCircularAngle = true;   % <-- set false if 'Precision' is error magnitude

% Colors & markers
markerShapes = {'o','s'};                 % R:o, NR:s
groupColors  = [ 0.8500 0.3250 0.0980 ;   % Grouped (reddish)
                 0       0.4470 0.7410 ]; % Separated (bluish)
cueColors    = [ 0.8500 0.3250 0.0980 ;   % R (reddish)
                 0       0.4470 0.7410 ]; % NR (bluish)
GroupNames   = {'Grouped','Separated'};
CueNames     = {'R','NR'};
cueIndex     = @(lab) find(strcmp(lab, CueNames), 1);   % 'R'->1, 'NR'->2

% X positions
nDur = numel(presDurs);
xCenters = 1:nDur;
offsets4 = [ -0.18, -0.06, +0.06, +0.18 ];   % 4 sub-points (Grp×Cue)
offsets2 = [ -0.12, +0.12 ];                 % 2 sub-points (Cue only)

% Y-limits (consistent across panels)
if isempty(RT)
    ylRT = [0 1000];
else
    yRTmin = floor(min(RT)/50)*50;
    yRTmax = ceil(max(RT)/50)*50;
    ylRT   = [yRTmin, yRTmax];
end
ylCSD  = [0, 180];                            % circular SD range in degrees

% Bootstrap settings
nBoot = 2000; alpha = 0.05;

%% ---------------------- FIGURE 1: RT by Grp×Cue (med+CI) ----------------
fig1 = figure('Color','w','Name','RT (median + BCa CI) by Dur × Group × Cue (per ID)');
tl = tiledlayout(fig1, 2, 3, 'Padding','compact', 'TileSpacing','compact');

for k = 1:min(5, numel(IDs))
    nexttile(tl, k); ax = gca; hold(ax,'on');

    thisID = IDs{k};
    rows = categorical(dataAll.ID) == thisID;
    if ~any(rows)
        title(ax, sprintf('%s (no data)', thisID));
        axis(ax,'off'); continue
    end

    g = grouping(rows);
    c = cueType(rows);
    d = presDur(rows);
    r = RT(rows);

    gOrd = categories(g);
    cOrd = categories(c);
    nG = numel(gOrd); nC = numel(cOrd);

    % Raw scatter
    jitterWidth = 0.04;
    for iDur = 1:nDur
        for iG = 1:nG
            for iC = 1:nC
                baseX = xCenters(iDur) + offsets4((iG-1)*nC + iC);
                idx = (d==presDurs(iDur)) & (g==gOrd{iG}) & (c==cOrd{iC});
                if ~any(idx), continue; end
                rr = r(idx);
                xJ = (rand(sum(idx),1)*2 - 1) * jitterWidth;
                scatter(ax, baseX + xJ, rr, 10, ...
                    'MarkerFaceColor', groupColors(iG,:), ...
                    'MarkerEdgeColor', 'none', ...
                    'MarkerFaceAlpha', 0.15, 'MarkerEdgeAlpha', 0.05);
            end
        end
    end

    % Median + bootstrapped CI (asymmetric)
    for iDur = 1:nDur
        for iG = 1:nG
            for iC = 1:nC
                baseX = xCenters(iDur) + offsets4((iG-1)*nC + iC);
                idx = (d==presDurs(iDur)) & (g==gOrd{iG}) & (c==cOrd{iC});
                if ~any(idx), continue; end
                rr = r(idx);
                if numel(rr)<2
                    med = median(rr,'omitnan'); lo=NaN; hi=NaN;
                else
                    [med, ciL, ciU] = medCI(rr, nBoot, alpha);
                    lo = med - ciL; hi = ciU - med;
                end
                if ~isnan(lo) && ~isnan(hi)
                    errorbar(ax, baseX, med, lo, hi, 'LineStyle','none', ...
                        'Color', groupColors(iG,:), 'LineWidth', 1.2);
                end
                msIdx = cueIndex(cOrd{iC}); if isempty(msIdx), msIdx = 1; end
                plot(ax, baseX, med, markerShapes{msIdx}, ...
                    'MarkerSize', 7, 'MarkerFaceColor', groupColors(iG,:), ...
                    'MarkerEdgeColor','k', 'LineWidth', 1.0);
            end
        end
    end

    set(ax,'XTick',xCenters, ...
           'XTickLabel', arrayfun(@(x) sprintf('%.2f', x), presDurs, 'UniformOutput',false), ...
           'FontSize',11, 'LineWidth',1.2);
    ylim(ax, ylRT);
    xlim(ax, [0.5, nDur+0.5]); box(ax,'on'); grid(ax,'on');
    ax.GridAlpha = 0.15; ax.Layer='top';
    title(ax, char(thisID), 'FontWeight','bold');

    if k>3, xlabel(ax,'Presentation Duration (s)'); end
    if any(k==[1,4]), ylabel(ax,'RT (ms)'); end
end

% Legend in tile 6
nexttile(tl, 6); axis off;
hL = gobjects(4,1); Lbl = cell(4,1); kk = 0;
for iG = 1:2
    for iC = 1:2
        kk = kk+1;
        hL(kk) = plot(NaN, NaN, markerShapes{iC}, ...
            'MarkerSize',7, 'MarkerFaceColor', groupColors(iG,:), ...
            'MarkerEdgeColor','k', 'LineWidth',1.0); hold on;
        Lbl{kk} = sprintf('%s, %s', GroupNames{iG}, CueNames{iC});
    end
end
legend(hL, Lbl, 'Location','northwest'); title('Legend');

title(tl, 'RT (median + BCa CI) by Duration × Group × Cue (per ID)', ...
    'FontSize',14,'FontWeight','bold');

%% -------- FIGURE 2: Circular SD by Grp×Cue (per ID panels) ------------
fig2 = figure('Color','w','Name','Circular SD by Dur × Group × Cue (per ID)');
tl2 = tiledlayout(fig2, 2, 3, 'Padding','compact', 'TileSpacing','compact');

for k = 1:min(5, numel(IDs))
    nexttile(tl2, k); ax = gca; hold(ax,'on');

    thisID = IDs{k};
    rows = categorical(dataAll.ID) == thisID;
    if ~any(rows)
        title(ax, sprintf('%s (no data)', thisID)); axis(ax,'off'); continue
    end

    g = grouping(rows);
    c = cueType(rows);
    d = presDur(rows);
    p = precision(rows);

    gOrd = categories(g);
    cOrd = categories(c);
    nG = numel(gOrd); nC = numel(cOrd);

    % Compute circSD/SE (or linear if isCircularAngle=false)
    for iDur = 1:nDur
        for iG = 1:nG
            for iC = 1:nC
                baseX = xCenters(iDur) + offsets4((iG-1)*nC + iC);
                idx = (d == presDurs(iDur)) & (g == gOrd{iG}) & (c == cOrd{iC});
                if ~any(idx), continue; end
                vals = p(idx);
                nT = numel(vals);
                if nT < 2, continue; end

                if isCircularAngle
                    theta = deg2rad( mod(vals,360) );
                    C = sum(cos(theta)); S = sum(sin(theta));
                    Rbar = sqrt(C^2 + S^2) / nT;
                    csd = rad2deg( sqrt(max(0, -2*log(max(Rbar, eps)))) );
                    cse = csd / sqrt(nT);
                else
                    csd = std(vals, 'omitnan');
                    cse = csd / sqrt(nT);
                end

                errorbar(ax, baseX, csd, cse, 'LineStyle','none', ...
                    'Color', groupColors(iG,:), 'LineWidth', 1.2);
                msIdx = cueIndex(cOrd{iC}); if isempty(msIdx), msIdx=1; end
                plot(ax, baseX, csd, markerShapes{msIdx}, ...
                    'MarkerSize', 7, 'MarkerFaceColor', groupColors(iG,:), ...
                    'MarkerEdgeColor','k', 'LineWidth',1.0);
            end
        end
    end

    set(ax,'XTick',xCenters, ...
           'XTickLabel', arrayfun(@(x) sprintf('%.2f', x), presDurs, 'UniformOutput',false), ...
           'FontSize',11, 'LineWidth',1.2);
    ylim(ax, ylCSD); xlim(ax, [0.5, nDur+0.5]); box(ax,'on'); grid(ax,'on');
    ax.GridAlpha = 0.15; ax.Layer='top';
    title(ax, char(thisID), 'FontWeight','bold');

    if k>3, xlabel(ax,'Presentation Duration (s)'); end
    if any(k==[1,4])
        ylab = 'Circ. SD (deg)';
        if ~isCircularAngle, ylab = 'SD (deg)'; end
        ylabel(ax, ylab);
    end
end

% Legend in tile 6
nexttile(tl2, 6); axis off;
hL = gobjects(4,1); Lbl = cell(4,1); kk = 0;
for iG = 1:2
    for iC = 1:2
        kk = kk+1;
        hL(kk) = plot(NaN, NaN, markerShapes{iC}, 'MarkerSize',7, ...
            'MarkerFaceColor', groupColors(iG,:), 'MarkerEdgeColor','k', 'LineWidth',1.0); hold on;
        Lbl{kk} = sprintf('%s, %s', GroupNames{iG}, CueNames{iC});
    end
end
legend(hL, Lbl, 'Location','northwest'); title('Legend');

title(tl2, 'Circular SD by Duration × Group × Cue (per ID)','FontSize',14,'FontWeight','bold');

%% ------------- FIGURE 3: RT by Cue only (med+CI; no Grouping) ----------
fig3 = figure('Color','w','Name','RT (median + BCa CI) by Dur × Cue (per ID) – no Grouping');
tl3 = tiledlayout(fig3, 2, 3, 'Padding','compact','TileSpacing','compact');

for k = 1:min(5, numel(IDs))
    nexttile(tl3, k); ax = gca; hold(ax,'on');

    thisID = IDs{k};
    rows = categorical(dataAll.ID) == thisID;
    if ~any(rows)
        title(ax, sprintf('%s (no data)', thisID)); axis(ax,'off'); continue
    end

    c = cueType(rows);
    d = presDur(rows);
    r = RT(rows);

    cOrd = categories(c); nC = numel(cOrd);
    jitterWidth = 0.05;

    % Scatter
    for iDur = 1:nDur
        for iC = 1:nC
            idx = (d == presDurs(iDur)) & (c == cOrd{iC});
            if ~any(idx), continue; end
            rr = r(idx);
            baseX = xCenters(iDur) + offsets2(iC);
            xJ = (rand(sum(idx),1)*2 - 1) * jitterWidth;
            scatter(ax, baseX + xJ, rr, 10, ...
                'MarkerFaceColor', cueColors(iC,:), 'MarkerEdgeColor','none', ...
                'MarkerFaceAlpha', 0.15, 'MarkerEdgeAlpha', 0.05);
        end
    end

    % Median + bootstrapped CI
    for iDur = 1:nDur
        for iC = 1:nC
            idx = (d == presDurs(iDur)) & (c == cOrd{iC});
            if ~any(idx), continue; end
            baseX = xCenters(iDur) + offsets2(iC);
            rr = r(idx);
            if numel(rr)<2
                med = median(rr,'omitnan'); lo=NaN; hi=NaN;
            else
                [med, ciL, ciU] = medCI(rr, nBoot, alpha);
                lo = med - ciL; hi = ciU - med;
            end
            if ~isnan(lo) && ~isnan(hi)
                errorbar(ax, baseX, med, lo, hi, 'LineStyle','none', ...
                    'Color', cueColors(iC,:), 'LineWidth',1.5);
            end
            plot(ax, baseX, med, 'o', 'MarkerSize',8, ...
                'MarkerFaceColor', cueColors(iC,:), 'MarkerEdgeColor','k', 'LineWidth', 1.0);
        end
    end

    set(ax,'XTick',xCenters, ...
           'XTickLabel', arrayfun(@(x) sprintf('%.2f', x), presDurs, 'UniformOutput',false), ...
           'FontSize',11, 'LineWidth',1.2);
    ylim(ax, ylRT); xlim(ax, [0.5, nDur+0.5]); box(ax,'on'); grid(ax,'on');
    ax.GridAlpha = 0.15; ax.Layer='top';
    title(ax, char(thisID), 'FontWeight','bold');

    if k>3, xlabel(ax,'Presentation Duration (s)'); end
    if any(k==[1,4]), ylabel(ax,'RT (ms)'); end
end

% Legend in tile 6
nexttile(tl3, 6); axis off;
hL = gobjects(2,1); Lbl = cell(2,1);
for iC = 1:2
    hL(iC) = plot(NaN, NaN, 'o', 'MarkerSize',8, ...
        'MarkerFaceColor', cueColors(iC,:), 'MarkerEdgeColor','k', 'LineWidth',1.0); hold on;
    Lbl{iC} = sprintf('Cue = %s', CueNames{iC});
end
legend(hL, Lbl, 'Location','northwest'); title('Legend');

title(tl3, 'RT (median + BCa CI) by Duration × Cue (per ID)', ...
    'FontSize',14,'FontWeight','bold');

%% ------ FIGURE 4: Circular SD by Dur × Cue (per ID) – no Grouping ------
fig4 = figure('Color','w','Name','Circular SD by Dur × Cue (per ID) – no Grouping');
tl4 = tiledlayout(fig4, 2, 3, 'Padding','compact','TileSpacing','compact');

for k = 1:min(5, numel(IDs))
    nexttile(tl4, k); ax = gca; hold(ax,'on');

    thisID = IDs{k};
    rows = categorical(dataAll.ID) == thisID;
    if ~any(rows)
        title(ax, sprintf('%s (no data)', thisID)); axis(ax,'off'); continue
    end

    c = cueType(rows);
    d = presDur(rows);
    p = precision(rows);

    cOrd = categories(c); nC = numel(cOrd);

    for iDur = 1:nDur
        for iC = 1:nC
            idx = (d == presDurs(iDur)) & (c == cOrd{iC});
            if ~any(idx), continue; end
            baseX = xCenters(iDur) + offsets2(iC);
            vals = p(idx);
            nT = numel(vals); if nT < 2, continue; end

            if isCircularAngle
                theta = deg2rad(mod(vals,360));
                C = sum(cos(theta)); S = sum(sin(theta));
                Rbar = sqrt(C^2 + S^2)/nT;
                csd = rad2deg(sqrt(max(0, -2*log(max(Rbar,eps)))));
                cse = csd/sqrt(nT);
            else
                csd = std(vals,'omitnan');
                cse = csd/sqrt(nT);
            end
            errorbar(ax, baseX, csd, cse,'LineStyle','none', ...
                'Color',cueColors(iC,:), 'LineWidth',1.5);
            plot(ax, baseX, csd,'o','MarkerSize',8,'MarkerFaceColor',cueColors(iC,:), ...
                'MarkerEdgeColor','k','LineWidth',1.0);
        end
    end

    set(ax,'XTick',xCenters, ...
           'XTickLabel', arrayfun(@(x) sprintf('%.2f', x), presDurs, 'UniformOutput',false), ...
           'FontSize',11,'LineWidth',1.2);
    ylim(ax, ylCSD); xlim(ax, [0.5, nDur+0.5]); box(ax,'on'); grid(ax,'on'); ax.GridAlpha=0.15; ax.Layer='top';
    title(ax, char(thisID), 'FontWeight','bold');

    if k>3, xlabel(ax,'Presentation Duration (s)'); end
    if any(k==[1,4])
        ylab = 'Circ. SD (deg)';
        if ~isCircularAngle, ylab = 'SD (deg)'; end
        ylabel(ax, ylab);
    end
end

% Legend in tile 6
nexttile(tl4, 6); axis off;
hL = gobjects(2,1); Lbl = cell(2,1);
for iC = 1:2
    hL(iC) = plot(NaN, NaN, 'o', 'MarkerSize',8, ...
        'MarkerFaceColor', cueColors(iC,:), 'MarkerEdgeColor','k', 'LineWidth',1.0); hold on;
    Lbl{iC} = sprintf('Cue = %s', CueNames{iC});
end
legend(hL, Lbl, 'Location','northwest'); title('Legend');

title(tl4,'Circular SD by Duration × Cue (per ID) – no Grouping','FontSize',14,'FontWeight','bold');


%% FIGURE 6: RT across Sessions (median + CI) per ID (collapsed over Durations & Grouping)
fig6 = figure('Color','w','Name','RT across Sessions (median + CI) per ID');
tl6 = tiledlayout(fig6, 2, 3, 'Padding','compact','TileSpacing','compact');

for k = 1:min(5, numel(IDs))
    nexttile(tl6, k); ax = gca; hold(ax,'on');
    thisID = IDs{k};
    rows = categorical(dataAll.ID) == thisID;
    if ~any(rows), axis(ax,'off'); title(char(thisID)); continue; end

    sess = dataAll.Session(rows);
    r    = RT(rows);
    c    = cueType(rows);
    sessList = unique(sess); sessList = sort(sessList);

    cCats = categories(c);
    for iC = 1:numel(cCats)
        thisC = cCats{iC};
        yMed = NaN(size(sessList));
        loCI = NaN(size(sessList));
        hiCI = NaN(size(sessList));

        for j = 1:numel(sessList)
            idx = (sess == sessList(j)) & (c == thisC);
            if ~any(idx), continue; end
            rr = r(idx);
            if numel(rr) < 2
                yMed(j) = median(rr, 'omitnan');
            else
                [yMed(j), ciL, ciU] = medCI(rr, nBoot, alpha);
                loCI(j) = ciL; hiCI(j) = ciU;
            end
        end

        % error bars (respect NaNs)
        ebLo = yMed - loCI; ebHi = hiCI - yMed;
        errorbar(ax, sessList, yMed, ebLo, ebHi, ...
            'LineStyle','none', 'Color', cueColors(cueIndex(thisC),:), 'LineWidth',1.2);
        plot(ax, sessList, yMed, '-o', ...
            'MarkerFaceColor', cueColors(cueIndex(thisC),:), ...
            'MarkerEdgeColor','k', 'Color', cueColors(cueIndex(thisC),:), ...
            'LineWidth',1.2, 'MarkerSize',6);
    end

    set(ax,'FontSize',11,'LineWidth',1.2); grid(ax,'on'); ax.GridAlpha=0.15; ax.Layer='top';
    ylabel(ax,'RT (ms)'); title(ax, char(thisID),'FontWeight','bold');
    if k>3, xlabel(ax,'Session'); end
end
% Legend tile
nexttile(tl6, 6); axis off;
hL = gobjects(2,1); Lbl = cell(2,1);
for iC = 1:2
    hL(iC) = plot(NaN,NaN,'-o','MarkerSize',6, ...
        'MarkerFaceColor',cueColors(iC,:), 'MarkerEdgeColor','k', ...
        'Color',cueColors(iC,:), 'LineWidth',1.2); hold on;
    Lbl{iC} = sprintf('Cue = %s', CueNames{iC});
end
legend(hL, Lbl, 'Location','northwest'); title('Legend');
title(tl6,'RT across Sessions (median + CI) per ID','FontSize',14,'FontWeight','bold');

%% FIGURE 7: CDF of RT by Cue (per ID; collapsed over Durations & Grouping)
fig7 = figure('Color','w','Name','ECDF of RT by Cue (per ID)');
tl7 = tiledlayout(fig7, 2, 3, 'Padding','compact','TileSpacing','compact');

for k = 1:min(5, numel(IDs))
    nexttile(tl7, k); ax = gca; hold(ax,'on');
    thisID = IDs{k};
    rows = categorical(dataAll.ID) == thisID;
    if ~any(rows), axis(ax,'off'); title(char(thisID)); continue; end

    r = RT(rows);
    c = cueType(rows);
    cOrd = categories(c);

    for iC = 1:numel(cOrd)
        rr = r(c == cOrd{iC}); rr = rr(~isnan(rr));
        if numel(rr) < 1, continue; end

        if exist('ecdf','file') == 2
            [f, x] = ecdf(rr);
        else
            % simple inline ECDF (no toolbox)
            x = sort(rr);
            f = (1:numel(x))' / numel(x);
            % (Optional) prepend zero step:
            % x = [x(1); x]; f = [0; f];
        end

        plot(ax, x, f, 'LineWidth', 1.5, 'Color', cueColors(cueIndex(cOrd{iC}),:));
    end

    grid(ax,'on'); ax.GridAlpha=0.15; ax.Layer='top'; box(ax,'on');
    if ~isempty(RT), xlim(ax, [min(RT) max(RT)]); end
    ylim(ax, [0 1]);
    title(ax, char(thisID),'FontWeight','bold');
    if k>3, xlabel(ax,'RT (ms)'); end
    if any(k==[1,4]), ylabel(ax,'Cumulative proportion'); end
end
% Legend tile
nexttile(tl7, 6); axis off;
hL = gobjects(2,1); Lbl = cell(2,1);
for iC = 1:2
    hL(iC) = plot(NaN,NaN,'-','LineWidth',1.5,'Color',cueColors(iC,:)); hold on;
    Lbl{iC} = sprintf('Cue = %s', CueNames{iC});
end
legend(hL, Lbl, 'Location','northwest'); title('Legend');
title(tl7,'ECDF of RT by Cue (per ID)','FontSize',14,'FontWeight','bold');

% Bin edges shared across panels to make shapes comparable
if exist('ylP','var') && numel(ylP)==2
    pmin = ylP(1); pmax = ylP(2);
else
    pmin = min(precision); pmax = max(precision);
end
nBins = 30;                                % tweak if you want smoother/rougher
binEdges = linspace(pmin, pmax, nBins+1);
maxHalfWidth = 0.14;                       % half width of each vertical histogram “violin”
edgeLW = 1.0; faceAlpha = 0.25;


%% FIGURE 7b: ECDF of RT by Cue × Grouping (per ID; durations collapsed)
% Color encodes Cue (R/NR); line style encodes Grouping (Grouped solid, Separated dashed).

fig7b = figure('Color','w','Name','ECDF of RT by Cue × Grouping (per ID)');
tl7b  = tiledlayout(fig7b, 2, 3, 'Padding','compact','TileSpacing','compact');

for k = 1:min(5, numel(IDs))
    nexttile(tl7b, k); ax = gca; hold(ax,'on');
    thisID = IDs{k};
    rows = categorical(dataAll.ID) == thisID;
    if ~any(rows), axis(ax,'off'); title(char(thisID)); continue; end

    r = RT(rows);
    c = cueType(rows);
    g = grouping(rows);

    cOrd = categories(c);
    gOrd = categories(g);

    for iC = 1:numel(cOrd)
        for iG = 1:numel(gOrd)
            idx = (c == cOrd{iC}) & (g == gOrd{iG});
            rr  = r(idx); rr = rr(~isnan(rr));
            if numel(rr) < 1, continue; end

            % ECDF (built-in or fallback)
            if exist('ecdf','file') == 2
                [f, x] = ecdf(rr);
            else
                x = sort(rr); f = (1:numel(x))' / numel(x);
            end

            % Style: color by Cue, line style by Grouping
            col = cueColors(cueIndex(cOrd{iC}), :);
            ls  = '-';
            if strcmpi(gOrd{iG}, 'Separated')
                ls = '--';
            end

            plot(ax, x, f, 'LineWidth', 1.5, 'Color', col, 'LineStyle', ls);
        end
    end

    grid(ax,'on'); ax.GridAlpha = 0.15; ax.Layer = 'top'; box(ax,'on');
    if ~isempty(RT), xlim(ax, [min(RT) max(RT)]); end
    ylim(ax,[0 1]);
    title(ax, char(thisID),'FontWeight','bold');
    if k>3, xlabel(ax,'RT (ms)'); end
    if any(k==[1,4]), ylabel(ax,'Cumulative proportion'); end
end

% Legend tile (fixed 4-combo legend)
nexttile(tl7b, 6); axis off; hold on;
hL = gobjects(4,1); Lbl = cell(4,1);
% R, Grouped (solid)
hL(1) = plot([0 1],[0.9 0.9], '-', 'LineWidth', 2, 'Color', cueColors(1,:)); Lbl{1} = sprintf('%s, %s', CueNames{1}, GroupNames{1});
% R, Separated (dashed)
hL(2) = plot([0 1],[0.75 0.75], '--', 'LineWidth', 2, 'Color', cueColors(1,:)); Lbl{2} = sprintf('%s, %s', CueNames{1}, GroupNames{2});
% NR, Grouped (solid)
hL(3) = plot([0 1],[0.6 0.6], '-', 'LineWidth', 2, 'Color', cueColors(2,:)); Lbl{3} = sprintf('%s, %s', CueNames{2}, GroupNames{1});
% NR, Separated (dashed)
hL(4) = plot([0 1],[0.45 0.45], '--', 'LineWidth', 2, 'Color', cueColors(2,:)); Lbl{4} = sprintf('%s, %s', CueNames{2}, GroupNames{2});
legend(hL, Lbl, 'Location','northwest'); title('Legend');

title(tl7b,'ECDF of RT by Cue × Grouping (per ID)','FontSize',14,'FontWeight','bold');


%% FIGURE 8 (simple): Vertical histograms by Duration × Grouping × Cue (per ID)
% Same style as your Fig 9, but with Grouping lanes added.

% --- Ensure y-limits for precision ---
if ~exist('ylP','var') || isempty(ylP)
    pAll = precision(~isnan(precision) & isfinite(precision));
    if isempty(pAll), ylP = [0 360];
    else
        pr = prctile(pAll, [1 99]); span = max(1, pr(2)-pr(1)); pad = 0.05*span;
        ylP = [pr(1)-pad, pr(2)+pad];
    end
end

% --- Parameters (match Fig 9 aesthetics) ---
nBins        = 30;                                % histogram resolution
binEdges     = linspace(ylP(1), ylP(2), nBins+1); % shared bins across panels
maxHalfWidth = 0.12;                              % width of each mirrored hist
edgeLW       = 1.0;
faceAlpha    = 0.28;
laneOffset   = [-0.18, +0.18];                    % per-duration lane centers (G, S)
cueOffset    = [-0.05, +0.05];                    % within-lane offsets (R, NR)
laneHalf     = 0.16;                              % shaded lane half-width
laneShadeG   = [1.00 0.92 0.88];
laneShadeS   = [0.90 0.95 0.99];
laneAlpha    = 0.20;

fig8s = figure('Color','w','Name','Precision Distributions by Duration × Group × Cue (per ID)');
tl8s  = tiledlayout(fig8s, 2, 3, 'Padding','compact', 'TileSpacing','compact');

for k = 1:min(5, numel(IDs))
    nexttile(tl8s, k); ax = gca; hold(ax,'on');
    thisID = IDs{k};
    rows = categorical(dataAll.ID) == thisID;
    if ~any(rows), title(ax, sprintf('%s (no data)', thisID)); axis(ax,'off'); continue; end

    % Slice data for this participant
    d = presDur(rows);
    g = grouping(rows);
    c = cueType(rows);
    p = precision(rows);

    gOrd = categories(g); if isempty(gOrd), gOrd = {'Grouped'}; end
    cOrd = categories(c);                   % expect {'R','NR'} (present levels)

    % --- lane backgrounds for visual salience ---
    for iDur = 1:numel(presDurs)
        cxG = xCenters(iDur) + laneOffset(1);
        patch([cxG-laneHalf cxG+laneHalf cxG+laneHalf cxG-laneHalf], ...
              [ylP(1) ylP(1) ylP(2) ylP(2)], laneShadeG, ...
              'EdgeColor','none','FaceAlpha',laneAlpha,'Parent',ax);
        if numel(gOrd) > 1
            cxS = xCenters(iDur) + laneOffset(2);
            patch([cxS-laneHalf cxS+laneHalf cxS+laneHalf cxS-laneHalf], ...
                  [ylP(1) ylP(1) ylP(2) ylP(2)], laneShadeS, ...
                  'EdgeColor','none','FaceAlpha',laneAlpha,'Parent',ax);
        end
    end

    % --- draw mirrored histograms (no overlap) ---
    for iDur = 1:numel(presDurs)
        for iG = 1:numel(gOrd)
            baseLane = xCenters(iDur) + laneOffset(min(iG, numel(laneOffset)));

            for iC = 1:numel(cOrd)
                idx = (d == presDurs(iDur)) & (g == gOrd{iG}) & (c == cOrd{iC});
                if ~any(idx), continue; end

                baseX = baseLane + cueOffset(min(iC,2));
                col   = cueColors(min(iC,2),:);
                vals  = p(idx);

                % vertical mirrored histogram + median tick
                plotVerticalHistSimple(ax, vals, baseX, binEdges, maxHalfWidth, col, edgeLW, faceAlpha);
                medv = median(vals,'omitnan');
                plot(ax, [baseX-0.03, baseX+0.03], [medv medv], '-', 'Color', col, 'LineWidth', 1.2);
            end
        end

        % tiny lane labels at top
        text(xCenters(iDur)+laneOffset(1), ylP(2), 'G', 'HorizontalAlignment','center', ...
             'VerticalAlignment','bottom', 'FontWeight','bold', 'Color',[0.55 0.30 0.18]);
        if numel(gOrd) > 1
            text(xCenters(iDur)+laneOffset(2), ylP(2), 'S', 'HorizontalAlignment','center', ...
                 'VerticalAlignment','bottom', 'FontWeight','bold', 'Color',[0.10 0.25 0.45]);
        end
    end

    % Axes cosmetics
    set(ax,'XTick',xCenters, ...
           'XTickLabel', arrayfun(@(x) sprintf('%.2f', x), presDurs, 'UniformOutput',false), ...
           'FontSize',11,'LineWidth',1.2);
    ylim(ax, ylP); xlim(ax, [0.5, numel(presDurs)+0.5]);
    box(ax,'on'); grid(ax,'on'); ax.GridAlpha=0.15; ax.Layer='top';
    title(ax, char(thisID), 'FontWeight','bold');
    if k>3, xlabel(ax,'Presentation Duration (s)'); end
    if any(k==[1,4]), ylabel(ax,'Raw Precision (deg)'); end
end

% Legend tile (color = Cue; lane shading = Grouping)
nexttile(tl8s, 6); axis off; hold on;
plot([0.05 0.35],[0.90 0.90], '-', 'LineWidth', 8, 'Color', cueColors(1,:)); text(0.38,0.90,'Cue = R','FontSize',11);
plot([0.05 0.35],[0.76 0.76], '-', 'LineWidth', 8, 'Color', cueColors(2,:)); text(0.38,0.76,'Cue = NR','FontSize',11);
patch([0.05 0.25 0.25 0.05],[0.58 0.58 0.68 0.68], laneShadeG, 'EdgeColor','none', 'FaceAlpha', laneAlpha); text(0.28,0.63,'Lane = Grouped','FontSize',11);
patch([0.05 0.25 0.25 0.05],[0.42 0.42 0.52 0.52], laneShadeS, 'EdgeColor','none', 'FaceAlpha', laneAlpha); text(0.28,0.47,'Lane = Separated','FontSize',11);
axis([0 1 0 1]); axis off;
title(tl8s,'Precision Distributions by Duration × Group × Cue (per ID)', 'FontSize',14,'FontWeight','bold');

% --------------------- Local helper (unique name) -----------------------
function plotVerticalHistSimple(ax, x, baseX, edges, maxHalfWidth, colorRGB, edgeLW, faceAlpha)
% Draw a mirrored vertical histogram centered at baseX (like Fig 9).
x = x(:); x = x(isfinite(x));
if isempty(x), return; end
[counts,~] = histcounts(x, edges);
if max(counts) > 0
    w = (counts / max(counts)) * maxHalfWidth;
else
    w = zeros(size(counts));
end
yc = (edges(1:end-1) + edges(2:end)) / 2;
xLeft  = baseX - w(:);
xRight = baseX + w(:);
Xpoly = [xLeft; flipud(xRight)];
Ypoly = [yc(:);   flipud(yc(:))];
patch('Parent',ax,'XData',Xpoly,'YData',Ypoly, ...
    'FaceColor',colorRGB,'FaceAlpha',faceAlpha, ...
    'EdgeColor',colorRGB,'EdgeAlpha',0.9,'LineWidth',edgeLW);
end


%% FIGURE 9 (updated): Vertical histograms by Duration × Cue (grouping collapsed)
fig9 = figure('Color','w','Name','Precision Hist (vertical) by Duration × Cue (per ID)');
tl9  = tiledlayout(fig9, 2, 3, 'Padding','compact', 'TileSpacing','compact');

for k = 1:min(5, numel(IDs))
    nexttile(tl9,k); ax = gca; hold(ax,'on');
    thisID = IDs{k};
    rows = categorical(dataAll.ID)==thisID;
    if ~any(rows), title(ax, sprintf('%s (no data)', thisID)); axis(ax,'off'); continue; end

    c = cueType(rows); d = presDur(rows); p = precision(rows);
    cOrd = categories(c); nC = numel(cOrd);

    for iDur = 1:nDur
        for iC = 1:nC
            idx = (d==presDurs(iDur)) & (c==cOrd{iC});
            if ~any(idx), continue; end
            baseX = xCenters(iDur) + offsets2(iC);
            col   = cueColors(iC,:);
            ls    = '-'; if strcmp(cOrd{iC},'NR'), ls='--'; end
            plotVerticalHist(ax, p(idx), baseX, binEdges, maxHalfWidth, col, ls, edgeLW, faceAlpha);
        end
    end

    set(ax,'XTick',xCenters, ...
           'XTickLabel',arrayfun(@(x)sprintf('%.2f',x),presDurs,'UniformOutput',false), ...
           'FontSize',11,'LineWidth',1.2);
    ylim(ax,[pmin pmax]); xlim(ax,[0.5, nDur+0.5]); box(ax,'on'); grid(ax,'on'); ax.GridAlpha=0.15; ax.Layer='top';
    title(ax, char(thisID), 'FontWeight','bold');
    if k>3, xlabel(ax,'Presentation Duration (s)'); end
    if any(k==[1,4]), ylabel(ax,'Raw Precision (deg)'); end
end

% Legend tile (colors = Cue; line style = solid/dashed mirrors cue too)
nexttile(tl9,6); axis off; hold on;
hL = gobjects(2,1); Lbl = cell(2,1);
hL(1)=plot([0 1],[0.8 0.8],'-','LineWidth',3,'Color',cueColors(1,:)); Lbl{1}=sprintf('Cue = %s', CueNames{1});
hL(2)=plot([0 1],[0.6 0.6],'--','LineWidth',3,'Color',cueColors(2,:)); Lbl{2}=sprintf('Cue = %s', CueNames{2});
legend(hL,Lbl,'Location','northwest'); title('Legend');
title(tl9,'Raw Precision Distributions by Duration × Cue (per ID)','FontSize',14,'FontWeight','bold');

%% FIGURE 10 (combined): Rank-ordered precision by Duration × Cue (per ID)
% Shows R and NR together, durations encoded by shade (light=short, dark=long)

qVec = linspace(0.05, 0.95, 19);   % quantiles from 5% to 95%

% build shaded color series for each cue (light -> base)
mkShades = @(base,n) (ones(n,3) - (ones(n,3) - repmat(base,n,1)) .* (repmat(linspace(0.35,1,n)',1,3)));
Rcolors  = mkShades([0.8500 0.3250 0.0980], nDur);   % orange family (R)
NRcolors = mkShades([0.0000 0.4470 0.7410], nDur);   % blue family (NR)

fig10c = figure('Color','w','Name','Ordered Precision by Duration × Cue (per ID)');
tl10c  = tiledlayout(fig10c, 2, 3, 'Padding','compact','TileSpacing','compact');

for k = 1:min(5, numel(IDs))
    nexttile(tl10c, k); ax = gca; hold(ax,'on');
    thisID = IDs{k};
    rows = categorical(dataAll.ID) == thisID;
    if ~any(rows), title(ax, sprintf('%s (no data)', thisID)); axis(ax,'off'); continue; end

    d = presDur(rows);
    c = cueType(rows);
    p = precision(rows);
    e = abs(mod(precision(rows) + 180, 360) - 180);

    % ---- Cue = R (solid) ----
    for j = 1:nDur
        idx = (d == presDurs(j)) & (c == 'R');
        if ~any(idx), continue; end
        pj = e(idx);
        if exist('quantile','file') == 2
            qy = quantile(pj, qVec);
            medJ = quantile(pj, 0.5);
        else
            qy = prctile(pj, qVec*100);
            medJ = prctile(pj, 50);
        end
        plot(ax, qVec, qy, '-', 'LineWidth', 1.4, 'Color', Rcolors(j,:));
        plot(ax, 0.5, medJ, 'o', 'MarkerSize', 4, ...
            'MarkerFaceColor', Rcolors(j,:), 'MarkerEdgeColor','k');
    end

    % ---- Cue = NR (dashed) ----
    for j = 1:nDur
        idx = (d == presDurs(j)) & (c == 'NR');
        if ~any(idx), continue; end
        pj = e(idx);
        if exist('quantile','file') == 2
            qy = quantile(pj, qVec);
            medJ = quantile(pj, 0.5);
        else
            qy = prctile(pj, qVec*100);
            medJ = prctile(pj, 50);
        end
        plot(ax, qVec, qy, '--', 'LineWidth', 1.4, 'Color', NRcolors(j,:));
        plot(ax, 0.5, medJ, 'o', 'MarkerSize', 4, ...
            'MarkerFaceColor', NRcolors(j,:), 'MarkerEdgeColor','k');
    end

    box(ax,'on'); grid(ax,'on'); ax.GridAlpha=0.15; ax.Layer='top';
    xlim(ax, [0.05 0.95]); ylim(ax, ylP);
    title(ax, char(thisID), 'FontWeight','bold');
    if k>3, xlabel(ax,'Quantile (rank)'); end
    if any(k==[1,4]), ylabel(ax,'Raw Precision (deg)'); end
end

% Legend / key tile
nexttile(tl10c, 6); axis off; hold on;
% Cue key
plot([0.05 0.32],[0.9 0.9], '-', 'LineWidth', 2, 'Color', Rcolors(end,:)); text(0.35,0.9,'Cue = R (solid)','FontSize',11);
plot([0.05 0.32],[0.78 0.78],'--', 'LineWidth', 2, 'Color', NRcolors(end,:)); text(0.35,0.78,'Cue = NR (dashed)','FontSize',11);
% Duration shades (use first, middle, last as examples)
idxShow = unique(round(linspace(1, nDur, min(nDur, 3))));
yy = 0.58; dy = 0.12;
for ii = 1:numel(idxShow)
    j = idxShow(ii);
    plot([0.05 0.32],[yy  yy], '-',  'Color', Rcolors(j,:),  'LineWidth', 3); hold on;
    plot([0.05 0.32],[yy-0.05 yy-0.05], '--', 'Color', NRcolors(j,:), 'LineWidth', 3);
    text(0.35, yy-0.025, sprintf('Dur = %.2fs', presDurs(j)), 'FontSize',10);
    yy = yy - dy;
end
axis([0 1 0 1]); axis off;
title(tl10c,'Ordered Precision (Quantile Functions) by Duration × Cue (per ID)','FontSize',14,'FontWeight','bold');

% ==== Ensure precision y-limits exist (ylP) ====
if ~exist('ylP','var') || isempty(ylP)
    if exist('precision','var') && ~isempty(precision)
        pAll = precision(~isnan(precision) & isfinite(precision));
        if isempty(pAll)
            ylP = [0 360];  % fallback if nothing usable
        else
            % Use robust limits (1st–99th percentile) with a small pad
            pr = prctile(pAll, [1 99]);
            span = max(1, pr(2) - pr(1));
            pad  = 0.05 * span;
            ylP  = [pr(1)-pad, pr(2)+pad];
        end
    else
        ylP = [0 360];      % generic fallback for circular precision
    end
end
%% FIGURE 11: Ordered raw precision columns by Duration × Cue (per ID)
% --- absolute circular error for all rows (0..180) ---
absErrAll = abs( mod(precision + 180, 360) - 180 );

% shared y-limits for error (robust)
eAll = absErrAll(~isnan(absErrAll));
if isempty(eAll)
    ylE = [0 180];
else
    pr = prctile(eAll, [1 99]); span = max(1, pr(2)-pr(1));
    ylE = [max(0, pr(1)-0.05*span), min(180, pr(2)+0.05*span)];
end

% layout + aesthetics
fig12b = figure('Color','w','Name','Rank-ordered Abs Error by Duration × Cue (per ID)');
tl12b  = tiledlayout(fig12b, 2, 3, 'Padding','compact','TileSpacing','compact');

subWidth = 0.22;        % horizontal width allocated to each cue band within a duration
barAlpha = 0.35;        % transparency of bars
maxBarW  = 0.006;       % cap bar width so dense conditions don’t get too chunky

for k = 1:min(5, numel(IDs))
    nexttile(tl12b, k); ax = gca; hold(ax,'on');
    thisID = IDs{k};
    rows = categorical(dataAll.ID) == thisID;
    if ~any(rows), title(ax, sprintf('%s (no data)', thisID)); axis(ax,'off'); continue; end

    d = presDur(rows);
    c = cueType(rows);
    e = absErrAll(rows);

    cOrd = categories(c); nC = numel(cOrd);

    for iDur = 1:nDur
        for iC = 1:nC
            idx = (d == presDurs(iDur)) & (c == cOrd{iC});
            if ~any(idx), continue; end

            vals = sort(e(idx));                 % rank within this duration × cue
            n    = numel(vals);
            cx   = xCenters(iDur) + offsets2(iC);

            % bar geometry
            if n == 1
                bw = min(subWidth*0.9, maxBarW);
                xPositions = cx;
            else
                bw = min(subWidth / n, maxBarW);
                xPositions = linspace(cx - subWidth/2 + bw/2, cx + subWidth/2 - bw/2, n);
            end

            % draw tiny vertical bars (0 -> value)
            for t = 1:n
                rectangle(ax, 'Position', [xPositions(t)-bw/2, 0, bw, vals(t)], ...
                    'FaceColor', cueColors(iC,:), 'FaceAlpha', barAlpha, ...
                    'EdgeColor', 'none');
            end

            % optional faint band guides (left/right edges of each cue band)
            plot(ax, [cx - subWidth/2, cx - subWidth/2], ylE, '-', 'Color', [0 0 0 0.06]);
            plot(ax, [cx + subWidth/2, cx + subWidth/2], ylE, '-', 'Color', [0 0 0 0.06]);

            % mark the median as a short horizontal tick for quick comparison
            medv = median(vals,'omitnan');
            plot(ax, [cx - 0.06, cx + 0.06], [medv medv], '-', 'Color', cueColors(iC,:), 'LineWidth', 1.2);
        end
    end

    set(ax, 'XTick', xCenters, ...
            'XTickLabel', arrayfun(@(x) sprintf('%.2f', x), presDurs, 'UniformOutput', false), ...
            'FontSize', 11, 'LineWidth', 1.2);
    ylim(ax, ylE); xlim(ax, [0.5, nDur + 0.5]);
    box(ax,'on'); grid(ax,'on'); ax.GridAlpha=0.15; ax.Layer='top';
    title(ax, char(thisID), 'FontWeight','bold');
    if k>3, xlabel(ax,'Presentation Duration (s)'); end
    if any(k==[1,4]), ylabel(ax,'Abs circular error (deg)'); end
end

% legend tile
nexttile(tl12b, 6); axis off; hold on;
hL = gobjects(2,1); Lbl = cell(2,1);
for iC = 1:2
    hL(iC) = patch([0.05 0.25 0.25 0.05], [0.85-0.18*(iC-1) 0.85-0.18*(iC-1) 0.95-0.18*(iC-1) 0.95-0.18*(iC-1)], ...
                   cueColors(iC,:), 'EdgeColor','none', 'FaceAlpha', barAlpha); hold on;
    Lbl{iC} = sprintf('Cue = %s', CueNames{iC});
end
legend(hL, Lbl, 'Location','northwest'); title('Legend');
title(tl12b, 'Rank-ordered Abs Error by Duration × Cue (per ID)', 'FontSize', 14, 'FontWeight', 'bold');

%% ========================== HELPERS ====================================
function [med, ciL, ciU] = medCI(x, nBoot, alpha)
% Robust median with BCa bootstrap CI if available
x = x(:); x = x(~isnan(x));
if isempty(x)
    med = NaN; ciL = NaN; ciU = NaN; return;
end
med = median(x,'omitnan');
if numel(x) < 2
    ciL = med; ciU = med; return;
end
try
    ci = bootci(nBoot, {@(y) median(y,'omitnan'), x}, 'alpha', alpha, 'type', 'bca');
    ciL = ci(1); ciU = ci(2);
catch
    % Fallback: percentile bootstrap
    B = nan(nBoot,1); n = numel(x);
    for b = 1:nBoot
        idx = randi(n, n, 1);
        B(b) = median(x(idx),'omitnan');
    end
    q = quantile(B, [alpha/2, 1-alpha/2]);
    ciL = q(1); ciU = q(2);
end
end

function plotVerticalHist(ax, x, baseX, edges, maxHalfWidth, colorRGB, lineStyle, edgeLW, faceAlpha)
% Draws a mirrored, vertical histogram “violin” centered at baseX.
% Height = precision (edges), width encodes relative frequency within bins.
x = x(:); x = x(~isnan(x));
if numel(x) < 1, return; end
[counts,~] = histcounts(x, edges);
% scale to [0,1] and to desired half-width
if max(counts) > 0
    w = (counts / max(counts)) * maxHalfWidth;
else
    w = zeros(size(counts));
end
% y centers for the bins
yc = (edges(1:end-1) + edges(2:end))/2;

% Build polygon for mirrored shape
xLeft  = baseX - w(:);
xRight = baseX + w(:);
Xpoly = [xLeft; flipud(xRight)];
Ypoly = [yc(:);   flipud(yc(:))];

ph = patch('Parent',ax,'XData',Xpoly,'YData',Ypoly, ...
    'FaceColor',colorRGB,'FaceAlpha',faceAlpha, ...
    'EdgeColor',colorRGB,'EdgeAlpha',0.9,'LineWidth',edgeLW,'LineStyle',lineStyle);
uistack(ph,'bottom');  % keep patches behind medians/lines if you add any later
end


function y = iff(cond, a, b)
% Inline ternary helper
if cond, y = a; else, y = b; end
end

function f = ksdensitySafe(x, y)
% KDE robust to tiny N / zero variance / missing Statistics Toolbox
x = x(:); x = x(isfinite(x));
if isempty(x)
    f = zeros(size(y)); return
end
hasKS = exist('ksdensity','file') == 2;
if hasKS
    try
        f = ksdensity(x, y, 'Function','pdf');
        f(f<0) = 0;
        return
    catch
        % fall through to manual kernel if ksdensity errors
    end
end
% Manual Gaussian kernel density
n = numel(x);
s = std(x);
rngy = max(eps, range(y));
if ~isfinite(s) || s==0
    bw = 0.05 * rngy;          % small bump if zero spread
else
    bw = 1.06 * s * n^(-1/5);  % Silverman’s rule
end
bw = max(bw, 0.02 * rngy);
% Evaluate
F = exp(-0.5 * ((y(:) - x')./bw).^2) / (sqrt(2*pi)*bw);
f = sum(F, 2) / n;
f = f(:)';
end

function drawHalfViolin(ax, y, f, panelMax, baseX, halfWidth, side, colorRGB, faceAlpha)
% Scale density to width and draw a filled half-violin.
w = (f / max(panelMax, eps)) * halfWidth;
if strcmpi(side,'left')
    X = [baseX - w, fliplr(baseX*ones(size(w)))];
else
    X = [baseX*ones(size(w)), fliplr(baseX + w)];
end
Y = [y, fliplr(y)];
patch('Parent',ax,'XData',X,'YData',Y, ...
      'FaceColor',colorRGB,'FaceAlpha',faceAlpha, ...
      'EdgeColor',colorRGB,'EdgeAlpha',0.9,'LineWidth',0.8);
end