function [pracTbl, mainTbl] = TrialMatrixSeq3way_STInte(design, sessionN, participantID, age, timestamp)
% TrialMatrixSeq3way_STInte
%   Pilot 1: Main Redundancy Integration (Space-Time)
%   
%   Conditions:
%     1) Baseline: All unique items (R=0), N=4,6, High noise only
%     2) RS_TimeOnly: R redundant items at same location, N=4 (R=2), N=6 (R=3), High noise
%     3) RS_SpaceTime: R redundant items at different locations (ACW), N=4 (R=2), N=6 (R=3), High noise
%     4) RedundantGrouped: R redundant items grouped in one interval, N=4 (R=2), N=6 (R=3), High noise
%
%   Trial counts per set size:
%     Baseline: 80 trials
%     RS_TimeOnly: 80 trials (40 R-cue + 40 NR-cue)
%     RS_SpaceTime: 80 trials (40 R-cue + 40 NR-cue)
%     RedundantGrouped: 80 trials (40 R-cue + 40 NR-cue)
%   Total: 320 trials per set size, 640 total

  % -------------------------------
  % 1) Build single trial block (no separate practice/main)
  % -------------------------------
  baseTbl = buildBase(design.ItemNList, design.NoiseLevels, design.BaselineReps, design.RSReps, design.GroupedReps);

  % Fully randomize all trials (no blocking by set size)
  % This ensures set size, noise level, condition, etc. are all randomized
  mainTbl = baseTbl(randperm(height(baseTbl)), :);

  % Enrich (ids, placeholders, timing)
  mainTbl = enrich(mainTbl, sessionN, participantID, age, timestamp);

  % Durations
  mainTbl.presDur = repmat(design.presDur, height(mainTbl), 1);
  mainTbl.retDur  = repmat(design.retDur,  height(mainTbl), 1);

  % Sequence order, colors, locations
  mainTbl = addSequenceOrderST(mainTbl);
  
  % Return empty practice table (for compatibility with calling code)
  pracTbl = table();
end

% ───────────────────────────────── helpers ───────────────────────────────

function baseTbl = buildBase(itemNList, noiseLevels, baselineReps, rsReps, groupedReps)
% Build base table with all condition combinations
% For each N and NoiseLevel:
%   Baseline: baselineReps rows (R=0, Cue='NR', Cond='Baseline')
%     - Half simultaneous, half sequential (randomly assigned per N×Noise combination)
%   RS_TimeOnly: rsReps rows (R=2 for N=4, R=3 for N=6, Cue='R' or 'NR', Cond='RS_TimeOnly')
%   RS_SpaceTime: rsReps rows (R=2 for N=4, R=3 for N=6, Cue='R' or 'NR', Cond='RS_SpaceTime')
%   RedundantGrouped: groupedReps rows (R=2 for N=4, R=3 for N=6, Cue='R' or 'NR', Cond='RedundantGrouped')
  rows = {};
  for b = 1:numel(itemNList)
      N = itemNList(b);
      % Determine R based on N: N=4 → R=2, N=6 → R=3
      R = N/2;  % R=2 for N=4, R=3 for N=6
      
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
          
          % RS_TimeOnly: 40 R-cue + 40 NR-cue = 80 total
          for k = 1:rsReps/2
              rows(end+1,:) = {N, R, 'R', 'RS_TimeOnly', noise, 'sequential'}; %#ok<AGROW>
          end
          for k = 1:rsReps/2
              rows(end+1,:) = {N, R, 'NR', 'RS_TimeOnly', noise, 'sequential'}; %#ok<AGROW>
          end
          
          % RS_SpaceTime: 40 R-cue + 40 NR-cue = 80 total
          for k = 1:rsReps/2
              rows(end+1,:) = {N, R, 'R', 'RS_SpaceTime', noise, 'sequential'}; %#ok<AGROW>
          end
          for k = 1:rsReps/2
              rows(end+1,:) = {N, R, 'NR', 'RS_SpaceTime', noise, 'sequential'}; %#ok<AGROW>
          end
          
          % RedundantGrouped: 40 R-cue + 40 NR-cue = 80 total
          for k = 1:groupedReps/2
              rows(end+1,:) = {N, R, 'R', 'RedundantGrouped', noise, 'sequential'}; %#ok<AGROW>
          end
          for k = 1:groupedReps/2
              rows(end+1,:) = {N, R, 'NR', 'RedundantGrouped', noise, 'sequential'}; %#ok<AGROW>
          end
      end
  end
  baseTbl = cell2table(rows, 'VariableNames', {'ItemN','RedundantN','CueType','Condition','NoiseLevel','PresentationType'});
