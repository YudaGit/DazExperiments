%% quick_seq_plots.m  — Simple, loop-based plots in your earlier style (R2024b)
% What it does
%   • Combines sequential pilot .mat files into dataAll (table)
%   • Fig 1: Precision (circular SD) — Baseline vs GS vs RS
%   • Fig 2: RT — Baseline vs GS vs RS
%   • Fig 3: Precision (circular SD) — RS only by SequenceTag
%   • Fig 4: RT — RS only by SequenceTag
%   • Fig 5: Precision (circular SD) — GS only by SequenceTag
%   • Fig 6: RT — GS only by SequenceTag
%
% Notes
%   • Trims RT > rtMax (set below). Circular SD uses the angle column it finds:
%       - If 'response_error' (or similar) exists → uses that (signed deg).
%       - Else if 'Precision' exists → uses that (interpreted as angles in deg).
%   • Keeps the same “simple” loop pattern you used.
clear; clc
%% --------------------------- SETTINGS ----------------------------------
filePattern = 'Seq3wayData_*.mat';   % change if needed (e.g., 'Daz2_*.mat')
rtMax      = 2500;                   % ms; set [] to keep all
set(groot,'defaultAxesFontSize',12,'defaultLineLineWidth',1.2);

%% --------------------- LOAD & COMBINE FILES ----------------------------
files = dir(filePattern);
if isempty(files)
    warning('No files match "%s" in %s', filePattern, pwd);
end

dataAll = table();   % empty table to start
for i = 1:numel(files)
    fname = files(i).name;
    S = load(fname);
    fn = fieldnames(S);
    if numel(fn)~=1
        % try common case: struct with expTrials/table inside
        T = tryExtractFirstTable(S);
    else
        V = S.(fn{1});
        if istable(V)
            T = V;
        elseif isstruct(V)
            T = tryExtractFirstTable(V);
        else
            error('File %s: unsupported data type.', fname);
        end
    end
    dataAll = [dataAll; T]; %#ok<AGROW>
end

disp('Combined dataAll summary:'); whos dataAll

%% ----------- MAP COLUMN NAMES → local variables (robust-ish) -----------
vn  = string(dataAll.Properties.VariableNames);
low = lower(vn);

% Condition (Baseline/GS/RS)
candCond = ["condition","cond","cuetype","blocktype","cue_type","type","cue"];
condName = pickVar(low, vn, candCond);
Cond = string(dataAll.(condName));
Cond = mapToBGSRS(Cond);
Cond = categorical(Cond);

% SequenceTag (optional)
candTag = ["sequencetag","seqtag","sequence","stag","seq","tag"];
tagName = pickVar(low, vn, candTag, "");
if tagName == ""
    SequenceTag = categorical(repmat("None", height(dataAll), 1));
else
    SequenceTag = categorical(string(dataAll.(tagName)));
end

% RT (ms)
candRT = ["responsetime","response_time","response_rt","rt","rtms","rt_msec","rt_ms"];
rtName = pickVar(low, vn, candRT);
RT = double(dataAll.(rtName));
if nanmean(RT) < 20 && nanmean(RT) > 0
    RT = RT * 1000;  % was seconds → ms
end

% Angle column (for circular SD)
candErr = ["response_error","errdeg","angleerror","ang_err","resp_error","error"];
errName = pickVar(low, vn, candErr, "");
if errName ~= ""
    AngDeg = double(dataAll.(errName));   % signed error deg ([-180, 180]) preferred
else
    if any(low == "precision")
        AngDeg = double(dataAll.("Precision"));
    else
        error('No angle/error column found (looked for response_error/errdeg/... or Precision).');
    end
end

% Cue (R / NR), fallback to BL for baseline/unknown
candCue = ["cuetype","cue","rnr","rn","cue_cond","cuecondition","cued"];
cueName = pickVar(low, vn, candCue, "");
if cueName ~= ""
    Cue = string(dataAll.(cueName));
