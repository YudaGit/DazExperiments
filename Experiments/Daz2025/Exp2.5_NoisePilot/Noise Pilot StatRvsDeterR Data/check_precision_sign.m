% Check if stored Precision is actually ResponseAngle - TargetHue (reversed)

clear; close all; clc;

fprintf('=== Checking Precision Sign ===\n\n');

% Load one yS file
dataDir = '.';
filepath = fullfile(dataDir, 'HomoInte_yS_sess1_2026-01-30_14-10-20.mat');
data = load(filepath, 'expTrials');
trials = data.expTrials;

fprintf('Checking first 10 trials:\n\n');

for t = 1:min(10, height(trials))
    storedPrecision = trials.Precision(t);
    targetHue = trials.TargetHue(t);
    responseAngle = trials.ResponseAngle(t);
    
    if isnan(storedPrecision) || isnan(targetHue) || isnan(responseAngle)
        continue;
    end
    
    % Try both directions
    calc1 = targetHue - responseAngle;  % Standard
    if calc1 < -180
        calc1 = calc1 + 360;
    elseif calc1 > 180
        calc1 = calc1 - 360;
    end
    
    calc2 = responseAngle - targetHue;  % Reversed
    if calc2 < -180
        calc2 = calc2 + 360;
    elseif calc2 > 180
        calc2 = calc2 - 360;
    end
    
    diff1 = abs(storedPrecision - calc1);
    if diff1 > 180
        diff1 = 360 - diff1;
    end
    
    diff2 = abs(storedPrecision - calc2);
    if diff2 > 180
        diff2 = 360 - diff2;
    end
    
    fprintf('Trial %d: Stored=%.6f, TargetHue-Resp=%.6f (diff=%.6f), Resp-TargetHue=%.6f (diff=%.6f)\n', ...
        t, storedPrecision, calc1, diff1, calc2, diff2);
end
