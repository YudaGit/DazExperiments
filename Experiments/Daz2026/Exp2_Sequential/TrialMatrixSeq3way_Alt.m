function [pracTbl, mainTbl] = TrialMatrixSeq3way_ACW(design, sessionN, participantID, age, timestamp)
% 3-way sequential: Baseline (all-unique), RS (redundant singletons), GS (redundant group)
% ACW presentation always; ring rotated by random integer steps each trial.
% RS: contiguous redundant block (in time), NO wrap; GS: one multi-item group, WRAP allowed.
% SegmentOrder is a 1xK cell: singletons are scalars; the GS group is a row-vector.
%
% Columns added: SegmentOrder, Nseq, RingStart, SequenceTag, DupPos, StimulusLocations, Colors, Grouping.

  % -------------------------------
  % 1) Build practice & main bases
  % -------------------------------
  pracBase = buildBase(design.ItemNList, design.RedundantMap);
  mainBase = buildBase(design.ItemNList, design.RedundantMap);

  % Inflate according to reps
  pracRows = repelem(pracBase, design.PracticeReps, 1);
  mainRows = repelem(mainBase, design.MainReps,     1);

  % Block-shuffle by ItemN
  pracTbl = blockByItem(pracRows, design.ItemNList);
  mainTbl = blockByItem(mainRows, design.ItemNList);

  % Enrich (ids, placeholders, timing)
  pracTbl = enrich(pracTbl, sessionN, participantID, age, timestamp);
  mainTbl = enrich(mainTbl, sessionN, participantID, age, timestamp);

  % Durations
  pracTbl.presDur = repmat(design.presDur, height(pracTbl), 1);
  pracTbl.retDur  = repmat(design.retDur,  height(pracTbl), 1);
  mainTbl.presDur = repmat(design.presDur, height(mainTbl), 1);
  mainTbl.retDur  = repmat(design.retDur,  height(mainTbl), 1);

  % ACW segments + colors + locations
  pracTbl = addSequenceOrderACW(pracTbl);
  mainTbl = addSequenceOrderACW(mainTbl);
end

% ───────────────────────────────── helpers ───────────────────────────────

function baseTbl = buildBase(itemNList, redundantMap)
% Rows with columns: ItemN, RedundantN, CueType, Condition (all as cell strings)
% For each N:
%   Baseline: 1 row (R=0, Cue='NR', Cond='Baseline')
%   RS      : 2 rows (R>0, Cue='R' & 'NR', Cond='RS')
%   GS      : 2 rows (R>0, Cue='R' & 'NR', Cond='GS')
  rows = {};
  for b = 1:numel(itemNList)
      N    = itemNList(b);
      reds = redundantMap{b};
      Rval = reds(end);            % e.g., 2 for N=4, 3 for N=6

      rows(end+1,:) = {N, 0,    'NR', 'Baseline'}; %#ok<AGROW>
      rows(end+1,:) = {N, Rval, 'R',  'RS'      }; %#ok<AGROW>
      rows(end+1,:) = {N, Rval, 'NR', 'RS'      }; %#ok<AGROW>
      rows(end+1,:) = {N, Rval, 'R',  'GS'      }; %#ok<AGROW>
      rows(end+1,:) = {N, Rval, 'NR', 'GS'      }; %#ok<AGROW>
  end
  baseTbl = cell2table(rows, 'VariableNames', {'ItemN','RedundantN','CueType','Condition'});
end

function tblOut = blockByItem(tblIn, itemList)
  tblOut = table();
  for i = 1:numel(itemList)
      blk = tblIn(tblIn.ItemN==itemList(i), :);
      tblOut = [tblOut; blk(randperm(height(blk)), :)]; %#ok<AGROW>
  end
end

function T = enrich(coreTbl, sessionN, pid, age, ts)
  % Allocate ids, placeholders; don't set Colors/StimulusLocations yet—we’ll set them in addSequenceOrderACW
  global V
  n = height(coreTbl);
  T = coreTbl;

  T.ID        = repmat({pid},    n,1);
  T.Age       = repmat(age,      n,1);
  T.SessionN  = repmat(sessionN, n,1);
  T.StartTime = repmat({ts},     n,1);
  T.CuedFeature   = repmat({'Color'}, n,1);
  T.CuedFeature_i = zeros(n,1);
  T.WheelRotation = repmat(V.color.rotation, n,1);

  % pre-allocate data columns
  emptyCell = {nan};
  for f = {'Colors','StimulusLocations','MouseX','MouseY','MouseAngles','MouseDistances','MouseTime','DupPos'}
    T.(f{1}) = emptyCell(ones(n,1));
  end
  for f = {'Target','ResponseAngle','DerotatedResponseAngle','Precision','ResponseTime','MouseInitTooSlow','MouseInitTooFast','TrialTooSlow'}
    T.(f{1}) = nan(n,1);
  end
end

