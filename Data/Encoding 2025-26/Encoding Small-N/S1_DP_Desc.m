%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Study 1--Redundancy encoding durations-- Data Processing and Descriptives
% Combine and prepare data for descriptive plotting
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear; clc, close all; rng(1) % Clear and fix randomisation for bootstraps

% Combine data

filePattern = 'EncodingData_*.mat';
files = dir(filePattern);

if isempty(files)
    error('no file found matching pattern: %s', filePattern);
end

[~, ix] = sort([files.datenum]);
files = files(ix);

allT = cell(numel(files), 1); % establish table for all

for i = 1:numel(files)
    fname = files(i).name;
    % Parse ID and session from filename
    tok = regexp(fname, '^EncodingData_([A-Za-z]+)_sess(\d+)_', 'tokens', 'once')
    if isempty(tok)
        warning('Skipping file with unexpected name: %s', fname);
        continue
    end
    pid = upper(tok{1}) % Standardise initial's letter case
    sessN = str2double(tok{2});

    S = load(fname);
    fns = fieldnames(S);
    % Choose a table-like payload
    V = [];
    %if numel(fns) == 1
    if isscalar(fns) % test suggested function isscaler
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
            for k = 1:numell(fns)
                if isstruct(S.(fns{k})) && isvector(S.(fns{k}))
                    try
                        V = struct2table(S.(fns{k}));
                        break
                    catch
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
    % Add/override ID & session from filename
    V.ID = repmat(string(pid), height(V), 1);
    V.Session = repmat(sessN, height(V), 1);
    allT{i} = V;
end

% Concatenate and sanity-check
allT = allT(~cellfun('isempty', allT));
if isempty(allT)
    error('No usable data tables found.');
end
dataAll = vertcat(allT{:});
dataAll.ID      = categorical(dataAll.ID); % Enforce useful datatype
dataAll.Session = double(dataAll.Session);

ct = varfun(@numel, dataAll, ...
    'InputVariables', 'Session', ...
    'GroupingVariables', {'ID','Session'});
if any(strcmp(ct.Properties.VariableNames, 'numel_Session'))
    ct.Properties.VariableNames{'numel_Session'} = 'N';
end
disp(ct);

dataAll_raw = dataAll
n0 = height(dataAll);
nNanRT = sum(isnan(dataAll.ResponseTime));
dataAll = dataAll(~isnan(dataAll.ResponseTime), :);

nHigh = sum(dataAll.ResponseTime > 2500);
dataAll = dataAll(dataAll.ResponseTime <= 2500, :);
fprintf('Trials: %d total | %d dropped (NaN RT) | %d dropped (>2500 ms) | %d remain\n', ...
    n0, nNanRT, nHigh, height(dataAll));

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
isCircularAngle = false;   % <-- set false if 'Precision' is error magnitude

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

