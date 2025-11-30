% Quick test to verify segment structure for RS_TimeOnly
% This will show if segments are being grouped incorrectly

% Simulate RS_TimeOnly with N=4, R=2
N = 4;
R = 2;
numLocs = N - R + 1;  % 3 locations

% Create test locations
baseLocs = 90 + (0:numLocs-1)*(360/numLocs);
rotatedLocs = baseLocs;  % No rotation for simplicity
redundantLocAngle = rotatedLocs(1);  % First location is redundant

% Simulate the segment creation logic
acwLocSequence = [redundantLocAngle, redundantLocAngle, rotatedLocs(2), rotatedLocs(3)];  % R items first, then unique

segs = {};
rItemIdx = 1;
uItemIdx = R + 1;

for seqPos = 1:N
    locAngle = acwLocSequence(seqPos);
    if locAngle == redundantLocAngle && rItemIdx <= R
        segs{end+1} = rItemIdx;
        rItemIdx = rItemIdx + 1;
    else
        segs{end+1} = uItemIdx;
        uItemIdx = uItemIdx + 1;
    end
end

fprintf('Segment structure:\n');
for i = 1:numel(segs)
    fprintf('  Segment %d: item %d (location %.1f°)\n', i, segs{i}, acwLocSequence(i));
end

fprintf('\nVerification:\n');
fprintf('  Number of segments: %d (should equal N=%d)\n', numel(segs), N);
for i = 1:numel(segs)
    fprintf('  Segment %d is scalar: %s (size: %s)\n', i, mat2str(isscalar(segs{i})), mat2str(size(segs{i})));
end

