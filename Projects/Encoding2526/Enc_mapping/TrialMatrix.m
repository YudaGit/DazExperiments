function [practiceTrials, expTrials] = TrialMatrix(design)
% Build the requested trial totals, balanced across seed hues.
practiceTrials = makeTrials(design.SeedHues, design.PracticeTrialN);
expTrials = makeTrials(design.SeedHues, design.MainTrialN);
end

function trials = makeTrials(seeds, n)
assert(isscalar(n) && isfinite(n) && n >= 0 && n == floor(n), ...
    'Trial count must be a nonnegative integer.');
nSeeds = numel(seeds);
hues = repmat(seeds(:), floor(n/nSeeds), 1);
extra = seeds(randperm(nSeeds, mod(n, nSeeds)));
hues = [hues; extra(:)];
hues = hues(randperm(n));
trials = table((1:n)', hues, randi([0 359], n, 1), ...
    randi([0 359], n, 1), randi(2^31-1, n, 1), ...
    'VariableNames', {'Trial','TargetHueDeg','TargetLocationDeg', ...
    'WheelRotationDeg','DecaySeed'});
fields = {'TargetX','TargetY','TargetRGBHueDeg','OnsetSecs','ResponseTimeMs', ...
    'ResponseScreenAngleDeg','ResponseHueDeg','SignedErrorDeg','VisibleFraction'};
for ii = 1:numel(fields), trials.(fields{ii}) = nan(n,1); end
trials.MissedFrames = zeros(n,1);
trials.TimedOut = false(n,1);
trials.Completed = false(n,1);
end
