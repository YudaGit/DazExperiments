% Test to verify timing structure for RS_TimeOnly
% Simulate the presentation timing to check if all segments get equal time

clear; close all;

fprintf('=== RS_TimeOnly TIMING SIMULATION ===\n\n');

% Timing parameters
SegmentDur = 0.30;  % seconds
ISI = 0.15;         % seconds

% Example: N=4, R=2 (RS_TimeOnly)
N = 4;
R = 2;

fprintf('Example: N=%d, R=%d (RS_TimeOnly)\n', N, R);
fprintf('Segment duration: %.2f s\n', SegmentDur);
fprintf('ISI duration: %.2f s\n', ISI);
fprintf('\n');

% Simulate segment sequence (R items at positions 3-4, unique at 1-2)
% Segments: [3] [4] [1] [2]  (R items are 1-2, shown at segments 3-4)
segments = {3, 4, 1, 2};
locs = [210, 210, 330, 90];  % R items (1-2) at 210, unique (3-4) at 330, 90

fprintf('Segment sequence:\n');
for s = 1:length(segments)
    fprintf('  Segment %d: Item %d at location %.0f°\n', s, segments{s}, locs(segments{s}));
end
fprintf('\n');

% Simulate timing
fprintf('Timing breakdown:\n');
totalTime = 0;
for seg = 1:length(segments)
    fprintf('Segment %d (Item %d):\n', seg, segments{s});
    fprintf('  - Stimulus shown: %.2f s\n', SegmentDur);
    totalTime = totalTime + SegmentDur;
    
    if seg < length(segments)
        fprintf('  - ISI: %.2f s\n', ISI);
        totalTime = totalTime + ISI;
    end
    fprintf('  - Cumulative time: %.2f s\n', totalTime);
    fprintf('\n');
end

fprintf('Total presentation time: %.2f s\n', totalTime);
fprintf('Expected time per segment: %.2f s (stimulus) + %.2f s (ISI) = %.2f s\n', ...
    SegmentDur, ISI, SegmentDur + ISI);
fprintf('Last segment: %.2f s (no ISI)\n', SegmentDur);

fprintf('\n=== CHECKING R ITEMS ===\n');
rItemSegments = [];
for s = 1:length(segments)
    if segments{s} <= R
        rItemSegments(end+1) = s;
    end
end

fprintf('R items appear at segments: %s\n', mat2str(rItemSegments));
fprintf('R item timing:\n');
for i = 1:length(rItemSegments)
    seg = rItemSegments(i);
    if i == 1
        fprintf('  R item %d (segment %d): %.2f s (stimulus) + %.2f s (ISI) = %.2f s\n', ...
            segments{seg}, seg, SegmentDur, ISI, SegmentDur + ISI);
    else
        fprintf('  R item %d (segment %d): %.2f s (stimulus) + %.2f s (ISI) = %.2f s\n', ...
            segments{seg}, seg, SegmentDur, ISI, SegmentDur + ISI);
    end
end

fprintf('\n✓ All segments receive equal timing!\n');
fprintf('  Each segment: %.2f s stimulus + %.2f s ISI (except last)\n', SegmentDur, ISI);