else
    Cue = repmat("BL", height(dataAll), 1); % BL = baseline/unknown
end
Cue = upper(strtrim(Cue));
Cue = replace(Cue, ["REDUNDANT","R-","RED"], "R");
Cue = replace(Cue, ["NONRED","NON-REDUNDANT","NONREDUNDANT","NR-","NON"], "NR");
Cue(~ismember(Cue,["R","NR"])) = "BL"; % baseline/unknown
Cue = categorical(Cue);

%% ----------------------------- TRIM / KEEP -----------------------------
if ~isempty(rtMax)
    keep = RT <= rtMax & ~isnan(RT) & ~isnan(AngDeg);
else
    keep = ~isnan(RT) & ~isnan(AngDeg);
end
Cond        = Cond(keep);
SequenceTag = SequenceTag(keep);
RT          = RT(keep);
AngDeg      = AngDeg(keep);
Cue         = Cue(keep);

%% ---- Build combined condition label for Fig1&2 (vectorized, trimmed len)
n = numel(Cond);
Comb = strings(n,1);
isBL   = (Cond=="Baseline");
isGS_R = (Cond=="GS" & Cue=="R");
isGS_N = (Cond=="GS" & Cue=="NR");
isRS_R = (Cond=="RS" & Cue=="R");
isRS_N = (Cond=="RS" & Cue=="NR");

Comb(isBL)   = "Baseline";
Comb(isGS_R) = "GS-R";
Comb(isGS_N) = "GS-NR";
Comb(isRS_R) = "RS-R";
Comb(isRS_N) = "RS-NR";

keepComb = Comb ~= "";
Comb        = categorical(Comb(keepComb));
RT          = RT(keepComb);
AngDeg      = AngDeg(keepComb);
SequenceTag = SequenceTag(keepComb);
Cond        = Cond(keepComb);
Cue         = Cue(keepComb);

%% ===== Fig 1: Precision (circSD) — Baseline vs GS-R/GS-NR vs RS-R/RS-NR
combLevels = ["Baseline","GS-R","GS-NR","RS-R","RS-NR"];
combLevels = combLevels(ismember(combLevels, categories(Comb)));
xC = 1:numel(combLevels);

circSD = nan(numel(combLevels),1);
circSE = nan(numel(combLevels),1);
for i = 1:numel(combLevels)
    sel = (Comb == combLevels{i});
    [sdDeg, seDeg] = circSD_and_SE_deg(AngDeg(sel));
    circSD(i) = sdDeg;  circSE(i) = seDeg;
end

figure('Color','w'); hold on;
errorbar(xC, circSD, circSE, 'o', ...
    'LineStyle','none', ...                        % ← no connecting lines
    'Color',[0 0.4470 0.7410], ...
    'MarkerFaceColor',[0 0.4470 0.7410], ...
    'MarkerSize',6, 'LineWidth',1.2, 'CapSize',12);
set(gca,'XTick',xC,'XTickLabel',combLevels,'XTickLabelRotation',10);
xlim([0.5, numel(combLevels)+0.5]); grid on; box on;
ylabel('Precision (circular SD, deg)'); title('Precision — Baseline vs GS/RS (R & NR)');
hold off;


%% ===== Fig 2: RT — Baseline vs GS-R/GS-NR vs RS-R/RS-NR (with jitter)
meanRT = nan(numel(combLevels),1);
semRT  = nan(numel(combLevels),1);

figure('Color','w'); hold on;
for i = 1:numel(combLevels)
    sel = (Comb == combLevels{i});
    nSel = sum(sel);
    if nSel>0
        jit = (rand(nSel,1)*2-1)*0.08;
        scatter(xC(i)+jit, RT(sel), 12, 'MarkerFaceColor',[.6 .7 .9], ...
            'MarkerEdgeColor','none','MarkerFaceAlpha',0.25,'MarkerEdgeAlpha',0.05);
        meanRT(i) = mean(RT(sel),'omitnan');
        semRT(i)  = std(RT(sel),'omitnan')/sqrt(sum(~isnan(RT(sel))));
    end
