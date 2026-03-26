function [pracTbl, mainTbl] = TrialMatrixSeq3way_HomoInte(design, sessionN, participantID, age, timestamp)
% TrialMatrixSeq3way_HomoInte
%   Pilot 2: Homogeneous Integration Conditions
%   
%   Conditions:
%     1) Baseline: All unique items (R=0), N=2,6, Low/High noise
%     2) Homo-Space: All same hue (R=N), simultaneous, N=2,6, Low/High noise
%     3) Homo-Time: All same hue (R=N), sequential same location, N=2,6, Low/High noise
%     4) Homo-Space+Time: All same hue (R=N), sequential ACW different locations, N=2,6, Low/High noise
%
%   Trial counts:
%     Baseline: 60 trials per N×Noise combination (240 total)
%     Homo conditions: 20 trials per N×Noise combination (80 each, 240 total)
%   Total: 480 trials

  % -------------------------------
  % 1) Build single trial block (no separate practice/main)
  % -------------------------------
  baseTbl = buildBase(design.ItemNList, design.NoiseLevels, design.BaselineReps, design.HomoReps);

  % Fully randomize all trials (no blocking by set size)
  % This ensures set size, noise level, condition, etc. are all randomized
  mainTbl = baseTbl(randperm(height(baseTbl)), :);

  % Enrich (ids, placeholders, timing)
  mainTbl = enrich(mainTbl, sessionN, participantID, age, timestamp);

  % Durations
  mainTbl.presDur = repmat(design.presDur, height(mainTbl), 1);
  mainTbl.retDur  = repmat(design.retDur,  height(mainTbl), 1);

  % Sequence order, colors, locations
  mainTbl = addSequenceOrderHomo(mainTbl);
  
  % Return empty practice table (for compatibility with calling code)
  pracTbl = table();
end

% ───────────────────────────────── helpers ───────────────────────────────

function baseTbl = buildBase(itemNList, noiseLevels, baselineReps, homoReps)
% Build base table with all condition combinations
% For each N and NoiseLevel:
%   Baseline: baselineReps rows (R=0, Cue='NR', Cond='Baseline')
%     - Half simultaneous, half sequential (randomly assigned per N×Noise combination)
%   Homo-Space: homoReps rows (R=N, Cue='NR', Cond='Homo_Space')
%   Homo-Time: homoReps rows (R=N, Cue='NR', Cond='Homo_Time')
%   Homo-Space+Time: homoReps rows (R=N, Cue='NR', Cond='Homo_SpaceTime')
  rows = {};
  for b = 1:numel(itemNList)
      N = itemNList(b);
      for n = 1:numel(noiseLevels)
          noise = noiseLevels{n};
          
          % Baseline (R=0): Split half simultaneous, half sequential
          % Create random assignment for this N×Noise combination
          presentationTypes = repmat({'sequential'}, baselineReps, 1);
          numSimultaneous = floor(baselineReps / 2);
          simultaneousIdx = randperm(baselineReps, numSimultaneous);
          for idx = simultaneousIdx
              presentationTypes{idx} = 'simultaneous';
          end
          
          for k = 1:baselineReps
              rows(end+1,:) = {N, 0, 'NR', 'Baseline', noise, presentationTypes{k}}; %#ok<AGROW>
          end
          
          % Homogeneous conditions (R=N)
          for k = 1:homoReps
              rows(end+1,:) = {N, N, 'NR', 'Homo_Space', noise, 'simultaneous'}; %#ok<AGROW>
          end
          for k = 1:homoReps
              rows(end+1,:) = {N, N, 'NR', 'Homo_Time', noise, 'sequential'}; %#ok<AGROW>
          end
          for k = 1:homoReps
              rows(end+1,:) = {N, N, 'NR', 'Homo_SpaceTime', noise, 'sequential'}; %#ok<AGROW>
          end
      end
  end
  baseTbl = cell2table(rows, 'VariableNames', {'ItemN','RedundantN','CueType','Condition','NoiseLevel','PresentationType'});
end

% Removed blockByItem - now using full randomization instead
% This ensures all conditions (set size, noise, condition type) are randomized together

function T = enrich(coreTbl, sessionN, pid, age, ts)
  % Allocate ids, placeholders; don't set Colors/StimulusLocations yet
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
  for f = {'Colors','StimulusLocations','MouseX','MouseY','MouseAngles','MouseDistances','MouseTime','DupPos','SegmentOrder'}
    T.(f{1}) = emptyCell(ones(n,1));
  end
  for f = {'Target','ResponseAngle','DerotatedResponseAngle','Precision','ResponseTime','MouseInitTooSlow','MouseInitTooFast','TrialTooSlow','Nseq','RingStart'}
    T.(f{1}) = nan(n,1);
  end
  T.SequenceTag = strings(n,1);
  T.Grouping    = repmat({'Separate'}, n,1);
  
  % Initialize PresentationType if not already present (for backward compatibility)
  if ~ismember('PresentationType', T.Properties.VariableNames)
      T.PresentationType = repmat({'sequential'}, n, 1);
  end