function T = addSequenceOrderACW(T)
% Build SegmentOrder (cell of scalars or one vector for GS), RingStart, SequenceTag.
% Guarantee: flatten(SegmentOrder) lists each spatial index 1..N exactly once.
  n = height(T);
  T.SegmentOrder = cell(n,1);
  T.Nseq         = nan(n,1);
  T.RingStart    = nan(n,1);
  T.SequenceTag  = strings(n,1);
  T.Grouping     = repmat({'Separate'}, n,1);

  for k = 1:n
    N    = T.ItemN(k);
    R    = T.RedundantN(k);
    cond = T.Condition{k};    % 'Baseline' | 'RS' | 'GS'

    % ACW ring, rotated
    s0   = randi(N);                          % 1..N
    ring = circshift(1:N, [0, s0-1]);         % ACW order of spatial indices

    switch cond
      case 'Baseline'
        segs = num2cell(ring);
        tag  = strjoin(string(1:N),' ');
        dupPos = [];

      case 'RS'   % adjacent singletons, NO wrap (in time)
        b = randi(N - R + 1);                 % start of R-block in timeline (1..N-R+1)
        dupPos = ring(b:b+R-1);

        segs = {};
        lab  = strings(1,0);
        i    = 1;
        while i <= N
          if i == b
            rr = ring(i:i+R-1);
            segs = [segs, num2cell(rr)];      %#ok<AGROW>
            lab  = [lab, repmat("R",1,R)];    %#ok<AGROW>
            i = i + R;
          else
            segs{end+1} = ring(i);            %#ok<AGROW>
            lab(end+1)  = "U";                %#ok<AGROW>
            i = i + 1;
          end
        end
        tag = strjoin(lab,'');

      case 'GS'   % one multi-item group, WRAP allowed (in time & space)
        b  = randi(N);                                        % group starts at timeline index b
        idxsTimeline = mod((b-1):(b+R-2), N) + 1;             % timeline indices occupied by group
        dupPos = ring(idxsTimeline);                          % spatial indices in the group

        inGroup = false(1,N);
        inGroup(idxsTimeline) = true;

        segs = {};
        lab  = strings(1,0);
        i    = 1;
        while i <= N
          if i == b
            grp = ring(idxsTimeline);                         % one vector segment
            segs{end+1} = grp;                                %#ok<AGROW>
            lab(end+1)  = "G";                                %#ok<AGROW>
            % jump over the group; if wrap occurs this will end the loop, which is fine—
            % earlier wrapped positions were skipped below via inGroup(i) test.
            i = i + R;
          elseif inGroup(i)
            % belongs to the (wrapped) group but occurs before b in the timeline → skip here
            i = i + 1;
          else
            segs{end+1} = ring(i);                            %#ok<AGROW>
            lab(end+1)  = "U";                                %#ok<AGROW>
            i = i + 1;
          end
        end
        tag = strjoin(lab,'');  % "UUUG", "UGUU", etc.

      otherwise
        error('Unknown Condition: %s', cond);
    end

    % Write segments
    T.SegmentOrder{k} = segs;
    T.Nseq(k)         = numel(segs);
    T.RingStart(k)    = s0;
    T.SequenceTag(k)  = string(tag);
    T.DupPos{k}       = dupPos;

    % Colors to match dupPos (if any)
    cols = zeros(1,N);
    if ~isempty(dupPos)
      dupHue = randi(360);
      cols(dupPos) = dupHue;
      uniq = setdiff(1:N, dupPos);
      cols(uniq) = pickUniqueHues(numel(uniq), 30, dupHue);
      T.Grouping{k} = 'Grouped';
    else
      cols = pickUniqueHues(N, 30, []);
      T.Grouping{k} = 'Separate';
    end
    T.Colors{k} = cols;

    % Fixed ring angles (ACW) rotated by s0 so item indices and SegmentOrder align spatially
    baseLocs = 90 + (0:N-1)*(360/N);
    T.StimulusLocations{k} = circshift(baseLocs, [0, s0-1]);

    % Target pool by cue
    if ~isempty(dupPos) && strcmp(T.CueType{k},'R')
      pool = dupPos;
    else
      pool = setdiff(1:N, dupPos);
    end
    T.Target(k) = pool(randi(numel(pool)));

    % Safety: each spatial index appears exactly once across the segments
    flat = [segs{:}];
    assert(numel(flat)==N && numel(unique(flat))==N, ...
      'Internal build error: segments do not form a partition of 1..N (N=%d).', N);
  end
end

function hues = pickUniqueHues(n, mindeg, avoidHueOrEmpty)
% Return n integers in [1..360] with >= mindeg spacing; if avoidHue given, keep distance to it as well.
  hues = zeros(1,n);
  k=0; tries=0;
  while k<n
    cand = randi(360);
    if ~isempty(avoidHueOrEmpty)
      if circdist(cand, avoidHueOrEmpty) < mindeg
        tries=tries+1; if tries<500, continue; end
      end
    end
    ok = true;
    for j=1:k
      if circdist(cand, hues(j)) < mindeg, ok=false; break; end
    end
    if ok
      k=k+1; hues(k)=cand; tries=0;
    else
      tries=tries+1; if tries>1000, k=k+1; hues(k)=cand; tries=0; end
    end
  end
end

function d = circdist(a,b)
  d = abs(a-b); d = min(d,360-d);
end
