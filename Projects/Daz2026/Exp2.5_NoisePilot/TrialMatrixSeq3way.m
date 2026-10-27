function [pracTbl, mainTbl] = TrialMatrixSeq3way(design, sessionN, participantID, age, timestamp)
%======================================================================
% TrialMatrixSeq3way
%   Three categories per set size (N=4,6):
%     1) Baseline (all-unique singletons across N steps)
%     2) RS  (Singleton Redundancy, R items appear as adjacent singletons;
%             adjacency is by index WITHOUT wrap: 4~1 not allowed)
%     3) GS  (Group+Singleton: redundant items drawn TOGETHER in one step;
%             adjacency by index WITH wrap allowed, e.g., 5,6,1)
%
% Balancing:
%   For each N:
%     - Baseline trials = floor(MainReps/2)
%     - RS trials       = MainReps (half R-cue, half NR-cue)
%     - GS trials       = MainReps (half R-cue, half NR-cue)
%
% Adds:
%   - Condition   : {'Baseline','RS','GS'}
%   - SegmentOrder: 1×nseq cell; each cell holds a numeric vector of indices
%   - SequenceTag : string like 'RRUU', 'URRU', 'RGUUU', 'UURGU', ...
%   - Grouping    : 'Grouped' or 'Separate'
%   - RedundantPositions, UniquePositions
%
% Other columns follow your previous tables (IDs, Colors, etc.).
%======================================================================
global V;

if mod(design.MainReps,2)~=0
    warning('design.MainReps is odd; splitting R/NR as equally as possible.');
end

% ---------- 1) Build MAIN rows ----------
rows = cell(0,4);
for b = 1:numel(design.ItemNList)
    N    = design.ItemNList(b);
    Rval = pickR_for_N(N, design.RedundantMap);   % N=4→2, N=6→3
    
    repsBase = floor(design.MainReps/2);
    repsRS   = design.MainReps;
    repsGS   = design.MainReps;

    % Baseline (all unique; treat CueType='NR' for consistency)
    for k=1:repsBase
        rows(end+1,:) = {N, 0, 'NR', 'Baseline'}; %#ok<AGROW>
    end

    % RS: half R-cue, half NR-cue
    nR  = floor(repsRS/2); nNR = repsRS - nR;
    for k=1:nR,  rows(end+1,:) = {N, Rval, 'R',  'RS'};  end
    for k=1:nNR, rows(end+1,:) = {N, Rval, 'NR', 'RS'};  end

    % GS: half R-cue, half NR-cue
    nR  = floor(repsGS/2); nNR = repsGS - nR;
    for k=1:nR,  rows(end+1,:) = {N, Rval, 'R',  'GS'};  end
    for k=1:nNR, rows(end+1,:) = {N, Rval, 'NR', 'GS'};  end
end
if isempty(rows)
    mainBase = table('Size',[0 4], ...
        'VariableTypes', {'double','double','string','string'}, ...
        'VariableNames', {'ItemN','RedundantN','CueType','Condition'});
else
    mainBase = cell2table(rows, 'VariableNames',{'ItemN','RedundantN','CueType','Condition'});
end

% ---------- 2) Build PRACTICE rows ----------
rows = cell(0,4);
for b = 1:numel(design.ItemNList)
    N    = design.ItemNList(b);
    Rval = pickR_for_N(N, design.RedundantMap);

    repsBase = floor(design.PracticeReps/2);
    repsRS   = design.PracticeReps;
    repsGS   = design.PracticeReps;

    for k=1:repsBase, rows(end+1,:) = {N, 0,    'NR', 'Baseline'}; end
    nR  = floor(repsRS/2); nNR = repsRS - nR;
    for k=1:nR,  rows(end+1,:) = {N, Rval, 'R',  'RS'};  end
    for k=1:nNR, rows(end+1,:) = {N, Rval, 'NR', 'RS'};  end

    nR  = floor(repsGS/2); nNR = repsGS - nR;
    for k=1:nR,  rows(end+1,:) = {N, Rval, 'R',  'GS'};  end
    for k=1:nNR, rows(end+1,:) = {N, Rval, 'NR', 'GS'};  end
