% Test location spacing for all conditions
% Verify locations are evenly spaced on a circle

fprintf('=== LOCATION SPACING VERIFICATION ===\n\n');

% Test cases
testCases = [
    struct('N', 4, 'R', 2, 'cond', 'RS_TimeOnly');
    struct('N', 6, 'R', 3, 'cond', 'RS_TimeOnly');
    struct('N', 4, 'R', 0, 'cond', 'Baseline');
    struct('N', 6, 'R', 0, 'cond', 'Baseline');
];

for t = 1:numel(testCases)
    N = testCases(t).N;
    R = testCases(t).R;
    cond = testCases(t).cond;
    
    fprintf('Condition: %s, N=%d, R=%d\n', cond, N, R);
    
    if strcmp(cond, 'RS_TimeOnly')
        numLocs = N - R + 1;
        baseLocs = 90 + (0:numLocs-1)*(360/numLocs);
        fprintf('  Number of locations: %d\n', numLocs);
        fprintf('  Locations: %s\n', mat2str(baseLocs));
        
        % Check spacing
        if numLocs > 1
            spacing = diff([baseLocs, baseLocs(1) + 360]);  % Include wrap-around
            fprintf('  Spacing between locations: %s\n', mat2str(spacing));
            if all(abs(spacing - 360/numLocs) < 0.01)
                fprintf('  ✓ Evenly spaced (%.1f° apart)\n', 360/numLocs);
            else
                fprintf('  ✗ NOT evenly spaced!\n');
            end
        end
    else
        baseLocs = 90 + (0:N-1)*(360/N);
        fprintf('  Number of locations: %d\n', N);
        fprintf('  Locations: %s\n', mat2str(baseLocs));
        
        % Check spacing
        spacing = diff([baseLocs, baseLocs(1) + 360]);  % Include wrap-around
        fprintf('  Spacing between locations: %s\n', mat2str(spacing));
        if all(abs(spacing - 360/N) < 0.01)
            fprintf('  ✓ Evenly spaced (%.1f° apart)\n', 360/N);
        else
            fprintf('  ✗ NOT evenly spaced!\n');
        end
    end
    fprintf('\n');
end