%% === Strict grouping: "all R adjacent" (e.g., all 3 R's together) + Even/Uneven ===
% Inputs (in dataAll):
%   - Colors:              each row is a 1x6 numeric, or cell/str like "[175,42,...]"
%   - StimulusLocations:   each row is a 1x6 numeric of angles (deg)
% Output columns added:
%   - Grouping_adjRblock      : 'Grouped' (all R contiguous) / 'Separated' / 'Unverifiable'
%   - SeparatePattern_adjR    : 'Grouped' / 'Even' / 'Uneven' / 'Unknown'
%   - RMask_adjR              : 'R,NR,...' in ring order (for manual checks)
%   - nR_adjR                 : number of redundant items in the array

N = height(dataAll);
K = 6;

% -------- Parse Colors -> numeric N x 6 matrix C --------
C = nan(N,K);
if iscell(dataAll.Colors)
    for i = 1:N
        vi = dataAll.Colors{i};
        if isnumeric(vi) && isvector(vi) && numel(vi)==K
            C(i,:) = double(vi(:)).';
        else
            si = string(dataAll.Colors{i});
            tok = regexp(si, '(-?\d+(\.\d+)?)', 'match');
            if numel(tok)==K, C(i,:) = str2double(tok(:)).'; end
        end
    end
elseif isnumeric(dataAll.Colors) && size(dataAll.Colors,2)==K
    C = double(dataAll.Colors);
else
    for i = 1:N
        si = string(dataAll.Colors(i));
        tok = regexp(si, '(-?\d+(\.\d+)?)', 'match');
        if numel(tok)==K, C(i,:) = str2double(tok(:)).'; end
    end
end

% -------- Parse StimulusLocations -> numeric N x 6 matrix L --------
L = nan(N,K);
if iscell(dataAll.StimulusLocations)
    for i = 1:N
        vi = dataAll.StimulusLocations{i};
        if isnumeric(vi) && isvector(vi) && numel(vi)==K
            L(i,:) = double(vi(:)).';
        else
            si = string(dataAll.StimulusLocations{i});
            tok = regexp(si, '(-?\d+(\.\d+)?)', 'match');
            if numel(tok)==K, L(i,:) = str2double(tok(:)).'; end
        end
    end
elseif isnumeric(dataAll.StimulusLocations) && size(dataAll.StimulusLocations,2)==K
    L = double(dataAll.StimulusLocations);
else
    for i = 1:N
        si = string(dataAll.StimulusLocations(i));
        tok = regexp(si, '(-?\d+(\.\d+)?)', 'match');
        if numel(tok)==K, L(i,:) = str2double(tok(:)).'; end
    end
end

% -------- Outputs --------
Grouping_adjRblock     = strings(N,1); Grouping_adjRblock(:) = "Unverifiable";
SeparatePattern_adjR   = strings(N,1); SeparatePattern_adjR(:) = "Unknown";
RMask_adjR             = strings(N,1);
nR_adjR                = nan(N,1);

alt1 = [1 0 1 0 1 0];
alt2 = [0 1 0 1 0 1];

for i = 1:N
    if any(isnan(C(i,:))) || any(isnan(L(i,:))), continue; end

    % --- Redundant positions in INDEX order: colour occurs >=2 in the array
    ci = C(i,:);
    [vals,~,ic] = unique(ci(:));                 % column map
    counts      = accumarray(ic, 1, [numel(vals), 1]);
    isDup_idx   = reshape(counts(ic) >= 2, 1, K); % 1x6 logical

    % --- Ring order (per trial): sort angles (CW vs CCW immaterial)
    Li = mod(L(i,:), 360);
    [~, ord] = sort(Li, 'ascend');               % ring order indices
    r = isDup_idx(ord);                           % 1x6 logical in ring order
    v = double(r);                                % 1=R, 0=NR
    nR = sum(r);
    nR_adjR(i) = nR;

    % --- Grouped iff ALL R's form ONE contiguous block around the ring ---
    % i.e., there exists a start s such that r(s:s+nR-1) are all 1 (with wrap)
    grouped = false;
    if nR >= 2
        for s = 1:K
            allAdj = true;
            for j = 0:nR-1
                if ~r( mod(s-1+j, K) + 1 )
                    allAdj = false; break;
                end
            end
            if allAdj
                grouped = true; break;
            end
        end
    end

    if grouped
        Grouping_adjRblock(i)   = "Grouped";
        SeparatePattern_adjR(i) = "Grouped";   % by definition
    else
        Grouping_adjRblock(i) = "Separated";
        % Even only makes sense when nR == K/2 (for K=6, that's 3)
        if (nR == K/2) && (isequal(v, alt1) || isequal(v, alt2))
            SeparatePattern_adjR(i) = "Even";
        else
            SeparatePattern_adjR(i) = "Uneven";
        end
    end

    % Human-readable mask string in ring order
    labs = strings(1,K); labs(:) = "NR"; labs(r) = "R";
    RMask_adjR(i) = strjoin(labs, ",");
end

% -------- Attach to table --------
dataAll.Grouping_adjRblock    = categorical(Grouping_adjRblock, ["Grouped","Separated","Unverifiable"]);
dataAll.SeparatePattern_adjR  = categorical(SeparatePattern_adjR, ["Grouped","Even","Uneven","Unknown"]);
dataAll.RMask_adjR            = RMask_adjR;
dataAll.nR_adjR               = nR_adjR;

% -------- Quick summaries --------
disp("== Strict grouping (all R adjacent) counts ==");
disp(groupcounts(dataAll, "Grouping_adjRblock"));

disp("== Split of SEPARATED trials (Even vs Uneven) ==");
disp(groupcounts(dataAll(dataAll.Grouping_adjRblock=="Separated", :), "SeparatePattern_adjR"));

% -------- Manual spot-check helpers (optional) --------
% Show a few separated-even and separated-uneven examples:
idxEven   = find(dataAll.Grouping_adjRblock=="Separated" & dataAll.SeparatePattern_adjR=="Even");
idxUneven = find(dataAll.Grouping_adjRblock=="Separated" & dataAll.SeparatePattern_adjR=="Uneven");
if ~isempty(idxEven)
    fprintf('Example SEPARATED-EVEN (trial %d): RMask=%s\n', idxEven(1), dataAll.RMask_adjR(idxEven(1)));
end
if ~isempty(idxUneven)
    fprintf('Example SEPARATED-UNEVEN (trial %d): RMask=%s\n', idxUneven(1), dataAll.RMask_adjR(idxUneven(1)));
end

%% Exact combinatorics for N=6, R=3
N = 6; R = 3;
subs = nchoosek(1:N, R);                  % all 3-of-6 subsets
isBlock = false(size(subs,1),1);          % all R adjacent?
isEven  = false(size(subs,1),1);          % alternating pattern?

for i = 1:size(subs,1)
    S = zeros(1,N); S(subs(i,:)) = 1;     % 1=R, 0=NR (index order)
    % all-R contiguous (with wrap)
    blk = false;
    for s = 1:N
        ok = true;
        for j = 0:R-1
            if ~S(mod(s-1+j,N)+1), ok = false; break; end
        end
        if ok, blk = true; break; end
    end
    isBlock(i) = blk;
    isEven(i)  = isequal(S, [1 0 1 0 1 0]) || isequal(S, [0 1 0 1 0 1]);
end

p_block      = mean(isBlock);                 % = 6/20 = 0.30
p_even_all   = mean(isEven);                  % = 2/20 = 0.10
p_even_sep   = sum(isEven & ~isBlock) / sum(~isBlock);   % = 2/14 ≈ 0.142857

fprintf('Exact: P(Grouped)=%.2f, P(Even overall)=%.2f, P(Even|Separated)=%.5f\n', ...
        p_block, p_even_all, p_even_sep);

%% Dataset check: restrict to trials with exactly R=3 redundant items (by geometry)
% (If your design always has R=3, this will be all trials.)
has3 = (dataAll.nR_adjR == 3);   % created by the previous block
sep  = (dataAll.Grouping_adjRblock == "Separated") & has3;
even = (dataAll.SeparatePattern_adjR == "Even") & has3;

n_sep  = sum(sep);
k_even = sum(even & sep);
p_hat  = k_even / max(1,n_sep);

fprintf('Observed: Even among Separated = %d / %d = %.5f\n', k_even, n_sep, p_hat);

% 95% binomial CI for p_hat
if exist('binofit','file') == 2
    [~, ci] = binofit(k_even, n_sep, 0.05);
    fprintf('95%% CI: [%.5f, %.5f] ; expected %.5f\n', ci(1), ci(2), p_even_sep);
else
    % Wald approx if Statistics Toolbox not available
    p0 = p_hat; se = sqrt(p0*(1-p0)/max(1,n_sep));
    ci = [p_hat - 1.96*se, p_hat + 1.96*se];
    fprintf('95%% Wald CI: [%.5f, %.5f] ; expected %.5f\n', ci(1), ci(2), p_even_sep);
end

%% ------------ Figure: per-participant ridgeline histograms -------------
% --- DURATIONS: convert to milliseconds for plotting (50..350 evenly spaced)
rawPD = double(dataAll.PresDur);
if max(rawPD) <= 10        % your PresDur is likely in seconds (0.05..0.35)
    pd_ms_each = round(1000*rawPD);
else                       % already milliseconds
    pd_ms_each = round(rawPD);
end
pd_ms = unique(pd_ms_each);               % e.g., [50 100 150 200 250 300 350]
pd_ms = sort(pd_ms);

% --- PARTICIPANTS: take the 4 in your current dataframe
IDs4 = string(categories(categorical(dataAll.ID)));
IDs4 = IDs4(1:min(4, numel(IDs4)));

% --- ERRORS & BINS: 1° bins, raw counts
xAll  = double(dataAll.Precision);        % signed error (−180..180)
edges = -180:1:180;

% --- COLORS
colNR = [0     0.4470 0.7410];
colR  = [0.850 0.3250 0.0980];
alphaFill = 0.35;

% Compact vertical packing: tallest bar uses ~90% of the gap between durations
gap         = (numel(pd_ms)>=2)*min(diff(pd_ms)) + (numel(pd_ms)<2)*50;
fillFrac    = 0.90;
targetHt    = fillFrac * gap;

% Global max count for a single vertical scale across all panels/durations/cues
maxCnt = 1;
for ii = 1:numel(IDs4)
    id   = IDs4(ii);
    selI = strcmp(string(dataAll.ID), id);
    for dms = pd_ms(:)'
        selD = (pd_ms_each == dms) & selI;
        for cue = ["R","NR"]
            x = xAll(selD & strcmp(string(dataAll.CueType), cue));
            if ~isempty(x)
                cnt = histcounts(x, edges, 'Normalization','count');
                if ~isempty(cnt), maxCnt = max(maxCnt, max(cnt)); end
            end
        end
    end
end
bandScale = targetHt / maxCnt;   % ms per count

% Figure
figure('Color','w','Units','normalized','Position',[0.02 0.08 0.96 0.84]);
tlo = tiledlayout(1, numel(IDs4), 'TileSpacing','compact','Padding','compact');
title(tlo, 'Error histograms (1° bins, raw counts) by encoding duration, per participant');

hNR = []; hR = [];

for ii = 1:numel(IDs4)
    ax = nexttile; hold(ax,'on');
    id = IDs4(ii);

    selI     = strcmp(string(dataAll.ID), id);
    thisX    = xAll(selI);
    thisD_ms = pd_ms_each(selI);
    thisCue  = string(dataAll.CueType(selI));

    for dms = pd_ms(:)'
        atD = (thisD_ms == dms);

        % duration baseline
        plot(ax, [-180 180], [dms dms], '-', 'Color', 0.9*[1 1 1], 'LineWidth', 1);

        % NR (blue) — upward bars: y1 = dms - (bandScale * count) because YDir='reverse'
        x = thisX(atD & thisCue=="NR");
        if ~isempty(x)
            cnt = histcounts(x, edges, 'Normalization','count');
            for bi = 1:numel(cnt)
                c = cnt(bi); if c==0, continue; end
                xL = edges(bi); xR = edges(bi+1);
                y0 = dms; y1 = dms - bandScale*c;   % upward on screen
                patch('XData',[xL xR xR xL], 'YData',[y0 y0 y1 y1], ...
                      'FaceColor',colNR, 'EdgeColor','none', 'FaceAlpha',alphaFill, 'Parent',ax);
            end
            if isempty(hNR), hNR = plot(ax,nan,nan,'s','MarkerFaceColor',colNR,'MarkerEdgeColor','none'); end
        end

        % R (red) overlaid at same baseline
        x = thisX(atD & thisCue=="R");
        if ~isempty(x)
            cnt = histcounts(x, edges, 'Normalization','count');
            for bi = 1:numel(cnt)
                c = cnt(bi); if c==0, continue; end
                xL = edges(bi); xR = edges(bi+1);
                y0 = dms; y1 = dms - bandScale*c;
                patch('XData',[xL xR xR xL], 'YData',[y0 y0 y1 y1], ...
                      'FaceColor',colR, 'EdgeColor','none', 'FaceAlpha',alphaFill, 'Parent',ax);
            end
            if isempty(hR), hR = plot(ax,nan,nan,'s','MarkerFaceColor',colR,'MarkerEdgeColor','none'); end
        end
    end

    % Axis: leave room above 50 ms so top bars aren’t clipped
    topPad   = max(2, targetHt*0.05);
    yminPlot = min(pd_ms) - targetHt - topPad;   % smaller number = higher on screen
    ymaxPlot = max(pd_ms) + targetHt*0.05;

    xlim(ax, [-180 180]);
    ylim(ax, [yminPlot, ymaxPlot]);
    set(ax, 'YDir','reverse');                   % 50 ms at top, 350 ms at bottom
    yticks(ax, pd_ms);
    yticklabels(ax, strcat(string(pd_ms), " ms"));
    xlabel(ax, 'Error (deg, signed)');
    if ii==1, ylabel(ax, 'Encoding duration'); end
    title(ax, "ID " + id);
    grid(ax,'on'); box(ax,'on');
end

legend([hNR hR], {'NR (counts, 1° bins)', 'R (counts, 1° bins)'}, ...
       'Location','southoutside','Orientation','horizontal','Box','off');


%% Figure 2-------- Ridgeline HISTOGRAMS for RT (raw counts), 1x4 panels ----------
% Needs: dataAll.ID, dataAll.PresDur, dataAll.ResponseTime, dataAll.CueType

% --- Ensure durations in ms for the Y axis (50..350 evenly spaced) ---
if ~exist('pd_ms_each','var') || ~exist('pd_ms','var')
    rawPD = double(dataAll.PresDur);
    if max(rawPD) <= 10        % seconds (0.05..0.35)
        pd_ms_each = round(1000*rawPD);
    else                       % already ms
        pd_ms_each = round(rawPD);
    end
    pd_ms = unique(pd_ms_each); pd_ms = sort(pd_ms);
end

% --- Pick the 4 participants available (or first 4) ---
IDs4 = string(categories(categorical(dataAll.ID)));
IDs4 = IDs4(1:min(4, numel(IDs4)));

% --- RT data & 50 ms bins (change binMS if you prefer 25/100 etc.) ---
rtAll  = double(dataAll.ResponseTime);       % already filtered to <= 2500 earlier
binMS  = 25;                                 % <-- tweak here
rtMax  = max(rtAll);
rtMaxB = max(binMS, ceil(rtMax/binMS)*binMS);
rtEdges = 0:binMS:rtMaxB;

% --- Colors & transparency ---
colNR = [0     0.4470 0.7410];
colR  = [0.850 0.3250 0.0980];
alphaFill = 0.35;

% --- Vertical packing: tallest bar ~90% of the gap between durations ---
gap         = (numel(pd_ms)>=2)*min(diff(pd_ms)) + (numel(pd_ms)<2)*50;
fillFrac    = 0.90;
targetHt    = fillFrac * gap;

% --- Global max count for single shared vertical scale ---
maxCnt = 1;
for ii = 1:numel(IDs4)
    id   = IDs4(ii);
    selI = strcmp(string(dataAll.ID), id);
    for dms = pd_ms(:)'
        selD = (pd_ms_each == dms) & selI;
        for cue = ["R","NR"]
            x = rtAll(selD & strcmp(string(dataAll.CueType), cue));
            if ~isempty(x)
                cnt = histcounts(x, rtEdges, 'Normalization','count');
                if ~isempty(cnt), maxCnt = max(maxCnt, max(cnt)); end
            end
        end
    end
end
bandScale = targetHt / maxCnt;   % ms of vertical height per count

% --- Figure (1x4) ---
figure('Color','w','Units','normalized','Position',[0.02 0.08 0.96 0.84]);
tlo = tiledlayout(1, numel(IDs4), 'TileSpacing','compact','Padding','compact');
title(tlo, 'RT histograms (raw counts) by encoding duration (R overlaid with NR), per participant');

hNR = []; hR = [];

for ii = 1:numel(IDs4)
    ax = nexttile; hold(ax,'on');
    id = IDs4(ii);

    selI    = strcmp(string(dataAll.ID), id);
    thisRT  = rtAll(selI);
    thisDms = pd_ms_each(selI);
    thisCue = string(dataAll.CueType(selI));

    for dms = pd_ms(:)'
        atD = (thisDms == dms);

        % baseline at this duration
        plot(ax, [0 rtEdges(end)], [dms dms], '-', 'Color', 0.9*[1 1 1], 'LineWidth', 1);

        % ---- NR (blue), upward bars (YDir will be 'reverse') ----
        x = thisRT(atD & thisCue=="NR");
        if ~isempty(x)
            cnt = histcounts(x, rtEdges, 'Normalization','count');
            for bi = 1:numel(cnt)
                c = cnt(bi); if c==0, continue; end
                xL = rtEdges(bi); xR = rtEdges(bi+1);
                y0 = dms; y1 = dms - bandScale*c;   % upward on screen
                patch('XData',[xL xR xR xL], 'YData',[y0 y0 y1 y1], ...
                      'FaceColor',colNR, 'EdgeColor','none', 'FaceAlpha',alphaFill, 'Parent',ax);
            end
            if isempty(hNR)
                hNR = plot(ax, nan, nan, 's', 'MarkerFaceColor', colNR, 'MarkerEdgeColor','none');
            end
        end

        % ---- R (red), same baseline (overlay) ----
        x = thisRT(atD & thisCue=="R");
        if ~isempty(x)
            cnt = histcounts(x, rtEdges, 'Normalization','count');
            for bi = 1:numel(cnt)
                c = cnt(bi); if c==0, continue; end
                xL = rtEdges(bi); xR = rtEdges(bi+1);
                y0 = dms; y1 = dms - bandScale*c;   % upward on screen
                patch('XData',[xL xR xR xL], 'YData',[y0 y0 y1 y1], ...
                      'FaceColor',colR, 'EdgeColor','none', 'FaceAlpha',alphaFill, 'Parent',ax);
            end
            if isempty(hR)
                hR = plot(ax, nan, nan, 's', 'MarkerFaceColor', colR, 'MarkerEdgeColor','none');
            end
        end
    end

    % --- Axes & labels (leave room above top duration so bars don't clip) ---
    topPad   = max(2, targetHt*0.05);
    yminPlot = min(pd_ms) - targetHt - topPad;  % smaller number = higher on screen
    ymaxPlot = max(pd_ms) + targetHt*0.05;

    xlim(ax, [0 rtEdges(end)]);
    ylim(ax, [yminPlot, ymaxPlot]);
    set(ax, 'YDir','reverse');                  % 50 ms at top → 350 ms at bottom
    yticks(ax, pd_ms);
    yticklabels(ax, strcat(string(pd_ms), " ms"));
    xlabel(ax, 'RT (ms)');
    if ii==1, ylabel(ax, 'Encoding duration'); end
    title(ax, "ID " + id);
    grid(ax,'on'); box(ax,'on');
end

legend([hNR hR], {'NR (counts)', 'R (counts)'}, ...
       'Location','southoutside','Orientation','horizontal','Box','off');

%% ================= Fig 3: Circular SD (deg) by duration × pattern × cue =================
% Needs in dataAll:
%   ID, PresDur, Precision (deg, -180..180), CueType (R/NR or synonyms),
%   SeparatePattern_adjR (Grouped/Even/Uneven from your strict rule block)

% --- Durations to ms for x-axis ---
rawPD = double(dataAll.PresDur);
if max(rawPD) <= 10
    pd_ms_each = round(1000*rawPD);
else
    pd_ms_each = round(rawPD);
end
pd_ms = unique(pd_ms_each); pd_ms = sort(pd_ms);
nDur  = numel(pd_ms);

% --- Participants (first 4) ---
IDs4 = string(categories(categorical(dataAll.ID)));
IDs4 = IDs4(1:min(4, numel(IDs4)));

% --- Patterns & cues ---
PAT = ["Grouped","Even","Uneven"];   nPat = numel(PAT);
CUE = ["R","NR"];                    nCue = numel(CUE);

% --- Colors & markers (by pattern); cue shown via line style & fill ---
colPAT = [ 0.8500 0.3250 0.0980;   % Grouped (red-ish)
           0.4940 0.1840 0.5560;   % Even (purple)
           0.0000 0.4470 0.7410 ]; % Uneven (blue)
mkPAT  = {'o','^','s'};
patOff = [-0.18, 0, +0.18];         % jitter per pattern
cueOff = [-0.05, +0.05];            % tiny jitter: R then NR

% --- Normalize CueType to "R"/"NR" strings safely ---
cueAll = upper(string(dataAll.CueType));
cueAll = regexprep(cueAll, '^\s*REDUNDANT\s*$', 'R');
cueAll = regexprep(cueAll, '^\s*NON[-\s]?REDUNDANT\s*$', 'NR');
cueAll(~ismember(cueAll, ["R","NR"])) = missing;

% --- Pull arrays we’ll subset repeatedly ---
idAll   = string(dataAll.ID);
patAll  = string(dataAll.SeparatePattern_adjR);  % 'Grouped','Even','Uneven','Unknown'
errAll  = double(dataAll.Precision);             % signed deg
durAll  = pd_ms_each;

% --- Bootstrap params ---
if ~exist('nBoot','var'), nBoot = 2000; end
alpha = 0.05; q = [100*(alpha/2), 100*(1-alpha/2)];

% --- Circular SD (deg) helper ---
circSDdeg = @(ang_deg) ...
    (180/pi) * sqrt(max(0, -2*log( max(eps, hypot(mean(cosd(ang_deg)), mean(sind(ang_deg)))) )));

% --- Preallocate: [dur × pattern × cue × participant] ---
CS   = nan(nDur, nPat, nCue, numel(IDs4));
CIlo = nan(nDur, nPat, nCue, numel(IDs4));
CIhi = nan(nDur, nPat, nCue, numel(IDs4));

% --- Compute CSD + 95% CI per cell ---
for pi = 1:numel(IDs4)
    selID = (idAll == IDs4(pi));
    for di = 1:nDur
        dms = pd_ms(di);
        selDur = selID & (durAll == dms);
        for pj = 1:nPat
            selPat = selDur & (patAll == PAT(pj));
            for cj = 1:nCue
                sel = selPat & (cueAll == CUE(cj));
                x = errAll(sel);
                x = x(~isnan(x));
                if numel(x) < 2
                    continue
                end
                % point estimate
                y = circSDdeg(x);
                CS(di,pj,cj,pi) = y;
                % bootstrap CI
                if exist('bootstrp','file') == 2
                    bs = bootstrp(nBoot, circSDdeg, x);
                else
                    n = numel(x); bs = nan(nBoot,1);
                    for b = 1:nBoot
                        idx = randi(n, n, 1);
                        bs(b) = circSDdeg(x(idx));
                    end
                end
                pr = prctile(bs, q);
                CIlo(di,pj,cj,pi) = pr(1);
                CIhi(di,pj,cj,pi) = pr(2);
            end
        end
    end
end

% --- Plot (2×2 panels) ---
fig = figure('Color','w','Units','normalized','Position',[0.05 0.06 0.88 0.86]);
tlo = tiledlayout(2, 2, 'TileSpacing','compact','Padding','compact');
title(tlo, 'Circular SD of error (deg) by duration, grouping pattern, and cue (95% CI)');

x0 = 1:nDur;
hLegend = gobjects(nPat, nCue);  % for combined legend

for pi = 1:numel(IDs4)
    ax = nexttile; hold(ax, 'on');

    for pj = 1:nPat
        for cj = 1:nCue
            xp = x0 + patOff(pj) + cueOff(cj);
            y   = CS(:,pj,cj,pi);
            lo  = CIlo(:,pj,cj,pi);
            hi  = CIhi(:,pj,cj,pi);
            good = ~(isnan(y) | isnan(lo) | isnan(hi));
            if ~any(good)
                % placeholder for legend if nothing in this panel for that series
                hLegend(pj,cj) = plot(ax, NaN, NaN, '-', 'Color', colPAT(pj,:));
                continue
            end

            % cue styling
            isR = (CUE(cj)=="R");
            ls  = '-'; if ~isR, ls = '--'; end
            mfc = colPAT(pj,:); if ~isR, mfc = 'none'; end

            % error bars
            dyLo = y - lo; dyHi = hi - y;
            hLegend(pj,cj) = errorbar(ax, xp(good), y(good), dyLo(good), dyHi(good), ...
                'LineStyle', ls, 'LineWidth', 1.5, 'Color', colPAT(pj,:), ...
                'Marker', mkPAT{pj}, 'MarkerSize', 5, ...
                'MarkerFaceColor', mfc, 'MarkerEdgeColor', colPAT(pj,:), ...
                'CapSize', 0, 'DisplayName', sprintf('%s – %s', PAT(pj), CUE(cj)));
        end
    end

    % axes
    xlim(ax, [0.5, nDur+0.5]);
    xticks(ax, x0); xticklabels(ax, string(pd_ms) + " ms");
    ymax = min(180, max( 5, ceil(nanmax(CIhi(:))*1.05) ));
    ylim(ax, [0, ymax]);
    ylabel(ax, 'Circular SD (deg)'); xlabel(ax, 'Encoding duration');
    grid(ax, 'on'); box(ax, 'on');
    title(ax, "ID " + IDs4(pi));
end

% Single combined legend (6 entries: Grouped/Even/Uneven × R/NR)
lg.Title.String = 'Pattern × Cue';

%% ===================== Figure 4: RT CDFs by duration × pattern × cue =====================
% Needs in dataAll:
%   ID, PresDur, ResponseTime, CueType, SeparatePattern_adjR ('Grouped','Even','Uneven')

% --- Durations to ms for the Y-axis (bands) ---
rawPD = double(dataAll.PresDur);
if max(rawPD) <= 10
    pd_ms_each = round(1000*rawPD);
else
    pd_ms_each = round(rawPD);
end
pd_ms = unique(pd_ms_each); pd_ms = sort(pd_ms);
nDur  = numel(pd_ms);

% --- Participants (first 4) ---
IDs4 = string(categories(categorical(dataAll.ID)));
IDs4 = IDs4(1:min(4, numel(IDs4)));

% --- Normalise CueType to "R"/"NR" ---
cueAll = upper(string(dataAll.CueType));
cueAll = regexprep(cueAll, '^\s*REDUNDANT\s*$', 'R');
cueAll = regexprep(cueAll, '^\s*NON[-\s]?REDUNDANT\s*$', 'NR');
cueAll(~ismember(cueAll, ["R","NR"])) = missing;

% --- Patterns & styling ---
PAT   = ["Grouped","Even","Uneven"];     % line style per pattern
CUE   = ["R","NR"];                      % color per cue
lsPAT = {'-','--',':'};                  % Grouped, Even, Uneven
colCue = [ 0.8500 0.3250 0.0980;         % R (reddish)
           0.0000 0.4470 0.7410 ];       % NR (bluish)

% --- Data arrays ---
idAll   = string(dataAll.ID);
patAll  = string(dataAll.SeparatePattern_adjR);   % 'Grouped','Even','Uneven','Unknown'
rtAll   = double(dataAll.ResponseTime);           % ms (already filtered <= 2500 earlier)
durAll  = pd_ms_each;

% --- CDF helper (no toolbox needed) ---
ecdf_xy = @(x) deal(sort(x(:)), (1:numel(x)).'/numel(x));  % returns xx, F(xx)

% --- X (RT) range shared across panels ---
binMS  = 25;
rtMax  = max(rtAll(~isnan(rtAll)));
rtMaxB = max(binMS, ceil(rtMax/binMS)*binMS);

% --- Vertical packing (band height per duration) ---
gap       = (nDur>=2)*min(diff(pd_ms)) + (nDur<2)*50;
fillFrac  = 0.90;                % each CDF band fills ~90% of the gap
targetHt  = fillFrac * gap;      % ms of vertical band height for F=1
bandScale = targetHt / 1.0;      % since CDF goes 0..1

% --- Figure: 2×2 panels (participants) ---
fig = figure('Color','w','Units','normalized','Position',[0.04 0.06 0.92 0.86]);
tlo = tiledlayout(2, 2, 'TileSpacing','compact','Padding','compact');
title(tlo, 'RT CDFs by encoding duration, grouping pattern (line style), and cue (color)');

% legend handles (6 combos, created once on first panel)
hLegend = gobjects(numel(PAT), numel(CUE));
legendMade = false;

for pi = 1:numel(IDs4)
    ax = nexttile; hold(ax,'on');

    selID = (idAll == IDs4(pi));
    thisRT   = rtAll(selID);
    thisDur  = durAll(selID);
    thisPat  = patAll(selID);
    thisCue  = cueAll(selID);

    % Baselines for each duration
    for di = 1:nDur
        dms = pd_ms(di);
        plot(ax, [0 rtMaxB], [dms dms], '-', 'Color', 0.9*[1 1 1], 'LineWidth', 1);
    end

    % Draw CDF curves per duration × pattern × cue
    for di = 1:nDur
        dms = pd_ms(di);
        atD = (thisDur == dms);

        for pj = 1:numel(PAT)
            atP = atD & (thisPat == PAT(pj));

            for cj = 1:numel(CUE)
                atC = atP & (thisCue == CUE(cj));
                x = thisRT(atC);
                x = x(~isnan(x));
                if numel(x) < 1, continue; end

                [xx, Fy] = ecdf_xy(x);                 % xx in ms, Fy in 0..1
                yPlot = dms - bandScale * Fy;          % upward from baseline (YDir='reverse')
                hp = plot(ax, xx, yPlot, ...
                    'LineStyle', lsPAT{pj}, ...
                    'LineWidth', 1.3, ...
                    'Color', colCue(cj,:), ...
                    'HitTest','off');

                % create a single handle per (pattern,cue) for legend on first panel
                if ~legendMade && ~isempty(hp) && isgraphics(hp)
                    hLegend(pj, cj) = plot(ax, NaN, NaN, ...
                        'LineStyle', lsPAT{pj}, 'LineWidth', 1.6, ...
                        'Color', colCue(cj,:), ...
                        'DisplayName', sprintf('%s – %s', PAT(pj), CUE(cj)));
                end
            end
        end
    end
    legendMade = true;

    % Axes cosmetics
    set(ax, 'YDir','reverse');                         % 50 ms at top → 350 ms at bottom
    topPad   = max(2, targetHt*0.05);
    yminPlot = min(pd_ms) - targetHt - topPad;
    ymaxPlot = max(pd_ms) + targetHt*0.05;

    xlim(ax, [0, rtMaxB]);
    ylim(ax, [yminPlot, ymaxPlot]);
    yticks(ax, pd_ms); yticklabels(ax, string(pd_ms) + " ms");
    xlabel(ax, 'RT (ms)');
    if pi==1 || pi==3, ylabel(ax, 'Encoding duration'); end
    title(ax, "ID " + IDs4(pi));
    grid(ax,'on'); box(ax,'on');
end

% --------- Combined legend spanning the tiled layout (fix for your error) ---------
% Use an axes handle (e.g., the last one) and then dock legend under the layout.
axForLegend = ax;  % 'ax' from the loop is the last tile's axes
valid = isgraphics(hLegend);
hUse  = hLegend(valid);
% Build labels from DisplayName
lbls = arrayfun(@(h) string(get(h,'DisplayName')), hUse, 'UniformOutput', false);

lg = legend(axForLegend, hUse, lbls, ...
    'NumColumns', 3, 'Orientation','horizontal', 'Box','off');
lg.Layout.Tile = 'south';   % place legend below the tiles

%% ===================== Figure 4B (Cue only): RT CDFs by duration × cue =====================
% Needs in dataAll:
%   ID, PresDur, ResponseTime, CueType
% Outputs: 2x2 panels (participants); per-duration ridgeline CDFs, color = cue (R/NR)

% --- Durations to ms for Y-axis bands ---
rawPD = double(dataAll.PresDur);
if max(rawPD) <= 10
    pd_ms_each = round(1000*rawPD);
else
    pd_ms_each = round(rawPD);
end
pd_ms = unique(pd_ms_each); pd_ms = sort(pd_ms);
nDur  = numel(pd_ms);

% --- Participants (first 4) ---
IDs4 = string(categories(categorical(dataAll.ID)));
IDs4 = IDs4(1:min(4, numel(IDs4)));

% --- Normalise CueType to "R"/"NR" ---
cueAll = upper(string(dataAll.CueType));
cueAll = regexprep(cueAll, '^\s*REDUNDANT\s*$', 'R');
cueAll = regexprep(cueAll, '^\s*NON[-\s]?REDUNDANT\s*$', 'NR');
cueAll(~ismember(cueAll, ["R","NR"])) = missing;

% --- Data arrays ---
idAll  = string(dataAll.ID);
rtAll  = double(dataAll.ResponseTime);   % ms (already cleaned <= 2500 earlier)
durAll = pd_ms_each;

% --- Styles (color = cue) ---
CUE    = ["R","NR"];
colCue = [ 0.8500 0.3250 0.0980;    % R (reddish)
           0.0000 0.4470 0.7410 ];  % NR (bluish)

% --- ECDF helper (toolbox-free) ---
ecdf_xy = @(x) deal(sort(x(:)), (1:numel(x)).'/numel(x));  % returns xx, F(xx)

% --- Shared RT axis range ---
binMS  = 25;
rtMax  = max(rtAll(~isnan(rtAll)));
rtMaxB = max(binMS, ceil(rtMax/binMS)*binMS);

% --- Vertical packing for ridgelines ---
gap       = (nDur>=2)*min(diff(pd_ms)) + (nDur<2)*50;
fillFrac  = 0.90;                 % each CDF band fills ~90% of the gap
targetHt  = fillFrac * gap;       % vertical height for F=1
bandScale = targetHt / 1.0;       % CDF is 0..1

% --- Figure & layout ---
fig = figure('Color','w','Units','normalized','Position',[0.04 0.06 0.92 0.86]);
tlo = tiledlayout(2, 2, 'TileSpacing','compact','Padding','compact');
title(tlo, 'RT CDFs by encoding duration (bands) and cue (color)');

axs = gobjects(numel(IDs4),1);   % store axes for legend anchoring

for pi = 1:numel(IDs4)
    ax = nexttile; axs(pi)=ax; hold(ax,'on');

    selID   = (idAll == IDs4(pi));
    thisRT  = rtAll(selID);
    thisDur = durAll(selID);
    thisCue = cueAll(selID);

    % Baselines (one per duration)
    for di = 1:nDur
        dms = pd_ms(di);
        plot(ax, [0 rtMaxB], [dms dms], '-', 'Color', 0.9*[1 1 1], 'LineWidth', 1);
    end

    % CDF curves per duration × cue
    for di = 1:nDur
        dms = pd_ms(di);
        atD = (thisDur == dms);

        for cj = 1:numel(CUE)
            atC = atD & (thisCue == CUE(cj));
            x = thisRT(atC);
            x = x(~isnan(x));
            if isempty(x), continue; end

            [xx, Fy] = ecdf_xy(x);           % xx in ms, Fy in 0..1
            yPlot = dms - bandScale * Fy;    % upward from baseline (YDir='reverse')
            plot(ax, xx, yPlot, ...
                'LineStyle', '-', 'LineWidth', 1.4, ...
                'Color', colCue(cj,:), 'HitTest','off');
        end
    end

    % Axes cosmetics
    set(ax, 'YDir','reverse');                       % 50 ms at top → 350 ms at bottom
    topPad   = max(2, targetHt*0.05);
    yminPlot = min(pd_ms) - targetHt - topPad;
    ymaxPlot = max(pd_ms) + targetHt*0.05;

    xlim(ax, [0, rtMaxB]);
    ylim(ax, [yminPlot, ymaxPlot]);
    yticks(ax, pd_ms); yticklabels(ax, string(pd_ms) + " ms");
    xlabel(ax, 'RT (ms)');
    if pi==1 || pi==3, ylabel(ax, 'Encoding duration'); end
    title(ax, "ID " + IDs4(pi));
    grid(ax,'on'); box(ax,'on');
end

% --- Legend (attach to an axes, then dock under layout) ---
axForLegend = axs(find(isgraphics(axs),1,'last'));  % pick the last valid axes
hold(axForLegend,'on');
hR  = plot(axForLegend, nan, nan, '-', 'LineWidth',1.6, 'Color', colCue(1,:), 'DisplayName','R');
hNR = plot(axForLegend, nan, nan, '-', 'LineWidth',1.6, 'Color', colCue(2,:), 'DisplayName','NR');
lg = legend(axForLegend, [hR hNR], 'Orientation','horizontal', 'Box','off', 'NumColumns', 2);
lg.Layout.Tile = 'south';   % place legend under the tiles

%% ===================== Figure 5: Circular SD by duration × cue (R vs NR) =====================
% Needs in dataAll:
%   ID, PresDur, Precision (deg, -180..180), CueType (R/NR or synonyms)

% --- Durations to ms for x-axis ---
rawPD = double(dataAll.PresDur);
if max(rawPD) <= 10
    pd_ms_each = round(1000*rawPD);
else
    pd_ms_each = round(rawPD);
end
pd_ms = unique(pd_ms_each); pd_ms = sort(pd_ms);
nDur  = numel(pd_ms);

% --- Participants (first 4) ---
IDs4 = string(categories(categorical(dataAll.ID)));
IDs4 = IDs4(1:min(4, numel(IDs4)));

% --- Normalise CueType to "R"/"NR" ---
cueAll = upper(string(dataAll.CueType));
cueAll = regexprep(cueAll, '^\s*REDUNDANT\s*$', 'R');
cueAll = regexprep(cueAll, '^\s*NON[-\s]?REDUNDANT\s*$', 'NR');
cueAll(~ismember(cueAll, ["R","NR"])) = missing;

% --- Data we subset repeatedly ---
idAll   = string(dataAll.ID);
errAll  = double(dataAll.Precision);   % signed angular errors (deg)
durAll  = pd_ms_each;

% --- Bootstrap params ---
if ~exist('nBoot','var'), nBoot = 2000; end
alpha = 0.05; q = [100*(alpha/2), 100*(1-alpha/2)];

% --- Circular SD (deg) helper (same formula as before) ---
circSDdeg = @(ang_deg) ...
    (180/pi) * sqrt(max(0, -2*log( max(eps, hypot(mean(cosd(ang_deg)), mean(sind(ang_deg)))) )));

% --- Preallocate: [dur × cue × participant] ---
CUE  = ["R","NR"]; nCue = numel(CUE);
CS   = nan(nDur, nCue, numel(IDs4));   % point estimate
CIlo = nan(nDur, nCue, numel(IDs4));   % lower 95%
CIhi = nan(nDur, nCue, numel(IDs4));   % upper 95%

% --- Compute CSD + 95% CI per cell (pooling across patterns) ---
for pi = 1:numel(IDs4)
    selID = (idAll == IDs4(pi));
    for di = 1:nDur
        dms    = pd_ms(di);
        selDur = selID & (durAll == dms);
        for cj = 1:nCue
            sel = selDur & (cueAll == CUE(cj));
            x = errAll(sel);
            x = x(~isnan(x));
            if numel(x) < 2
                continue
            end
            % point estimate
            y = circSDdeg(x);
            CS(di,cj,pi) = y;

            % bootstrap CI
            if exist('bootstrp','file') == 2
                bs = bootstrp(nBoot, circSDdeg, x);
            else
                n = numel(x); bs = nan(nBoot,1);
                for b = 1:nBoot
                    idx = randi(n, n, 1);
                    bs(b) = circSDdeg(x(idx));
                end
            end
            pr = prctile(bs, q);
            CIlo(di,cj,pi) = pr(1);
            CIhi(di,cj,pi) = pr(2);
        end
    end
end

% --- Plot: 2×2 panels, R vs NR with error bars ---
fig = figure('Color','w','Units','normalized','Position',[0.06 0.08 0.86 0.80]);
tlo = tiledlayout(2, 2, 'TileSpacing','compact','Padding','compact');
title(tlo, 'Circular SD of error (deg) by encoding duration and cue (95% CI)');

x0      = 1:nDur;
cueOff  = [-0.06, +0.06];                 % small jitter so bars/markers don’t overlap
colCue  = [ 0.8500 0.3250 0.0980;         % R (reddish)
            0.0000 0.4470 0.7410 ];       % NR (bluish)
mkCue   = {'o','s'};
lsCue   = {'-','--'};

axs = gobjects(numel(IDs4),1);

for pi = 1:numel(IDs4)
    ax = nexttile; axs(pi)=ax; hold(ax,'on');

    h = gobjects(nCue,1);
    for cj = 1:nCue
        xp  = x0 + cueOff(cj);
        y   = CS(:,cj,pi);
        lo  = CIlo(:,cj,pi);
        hi  = CIhi(:,cj,pi);
        good = ~(isnan(y) | isnan(lo) | isnan(hi));
        dyLo = y - lo; dyHi = hi - y;

        if any(good)
            h(cj) = errorbar(ax, xp(good), y(good), dyLo(good), dyHi(good), ...
                'LineStyle', lsCue{cj}, 'LineWidth', 1.6, 'Color', colCue(cj,:), ...
                'Marker', mkCue{cj}, 'MarkerSize', 5, ...
                'MarkerFaceColor', colCue(cj,:), 'MarkerEdgeColor', colCue(cj,:), ...
                'CapSize', 0, 'DisplayName', string(CUE(cj)));
        else
            h(cj) = plot(ax, NaN, NaN, '-', 'Color', colCue(cj,:), 'DisplayName', string(CUE(cj)));
        end
    end

    xlim(ax, [0.5, nDur+0.5]);
    xticks(ax, x0); xticklabels(ax, string(pd_ms) + " ms");
    ylim(ax, [0, min(180, max(5, ceil(nanmax(CIhi(:))*1.05)))]);
    ylabel(ax, 'Circular SD (deg)'); xlabel(ax, 'Encoding duration');
    grid(ax,'on'); box(ax,'on'); title(ax, "ID " + IDs4(pi));

    if pi == numel(IDs4)
        lg = legend(ax, h, 'Location','southoutside', 'Orientation','horizontal', 'Box','off');
        lg.Layout.Tile = 'south';   % dock legend under the tiled layout
    end
end

%% ================= Within-person ANOVAs (RT trial-level; CSD cell-level) =================
% Factors:
%   Duration: 7 levels (ms)
%   Cue:      R vs NR
%   Pattern:  Grouped / Even / Uneven  (SeparatePattern_adjR)
%
% RT  -> trial-level ANOVA on log(RT)
% CSD -> cell-level (Duration×Cue×Pattern) weighted linear model on circular SD

% ---------- Prep common variables ----------
% Duration to ms
rawPD = double(dataAll.PresDur);
if max(rawPD) <= 10
    pd_ms_each = round(1000*rawPD);
else
    pd_ms_each = round(rawPD);
end
pd_ms = sort(unique(pd_ms_each));

% Normalize cue to "R"/"NR"
cueAll = upper(string(dataAll.CueType));
cueAll = regexprep(cueAll, '^\s*REDUNDANT\s*$', 'R');
cueAll = regexprep(cueAll, '^\s*NON[-\s]?REDUNDANT\s*$', 'NR');
cueAll(~ismember(cueAll,["R","NR"])) = missing;

% Pattern labels (strict rule you computed earlier)
patAll   = string(dataAll.SeparatePattern_adjR);
validPat = ismember(patAll, ["Grouped","Even","Uneven"]);

% Per-trial arrays
idAll  = string(dataAll.ID);
rtAll  = double(dataAll.ResponseTime);
errAll = double(dataAll.Precision);

% Circular SD helper (deg)
circSDdeg = @(ang_deg) ...
    (180/pi) * sqrt(max(0, -2*log( max(eps, hypot(mean(cosd(ang_deg)), mean(sind(ang_deg)))) )));

% Participants to analyze
IDs = string(categories(categorical(dataAll.ID)));

fprintf('\n=================== WITHIN-PERSON ANOVAS ===================\n');

for pi = 1:numel(IDs)
    pid = IDs(pi);
    fprintf('\n---- Participant %s ----\n', pid);

    %% ---------- A) RT: trial-level 3-way ANOVA on log RT ----------
    sel = (idAll==pid) & ~isnan(rtAll) & ~isnan(pd_ms_each) & ~ismissing(cueAll) & validPat;

    Trt = table;
    Trt.logRT    = log(rtAll(sel));
    Trt.Duration = categorical(pd_ms_each(sel), pd_ms, string(pd_ms)+" ms");
    Trt.Cue      = categorical(cueAll(sel), ["R","NR"]);
    Trt.Pattern  = categorical(patAll(sel), ["Grouped","Even","Uneven"]);

    if height(Trt) < 20
        warning('Too few RT trials for %s; skipping RT ANOVA.', pid);
    else
        if exist('anovan','file') ~= 2
            warning('ANOVAN unavailable; skipping RT ANOVA for %s.', pid);
        else
            % Type III SS via ANOVAN (handles imbalance)
            [pRT, tblRT] = anovan(Trt.logRT, {Trt.Duration, Trt.Cue, Trt.Pattern}, ...
                'model','full', 'varnames',{'Duration','Cue','Pattern'}, ...
                'sstype', 3, 'display','off');
            fprintf('RT (log) ANOVAN, p-values (Type III):\n');
            varNames = {'Duration','Cue','Pattern','Dur_x_Cue','Dur_x_Pat','Cue_x_Pat','Dur_x_Cue_x_Pat'};
            disp(array2table(pRT(:).', 'VariableNames', varNames));
            % If you want the full ANOVA table:
            % disp(tblRT)
        end
    end

    %% ---------- B) Precision: cell-level CSD with weights ----------
    sel2 = (idAll==pid) & ~isnan(errAll) & ~isnan(pd_ms_each) & ~ismissing(cueAll) & validPat;

    Dur  = categorical(pd_ms_each(sel2), pd_ms, string(pd_ms)+" ms");
    Cue  = categorical(cueAll(sel2), ["R","NR"]);
    Pat  = categorical(patAll(sel2), ["Grouped","Even","Uneven"]);
    Err  = errAll(sel2);

    [G, DurU, CueU, PatU] = findgroups(Dur, Cue, Pat);
    cellN   = splitapply(@numel, Err, G);
    cellCSD = splitapply(circSDdeg, Err, G);

    Tcsd = table(DurU, CueU, PatU, cellCSD, cellN, ...
        'VariableNames', {'Duration','Cue','Pattern','CSD','N'});

    % Drop empty/small cells
    Tcsd = Tcsd(~isnan(Tcsd.CSD) & Tcsd.N>1, :);

    if height(Tcsd) < 10
        warning('Too few CSD cells for %s; skipping CSD model.', pid);
    else
        if exist('fitlm','file') ~= 2
            warning('fitlm unavailable; skipping CSD model for %s.', pid);
        else
            % Weighted linear model on cell means (weights = trial counts)
            Tcsd.Duration = categorical(Tcsd.Duration);  % ensure categorical in table
            mdl = fitlm(Tcsd, 'CSD ~ Duration*Cue*Pattern', 'Weights', Tcsd.N);
            fprintf('CSD (deg) weighted LM ANOVA (Type I by default):\n');
            disp(anova(mdl,'summary'));

            % Optional Type III on cell means (unweighted):
            % if exist('anovan','file') == 2
            %   [pCSD, tblCSD] = anovan(Tcsd.CSD, {Tcsd.Duration, Tcsd.Cue, Tcsd.Pattern}, ...
            %      'model','full','varnames',{'Duration','Cue','Pattern'}, 'sstype',3, 'display','off');
            %   varNamesC = {'Duration','Cue','Pattern','Dur_x_Cue','Dur_x_Pat','Cue_x_Pat','Dur_x_Cue_x_Pat'};
            %   disp(array2table(pCSD(:).', 'VariableNames', varNamesC));
            % end
        end
    end

    %% ---------- C) Quick balance check (Duration×Cue×Pattern cell counts) ----------
    % Long table of factor combinations for this participant
    Tlong = table(Dur, Cue, Pat, 'VariableNames', {'Duration','Cue','Pattern'});

    % Counts per Duration×Cue×Pattern using varfun(@numel, ...)
    Ct = varfun(@numel, Tlong, ...
        'InputVariables','Pattern', ...
        'GroupingVariables', {'Duration','Cue','Pattern'});
    % Rename count column to 'N'
    ncol = find(strcmp(Ct.Properties.VariableNames, 'numel_Pattern'), 1);
    if ~isempty(ncol), Ct.Properties.VariableNames{ncol} = 'N'; end

    fprintf('Cell counts (Duration × Cue × Pattern), first rows:\n');
    disp(Ct(1:min(12,height(Ct)),:));

    % Wide view: columns = Pattern, values = counts
    bal = unstack(Ct, 'N', 'Pattern');   % dataVar='N' (numeric), indVar='Pattern'
    disp('Counts per Duration×Cue (columns = Pattern):');
    disp(bal);
end
