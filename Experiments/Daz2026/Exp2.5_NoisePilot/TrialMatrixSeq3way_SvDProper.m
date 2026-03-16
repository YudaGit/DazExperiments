function [pracTbl, mainTbl] = TrialMatrixSeq3way_SvDProper(design, sessionN, participantID, age, timestamp)
% TrialMatrixSeq3way_SvDProper
%   Pilot: Set-size 1 + Statistical vs Deterministic (SvD Proper)
%
%   Conditions:
%     - Set size 1: Single condition per noise (baseline = homogeneous for N=1).
%       One condition "SetSize1", low/high noise only. SetSize1Reps per noise.
%     - Set size 2 & 6: Baseline (R=0) + Homo_Space (R=N), each low/high noise.
%       BaselineReps and HomoReps per N×Noise combination.
%
%   Sampling mode (deterministic vs statistical) is alternated by session
%   and is set in the main pilot script, not in the trial matrix.
%
%   Trial counts (example with SetSize1Reps=20, BaselineReps=20, HomoReps=20):
%     SetSize1: 2 noises × 20 = 40
%     N=2: 2 noises × (20+20) = 80
%     N=6: 2 noises × (20+20) = 80
%     Total: 200 trials

  % -------------------------------
  % 1) Build single trial block (no separate practice/main)
  % -------------------------------
  baseTbl = buildBase(design.ItemNList, design.NoiseLevels, ...
      design.SetSize1Reps, design.BaselineReps, design.HomoReps);

  % Fully randomize all trials
  mainTbl = baseTbl(randperm(height(baseTbl)), :);

  % Enrich (ids, placeholders, timing)
  mainTbl = enrich(mainTbl, sessionN, participantID, age, timestamp);

  % Durations
  mainTbl.presDur = repmat(design.presDur, height(mainTbl), 1);
  mainTbl.retDur  = repmat(design.retDur,  height(mainTbl), 1);

  % Sequence order, colors, locations
  mainTbl = addSequenceOrderSvD(mainTbl);

  pracTbl = table();
end

% ───────────────────────────────── helpers ───────────────────────────────

function baseTbl = buildBase(itemNList, noiseLevels, setSize1Reps, baselineReps, homoReps)
% Build base table with all condition combinations.
% - For N=1: only "SetSize1" condition, setSize1Reps per noise (no baseline vs homo).
% - For N=2,6: Baseline + Homo_Space, baselineReps and homoReps per N×noise.
  rows = {};
  for b = 1:numel(itemNList)
    N = itemNList(b);
    for n = 1:numel(noiseLevels)
      noise = noiseLevels{n};

      if N == 1
        % Set-size 1: single condition (baseline and homo are the same)
        for k = 1:setSize1Reps
          rows(end+1,:) = {N, 1, 'NR', 'SetSize1', noise, 'simultaneous'}; %#ok<AGROW>
        end
      else
        % N=2 or 6: Baseline and Homo_Space
        for k = 1:baselineReps
          rows(end+1,:) = {N, 0, 'NR', 'Baseline', noise, 'simultaneous'}; %#ok<AGROW>
        end
        for k = 1:homoReps
          rows(end+1,:) = {N, N, 'NR', 'Homo_Space', noise, 'simultaneous'}; %#ok<AGROW>
        end
      end
    end
  end
  baseTbl = cell2table(rows, 'VariableNames', ...
      {'ItemN','RedundantN','CueType','Condition','NoiseLevel','PresentationType'});
end

function T = enrich(coreTbl, sessionN, pid, age, ts)
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

  emptyCell = {nan};
  for f = {'Colors','StimulusLocations','MouseX','MouseY','MouseAngles','MouseDistances','MouseTime','DupPos','SegmentOrder','MeanOffsets','BaseHues','TileRGB','TileHues'}
    T.(f{1}) = emptyCell(ones(n,1));
  end
  for f = {'Target','TargetHue','ResponseAngle','DerotatedResponseAngle','Precision','ResponseTime','MouseInitTooSlow','MouseInitTooFast','TrialTooSlow','Nseq','RingStart'}
    T.(f{1}) = nan(n,1);
  end
  T.SequenceTag = strings(n,1);
  T.Grouping   = repmat({'Separate'}, n,1);

  if ~ismember('PresentationType', T.Properties.VariableNames)
    T.PresentationType = repmat({'sequential'}, n, 1);
  end
end

function T = addSequenceOrderSvD(T)
% Build SegmentOrder, locations, colors for SetSize1, Baseline, and Homo_Space.
  n = height(T);

  for k = 1:n
    N    = T.ItemN(k);
    R    = T.RedundantN(k);
    cond = T.Condition{k};
    noise = T.NoiseLevel{k};
    T.NoiseLevel{k} = noise;

    switch cond
      case 'SetSize1'
        % N=1: single item, one segment, one location, one color
        dupPos = 1;
        segs = {1};
        tag = "G";
        cols = [randi(360)];  % 1×1 row for consistency with N>1
        baseLocs = 90;
        locs = baseLocs;
        s0 = 1;
        grouping = 'Grouped';

      case 'Baseline'
        % All unique items (simultaneous)
        dupPos = [];
        segs = {1:N};
        tag = "G";
        cols = pickUniqueHues(N, 30, []);
        baseLocs = 90 + (0:N-1)*(360/N);
        locs = baseLocs;
        s0 = 1;
        grouping = 'Grouped';

      case 'Homo_Space'
        dupPos = 1:N;
        segs = {1:N};
        tag = "G";
        dupHue = randi(360);
        cols = repmat(dupHue, 1, N);
        baseLocs = 90 + (0:N-1)*(360/N);
        locs = baseLocs;
        s0 = 1;
        grouping = 'Grouped';

      otherwise
        error('Unknown Condition: %s', cond);
    end

    T.SegmentOrder{k} = segs;
    T.Nseq(k)         = numel(segs);
    T.RingStart(k)    = s0;
    T.SequenceTag(k)  = string(strjoin(tag, ''));
    T.DupPos{k}       = dupPos;
    T.Colors{k}       = cols;
    T.StimulusLocations{k} = locs;
    T.Grouping{k}     = grouping;
    T.Target(k)       = randi(N);

    if N == 1
      assert(numel(segs)==1 && numel(segs{1})==1, 'SetSize1 should have 1 segment with 1 item');
    else
      assert(numel(segs)==1 && numel(segs{1})==N, 'Baseline/Homo_Space should have 1 segment with N items');
    end
  end
end

function hues = pickUniqueHues(n, mindeg, avoidHueOrEmpty)
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
