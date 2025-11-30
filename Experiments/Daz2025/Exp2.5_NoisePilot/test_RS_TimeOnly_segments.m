% Test RS_TimeOnly segment structure for N=6, R=3
% This will show if R items are in separate segments or grouped

N = 6;
R = 3;
numLocs = N - R + 1;  % 4 locations

% Create test locations
baseLocs = 90 + (0:numLocs-1)*(360/numLocs);
rotatedLocs = baseLocs;  % No rotation for simplicity
redundantLocAngle = rotatedLocs(1);  % First location is redundant

% Get unique locations
remainingLocAngles = rotatedLocs;
remainingLocAngles(1) = [];  % Remove redundant location
uniqueLocAngles = remainingLocAngles;  % [210, 270, 330]

% Build ACW sequence: R items at redundant location, then unique items
% For testing, let's say R items appear first, then unique items
acwLocSequence = [repmat(redundantLocAngle, 1, R), uniqueLocAngles];

fprintf('=== RS_TimeOnly Test: N=%d, R=%d ===\n\n', N, R);
fprintf('Location sequence (ACW order):\n');
for i = 1:N
    fprintf('  Position %d: location %.1f°\n', i, acwLocSequence(i));
end
fprintf('\n');

% Simulate the segment creation logic
segs = {};
tag = strings(1,0);
rItemIdx = 1;
uItemIdx = R + 1;

for seqPos = 1:N
    locAngle = acwLocSequence(seqPos);
    if locAngle == redundantLocAngle && rItemIdx <= R
        % This is an R item position
        segs{end+1} = rItemIdx;
        tag(end+1) = "R";
        fprintf('Position %d: Created segment for R item %d at location %.1f°\n', seqPos, rItemIdx, locAngle);
        rItemIdx = rItemIdx + 1;
    else
        % This is a unique item position
        segs{end+1} = uItemIdx;
        tag(end+1) = "U";
        fprintf('Position %d: Created segment for unique item %d at location %.1f°\n', seqPos, uItemIdx, locAngle);
        uItemIdx = uItemIdx + 1;
    end
end

fprintf('\n=== Segment Structure ===\n');
fprintf('Total segments: %d\n', numel(segs));
for i = 1:numel(segs)
    fprintf('  Segment %d: item %d (location %.1f°)\n', i, segs{i}, acwLocSequence(i));
    fprintf('    Segment type: %s\n', char(tag(i)));
    fprintf('    Segment is scalar: %s\n', mat2str(isscalar(segs{i})));
    fprintf('    Segment size: %s\n', mat2str(size(segs{i})));
end

fprintf('\n=== R Items Analysis ===\n');
rSegments = [];
for i = 1:numel(segs)
    if tag(i) == "R"
        rSegments(end+1) = i;
    end
end
fprintf('R items appear in segments: %s\n', mat2str(rSegments));
fprintf('Number of R segments: %d (should equal R=%d)\n', numel(rSegments), R);

if numel(rSegments) == R
    fprintf('✓ Each R item is in a separate segment\n');
else
    fprintf('✗ R items are grouped! Expected %d segments, got %d\n', R, numel(rSegments));
end

