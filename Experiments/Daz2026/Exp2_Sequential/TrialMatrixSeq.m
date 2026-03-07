function [pracTbl, mainTbl] = TrialMatrixSeq(design, sessionN, participantID, age, timestamp)
%======================================================================
% TrialMatrix – EXP2 Redundancy Sequence
% Builds practice & main trial tables, handling SeqType→Nseq mapping.
% Requires in `design`:
%   .ItemN, .RedundantN, .CueType, .presDurList, .retDurList,
%   .PracticeReps, .MainReps,
%   .SeqType, .NseqList
%======================================================================
global V

% 1) Build core factorial including SeqType
core = allcomb( ...
    num2cell(design.ItemN(:)), ...
    num2cell(design.RedundantN(:)), ...
    design.CueType, ...
    num2cell(design.presDurList(:)), ...
    num2cell(design.retDurList(:)), ...
    num2cell(design.SeqType(:)) );
factorNames = {'ItemN','RedundantN','CueType','PresDur','RetDur','SeqType'};
coreTbl = cell2table(core, 'VariableNames', factorNames);

% 2) Map SeqType → Nseq
if iscell(coreTbl.SeqType)
    seqIdx = cell2mat(coreTbl.SeqType);
else
    seqIdx = coreTbl.SeqType;
end
assert(all(seqIdx>=1 & seqIdx<=numel(design.NseqList)), ...
    'Each SeqType must index into NseqList');

% force the lookup into a column
lookup = design.NseqList(seqIdx(:));
lookup = lookup(:);
coreTbl.Nseq = lookup;

% 3) Inflate & shuffle practice/main
pracRows = repelem(coreTbl, design.PracticeReps, 1);
mainRows = repelem(coreTbl, design.MainReps,    1);
pracRows = pracRows(randperm(height(pracRows)), :);
mainRows = mainRows(randperm(height(mainRows)), :);

% 4) Enrich and return
pracTbl = enrichRows(pracRows, sessionN, participantID, age, timestamp);
mainTbl = enrichRows(mainRows, sessionN, participantID, age, timestamp);
end


%─────────────────────────────────────────────────────────────────────
function tbl = enrichRows(coreRows, sessionN, pid, age, ts)
global V
n = height(coreRows);
tbl = coreRows;

% IDs & demographics
tbl.ID        = repmat({pid}, n,1);
tbl.Age       = repmat(age,  n,1);
tbl.StartTime = repmat({ts},  n,1);
tbl.SessionN  = repmat(sessionN,n,1);

% Cue & wheel settings
tbl.CuedFeature   = repmat({'Color'}, n,1);
tbl.CuedFeature_i = zeros(n,1);
tbl.WheelRotation = repmat(V.color.rotation,n,1);

% Allocate storage columns
emptyCell = {nan};
for c = {'Orientations','Colors','StimulusLocations','MouseX','MouseY','MouseAngles','MouseDistances','MouseTime'}
    tbl.(c{1}) = emptyCell(ones(n,1));
end
for c = {'Target','ResponseAngle','DerotatedResponseAngle','Precision','ResponseTime','MouseInitTooSlow','MouseInitTooFast','TrialTooSlow'}
    tbl.(c{1}) = nan(n,1);
end

% Randomise stimuli & assign targets
minDist = 30;
for ii = 1:n
    N = tbl.ItemN(ii); 
    R = tbl.RedundantN(ii);

    % --- Colour assignment ---
    dupCol = randi(360);
    dupPos = randperm(N,R);
    cols   = zeros(1,N);
    cols(dupPos) = dupCol;
    uniquePos = setdiff(1:N, dupPos);
    filled    = 0;
    while filled < numel(uniquePos)
        cand = randi(360);
        if circDist(cand, dupCol) < minDist, continue; end
        if filled>0 && any(circDist(cand, cols(uniquePos(1:filled)))<minDist), continue; end
        filled = filled+1;
        cols(uniquePos(filled)) = cand;
    end
    tbl.Colors{ii} = cols;

    % --- Position assignment on invisible circle ---
    baseAng = (0:N-1)*(360/N) + randi(floor(360/N));
    tbl.StimulusLocations{ii} = baseAng(randperm(N));

    % --- Grouping label ---
    if areGrouped(dupPos,N)
        tbl.Grouping{ii} = 'Grouped';
    else
        tbl.Grouping{ii} = 'Separate';
    end

    % --- Target selection ---
    if strcmp(tbl.CueType{ii}, 'R') && R>0
        pool = dupPos;
    else
        pool = setdiff(1:N, dupPos);
    end
    tbl.Target(ii) = pool(randi(numel(pool)));
end

% Shuffle enriched rows & index
tbl = tbl(randperm(n), :);
tbl.Index = (1:n)';

% Rotating start location for SeqType==3
tbl.StartLocation = mod(tbl.Index-1, tbl.ItemN) + 1;
end


%─────────────────────────────────────────────────────────────────────
function comb = allcomb(varargin)
% Cartesian product of inputs → cell array
n = nargin; grids = varargin;
for k = 1:n
    if ~iscell(grids{k}), grids{k} = num2cell(grids{k}); end
    grids{k} = grids{k}(:);
end
[grids{:}] = ndgrid(grids{:});
for k = 1:n, grids{k} = grids{k}(:); end
comb = [grids{:}];
end

function d = circDist(a,b)
% Minimum circular distance (degrees)
d = abs(a-b);
d = min(d, 360-d);
end

function tf = areGrouped(pos,N)
% True if positions in pos form a contiguous block on an N‐item circle
R = numel(pos);
for k = 1:R
    block = mod(pos(k)-1 + (0:R-1), N) + 1;
    if all(ismember(block,pos))
        tf = true;
        return;
    end
end
tf = false;
end
