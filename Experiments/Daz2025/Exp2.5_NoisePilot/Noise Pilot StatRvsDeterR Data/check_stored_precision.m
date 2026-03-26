% Check what the stored Precision actually represents

clear; close all; clc;

fprintf('=== Checking What Stored Precision Represents ===\n\n');

% Load one yS file
dataDir = '.';
filepath = fullfile(dataDir, 'HomoInte_yS_sess1_2026-01-30_14-10-20.mat');
data = load(filepath, 'expTrials');
trials = data.expTrials;

fprintf('Checking first 10 trials:\n\n');

for t = 1:min(10, height(trials))
    storedPrecision = trials.Precision(t);
    cond = trials.Condition{t};
    targetHue = trials.TargetHue(t);
    responseAngle = trials.ResponseAngle(t);
    baseH = trials.BaseHues{t};
    meanOff = trials.MeanOffsets{t};
    
    if isnan(storedPrecision) || isnan(targetHue) || isnan(responseAngle)
        continue;
    end
    
    % Get baseHue
    if strcmp(cond, 'Baseline')
        idx = trials.Target(t);
        baseHue = baseH(idx);
        meanOffset = meanOff(idx);
    else
        baseHue = baseH(1);
        meanOffset = mean(meanOff);
    end
    
    % Calculate different possibilities
    calc1 = targetHue - responseAngle;  % TargetHue - ResponseAngle
    if calc1 < -180
        calc1 = calc1 + 360;
    elseif calc1 > 180
        calc1 = calc1 - 360;
    end
    
    calc2 = baseHue - responseAngle;  % baseHue - ResponseAngle
    if calc2 < -180
        calc2 = calc2 + 360;
    elseif calc2 > 180
        calc2 = calc2 - 360;
    end
    
    calc3 = calc1 - meanOffset;  % (TargetHue - ResponseAngle) - meanOffset
    if calc3 < -180
        calc3 = calc3 + 360;
    elseif calc3 > 180
        calc3 = calc3 - 360;
    end
    
    diff1 = abs(storedPrecision - calc1);
    if diff1 > 180
        diff1 = 360 - diff1;
    end
    
    diff2 = abs(storedPrecision - calc2);
    if diff2 > 180
        diff2 = 360 - diff2;
    end
    
    diff3 = abs(storedPrecision - calc3);
    if diff3 > 180
        diff3 = 360 - diff3;
    end
    
    fprintf('Trial %d (%s):\n', t, cond);
    fprintf('  Stored Precision: %.6f\n', storedPrecision);
    fprintf('  TargetHue - ResponseAngle: %.6f (diff=%.9f)\n', calc1, diff1);
    fprintf('  baseHue - ResponseAngle: %.6f (diff=%.9f)\n', calc2, diff2);
    fprintf('  (TargetHue-Resp) - meanOffset: %.6f (diff=%.9f)\n', calc3, diff3);
    fprintf('  meanOffset: %.6f\n', meanOffset);
    fprintf('\n');
end
