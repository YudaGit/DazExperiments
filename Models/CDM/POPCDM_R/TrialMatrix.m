function [pracTbl, mainTbl] = TrialMatrix(design, ...
                               sessionN, participantID, age, timestamp)
%======================================================================
% TrialMatrix   –   EXP-1 Encoding
% INPUT  (design struct – all fields mandatory)
%   design.ItemN          : scalar set-size  (e.g., 6)
%   design.RedundantN     : scalar redundant count (e.g., 2)
%   design.Grouping       : cellstr {'Grouped','Separate'}
%   design.CueType        : cellstr {'R','NR'}
%   design.presDurList    : vector of presentation times (s)
%   design.retDurList     : vector of retention times (s)
%   design.PracticeReps   : integer reps per cell in practice block
%   design.MainReps       : integer reps per cell in main block
%
% OUTPUT
%   pracTbl, mainTbl      : shuffled tables ready for RunBlock
%======================================================================

global V  % for wheel rotation constant

core = allcomb( ... % Cartesian product of all factors
        design.ItemN, ...
        design.RedundantN, ...
        design.CueType, ...
        design.presDurList, ...
        design.retDurList);  %removed design.Grouping, ...

factorNames = {'ItemN','RedundantN','CueType','PresDur','RetDur'}; % Removed  'Grouping'
coreTbl = cell2table(core, 'VariableNames', factorNames);

% Inflate rows for practice & main blocks
pracRows = repelem(coreTbl, design.PracticeReps, 1);
mainRows = repelem(coreTbl, design.MainReps, 1);

% Within block shuffle
pracRows = pracRows(randperm(height(pracRows)), :);
mainRows = mainRows(randperm(height(mainRows)), :);

% Enrich: add colours, positions, targets, legacy cols and obs information
pracTbl = enrichRows(pracRows, sessionN, participantID, age, timestamp);
mainTbl = enrichRows(mainRows, sessionN, participantID, age, timestamp);
end

%───────────────────Enrich Rows────────────────────────────
function tbl = enrichRows(coreRows, sessionN, pid, age, ts)
% Add per-trial randomisations and all legacy columns expected by helpers.

global V
n = height(coreRows);
tbl = coreRows;

% participant/session identifiers
tbl.ID         = repmat({pid}, n,1);
tbl.Age        = repmat(age,  n,1);
tbl.StartTime  = repmat({ts}, n,1);
tbl.SessionN   = repmat(sessionN, n,1);

tbl.CuedFeature    = repmat({'Color'}, n,1); tbl.CuedFeature_i  = zeros(n,1);
tbl.WheelRotation  = repmat(V.color.rotation, n,1);

% allocate response-collection columns
empty = {nan};
tbl.Orientations = empty(ones(n,1));
tbl.Colors = empty(ones(n,1));
tbl.StimulusLocations = empty(ones(n,1));
tbl.Target = zeros(n,1);

tbl.MouseX = empty(ones(n,1));
tbl.MouseY = empty(ones(n,1));
tbl.MouseAngles = empty(ones(n,1));
tbl.MouseDistances = empty(ones(n,1));
tbl.MouseTime = empty(ones(n,1));
tbl.ResponseAngle = nan(n,1);
tbl.DerotatedResponseAngle = nan(n,1);
tbl.Precision = nan(n,1);
tbl.ResponseTime = nan(n,1);
tbl.MouseInitTooSlow  = nan(n,1);
tbl.MouseInitTooFast = nan(n,1);
tbl.TrialTooSlow = nan(n,1);

% Randomise per-trial stimuli (color, ID, )
minDist = 30; %degrees

for ii = 1:n
    N = tbl.ItemN(ii);  R = tbl.RedundantN(ii);
    colorIdx = zeros(1,N);
    
    dupCol = randi(360); % random duplicate color
    dupPos = randperm(N, R); % which positions get duplicates
    colorIdx = zeros(1,N);
    colorIdx(dupPos) = dupCol;
    uniquePos = setdiff(1:N, dupPos); % fill the rest with unique colors
    filled = 0;

    while filled < numel(uniquePos)
        cand = randi(360);

        if circDist(cand, dupCol) < minDist, continue, end % redo if too close to duplicate color
        
        if filled > 0
            d = circDist(cand, colorIdx(uniquePos(1:filled))); % redo if too close to chosen unique  color
            if any(d < minDist), continue, end
        end
    
        filled = filled + 1;
        colorIdx(uniquePos(filled)) = cand;
    end
    
    tbl.Colors{ii} = colorIdx;   % store indices, not RGB
    dupIdx          = dupPos;    % for target pool 

    base = (0:N-1)*(360/N) + randi(360/N);  % equally spaced, random start
    tbl.StimulusLocations{ii} = base(randperm(N));   % shuffle positions

  % label Grouping (purely descriptive)
    if R==0
        tbl.Grouping{ii} = 'Separate';
    elseif areGrouped(dupPos,N)
        tbl.Grouping{ii} = 'Grouped';
    else
        tbl.Grouping{ii} = 'Separate';
    end
        
    % target selection
    if strcmp(tbl.CueType{ii},'R') && R>0
        pool = dupIdx;
    else
        pool = setdiff(1:N, dupIdx);
    end
    tbl.Target(ii) = pool(randi(numel(pool)));
end

tbl = tbl(randperm(n),:);    % final shuffle
tbl.Index = (1:n)';          % legacy trial counter
end

%------------------------- Make array based on input -------------------------------
function comb = allcomb(varargin)
% Cartesian product of input vectors / cells.
% Returns a cell array whose columns correspond to the inputs.
%
%   comb = allcomb(A,B,C,...) produces a table with size
%          (numel(A)*numel(B)*numel(C)...) × nargin

n = nargin;
grids = varargin;

% ensure each input is a cell column
for k = 1:n
    if ~iscell(grids{k})
        grids{k} = num2cell(grids{k}); % wrap numeric or char vector
    end
    grids{k} = grids{k}(:); % column
end

% build ndgrid
[grids{:}] = ndgrid(grids{:});

% linearise and concatenate
for k = 1:n
    grids{k} = grids{k}(:);
end
comb = [grids{:}]; % now all cell, so concatenation works
end

%------------------color randomiser--------------------------------
function idx = randColors(N)
idx = randperm(360, N);       % or randi(360,1,N) if you allow dupes
end                           % end randColors

% ---------- randOrientations  (sibling) -------------------------------
function ang = randOrientations(N)
% Return a 1×N vector of random orientations (degrees 0–359).
ang = randi(360, 1, N) - 1;
end

%-----------------------------------------------------------------------
function d = circDist(a,b)
% Returns the smaller of clockwise / counter-clockwise distance (deg)
d = abs(a - b);
d = min(d, 360 - d);
end

%-----------------------------------------------------------------------
function tf = areGrouped(pos,N)
% True if the indices in POS occupy R consecutive slots on an N-item circle
R = numel(pos);
for k = 1:R
    start = pos(k);
    wanted = mod(start-1 + (0:R-1), N) + 1;   % contiguous block length R
    if all(ismember(wanted,pos))
        tf = true;  return
    end
end
tf = false;
end