function [pracTbl, mainTbl] = TrialMatrixSeqGG(design, sessionN, participantID, age, timestamp)
%======================================================================
% TrialMatrixSeqGS: group + singleton ordering, blocked ItemN
%   design.ItemNList    = [3 4 6]
%   design.RedundantMap = { [0 2], [0 2], [0 3] }
%   design.CueBalance   = {'noRedundant','cueR','cueNR'}
%   design.PracticeReps, design.MainReps, design.presDur, design.retDur
%======================================================================
global V;
  % 1) one rep of each ItemN × CueBalance
  rows = {};
  for b=1:numel(design.ItemNList)
    N    = design.ItemNList(b);
    reds = design.RedundantMap{b};
    for cb = design.CueBalance
      switch cb{1}
        case 'noRedundant'
          R = 0;
        case 'cueR'
          R = reds(end);
        case 'cueNR'
          R = reds(end);
      end
      rows(end+1,:) = {N, R, cb{1}}; %#ok<AGROW>
    end
  end
  baseTbl = cell2table(rows, 'VariableNames', {'ItemN','RedundantN','CueType'});

  % 2) inflate
  pracRows = repelem(baseTbl, design.PracticeReps, 1);
  mainRows = repelem(baseTbl, design.MainReps,     1);
  % 3) block‐shuffle
  pracTbl = blockByItem(pracRows, design.ItemNList);
  mainTbl = blockByItem(mainRows, design.ItemNList);
  % 4) enrich
  pracTbl = enrich(pracTbl, sessionN, participantID, age, timestamp);
  mainTbl = enrich(mainTbl, sessionN, participantID, age, timestamp);
  % 5) durations
  for T = {pracTbl, mainTbl}
    T{1}.presDur = repmat(design.presDur, height(T{1}), 1);
    T{1}.retDur  = repmat(design.retDur,  height(T{1}), 1);
  end
  % 6) two‐segment order
  pracTbl = addSequenceGG(pracTbl);
  mainTbl = addSequenceGG(mainTbl);
end

% ─────────────────────────────────────────────────────────────────────
function tblOut = blockByItem(tblIn, itemList)
  tblOut = table();
  for i=1:numel(itemList)
    block = tblIn(tblIn.ItemN==itemList(i),:);
    tblOut = [tblOut; block(randperm(height(block)),:)];
  end
end

% ─────────────────────────────────────────────────────────────────────
function T = enrich(coreTbl, sessionN, pid, age, ts)
  global V;
  n = height(coreTbl);
  T = coreTbl;

  % IDs & session info
  T.ID        = repmat({pid},n,1);
  T.Age       = repmat(age, n,1);
  T.SessionN  = repmat(sessionN,n,1);
  T.StartTime = repmat({ts},n,1);
  T.CuedFeature   = repmat({'Color'},n,1);
  T.CuedFeature_i = zeros(n,1);
  T.WheelRotation = repmat(V.color.rotation,n,1);

  % prepare storage for colours & responses
  emptyC = {nan};
  for f = {'Colors','StimulusLocations','MouseX','MouseY','MouseAngles','MouseDistances','MouseTime'}
    T.(f{1}) = emptyC(ones(n,1));
  end
  for f = {'Target','ResponseAngle','DerotatedResponseAngle','Precision','ResponseTime','MouseInitTooSlow','MouseInitTooFast','TrialTooSlow'}
    T.(f{1}) = nan(n,1);
  end

  % assign colours, fixed 12-o'clock base positions, grouping & targets
  for ii=1:n
    N = T.ItemN(ii);
    R = T.RedundantN(ii);

    % colours (as before)
    dupCol  = randi(360);
    dupPos  = randperm(N,R);
    cols    = zeros(1,N);
    cols(dupPos) = dupCol;
    upos    = setdiff(1:N,dupPos);
    filled  = 0; mind = 30;
    while filled < numel(upos)
      cand = randi(360);
      if circDist(cand,dupCol)<mind, continue; end
      if filled>0 && any(circDist(cand,cols(upos(1:filled)))<mind), continue; end
      filled=filled+1; cols(upos(filled))=cand;
    end
    T.Colors{ii} = cols;

    % fixed positions (12o’clock = 90°)
    T.StimulusLocations{ii} = 90 + (0:N-1)*(360/N);

    % grouping label (optional)
    if R>0 && areGrouped(dupPos,N)
      T.Grouping{ii} = 'Grouped';
    else
      T.Grouping{ii} = 'Separate';
    end

    % target pool
    if strcmp(T.CueType{ii},'R') && R>0
      pool = dupPos;
    else
      pool = setdiff(1:N, dupPos);
    end
    T.Target(ii) = pool(randi(numel(pool)));
  end

  T.Index = (1:n)';
end

% ─────────────────────────────────────────────────────────────────────
function T = addSequenceGG(T)
  n = height(T);
  T.Nseq = repmat(2,n,1);
  T.SegmentOrder = cell(n,1);
  for i=1:n
    N = T.ItemN(i);
    R = T.RedundantN(i);
    dupPos = find(T.Colors{i} == mode(T.Colors{i}));
    if R>0
      group1 = dupPos(:)';                           % redundant group
      group2 = setdiff(1:N, dupPos, 'stable');      % the rest
    else
      if N==3
        k = randi([1,2]);                           % either 1 or 2 items
      else
        k = N/2;                                    % half for 4 or 6
      end
      group1 = 1:k;                                 % lowest‐index items
      group2 = (k+1):N;
    end
    % randomize order
    if rand<.5
      T.SegmentOrder{i} = {group1, group2};
    else
      T.SegmentOrder{i} = {group2, group1};
    end
  end
end

% reusable circular‐distance & grouping tests
function d = circDist(a,b)
  d = abs(a-b); d = min(d,360-d);
end
function tf = areGrouped(pos,N)
  tf=false; R=numel(pos);
  for k=1:R
    block = mod(pos(k)-1 + (0:R-1),N)+1;
    if all(ismember(block,pos)), tf=true; return; end
  end
end