end

function T = addSequenceOrderHomo(T)
% Build SegmentOrder, locations, colors for homogeneous conditions
  n = height(T);
  
  for k = 1:n
    N    = T.ItemN(k);
    R    = T.RedundantN(k);
    cond = T.Condition{k};    % 'Baseline' | 'Homo_Space' | 'Homo_Time' | 'Homo_SpaceTime'
    noise = T.NoiseLevel{k};  % 'low' | 'high'
    
    % Set noise level (already in table, but ensure it's set)
    T.NoiseLevel{k} = noise;
    
    switch cond
      case 'Baseline'
        % All unique items
        % Check if simultaneous or sequential presentation
        if ismember('PresentationType', T.Properties.VariableNames) && ...
           strcmp(T.PresentationType{k}, 'simultaneous')
            % Simultaneous presentation (like Homo_Space)
            dupPos = [];
            
            % Single segment containing all items
            segs = {1:N};
            tag = "G";
            
            % Colors: all unique
            cols = pickUniqueHues(N, 30, []);
            
            % Locations: N evenly spaced positions (no rotation needed for simultaneous)
            baseLocs = 90 + (0:N-1)*(360/N);
            locs = baseLocs;
            s0 = 1;  % Not used for simultaneous, but set for consistency
            
            % Grouping
            grouping = 'Grouped';
        else
            % Sequential ACW presentation (default)
            s0 = randi(N);
            ring = circshift(1:N, [0, s0-1]);
            segs = num2cell(ring);
            tag = repmat("U", 1, N);
            dupPos = [];
            
            % Colors: all unique
            cols = pickUniqueHues(N, 30, []);
            
            % Locations: N evenly spaced positions, rotated
            baseLocs = 90 + (0:N-1)*(360/N);
            locs = circshift(baseLocs, [0, s0-1]);
            
            % Grouping
            grouping = 'Separate';
        end
        
      case 'Homo_Space'
        % All same hue, simultaneous (all items in one interval)
        dupPos = 1:N;  % All items are redundant
        
        % Single segment containing all items
        segs = {1:N};
        tag = "G";
        
        % Colors: all same hue
        dupHue = randi(360);
        cols = repmat(dupHue, 1, N);
        
        % Locations: N evenly spaced positions (no rotation needed for simultaneous)
        baseLocs = 90 + (0:N-1)*(360/N);
        locs = baseLocs;
        s0 = 1;  % Not used for simultaneous, but set for consistency
        
        % Grouping
        grouping = 'Grouped';
        
      case 'Homo_Time'
        % All same hue, sequential, same location
        dupPos = 1:N;  % All items are redundant
        
        % N segments, each showing one item at the same location
        % Choose which location (randomly)
        locIdx = randi(N);
        segs = num2cell(1:N);  % Each segment shows one item (1, 2, ..., N)
        tag = repmat("R", 1, N);
        
        % Colors: all same hue
        dupHue = randi(360);
        cols = repmat(dupHue, 1, N);
        
        % Locations: All items at same location angle
        baseLocs = 90 + (0:N-1)*(360/N);
        locs = repmat(baseLocs(locIdx), 1, N);  % All items use same location angle
        s0 = locIdx;  % Starting location index
        
        % Grouping
        grouping = 'Grouped';
        
      case 'Homo_SpaceTime'
        % All same hue, sequential ACW, different locations
        dupPos = 1:N;  % All items are redundant
        
        % ACW ring, rotated
        s0 = randi(N);
        ring = circshift(1:N, [0, s0-1]);
        segs = num2cell(ring);
        tag = repmat("R", 1, N);
        
        % Colors: all same hue
        dupHue = randi(360);
        cols = repmat(dupHue, 1, N);
        
        % Locations: N evenly spaced positions, rotated
        baseLocs = 90 + (0:N-1)*(360/N);
        locs = circshift(baseLocs, [0, s0-1]);
        
        % Grouping
        grouping = 'Grouped';
        
      otherwise
        error('Unknown Condition: %s', cond);
    end
    
    % Write to table
    T.SegmentOrder{k} = segs;
    T.Nseq(k)         = numel(segs);
    T.RingStart(k)    = s0;
    T.SequenceTag(k)  = string(strjoin(tag, ''));
    T.DupPos{k}       = dupPos;
    T.Colors{k}       = cols;
    T.StimulusLocations{k} = locs;
    T.Grouping{k}     = grouping;
    
    % Target: For homogeneous, cue any item (all identical)
    T.Target(k) = randi(N);
    
    % Safety check
    if strcmp(cond, 'Homo_Space')
        % For simultaneous, verify all items in one segment
        assert(numel(segs)==1 && numel(segs{1})==N, ...
            'Homo_Space: should have 1 segment with N items');
    else
        % For sequential, verify each spatial index appears exactly once
        flat = [segs{:}];
        assert(numel(flat)==N && numel(unique(flat))==N, ...
            'Internal build error: segments do not form a partition of 1..N (N=%d).', N);
    end
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
