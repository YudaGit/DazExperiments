function [pracTbl, mainTbl] = TrialMatrixSeqGS(design, sessionN, participantID, age, timestamp)
%======================================================================
% TrialMatrixSeqGS: group + singleton ordering, blocked ItemN
%   design.ItemNList    = [3 4 6]
%   design.RedundantMap = { [0 2], [0 2], [0 3] }
%   design.CueBalance   = {'noRedundant','cueR','cueNR'}
%   design.PracticeReps, design.MainReps, design.presDur, design.retDur
%======================================================================
global V;

  %% 1) Build base table (one rep of each ItemN × CueBalance)
  rows = {};
  for b = 1:numel(design.ItemNList)
    N    = design.ItemNList(b);
    reds = design.RedundantMap{b};
    for cb = design.CueBalance
      switch cb{1}
        case 'noRedundant'
          R = 0; cueType = 'NR';
        case 'cueR'
          R = reds(end); cueType = 'R';
        case 'cueNR'
          R = reds(end); cueType = 'NR';
      end
      rows(end+1,:) = {N, R, cueType}; %#ok<AGROW>
    end
  end
  baseTbl = cell2table(rows,'VariableNames',{'ItemN','RedundantN','CueType'});

  %% 2) Inflate for practice & main
  pracRows = repelem(baseTbl, design.PracticeReps, 1);
  mainRows = repelem(baseTbl, design.MainReps,     1);

  %% 3) Block‐shuffle by ItemN
  pracTbl = blockByItem(pracRows, design.ItemNList);
  mainTbl = blockByItem(mainRows, design.ItemNList);

  %% 4) Enrich with demographics, colours, fixed positions, targets
  pracTbl = enrich(pracTbl, sessionN, participantID, age, timestamp);
  mainTbl = enrich(mainTbl, sessionN, participantID, age, timestamp);

  %% 5) Add presDur, retDur and compute Nseq & balanced group‐position
  pracTbl.presDur = repmat(design.presDur, height(pracTbl), 1);
  pracTbl.retDur  = repmat(design.retDur,  height(pracTbl), 1);
  mainTbl.presDur = repmat(design.presDur, height(mainTbl), 1);
  mainTbl.retDur  = repmat(design.retDur,  height(mainTbl), 1);

  pracTbl = addSequenceOrder(pracTbl);
  mainTbl = addSequenceOrder(mainTbl);
end


%% ───── blockByItem ──────────────────────────────────────────────────────
function tblOut = blockByItem(tblIn, itemList)
  tblOut = table();
  for i = 1:numel(itemList)
    block = tblIn(tblIn.ItemN==itemList(i), :);
    block = block(randperm(height(block)),:);
    tblOut = [tblOut; block]; %#ok<AGROW>
  end
end


%% ───── enrich ───────────────────────────────────────────────────────────
function T = enrich(coreTbl, sessionN, pid, age, ts)
  global V;
  n = height(coreTbl);
  T = coreTbl;

  % Participant & session info
  T.ID        = repmat({pid},    n,1);
  T.Age       = repmat(age,      n,1);
  T.SessionN  = repmat(sessionN, n,1);
  T.StartTime = repmat({ts},     n,1);
  T.CuedFeature   = repmat({'Color'},n,1);
  T.CuedFeature_i = zeros(n,1);
  T.WheelRotation = repmat(V.color.rotation,n,1);

  % Allocate response data columns
  emptyCell = {nan};
  for f = {'Colors','StimulusLocations','MouseX','MouseY','MouseAngles','MouseDistances','MouseTime'}
    T.(f{1}) = emptyCell(ones(n,1));
  end
  for f = {'Target','ResponseAngle','DerotatedResponseAngle','Precision','ResponseTime','MouseInitTooSlow','MouseInitTooFast','TrialTooSlow'}
    T.(f{1}) = nan(n,1);
  end

  % Assign colours, fixed positions, grouping, targets
  for ii = 1:n
    N = T.ItemN(ii);
    R = T.RedundantN(ii);

    % --- colour assignment (as before) ---
    dupCol = randi(360);
    dupPos = randperm(N,R);
    cols   = zeros(1,N);
    cols(dupPos) = dupCol;
    uniquePos = setdiff(1:N, dupPos);
    filled = 0; mind = 30;
    while filled < numel(uniquePos)
      cand = randi(360);
      if circDist(cand, dupCol)<mind, continue; end
      if filled>0 && any(circDist(cand, cols(uniquePos(1:filled)))<mind), continue; end
      filled = filled+1;
      cols(uniquePos(filled)) = cand;
    end
    T.Colors{ii} = cols;

    % --- fixed positions (12-o'clock at 90°) ---
    T.StimulusLocations{ii} = 90 + (0:N-1)*(360/N);

    % --- grouping label (optional) ---
    if R>0 && areGrouped(dupPos,N)
      T.Grouping{ii} = 'Grouped';
    else
      T.Grouping{ii} = 'Separate';
    end

    % --- target selection ---
    if strcmp(T.CueType{ii},'R') && R>0
      pool = dupPos;
    else
      pool = uniquePos;
    end
    T.Target(ii) = pool(randi(numel(pool)));
  end

  % final indexing
  T.Index = (1:n)';
end


%% ───── addSequenceOrder ─────────────────────────────────────────────────
function T = addSequenceOrder(T)
  % For each row, build a cell array of segment‐indices, 
  % insert dupPos at a balanced random position, 
  % singletons in ascending order in the remaining slots.
  n = height(T);
  T.Nseq = nan(n,1);
  T.SegmentOrder = cell(n,1);

  % Group together all trials of same (ItemN,RedundantN) to balance positions
  [G,~,gidx] = unique([T.ItemN T.RedundantN],'rows');
  for gi = 1:size(G,1)
    rows = find(gidx==gi);
    N  = G(gi,1);
    R  = G(gi,2);
    M  = numel(rows);

    if R==0
      % no group segment → just singleton order 1..N
      for k=rows(:)'
        T.Nseq(k) = N;
        T.SegmentOrder{k} = num2cell(1:N);
      end
    else
      % there are R>0 → Nseq = 1 + (N-R)
      nseq = 1 + (N-R);
      % balanced random positions for the “group” segment
      posList = repmat(1:nseq, 1, ceil(M/nseq));
      posList = posList(1:M);
      posList = posList(randperm(M));

      for ii = 1:M
        k = rows(ii);
        dupPos    = find(T.Colors{k}==mode(T.Colors{k}));
        uniquePos = setdiff(1:N, dupPos);
        uniquePos = sort(uniquePos);

        % build empty cell array
        segs = cell(1,nseq);
        % place group
        gp = posList(ii);
        segs{gp} = dupPos(:)';

        % fill singletons in the other slots, in order
        uidx = 1;
        for s = 1:nseq
          if isempty(segs{s})
            segs{s} = uniquePos(uidx);
            uidx = uidx+1;
          end
        end

        T.Nseq(k) = nseq;
        T.SegmentOrder{k} = segs;
      end
    end
  end
end


%% ───── circDist & areGrouped ────────────────────────────────────────────
function d = circDist(a,b)
  d = abs(a-b);
  d = min(d,360-d);
end

function tf = areGrouped(pos,N)
  R = numel(pos);
  tf = false;
  for k=1:R
    block = mod(pos(k)-1 + (0:R-1), N) + 1;
    if all(ismember(block,pos))
      tf = true; return;
    end
  end
end