end
errorbar(xC, meanRT, semRT, 'k.', 'LineWidth',1.2, 'CapSize',12);
plot(xC, meanRT, 'ks', 'MarkerFaceColor','k', 'MarkerSize',6);
set(gca,'XTick',xC,'XTickLabel',combLevels,'XTickLabelRotation',10);
xlim([0.5, numel(combLevels)+0.5]); grid on; box on;
ylabel('RT (ms)'); title('RT — Baseline vs GS/RS (R & NR)');
hold off;

%% ===== Common prep for SeqTag overlays (GS & RS with R/NR) =====
hasGS = any(Cond=='GS'); 
hasRS = any(Cond=='RS');
if hasGS || hasRS
    tagsGS = categories(removecats(SequenceTag(Cond=='GS')));
    tagsRS = categories(removecats(SequenceTag(Cond=='RS')));
    tagsAll = unique([string(tagsGS); string(tagsRS)], 'stable');
    xT = 1:numel(tagsAll);

    % Colors: two greens for GS, two reds for RS
    colGS_R  = [0.30 0.60 0.18];  % darker green
    colGS_NR = [0.65 0.80 0.45];  % lighter green
    colRS_R  = [0.80 0.30 0.20];  % darker red
    colRS_NR = [0.95 0.65 0.55];  % lighter red

    % series defs: {label, color, marker}
    series = {
        'GS-R',  colGS_R,  'o';
        'GS-NR', colGS_NR, 's';
        'RS-R',  colRS_R,  'o';
        'RS-NR', colRS_NR, 's';
    };

    % small horizontal offsets per series (avoid overlap)
    jitterOffsets = [-0.2, 0.2, -0.2, 0.2];
end

%% ===== Fig 3: Precision (circSD) by SequenceTag — GS/RS with R & NR (jittered)
if hasGS || hasRS
    figure('Color','w'); hold on;
    plotted = false(4,1);
    for si = 1:size(series,1)
        lab = series{si,1}; col = series{si,2}; mk = series{si,3};
        if startsWith(lab,'GS'), cSel = (Cond=='GS'); else, cSel = (Cond=='RS'); end
        if endsWith(lab,'-R'),  qSel = (Cue=='R');    else, qSel = (Cue=='NR');   end

        y  = nan(numel(tagsAll),1);
        ey = nan(numel(tagsAll),1);
        for iT = 1:numel(tagsAll)
            sel = cSel & qSel & (string(SequenceTag) == tagsAll(iT));
            [sdDeg, seDeg] = circSD_and_SE_deg(AngDeg(sel));
            y(iT)  = sdDeg;  ey(iT) = seDeg;
        end

        if any(~isnan(y))
            xp = xT + jitterOffsets(si); % ← jitter horizontally per series
            errorbar(xp, y, ey, ...
                'LineStyle','none', ...         % no connecting lines
                'Marker', mk, ...
                'Color', col, 'MarkerFaceColor', col, ...
                'MarkerSize',6, 'LineWidth',1.2, 'CapSize',12);
            plotted(si) = true;
        end
    end
    set(gca,'XTick',xT,'XTickLabel',tagsAll,'XTickLabelRotation',20);
    xlim([0.5-0.25, numel(tagsAll)+0.5+0.25]); % pad for jitter
    grid on; box on;
    ylabel('Precision (circular SD, deg)'); title('Precision by SequenceTag — GS/RS (R vs NR)');
    leg = series(plotted,1);
    if ~isempty(leg), legend(leg, 'Location','northeastoutside'); end
    hold off;
end