end
if isempty(rows)
    pracBase = table('Size',[0 4], ...
        'VariableTypes', {'double','double','string','string'}, ...
        'VariableNames', {'ItemN','RedundantN','CueType','Condition'});
else
    pracBase = cell2table(rows, 'VariableNames',{'ItemN','RedundantN','CueType','Condition'});
end

% ---------- 3) Block-shuffle by ItemN ----------
pracTbl = blockByItem(pracBase, design.ItemNList);
mainTbl = blockByItem(mainBase, design.ItemNList);

% ---------- 4) Enrich (IDs, stimuli, SegmentOrder, tags, targets, etc.) ----------
pracTbl = enrich(pracTbl, sessionN, participantID, age, timestamp);
mainTbl = enrich(mainTbl, sessionN, participantID, age, timestamp);

% ---------- 5) presDur / retDur ----------
pracTbl.presDur = repmat(design.presDur, height(pracTbl), 1);
pracTbl.retDur  = repmat(design.retDur,  height(pracTbl), 1);
mainTbl.presDur = repmat(design.presDur, height(mainTbl), 1);
mainTbl.retDur  = repmat(design.retDur,  height(mainTbl), 1);
end

%──────────────── helpers ────────────────
function R = pickR_for_N(N, RedundantMap)
% Find the R used for this N from design.RedundantMap (e.g., [0 2]→2, [0 3]→3)
if iscell(RedundantMap)
    % expect an entry per set size (same order as ItemNList)
    % else: pick the last element (>0) of a matching R-list
    all = [RedundantMap{:}];
    R = max(all(all>0)); % fallback
else
    R = max(RedundantMap(RedundantMap>0));
end
if N==4, R = 2; end
if N==6, R = 3; end
end

function tblOut = blockByItem(tblIn, itemList)
tblOut = table();
for i = 1:numel(itemList)
    block = tblIn(tblIn.ItemN==itemList(i), :);
    block = block(randperm(height(block)), :);
    tblOut = [tblOut; block]; %#ok<AGROW>
end
end

function T = enrich(coreTbl, sessionN, pid, age, ts)
global V
n = height(coreTbl);
T = coreTbl;

% IDs & basics
T.ID            = repmat({pid},    n,1);
T.Age           = repmat(age,      n,1);
T.SessionN      = repmat(sessionN, n,1);
T.StartTime     = repmat({ts},     n,1);
T.CuedFeature   = repmat({'Color'},n,1);
T.CuedFeature_i = zeros(n,1);
T.WheelRotation = repmat(V.color.rotation, n,1);

% Allocate response columns
emptyCell = {nan};
for f = {'Colors','StimulusLocations','MouseX','MouseY','MouseAngles','MouseDistances','MouseTime',...
         'SegmentOrder','RedundantPositions','UniquePositions'}
    T.(f{1}) = emptyCell(ones(n,1));
end
for f = {'Target','ResponseAngle','DerotatedResponseAngle','Precision','ResponseTime',...
         'MouseInitTooSlow','MouseInitTooFast','TrialTooSlow','Nseq'}
    T.(f{1}) = nan(n,1);
end
T.Grouping    = repmat({''}, n,1);
T.SequenceTag = repmat({''}, n,1);
T.NoiseLevel  = repmat({'low'}, n,1);  % Default to 'low' noise, can be 'low' or 'high'