end

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

function T = addSequenceOrderST(T)
% Build SegmentOrder, locations, colors for Pilot 1 conditions
% Conditions: Baseline, RS_TimeOnly, RS_SpaceTime, RedundantGrouped
  n = height(T);
  
  for k = 1:n
    N    = T.ItemN(k);
    R    = T.RedundantN(k);
    cond = T.Condition{k};    % 'Baseline' | 'RS_TimeOnly' | 'RS_SpaceTime' | 'RedundantGrouped'
    cue  = T.CueType{k};      % 'R' | 'NR'
    noise = T.NoiseLevel{k};  % 'high' (only high noise in Pilot 1)
    
    % Set noise level (already in table, but ensure it's set)
    T.NoiseLevel{k} = noise;
    
    switch cond
      case 'Baseline'
        % All unique items
        % Check if simultaneous or sequential presentation
        if ismember('PresentationType', T.Properties.VariableNames) && ...
           strcmp(T.PresentationType{k}, 'simultaneous')
            % Simultaneous presentation (all items in one interval)
            dupPos = [];
            
            % Single segment containing all items
            segs = {1:N};
            tag = "G";
            
            % Colors: all unique
            cols = pickUniqueHues(N, 30, []);
            
            % Locations: N evenly spaced positions (no rotation needed for simultaneous)
            baseLocs = 90 + (0:N-1)*(360/N);
            locs = baseLocs;
            % Normalize to 0-360 range
            locs = mod(locs, 360);
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
            % All locations on invisible circle, evenly spaced
            baseLocs = 90 + (0:N-1)*(360/N);
            locs = circshift(baseLocs, [0, s0-1]);
            % Normalize to 0-360 range
            locs = mod(locs, 360);
            
            % Grouping
            grouping = 'Separate';
        end
        
      case 'RS_TimeOnly'
        % R redundant items at SAME location across intervals
        % Number of unique spatial locations = N-R+1 (fewer locations than items)
        % Example: N=4, R=2 → 3 locations (one location shows R items, two show unique items)
        % Sequence: R items appear consecutively at same location, randomly positioned in ACW sequence
        % Locations must be evenly spaced around the circle
        
        numLocs = N - R + 1;  % Number of unique spatial locations
        
        % Create base locations: evenly spaced around circle
        baseLocs = 90 + (0:numLocs-1)*(360/numLocs);
        
        % Rotate locations by random amount (ACW rotation)
        s0 = randi(numLocs);
        rotatedLocs = circshift(baseLocs, [0, s0-1]);
        
        % Choose which location will show redundant items (in rotated order)
        redundantLocIdx = randi(numLocs);
        redundantLocAngle = rotatedLocs(redundantLocIdx);
        
        % Build ACW-ordered sequence of locations
        % Start from a random location to randomize starting point
        startLocIdx = randi(numLocs);
        startLocAngle = rotatedLocs(startLocIdx);
        
        % Sort all locations in ACW order starting from startLocAngle
        distances = mod(rotatedLocs - startLocAngle + 360, 360);
        [~, sortIdx] = sort(distances);
        acwOrderedLocs = rotatedLocs(sortIdx);
        
        % Find where redundant location appears in ACW order
        redundantPosInOrder = find(acwOrderedLocs == redundantLocAngle, 1);
        if isempty(redundantPosInOrder)
            error('RS_TimeOnly: Redundant location not found in ACW order');
        end
        
        % Build location sequence: replace single occurrence with R consecutive copies
        % This maintains ACW progression because redundant location is already in correct ACW position
        acwLocSequence = [acwOrderedLocs(1:redundantPosInOrder-1), ...
                          repmat(redundantLocAngle, 1, R), ...
                          acwOrderedLocs(redundantPosInOrder+1:end)];
        
        % Verify we have exactly N locations
        if length(acwLocSequence) ~= N
            error('RS_TimeOnly: Location sequence length mismatch. Expected %d, got %d', N, length(acwLocSequence));
        end
        
        % Build segments: map location sequence to item indices
        % Items 1:R are redundant, items R+1:N are unique
        segs = {};
        tag = strings(1,0);
        rItemIdx = 1;
        uItemIdx = R + 1;
        
        for seqPos = 1:N
            locAngle = acwLocSequence(seqPos);
            if locAngle == redundantLocAngle && rItemIdx <= R
                % This is an R item position - create singleton segment
                segs{end+1} = rItemIdx;  %#ok<AGROW>
                tag(end+1) = "R";  %#ok<AGROW>
                rItemIdx = rItemIdx + 1;
            else
                % This is a unique item position - create singleton segment
                segs{end+1} = uItemIdx;  %#ok<AGROW>
                tag(end+1) = "U";  %#ok<AGROW>
                uItemIdx = uItemIdx + 1;
            end
        end
        
        % Verify: should have exactly N segments, all singletons
        assert(numel(segs) == N, 'RS_TimeOnly: Expected %d segments, got %d', N, numel(segs));
        for s = 1:numel(segs)
            assert(isscalar(segs{s}), 'RS_TimeOnly: Segment %d must be singleton, got %d items', s, numel(segs{s}));
        end
        
        % Assign which items are redundant (first R items)
        dupPos = 1:R;
        uniquePos = (R+1):N;
        
        % Colors: R items same hue, unique items different hues
        % Ensure ALL hues (redundant + unique) are at least 30° apart
        numUnique = numel(uniquePos);
        allUniqueHues = pickUniqueHues(numUnique + 1, 30, []);  % Pick one extra for redundant
        dupHue = allUniqueHues(1);  % Use first as redundant hue
        cols = zeros(1,N);
        cols(dupPos) = dupHue;
        cols(uniquePos) = allUniqueHues(2:end);  % Remaining hues for unique items
        
        % Locations: map from location sequence to item locations
        % R items all get redundantLocAngle, unique items get their assigned locations
        locs = zeros(1,N);
        rItemIdx = 1;
        uItemIdx = R + 1;
        for seqPos = 1:N
            locAngle = acwLocSequence(seqPos);
            if locAngle == redundantLocAngle && rItemIdx <= R
                locs(rItemIdx) = redundantLocAngle;
                rItemIdx = rItemIdx + 1;
            else
                locs(uItemIdx) = locAngle;
                uItemIdx = uItemIdx + 1;
            end
        end
        % Normalize to 0-360 range
        locs = mod(locs, 360);
        
        grouping = 'Grouped';
        
      case 'RS_SpaceTime'
        % R redundant items at DIFFERENT locations (ACW order)
        % Number of locations = N (all items at different locations)
        % R items appear as adjacent singletons in ACW sequence
        
        % ACW ring, rotated
        s0 = randi(N);
        ring = circshift(1:N, [0, s0-1]);
        
        % Choose R adjacent items in the ACW timeline (no wrap)
        b = randi(N - R + 1);  % Start position in timeline (1..N-R+1)
        dupPos = ring(b:b+R-1);  % R adjacent items in ACW order
        
        % Build segments: R items as adjacent singletons, then unique items
        segs = {};
        tag = strings(1,0);
        i = 1;
        while i <= N
            if i == b
                % R redundant items: each as separate singleton
                for j = 1:R
                    segs{end+1} = ring(i+j-1);  %#ok<AGROW>
                    tag(end+1) = "R";  %#ok<AGROW>
                end
                i = i + R;
            else
                % Unique item
                segs{end+1} = ring(i);  %#ok<AGROW>
                tag(end+1) = "U";  %#ok<AGROW>
                i = i + 1;
            end
        end
        
        % Colors: R items same hue, unique items different hues
        % Ensure ALL hues (redundant + unique) are at least 30° apart
        uniquePos = setdiff(1:N, dupPos);
        numUnique = numel(uniquePos);
        allUniqueHues = pickUniqueHues(numUnique + 1, 30, []);  % Pick one extra for redundant
        dupHue = allUniqueHues(1);  % Use first as redundant hue
        cols = zeros(1,N);
        cols(dupPos) = dupHue;
        cols(uniquePos) = allUniqueHues(2:end);  % Remaining hues for unique items
        
        % Locations: N evenly spaced positions, rotated (all different)
        % All locations on invisible circle, evenly spaced
        baseLocs = 90 + (0:N-1)*(360/N);
        locs = circshift(baseLocs, [0, s0-1]);
        % Normalize to 0-360 range
        locs = mod(locs, 360);
        
        grouping = 'Grouped';
        
      case 'RedundantGrouped'
        % R redundant items grouped in ONE interval (like GS condition)
        % Number of intervals = N-R+1 (one group + N-R singletons)
        
        % ACW ring, rotated
        s0 = randi(N);
        ring = circshift(1:N, [0, s0-1]);
        
        % Choose R items for the group (can wrap in timeline)
        b = randi(N);  % Group starts at timeline index b
        idxsTimeline = mod((b-1):(b+R-2), N) + 1;  % Timeline indices occupied by group
        dupPos = ring(idxsTimeline);  % Spatial indices in the group
        
        % Build segments: one group + singletons
        inGroup = false(1,N);
        inGroup(idxsTimeline) = true;
        
        segs = {};
        tag = strings(1,0);
        i = 1;
        while i <= N
            if i == b
                % Group segment
                grp = ring(idxsTimeline);
                segs{end+1} = grp;  %#ok<AGROW>
                tag(end+1) = "G";  %#ok<AGROW>
                i = i + R;
            elseif inGroup(i)
                % Belongs to wrapped group, skip here (already included)
                i = i + 1;
            else
                % Singleton
                segs{end+1} = ring(i);  %#ok<AGROW>
                tag(end+1) = "U";  %#ok<AGROW>
                i = i + 1;
            end
        end
        
        % Colors: R items same hue, unique items different hues
        % Ensure ALL hues (redundant + unique) are at least 30° apart
        uniquePos = setdiff(1:N, dupPos);
        numUnique = numel(uniquePos);
        allUniqueHues = pickUniqueHues(numUnique + 1, 30, []);  % Pick one extra for redundant
        dupHue = allUniqueHues(1);  % Use first as redundant hue
        cols = zeros(1,N);
        cols(dupPos) = dupHue;
        cols(uniquePos) = allUniqueHues(2:end);  % Remaining hues for unique items
        
        % Locations: N evenly spaced positions, rotated
        % All locations on invisible circle, evenly spaced
        baseLocs = 90 + (0:N-1)*(360/N);
        locs = circshift(baseLocs, [0, s0-1]);
        % Normalize to 0-360 range
        locs = mod(locs, 360);
        
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
    
    % Target: Based on cue type
    if ~isempty(dupPos) && strcmp(cue, 'R')
        % Cue redundant item
        pool = dupPos;
    else
        % Cue non-redundant item
        pool = setdiff(1:N, dupPos);
    end
    T.Target(k) = pool(randi(numel(pool)));
    
    % Safety check: verify segments form a partition of 1..N
    % For equal timing: RS_TimeOnly and RS_SpaceTime must have singleton segments
    % RedundantGrouped can have one group segment (R items simultaneous)
    % Baseline can be simultaneous (1 segment with N items) or sequential (N singleton segments)
    if strcmp(cond, 'RedundantGrouped')
        % RedundantGrouped: one group segment (R items) + singleton segments (unique items)
        % Verify structure: exactly one group segment, rest are singletons
        groupSegCount = 0;
        for s = 1:numel(segs)
            if numel(segs{s}) > 1
                groupSegCount = groupSegCount + 1;
                assert(numel(segs{s}) == R, 'RedundantGrouped: Group segment should contain R=%d items, got %d', R, numel(segs{s}));
            else
                assert(isscalar(segs{s}), 'RedundantGrouped: Non-group segments must be singletons');
            end
        end
        assert(groupSegCount == 1, 'RedundantGrouped: Should have exactly 1 group segment, got %d', groupSegCount);
    elseif strcmp(cond, 'Baseline')
        % Baseline: can be simultaneous (1 segment with N items) or sequential (N singleton segments)
        if numel(segs) == 1
            % Simultaneous: verify single segment contains all N items
            assert(numel(segs{1}) == N, 'Baseline simultaneous: Segment should contain N=%d items, got %d', N, numel(segs{1}));
        else
            % Sequential: verify all segments are singletons
            assert(numel(segs) == N, 'Baseline sequential: Should have N=%d segments, got %d', N, numel(segs));
            for s = 1:numel(segs)
                assert(isscalar(segs{s}), 'Baseline sequential: Segment %d must be a singleton, got %d items', s, numel(segs{s}));
            end
        end
    else
        % RS_TimeOnly and RS_SpaceTime: all segments must be singletons for equal timing
        for s = 1:numel(segs)
            assert(isscalar(segs{s}), 'Condition %s: Segment %d must be a singleton (scalar) for equal timing, got %d items', cond, s, numel(segs{s}));
        end
    end
    
    if strcmp(cond, 'RS_TimeOnly')
        % For RS_TimeOnly, items can appear multiple times at same location
        % So we check that all items 1..N appear at least once
        flat = [segs{:}];
        assert(numel(flat) == N && all(ismember(1:N, flat)), ...
            'RS_TimeOnly: segments must contain all items 1..N (N=%d).', N);
    else
        % For other conditions, each item appears exactly once
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