%% ===== Fig 4: RT by SequenceTag — GS/RS with R & NR (jittered)
if hasGS || hasRS
    figure('Color','w'); hold on;
    plotted = false(4,1);
    for si = 1:size(series,1)
        lab = series{si,1}; col = series{si,2}; mk = series{si,3};
        if startsWith(lab,'GS'), cSel = (Cond=='GS'); else, cSel = (Cond=='RS'); end
        if endsWith(lab,'-R'),  qSel = (Cue=='R');    else, qSel = (Cue=='NR');   end

        m = nan(numel(tagsAll),1);
        s = nan(numel(tagsAll),1);
        for iT = 1:numel(tagsAll)
            sel = cSel & qSel & (string(SequenceTag) == tagsAll(iT));
            rti = RT(sel);
            m(iT) = mean(rti,'omitnan');
            s(iT) = std(rti,'omitnan')/sqrt(sum(~isnan(rti)));
        end

        if any(~isnan(m))
            xp = xT + jitterOffsets(si); % ← jitter horizontally per series
            errorbar(xp, m, s, ...
                'LineStyle','none', ...         % no connecting lines
                'Marker', mk, ...
                'Color', col, 'MarkerFaceColor', col, ...
                'MarkerSize',6, 'LineWidth',1.2, 'CapSize',12);
            plotted(si) = true;
        end
    end
    set(gca,'XTick',xT,'XTickLabel',tagsAll,'XTickLabelRotation',20);
    xlim([0.5-0.25, numel(tagsAll)+0.5+0.25]); % pad for jitter
    grid on; box on;
    ylabel('RT (ms)'); title('RT by SequenceTag — GS/RS (R vs NR)');
    leg = series(plotted,1);
    if ~isempty(leg), legend(leg, 'Location','northeastoutside'); end
    hold off;
end

%% ------------------------ HELPER UTILITIES -----------------------------
function name = pickVar(lowNames, origNames, candidates, defaultName)
    if nargin < 4, defaultName = ""; end
    name = defaultName;
    for c = candidates
        hit = find(lowNames == c, 1, 'first');
        if ~isempty(hit)
            name = origNames(hit);
            return;
        end
    end
end

function T = tryExtractFirstTable(S)
% Look for first table inside a struct (possibly nested one level).
    f = fieldnames(S);
    for i = 1:numel(f)
        v = S.(f{i});
        if istable(v), T = v; return; end
        if isstruct(v)
            ff = fieldnames(v);
            for j = 1:numel(ff)
                vv = v.(ff{j});
                if istable(vv), T = vv; return; end
            end
        end
    end
    error('Could not find a table inside the loaded struct.');
end

function out = mapToBGSRS(s)
    s = lower(strtrim(string(s)));
    out = strings(size(s));
    for k = 1:numel(s)
        si = s(k);
        if si=="" || si=="nan"
            out(k) = "Baseline";
        elseif contains(si,"base")
            out(k) = "Baseline";
        elseif contains(si,"gs") || contains(si,"group")
            out(k) = "GS";
        elseif contains(si,"rs") || contains(si,"redund")
            out(k) = "RS";
        else
            % keep original but capitalized
            out(k) = regexprep(si, '(^.)', '${upper($1)}');
        end
    end
    out = categorical(out);
end

function [sdDeg, seDeg] = circSD_and_SE_deg(angDeg)
% Circular SD in degrees, plus "circular SE" ≈ sd/sqrt(n).
% Works whether angDeg are signed errors ([-180,180]) or angles ([0,360)).
    a = deg2rad(angDeg(:));
    a = a(~isnan(a));
    n = numel(a);
    if n < 2
        sdDeg = NaN; seDeg = NaN; return;
    end
    C = sum(cos(a))/n;
    S = sum(sin(a))/n;
    Rbar = hypot(C,S);
    Rbar = max(min(Rbar,1), eps);
    sdRad = sqrt(-2*log(Rbar));
    sdDeg = rad2deg(sdRad);
    seDeg = sdDeg / sqrt(n); % simple large-n approximation
end