% Fill trial-by-trial
for ii = 1:n
    N   = T.ItemN(ii);
    R   = T.RedundantN(ii);
    cnd = T.Condition{ii};   % 'Baseline' | 'RS' | 'GS'

    % Positions around circle (12 o'clock = 90°)
    % Fixed positions: always use 6 evenly spaced positions starting at 12 o'clock
    % Actual stimuli will be placed at a subset of these 6 positions based on N
    allPositions = 90 + (0:5)*(360/6);  % 6 fixed positions: 90, 150, 210, 270, 330, 30
    % Select first N positions for this trial
    T.StimulusLocations{ii} = allPositions(1:N);

    % ----- choose redundant positions (dupPos) by condition -----
    switch cnd
        case 'Baseline'
            dupPos = [];                       % no redundancy
            T.Grouping{ii} = 'Separate';

        case 'RS'
            % contiguous, NON-wrap block of length R → start ∈ 1..(N-R)
            start = randi(N-R);
            dupPos = start : (start+R-1);
            T.Grouping{ii} = 'Grouped';

        case 'GS'
            % contiguous, WITH-wrap block of length R → start ∈ 1..N
            start = randi(N);
            dupPos = mod((start-1) + (0:R-1), N) + 1;
            T.Grouping{ii} = 'Grouped';
    end
    uniqPos = setdiff(1:N, dupPos);
    T.RedundantPositions{ii} = dupPos;
    T.UniquePositions{ii}    = uniqPos;

    % ----- assign colours (dup color identical; uniques spaced) -----
    cols = zeros(1,N);
    if ~isempty(dupPos)
        dupCol = randi(360);
        cols(dupPos) = dupCol;
        mind = 30; filled = 0;
        while filled < numel(uniqPos)
            cand = randi(360);
            if circDist(cand, dupCol) < mind, continue; end
            if filled>0 && any(circDist(cand, cols(uniqPos(1:filled))) < mind), continue; end
            filled = filled + 1;
            cols(uniqPos(filled)) = cand;
        end
    else
        % all unique
        mind = 30; cols(1) = randi(360);
        for k=2:N
            good = false;
            while ~good
                cand = randi(360);
                if all(circDist(cand, cols(1:k-1)) >= mind)
                    cols(k)=cand; good=true;
                end
            end
        end
    end
    T.Colors{ii} = cols;

    % ----- build SegmentOrder & SequenceTag -----
    if strcmp(cnd,'GS') && R>0
        % group step + (N-R) singleton steps
        nseq = 1 + (N - R);
        segs = cell(1, nseq);

        % randomly place the group step among the nseq slots
        gp = randi(nseq);
        segs{gp} = dupPos(:)';                   % group indices together

        % fill the other slots with singletons (uniques in ascending order)
        uSorted = sort(uniqPos);
        uidx = 1;
        for s = 1:nseq
            if isempty(segs{s})
                segs{s} = uSorted(uidx);
                uidx = uidx + 1;
            end
        end

        % make tag like 'URGUU' (N depends on set size)
        tag = strings(1,nseq);
        for s=1:nseq
            if numel(segs{s})>1, tag(s)="RG"; else, tag(s)="U"; end
        end
        T.SequenceTag{ii} = join(tag,"");
        T.Nseq(ii)        = nseq;
        T.SegmentOrder{ii}= segs;

    else
        % Baseline or RS → N singleton steps total
        nseq = N;
        segs = cell(1, nseq);

        if R==0   % Baseline: 1..N in index order
            for s=1:N, segs{s} = s; end
            tag = repmat("U",1,N);
        else
            % RS: put the R redundant indices in ADJACENT steps (block),
            % remaining steps are uniques. Choose block start freely.
            blockStart = randi(N-R+1);                     % steps 1..(N-R+1)
            rSorted    = sort(dupPos);
            uSorted    = sort(uniqPos);

            % fill block (redundant singletons in ascending index order)
            for k=1:R
                segs{blockStart + k - 1} = rSorted(k);
            end
            % fill the rest with uniques (ascending)
            uidx=1;
            for s=1:N
                if isempty(segs{s})
                    segs{s} = uSorted(uidx);
                    uidx = uidx + 1;
                end
            end

            % tag like 'RRUU','URRU',... (length N)
            tag = strings(1,N);
            for s=1:N
                if ismember(segs{s}, dupPos), tag(s)="R"; else, tag(s)="U"; end
            end
        end

        T.SequenceTag{ii} = join(tag,"");
        T.Nseq(ii)        = nseq;
        T.SegmentOrder{ii}= segs;
    end

    % ----- pick target (by cue) -----
    if R>0 && T.CueType{ii}=="R"
        pool = dupPos;
    else
        pool = uniqPos;
        if isempty(pool)  % baseline safety
            pool = 1:N;
        end
    end
    T.Target(ii) = pool(randi(numel(pool)));
end

% final row index
T.Index = (1:n)';

end

% circular distance in degrees
function d = circDist(a,b)
d = abs(a-b);
d = min(d,360-d);
end
