%% analyze_seqsingle.m
clear; close all; clc;

%% 1) Find & load all session files
filePattern = 'SeqSingleData_YDL_sess*.mat';
files = dir(filePattern);
if isempty(files)
    error('No files matching %s found.', filePattern);
end

% concatenate all expTrials tables
dataAll = table();
for f = files'
    S = load(f.name);
    fn = fieldnames(S);
    expT = S.(fn{1});            % should be the expTrials table
    if ~istable(expT)
        error('Loaded variable from %s is not a table.', f.name);
    end
    dataAll = [ dataAll; expT ]; %#ok<AGROW>
end

% — define Condition as AllUnique vs Redundant-R vs Redundant-NR —
dataAll.Condition = strings(height(dataAll),1);
isAll = dataAll.RedundantN==0;
dataAll.Condition(isAll)                              = "AllUnique";
dataAll.Condition(~isAll & dataAll.CueType=="R")     = "Redundant-R";
dataAll.Condition(~isAll & dataAll.CueType=="NR")    = "Redundant-NR";
dataAll.Condition = categorical(dataAll.Condition, ...
  ["AllUnique","Redundant-R","Redundant-NR"],'Ordinal',true);

%% 2) Pre‐filter RTs
% remove trials with RT > 2500 ms
% validRT = dataAll.ResponseTime <= 2500;
% dataAll = dataAll(validRT,:);

%% 3) Define Condition factor
% Unique: RedundantN==0
% Redundant-R: RedundantN>0 & CueType=='R'
% Redundant-NR: RedundantN>0 & CueType=='NR'
conds     = ["AllUnique","Redundant-R","Redundant-NR"];
setSizes  = [4, 6];
groupCats = ["All","Grouped","Separate"];
% colors for the three grouping levels:
groupCols.All      = [0,0.6,0];   % green
groupCols.Grouped  = [1,0,0];     % red
groupCols.Separate = [0,0,1];     % blue
% marker shapes by set size:
shape4 = 'o';
shape6 = 's';

% small horizontal offsets so the 6 series don’t sit on top of each other:
offsets = linspace(-0.35, +0.35, 6);

% preallocate
nC = numel(conds);
precMean = nan(nC,6); precSEM = nan(nC,6);
rtMean   = nan(nC,6); rtSEM  = nan(nC,6);

% helper circular‐SD in degrees
circSDdeg = @(x) rad2deg( sqrt(-2*log( sqrt(mean(cosd(x)).^2 + mean(sind(x)).^2) )) );

for iC = 1:nC
  for iG = 1:3            % grouping index
    for iS = 1:2          % set‐size index
      j = (iG-1)*2 + iS;  % which of the 6 series
      cond = conds(iC);
      sz   = setSizes(iS);

      % build logical index
      L = dataAll.Condition==cond & dataAll.ItemN==sz;
      if groupCats(iG)~="All"
        L = L & categorical(dataAll.Grouping)==groupCats(iG);
      end

      errs = dataAll.Precision(L);
      rts  = dataAll.ResponseTime(L);

      if numel(errs)>=2
        sd = circSDdeg(errs);
        precMean(iC,j) = sd;
        precSEM(iC,j)  = sd / sqrt(numel(errs));
      end
      if ~isempty(rts)
        rtMean(iC,j) = mean(rts);
        rtSEM(iC,j)  = std(rts)/sqrt(numel(rts));
      end
    end
  end
end

%% 1) Precision plot
figure('Color','w'); hold on;

% your existing conds, groupCats, markerShapes, offsets, groupCols definitions
conds     = ["Unique","Redundant-R","Redundant-NR"];
groupCats = ["All","Grouped","Separate"];
markerShapes = {'o','s'};  % 'o' for set=4, 's' for set=6
offsets = linspace(-0.35, +0.35, 6);

% STEP 1: preallocate & create dummy handles
hPrec = gobjects(6,1);
for j = 1:6
    grpIdx = ceil(j/2);       % 1→All, 2→Grouped, 3→Separate
    szIdx  = mod(j-1,2)+1;    % 1→set4, 2→set6
    col    = groupCols.(groupCats(grpIdx));
    mshape = markerShapes{szIdx};
    hPrec(j) = plot(nan, nan, mshape, ...
        'MarkerFaceColor', col, ...
        'MarkerEdgeColor','k', ...
        'MarkerSize',     8);   
end

% STEP 2: now overlay the real data
for j = 1:6
    grpIdx = ceil(j/2);
    szIdx  = mod(j-1,2)+1;
    col    = groupCols.(groupCats(grpIdx));
    mshape = markerShapes{szIdx};
    for iC = 1:numel(conds)
        x = iC + offsets(j);
        y = precMean(iC,j);
        e = precSEM(iC,j);
        if isnan(y), continue; end
        errorbar(x, y, e, 'LineStyle','none','Color',col,'LineWidth',1.2);
        plot(   x, y, mshape, 'MarkerFaceColor',col,'MarkerEdgeColor','k','MarkerSize',8);
    end
end

% STEP 3: cosmetics + legend
set(gca, 'XTick',1:3,'XTickLabel',conds,'FontSize',12);
xlabel('Condition','FontSize',14);
ylabel('Circular SD of Error (°)','FontSize',14);
title('Precision by Condition, Set-Size & Grouping','FontSize',16);
grid on;

legend(hPrec, { ...
  "4-All","6-All", ...
  "4-Grouped","6-Grouped", ...
  "4-Separate","6-Separate" }, ...
  'Location','northeastoutside');

hold off;

%% 2) RT plot
figure('Color','w'); hold on;

% reuse conds, groupCats, markerShapes, offsets, groupCols ...
hRT = gobjects(6,1);
for j = 1:6
    grpIdx = ceil(j/2);
    szIdx  = mod(j-1,2)+1;
    col    = groupCols.(groupCats(grpIdx));
    mshape = markerShapes{szIdx};
    hRT(j) = plot(nan,nan,mshape, ...
        'MarkerFaceColor',col,'MarkerEdgeColor','k','MarkerSize',8);
end

for j = 1:6
    grpIdx = ceil(j/2);
    szIdx  = mod(j-1,2)+1;
    col    = groupCols.(groupCats(grpIdx));
    mshape = markerShapes{szIdx};
    for iC = 1:numel(conds)
        x = iC + offsets(j);
        y = rtMean(iC,j);
        e = rtSEM(iC,j);
        if isnan(y), continue; end
        errorbar(x, y, e, 'LineStyle','none','Color',col,'LineWidth',1.2);
        plot(   x, y, mshape, 'MarkerFaceColor',col,'MarkerEdgeColor','k','MarkerSize',8);
    end
end

set(gca, 'XTick',1:3,'XTickLabel',conds,'FontSize',12);
xlabel('Condition','FontSize',14);
ylabel('Mean RT (ms)','FontSize',14);
title('RT by Condition, Set-Size & Grouping','FontSize',16);
grid on;

legend(hRT, { ...
  "4-All","6-All", ...
  "4-Grouped","6-Grouped", ...
  "4-Separate","6-Separate" }, ...
  'Location','northeastoutside');

hold off;