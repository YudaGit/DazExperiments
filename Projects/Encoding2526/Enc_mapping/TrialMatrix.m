function [practiceTrials, expTrials] = TrialMatrix(config)
% Minimal mapping-only schema. Metadata/settings are saved once in config.
practiceTrials = makeTrials(config.SeedHues, config.PracticeReps);
expTrials = makeTrials(config.SeedHues, config.MainReps);
end

function trials = makeTrials(seeds, reps)
hues = repmat(seeds(:), reps, 1);
hues = hues(randperm(numel(hues)));
n = numel(hues);
trials = table((1:n)', hues, randi([0 359], n, 1), ...
    randi([0 359], n, 1), randi(2^31-1, n, 1), ...
    'VariableNames', {'Trial','TargetHueDeg','TargetLocationDeg', ...
    'WheelRotationDeg','DecaySeed'});
fields = {'TargetX','TargetY','OnsetSecs','ResponseTimeMs', ...
    'ResponseScreenAngleDeg','ResponseHueDeg','SignedErrorDeg','VisibleFraction'};
for ii = 1:numel(fields), trials.(fields{ii}) = nan(n,1); end
trials.MissedFrames = zeros(n,1);
trials.TimedOut = false(n,1);
trials.Completed = false(n,1);
end
