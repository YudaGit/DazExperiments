% Script to verify trial count calculation for Pilot 1 (STInte)
% Given user settings: BaselineReps=10, RSReps=20, GroupedReps=20

clear; close all;

fprintf('=== PILOT 1 TRIAL COUNT CALCULATION ===\n\n');

% User settings
BaselineReps = 10;
RSReps = 20;
GroupedReps = 20;
ItemNList = [4 6];
NoiseLevels = {'high'};

fprintf('User Settings:\n');
fprintf('  BaselineReps = %d\n', BaselineReps);
fprintf('  RSReps = %d\n', RSReps);
fprintf('  GroupedReps = %d\n', GroupedReps);
fprintf('  Set sizes: %s\n', mat2str(ItemNList));
fprintf('  Noise levels: %s\n\n', strjoin(NoiseLevels, ', '));

% Calculate trials per condition per set size
fprintf('Trials per condition per set size:\n');
fprintf('  Baseline: %d trials × %d set sizes = %d trials\n', ...
    BaselineReps, numel(ItemNList), BaselineReps * numel(ItemNList));

fprintf('  RS_TimeOnly: %d trials × %d set sizes = %d trials\n', ...
    RSReps, numel(ItemNList), RSReps * numel(ItemNList));
fprintf('    (%.0f R-cue + %.0f NR-cue per set size)\n', RSReps/2, RSReps/2);

fprintf('  RS_SpaceTime: %d trials × %d set sizes = %d trials\n', ...
    RSReps, numel(ItemNList), RSReps * numel(ItemNList));
fprintf('    (%.0f R-cue + %.0f NR-cue per set size)\n', RSReps/2, RSReps/2);

fprintf('  RedundantGrouped: %d trials × %d set sizes = %d trials\n', ...
    GroupedReps, numel(ItemNList), GroupedReps * numel(ItemNList));
fprintf('    (%.0f R-cue + %.0f NR-cue per set size)\n', GroupedReps/2, GroupedReps/2);

% Total calculation
totalBaseline = BaselineReps * numel(ItemNList);
totalRS_TimeOnly = RSReps * numel(ItemNList);
totalRS_SpaceTime = RSReps * numel(ItemNList);
totalGrouped = GroupedReps * numel(ItemNList);

totalTrials = totalBaseline + totalRS_TimeOnly + totalRS_SpaceTime + totalGrouped;

fprintf('\n=== TOTAL TRIAL COUNT ===\n');
fprintf('  Baseline: %d\n', totalBaseline);
fprintf('  RS_TimeOnly: %d\n', totalRS_TimeOnly);
fprintf('  RS_SpaceTime: %d\n', totalRS_SpaceTime);
fprintf('  RedundantGrouped: %d\n', totalGrouped);
fprintf('  --------------------\n');
fprintf('  TOTAL: %d trials\n\n', totalTrials);

fprintf('Breakdown by set size:\n');
for N = ItemNList
    fprintf('  N=%d:\n', N);
    fprintf('    Baseline: %d\n', BaselineReps);
    fprintf('    RS_TimeOnly: %d (%.0f R + %.0f NR)\n', RSReps, RSReps/2, RSReps/2);
    fprintf('    RS_SpaceTime: %d (%.0f R + %.0f NR)\n', RSReps, RSReps/2, RSReps/2);
    fprintf('    RedundantGrouped: %d (%.0f R + %.0f NR)\n', GroupedReps, GroupedReps/2, GroupedReps/2);
    fprintf('    Subtotal: %d trials\n', BaselineReps + RSReps + RSReps + GroupedReps);
end

fprintf('\n=== VERIFICATION ===\n');
fprintf('Expected total: %d trials\n', totalTrials);
if totalTrials == 140
    fprintf('✓ Calculation matches: 140 trials\n');
else
    fprintf('✗ Mismatch! Expected 140, calculated %d\n', totalTrials);
end

