function [pracTbl, mainTbl] = TrialMatrixSeqSingle(design, sessionN, participantID, age, timestamp)
%======================================================================
% TrialMatrixSeqSingle – singleton‐only, blocked ItemN version
%   design.ItemNList    = [3 4 6]
%   design.RedundantMap = { [0 2], [0 2], [0 3] }
%   design.CueBalance   = {'noRedundant','cueR','cueNR'}
%   design.PracticeReps, design.MainReps, etc.
%======================================================================
global V;

%% 1) Build one‐repetition base table
rows = {};
for b = 1:numel(design.ItemNList)
    N    = design.ItemNList(b);
    reds = design.RedundantMap{b};
    for t = 1:numel(design.CueBalance)
        cb = design.CueBalance{t};
        switch cb
            case 'noRedundant'
                R = 0;  cueType = 'NR';
            case 'cueR'
                R = reds(end); cueType = 'R';
            case 'cueNR'
                R = reds(end); cueType = 'NR';
        end
        rows(end+1,:) = {N, R, cueType};  %#ok<AGROW>
    end
end
baseTbl = cell2table(rows, 'VariableNames', {'ItemN','RedundantN','CueType'});

%% 2) Inflate for practice & main
pracRows = repelem(baseTbl, design.PracticeReps, 1);
mainRows = repelem(baseTbl, design.MainReps,     1);

%% 3) Block‐shuffle by ItemN
pracTbl = blockByItem(pracRows, design.ItemNList);
mainTbl = blockByItem(mainRows, design.ItemNList);

%% 4) Enrich rows with demographics, stimuli, targets
pracTbl = enrich(pracTbl, sessionN, participantID, age, timestamp);
mainTbl = enrich(mainTbl, sessionN, participantID, age, timestamp);

pracTbl.presDur = repmat(design.presDur, height(pracTbl), 1);
pracTbl.retDur  = repmat(design.retDur,  height(pracTbl), 1);
mainTbl.presDur = repmat(design.presDur, height(mainTbl), 1);
mainTbl.retDur  = repmat(design.retDur,  height(mainTbl), 1);

end


%─────────────────────────────────────────────────────────────────────
function tblOut = blockByItem(tblIn, itemList)
% Keep each ItemN together as a block, but shuffle within each block
tblOut = table();
for i = 1:numel(itemList)
    block = tblIn(tblIn.ItemN==itemList(i), :);
    block = block(randperm(height(block)), :);
    tblOut = [tblOut; block];  %#ok<AGROW>
end
end

%─────────────────────────────────────────────────────────────────────
function tblOut = enrich(coreTbl, sessionN, pid, age, ts)
% Add IDs, random colours, fixed positions, targets, and response columns
global V;
n = height(coreTbl);
tblOut = coreTbl;

% Participant & session info
tblOut.ID        = repmat({pid},     n,1);
tblOut.Age       = repmat(age,       n,1);
tblOut.StartTime = repmat({ts},      n,1);
tblOut.SessionN  = repmat(sessionN,  n,1);
tblOut.CuedFeature   = repmat({'Color'},n,1);
tblOut.CuedFeature_i = zeros(n,1);
tblOut.WheelRotation = repmat(V.color.rotation,n,1);

% Allocate response data columns
emptyCell = {nan};
for f = {'Colors','StimulusLocations','MouseX','MouseY','MouseAngles','MouseDistances','MouseTime'}
    tblOut.(f{1}) = emptyCell(ones(n,1));
end
for f = {'Target','ResponseAngle','DerotatedResponseAngle','Precision','ResponseTime','MouseInitTooSlow','MouseInitTooFast','TrialTooSlow'}
    tblOut.(f{1}) = nan(n,1);
end

% Assign stimuli and targets
for ii = 1:n
    N = tblOut.ItemN(ii);
    R = tblOut.RedundantN(ii);
    % --- Colour assignment ---
    dupCol = randi(360);
    dupPos = randperm(N,R);
    cols   = zeros(1,N);
    cols(dupPos) = dupCol;
    uniquePos = setdiff(1:N, dupPos);
    filled = 0; mind = 30;
    while filled < numel(uniquePos)
        cand = randi(360);
        if circDist(cand, dupCol) < mind, continue; end
        if filled>0 && any(circDist(cand, cols(uniquePos(1:filled))) < mind), continue; end
        filled = filled+1;
        cols(uniquePos(filled)) = cand;
    end
    tblOut.Colors{ii} = cols;
    % --- Fixed positions on invisible circle (12 o'clock = 90°) ---
    tblOut.StimulusLocations{ii} = 90 + (0:N-1)*(360/N);
    % --- Grouping label (optional) ---
    if R>0 && areGrouped(dupPos,N)
        tblOut.Grouping{ii} = 'Grouped';
    else
        tblOut.Grouping{ii} = 'Separate';
    end
    % --- Target selection ---
    if strcmp(tblOut.CueType{ii},'R') && R>0
        pool = dupPos;
    else
        pool = setdiff(1:N, dupPos);
    end
    tblOut.Target(ii) = pool(randi(numel(pool)));
end

% Final indexing
tblOut.Index = (1:n)';
end

%─────────────────────────────────────────────────────────────────────
function d = circDist(a,b)
% Minimum circular distance (degrees)
d = abs(a-b);
d = min(d,360-d);
end

%─────────────────────────────────────────────────────────────────────
function tf = areGrouped(pos,N)
% True if pos forms a contiguous block on an N‐item circle
R = numel(pos);
tf = false;
for k=1:R
    block = mod(pos(k)-1 + (0:R-1), N) + 1;
    if all(ismember(block, pos))
        tf = true; 
        return;
    end
end
end
