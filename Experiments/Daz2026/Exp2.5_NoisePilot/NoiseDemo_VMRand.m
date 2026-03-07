function NoiseDemo_VMRand
% ------------------------------------------------------------
% Demo: Low vs High noise color square stimuli (B×B tiles)
% Sampling Method: Two-Component Von Mises Mixture
% Stages:
% 1) single low-noise @ 12 o'clock (click to replay; F next; B back)
% 2) single high-noise @ 12 o'clock
% 3) 4 items (R,U,L,D), LOW noise; R & L are redundant (same target, independent samples)
% 4) 4 items (R,U,L,D), HIGH noise; R & L are redundant (same target, independent samples)
% 5) 2-interval same location (LOW noise): redundant items (same target, independent samples)
% 6) 2-interval diff location (LOW noise): redundant items (same target, independent samples)
% 7) 2-interval same location (HIGH noise): redundant items (same target, independent samples)
% 8) 2-interval diff location (HIGH noise): redundant items (same target, independent samples)
%
% Truncated Von Mises Method:
% - Samples from vonMises(μ=target, κ=K) but truncated to ±maxDeviation
% - K: concentration parameter (high K = narrow, low K = wide)
% - maxDeviation: hard limit on how far samples can deviate from target (degrees)
% - All samples are guaranteed to stay within ±maxDeviation of target
% - Distribution is normalized so area under curve within truncation window is equal
%   for both noise levels (ensures fair comparison)
% - Low noise: high K, small maxDeviation → tight, concentrated samples
% - High noise: low K, large maxDeviation → wide, spread out samples
%
% Redundant Design
% - Let redudant items to be only rooted in the same original color, then
% sample them independently, so that they appear highly similar but not
% absolute repeats. 
% ------------------------------------------------------------

% ---------- Setup ----------
clear; close all; clc;
sca; Screen('CloseAll');
KbName('UnifyKeyNames');
PsychDefaultSetup(2);
Screen('Preference','SkipSyncTests',1);
Screen('Preference','VisualDebugLevel',1);

global V
global storedStimData
storedStimData = [];  % Initialize global variable for storing stimulus data
V = initiate();
win = V.window;

VA5deg = calibrateMonitor();
adjustSquareStim(VA5deg);   % sets V.square.*, V.layout.centerRadiusPx, etc.

ifi = Screen('GetFlipInterval', win);
fprintf('Refresh: %.2f Hz (%.3f ms/frame)\n', 1/ifi, ifi*1000);

% ---------- Parameters ----------
% Quantile-based Von Mises sampling
% Uses inverse transform sampling from Von Mises CDF for consistent variance
% No truncation needed - distribution naturally bounded by kappa parameter
% 
% Low noise parameters:
P.K_LowNoise      = 25;       % concentration parameter (high = narrow distribution)
                                % Higher kappa = tighter clustering around target
                                % Typical range: 20-100 for low noise

% High noise parameters:
P.K_HighNoise     = 1;         % concentration parameter (lower = wider distribution)
                                % Lower kappa = wider spread around target
                                % Typical range: 1-10 for high noise
                                
% Note: For better discriminability, aim for kappa ratio > 10:1
%       (e.g., Low=50, High=3 gives ~17:1 ratio)
P.redundancyMode  = 'statistical';  % 'statistical' or 'exact'
P.durMs          = 500;      % per-stim duration
P.ISI            = 0.300;    % seconds, stages 5/6
P.angles4        = [0 90 180 270];  % R,U,L,D (deg)
P.shotDir = 'stim_captures';

logMsg('--- NoiseDemo_VMRand (Quantile-Based Von Mises) start ---');

% --- Guard: make sure color wheel exists ---
if ~isfield(V,'color') || ~isfield(V.color,'map') || isempty(V.color.map)
    error('V.color.map is missing. Make sure your initiate() builds the OKLab/LAB color wheel before calling this demo.');
end

% --- Use your wheel as 0..255 RGB; resample to 360 if needed ---
if size(V.color.map,1) == 360
    P.cMap360_255 = V.color.map;
else
    idx = round(linspace(1, size(V.color.map,1), 360));
    P.cMap360_255 = V.color.map(idx, :);
end

% ---------- Intro ----------
FillBG(V); drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
DrawCenteredText(win,'Demo for low and high noise level color square stimuli, click mouse to proceed',30,[1 1 1]);
Screen('Flip',win);
if WaitForMouseClickOrEsc() < 0, cleanup(); return; end

% ---------- Stage loop ----------
stage = 1;
keepGoing = true;
while keepGoing
    logMsg(sprintf('Stage loop iteration, stage=%d', stage));
    switch stage
        case 1
            info = sprintf(['Stage 1: Single Stimulus\n' ...
                            'Noise: Low (K=%.1f)\n' ...
                            'Set Size: 1'], P.K_LowNoise);
            action = stage_click_to_repeat(win, @() stage_single(V, 90,  'low',  P, true, 'stage1'), info, ...
                @() generateTargetOffset_single(V, 90, 'low', P));
        case 2
            info = sprintf(['Stage 2: Single Stimulus\n' ...
                            'Noise: High (K=%.1f)\n' ...
                            'Set Size: 1'], P.K_HighNoise);
            action = stage_click_to_repeat(win, @() stage_single(V, 90,  'high', P, true, 'stage2'), info, ...
                @() generateTargetOffset_single(V, 90, 'high', P));
        case 3
            info = sprintf(['Stage 3: Four Stimuli with Replicas\n' ...
                            'Noise: Low (K=%.1f)\n' ...
                            'Set Size: 4'], P.K_LowNoise);
            action = stage_click_to_repeat(win, @() stage_four_with_replicas(V, P, 'low', true, 'stage3'), info, ...
                @() generateTargetOffset_four(V, P, 'low'));
        case 4
            info = sprintf(['Stage 4: Four Stimuli with Replicas\n' ...
                            'Noise: High (K=%.1f)\n' ...
                            'Set Size: 4'], P.K_HighNoise);
            action = stage_click_to_repeat(win, @() stage_four_with_replicas(V, P, 'high', true, 'stage4'), info, ...
                @() generateTargetOffset_four(V, P, 'high'));
        case 5
            info = sprintf(['Stage 5: Two-Interval Same Location\n' ...
                            'Noise: Low (K=%.1f)\n' ...
                            'Set Size: 1 (two intervals)'], P.K_LowNoise);
            action = stage_click_to_repeat(win, @() stage_two_interval_same_loc(V, 90, 'low', P), info, ...
                @() generateTargetOffset_single(V, 90, 'low', P));
        case 6
            info = sprintf(['Stage 6: Two-Interval Different Location\n' ...
                            'Noise: Low (K=%.1f)\n' ...
                            'Set Size: 1 (two intervals)'], P.K_LowNoise);
            action = stage_click_to_repeat(win, @() stage_two_interval_diff_loc(V, 90, 270, 'low', P), info, ...
                @() generateTargetOffset_single(V, 90, 'low', P));
        case 7
            info = sprintf(['Stage 7: Two-Interval Same Location\n' ...
                            'Noise: High (K=%.1f)\n' ...
                            'Set Size: 1 (two intervals)'], P.K_HighNoise);
            action = stage_click_to_repeat(win, @() stage_two_interval_same_loc(V, 90, 'high', P), info, ...
                @() generateTargetOffset_single(V, 90, 'high', P));
        case 8
            info = sprintf(['Stage 8: Two-Interval Different Location\n' ...
                            'Noise: High (K=%.1f)\n' ...
                            'Set Size: 1 (two intervals)'], P.K_HighNoise);
            action = stage_click_to_repeat(win, @() stage_two_interval_diff_loc(V, 90, 270, 'high', P), info, ...
                @() generateTargetOffset_single(V, 90, 'high', P));
        otherwise
            action = 'quit';
    end

    switch action
        case 'next'
            stage = min(stage+1, 8);
            logMsg(sprintf('Stage advanced to %d', stage));
        case 'prev'
            stage = max(stage-1, 1);
            logMsg(sprintf('Stage went back to %d', stage));
        case 'again'
            % do nothing; user can click again in same stage
        case 'quit'
            logMsg('Quit requested');
            keepGoing = false;
    end
end

cleanup();
end % ------------------------------- end main function -------------------------------


% ===================== Stage bodies ======================

function [targetDeg, meanOffset] = stage_single(V, angleDeg, noiseLevel, P, saveShot, shotTag)
% Get stored target from generateTargetOffset_single (via global)
% saveShot: enable screen capture (default: false)
% shotTag: tag for screenshot filename (default: 'stage1' or 'stage2' based on noiseLevel)
global storedStimData
if nargin < 5, saveShot = false; end
if nargin < 6, shotTag = sprintf('stage%d', strcmpi(noiseLevel, 'high') + 1); end

if ~isempty(storedStimData) && isfield(storedStimData, 'target') && ~isempty(storedStimData.target)
    % Use stored values
    targetHueDeg = storedStimData.target;
    rgb01 = storedStimData.pattern;
    huesDeg = storedStimData.hues;
    meanOffset = storedStimData.meanOffset;
    % Clear after use
    storedStimData = [];
else
    % Fallback: generate new if not set
    targetHueDeg = randi([0 359]);
    [rgb01, huesDeg] = makeNoisyPattern(V, targetHueDeg, noiseLevel, P);
    meanOffset = calculateMeanOffset(huesDeg, targetHueDeg);
end
% deferFlip=false means it will flip immediately and show for durMs
% Pass huesDeg for visualization
presentNoisySquareAt(V, targetHueDeg, noiseLevel, angleDeg, P.durMs, P, rgb01, false, saveShot, P.shotDir, shotTag, 'stim', huesDeg);
targetDeg = targetHueDeg;
end

function [targetDegs, meanOffsets] = stage_four_with_replicas(V, P, noiseLevel, saveShot, shotTag)
% Get stored values from generateTargetOffset_four (via global)
% Redundant items (R & L) share the same baseHue target but are sampled independently
% saveShot: enable screen capture (default: false)
% shotTag: tag for screenshot filename (default: 'stage3' or 'stage4' based on noiseLevel)
global storedStimData
if nargin < 4, saveShot = false; end
if nargin < 5, shotTag = sprintf('stage%d', strcmpi(noiseLevel, 'high') + 3); end
if ~isempty(storedStimData) && isfield(storedStimData, 'baseHue') && ~isempty(storedStimData.baseHue)
    % Use stored values
    baseHue = storedStimData.baseHue;
    uniqueHue1 = storedStimData.uniqueHue1;
    uniqueHue2 = storedStimData.uniqueHue2;
    uniqueHues1 = storedStimData.uniqueHues1;
    uniqueHues2 = storedStimData.uniqueHues2;
    meanOffsets = storedStimData.meanOffsets;
    % Clear after use
    storedStimData = [];
else
    % Fallback: generate new if not set
    baseHue    = randi([0 359]);
    uniqueHue1 = mod(baseHue + 60,  360);
    uniqueHue2 = mod(baseHue + 180, 360);
    [~, uniqueHues1] = makeNoisyPattern(V, uniqueHue1, noiseLevel, P);
    [~, uniqueHues2] = makeNoisyPattern(V, uniqueHue2, noiseLevel, P);
    % Calculate mean offsets (will recalc for redundant items when generating patterns)
    meanOffsets = [NaN, ...  % R - will calculate when generating pattern
                   calculateMeanOffset(uniqueHues1, uniqueHue1), ...
                   NaN, ...  % L - will calculate when generating pattern
                   calculateMeanOffset(uniqueHues2, uniqueHue2)];
end
targetDegs = [baseHue, uniqueHue1, baseHue, uniqueHue2];
angles = P.angles4;                         % [R U L D]

FillBG(V); drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
% Convert stored hues to RGB patterns for unique stimuli
uniquePattern1 = wheelRGB01_fromDegrees(uniqueHues1, P.cMap360_255);
uniquePattern2 = wheelRGB01_fromDegrees(uniqueHues2, P.cMap360_255);

% Generate redundant patterns (exact or statistical) using same baseHue target
[repPatternR, repHuesR, repPatternL, repHuesL] = ...
    getRedundantPatterns(V, baseHue, noiseLevel, P);

% Update mean offsets for redundant items (calculated from actual generated patterns)
if isnan(meanOffsets(1))
    meanOffsets(1) = calculateMeanOffset(repHuesR, baseHue);
end
if isnan(meanOffsets(3))
    meanOffsets(3) = calculateMeanOffset(repHuesL, baseHue);
end

presentNoisySquareAt(V, baseHue,    noiseLevel, angles(1), P.durMs, P, repPatternR, true, false); % R redundant (independent sample)
presentNoisySquareAt(V, uniqueHue1, noiseLevel, angles(2), P.durMs, P, uniquePattern1, true, false); % U unique
presentNoisySquareAt(V, baseHue,    noiseLevel, angles(3), P.durMs, P, repPatternL, true, false); % L redundant (independent sample)
presentNoisySquareAt(V, uniqueHue2, noiseLevel, angles(4), P.durMs, P, uniquePattern2, true, false); % D unique

% Flip to show all 4 stimuli
vbl = Screen('Flip', V.window);

% Screen capture for all 4 stimuli (if enabled)
if saveShot
    try
        ensureDir(P.shotDir);
        % Calculate bounding box that includes all 4 stimuli
        % Stimuli are at angles [0, 90, 180, 270] on the 5° circle
        side = V.square.side_px_full;
        margin = 20;  % Extra margin around stimuli
        
        % Get positions of all 4 stimuli
        rects = zeros(4, 4);
        for i = 1:4
            th = deg2rad(angles(i));
            cx = V.centerX + V.layout.centerRadiusPx * cos(th);
            cy = V.centerY - V.layout.centerRadiusPx * sin(th);
            rects(i, :) = CenterRectOnPointd([0 0 side side], cx, cy);
        end
        
        % Calculate bounding box
        minX = min(rects(:, 1)) - margin;
        minY = min(rects(:, 2)) - margin;
        maxX = max(rects(:, 3)) + margin;
        maxY = max(rects(:, 4)) + margin;
        
        grabRect = round([minX, minY, maxX, maxY]);
        
        % Capture the screen
        img = Screen('GetImage', V.window, grabRect);
        tstamp = datestr(now,'yyyymmdd_HHMMSS');
        tstamp = sprintf('%s_%03d', tstamp, round(rem(now*86400000, 1000)));
        fname = sprintf('%s_%s_%s.png', shotTag, noiseLevel, tstamp);
        fullPath = fullfile(P.shotDir, fname);
        imwrite(img, fullPath, 'png');
        fprintf('[saveShot] Saved: %s\n', fname);
    catch ME
        fprintf(2,'[saveShot] Failed: %s\n', ME.message);
        fprintf(2,'[saveShot] Stack: %s\n', getReport(ME));
    end
end

WaitSecs(P.durMs/1000);
end

function [targetDeg, meanOffset] = stage_two_interval_diff_loc(V, angle1, angle2, noiseLevel, P)
% Get stored target from generateTargetOffset_single (via global)
% Redundant items (interval 1 & 2) share the same hue target but are sampled independently
global storedStimData
if ~isempty(storedStimData) && isfield(storedStimData, 'target') && ~isempty(storedStimData.target)
    % Use stored target hue only
    hue = storedStimData.target;
    meanOffset = storedStimData.meanOffset;
    % Clear after use
    storedStimData = [];
else
    % Fallback: generate new if not set
    hue = randi([0 359]);
    [~, huesDeg] = makeNoisyPattern(V, hue, noiseLevel, P);
    meanOffset = calculateMeanOffset(huesDeg, hue);
end

% interval 1 - generate redundant pattern (mode-dependent)
FillBG(V); drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
[pat1, ~, pat2, ~] = getRedundantPatterns(V, hue, noiseLevel, P);
presentNoisySquareAt(V, hue, noiseLevel, angle1, P.durMs, P, pat1, false, false);
% Note: presentNoisySquareAt already waits for P.durMs internally, no extra WaitSecs needed

% ISI
FillBG(V); drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
Screen('Flip', V.window); WaitSecs(P.ISI);

% interval 2 at different angle - generate redundant pattern (same target hue)
FillBG(V); drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
presentNoisySquareAt(V, hue, noiseLevel, angle2, P.durMs, P, pat2, false, false);
% Note: presentNoisySquareAt already waits for P.durMs internally, no extra WaitSecs needed
targetDeg = hue;
end

function [targetDeg, meanOffset] = stage_two_interval_same_loc(V, angleDeg, noiseLevel, P)
% Get stored target from generateTargetOffset_single (via global)
% Redundant items (interval 1 & 2) share the same hue target but are sampled independently
global storedStimData
if ~isempty(storedStimData) && isfield(storedStimData, 'target') && ~isempty(storedStimData.target)
    % Use stored target hue only
    hue = storedStimData.target;
    meanOffset = storedStimData.meanOffset;
    % Clear after use
    storedStimData = [];
else
    % Fallback: generate new if not set
    hue = randi([0 359]);
    [~, huesDeg] = makeNoisyPattern(V, hue, noiseLevel, P);
    meanOffset = calculateMeanOffset(huesDeg, hue);
end

% interval 1 - generate redundant pattern (mode-dependent)
FillBG(V); drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
[pat1, ~, pat2, ~] = getRedundantPatterns(V, hue, noiseLevel, P);
presentNoisySquareAt(V, hue, noiseLevel, angleDeg, P.durMs, P, pat1, false, false);
% Note: presentNoisySquareAt already waits for P.durMs internally, no extra WaitSecs needed

% ISI
FillBG(V); drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
Screen('Flip', V.window); WaitSecs(P.ISI);

% interval 2 - generate redundant pattern (same target hue)
FillBG(V); drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
presentNoisySquareAt(V, hue, noiseLevel, angleDeg, P.durMs, P, pat2, false, false);
% Note: presentNoisySquareAt already waits for P.durMs internally, no extra WaitSecs needed
targetDeg = hue;
end


% ===================== Stage driver / UI ======================

function action = stage_click_to_repeat(win, doOnceFcn, infoText, getTargetOffsetFcn)
% Returns one of: 'next' | 'prev' | 'quit' | 'again'
% - Click: run doOnceFcn() then return 'again'
% - F:     return 'next'
% - B:     return 'prev'
% - ESC:   return 'quit'
% getTargetOffsetFcn: function that returns [targetDeg, meanOffset] or cell array for multiple stimuli
%   This function should also store the target in a way that doOnceFcn can access it
global V
action = 'again';

if ~exist('infoText','var') || isempty(infoText)
    infoText = '';
end

% Debounce: wait until no mouse button is down
while any(GetMouseButtons()), WaitSecs(0.01); end

% Generate initial target/offset for display
if exist('getTargetOffsetFcn', 'var') && ~isempty(getTargetOffsetFcn)
    targetOffsetInfo = getTargetOffsetFcn();
else
    targetOffsetInfo = [];
end

while true
    FillBG(V);
    drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
    
    % Build display text with target and mean offset
    displayText = infoText;
    if ~isempty(targetOffsetInfo)
        if iscell(targetOffsetInfo) && length(targetOffsetInfo) == 2
            % Multiple stimuli (stage 3/4)
            targetDegs = targetOffsetInfo{1};
            meanOffsets = targetOffsetInfo{2};
            offsetStr = sprintf('Targets: %s\nMean Offsets: %s', ...
                mat2str(round(targetDegs)), mat2str(round(meanOffsets*10)/10));
        else
            % Single stimulus
            targetDeg = targetOffsetInfo(1);
            meanOffset = targetOffsetInfo(2);
            offsetStr = sprintf('Target: %d°\nMean Offset: %.2f°', round(targetDeg), meanOffset);
        end
        displayText = sprintf('%s\n\n%s', infoText, offsetStr);
    end
    
    drawStageInfo(V, displayText);
    drawHUD(V, 'Click = show  |  F = next  |  B = back  |  ESC = quit');
    Screen('Flip', win);

    % Keyboard first so F/B don't also click
    [down,~,kc] = KbCheck;
    if down
        escKey = KbName('ESCAPE');
        if kc(escKey)
            action = 'quit';
            logMsg('Keypress detected: ESC (quit)');
            WaitSecs(0.1); % Brief debounce
            return;
        end
        fKey = KbName('f');
        if kc(fKey)
            action = 'next';
            logMsg('Keypress detected: F (next stage)');
            WaitSecs(0.1); % Brief debounce
            return;
        end
        bKey = KbName('b');
        if kc(bKey)
            action = 'prev';
            logMsg('Keypress detected: B (previous stage)');
            WaitSecs(0.1); % Brief debounce
            return;
        end
    end

    % Mouse: show once then return
    [~,~,buttons] = GetMouse;
    if buttons(1)
        doOnceFcn();
        WaitForMouseRelease();
        
        % Generate new target/offset for next stimulus
        if exist('getTargetOffsetFcn', 'var') && ~isempty(getTargetOffsetFcn)
            targetOffsetInfo = getTargetOffsetFcn();
        end
        
        action = 'again';
        logMsg('Mouse click: stimulus presented');
        return;
    end

    WaitSecs(0.01);
end
end

function WaitKeyRelease(targetKeys)
% Wait until specified keys (or all keys) are released
if nargin < 1 || isempty(targetKeys)
    targetKeys = [];
else
    targetKeys = unique(targetKeys(:)');
end

while true
    [down,~,kc] = KbCheck;
    if ~down
        break;
    end
    if ~isempty(targetKeys)
        if ~any(kc(targetKeys))
            break;
        end
    end
    WaitSecs(0.01);
end
end

% ===================== Drawing helpers ======================

function presentNoisySquareAt(V, hueDeg, noiseLevel, angleDeg, durMs, P, prePattern, deferFlip, saveShot, shotDir, shotTag, cropMode, huesDegForViz)
% Draw one B×B noisy square at a given polar angle on the 5° circle.
% noiseLevel: 'low' or 'high' (determines Von Mises kappa parameter)
% If prePattern is provided, reuse it (for replicas). If deferFlip=true, do not flip.
% huesDegForViz: optional hue values for distribution visualization
% Based on original working version from SqNoisyStim_Demo1.m

if nargin < 8 || isempty(deferFlip), deferFlip = false; end
if nargin < 9 || isempty(saveShot), saveShot = false; end
if nargin < 10 || isempty(shotDir), shotDir = 'stim_captures'; end
if nargin < 11 || isempty(shotTag), shotTag = 'stage'; end
if nargin < 12 || isempty(cropMode), cropMode = 'stim'; end
if nargin < 13, huesDegForViz = []; end

logMsg(sprintf('presentNoisySquareAt start: angle=%.1f, noiseLevel=%s, durMs=%d, deferFlip=%d', angleDeg, noiseLevel, durMs, deferFlip));

% center position on your 5° circle
th = deg2rad(angleDeg);
cx = V.centerX + V.layout.centerRadiusPx * cos(th);
cy = V.centerY - V.layout.centerRadiusPx * sin(th);

side   = V.square.side_px_full;
B      = V.square.B;
tilePx = V.square.tile_px;
rect   = CenterRectOnPointd([0 0 side side], cx, cy);
tileRects = buildTileRects(rect, B, tilePx);

if isempty(prePattern)
    rgb01 = makeNoisyPattern(V, hueDeg, noiseLevel, P);
else
    rgb01 = prePattern;  % reuse exact tiles/colors
end

% Convert to appropriate color format based on window mode
if ~(isfield(V, 'useFloat') && V.useFloat)
    % Standard mode: convert 0-1 to 0-255
    rgb01 = rgb01 * 255;
end

Screen('FillRect', V.window, rgb01', tileRects);

if ~deferFlip
    drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
    
    % Draw distribution visualization if hue data provided
    if ~isempty(huesDegForViz)
        drawDistributionViz(V, huesDegForViz, hueDeg, noiseLevel, P);
    end
    
    vbl = Screen('Flip', V.window);

    % Optional screen capture (only if saveShot enabled)
    if saveShot
        try
            ensureDir(shotDir);
            if strcmpi(cropMode,'stim')
                grabRect = round(rect + [-5 -5 5 5]);
            else
                grabRect = [];
            end
            img = Screen('GetImage', V.window, grabRect);
            tstamp = datestr(now,'yyyymmdd_HHMMSS');
            tstamp = sprintf('%s_%03d', tstamp, round(rem(now*86400000, 1000)));
            fname = sprintf('%s_h%03d_%s_%s.png', shotTag, round(mod(hueDeg,360)), noiseLevel, tstamp);
            fullPath = fullfile(shotDir, fname);
            imwrite(img, fullPath, 'png');
            fprintf('[saveShot] Saved: %s\n', fname);
        catch ME
            fprintf(2,'[saveShot] Failed: %s\n', ME.message);
            fprintf(2,'[saveShot] Stack: %s\n', getReport(ME));
        end
    end

    % Hold the stimulus on screen for the requested duration
    WaitSecs('UntilTime', vbl + durMs/1000);
end

logMsg('presentNoisySquareAt end');
end


function [rgb01, huesDeg] = makeNoisyPattern(V, hueDeg, noiseLevel, P)
% Returns nTiles×3 double in [0,1] and nTiles×1 hue degrees
% noiseLevel: 'low' or 'high' (determines Von Mises kappa parameter)
% Uses quantile-based sampling for consistent variance
B      = V.square.B;
nTiles = B * B;

% Get Von Mises kappa parameter based on noise level
if strcmpi(noiseLevel, 'low')
    K = P.K_LowNoise;
elseif strcmpi(noiseLevel, 'high')
    K = P.K_HighNoise;
else
    error('noiseLevel must be ''low'' or ''high''');
end

function [patternA, huesA, patternB, huesB] = getRedundantPatterns(V, baseHue, noiseLevel, P)
% Returns two patterns for redundant items based on selected mode
% - 'statistical': independent samples from same PDF
% - 'exact': same multiset of hues, different tile assignment
    if isfield(P, 'redundancyMode') && strcmpi(P.redundancyMode, 'exact')
        [patternA, huesA] = makeNoisyPattern(V, baseHue, noiseLevel, P);
        huesB = huesA(randperm(numel(huesA)));
        patternB = wheelRGB01_fromDegrees(huesB, P.cMap360_255);
    else
        [patternA, huesA] = makeNoisyPattern(V, baseHue, noiseLevel, P);
        [patternB, huesB] = makeNoisyPattern(V, baseHue, noiseLevel, P);
    end
end

% Sample hues using quantile-based Von Mises (no truncation needed)
huesDeg = sampleVonMisesQuantiles(hueDeg, K, nTiles);

% Convert each hue to RGB from your wheel
rgb01 = wheelRGB01_fromDegrees(huesDeg, P.cMap360_255);   % n×3, 0..1
end

function meanOffset = calculateMeanOffset(huesDeg, targetHueDeg)
% Calculate mean offset from target using shortest angular distance
% huesDeg: vector of hue values in degrees (0-360)
% targetHueDeg: target hue in degrees (0-360)
% Returns: mean offset in degrees (can be negative or positive)

% Convert to offsets using shortest angular distance
offsets = mod(huesDeg - targetHueDeg + 180, 360) - 180;
meanOffset = mean(offsets);
end

function targetOffset = generateTargetOffset_single(V, angleDeg, noiseLevel, P)
% Generate target and mean offset for single stimulus (for display before showing)
% Also stores values in global storedStimData for stage_single to use
global storedStimData
targetHueDeg = randi([0 359]);
[rgb01, huesDeg] = makeNoisyPattern(V, targetHueDeg, noiseLevel, P);
meanOffset = calculateMeanOffset(huesDeg, targetHueDeg);
targetOffset = [targetHueDeg, meanOffset];
% Store for stage_single to use
storedStimData.target = targetHueDeg;
storedStimData.pattern = rgb01;
storedStimData.hues = huesDeg;
storedStimData.meanOffset = meanOffset;
end

function targetOffset = generateTargetOffset_four(V, P, noiseLevel)
% Generate target and mean offset for four stimuli (for display before showing)
% Also stores values in global storedStimData for stage_four_with_replicas to use
% Note: Redundant items (R & L) share baseHue but patterns are generated independently
global storedStimData
baseHue    = randi([0 359]);
uniqueHue1 = mod(baseHue + 60,  360);
uniqueHue2 = mod(baseHue + 180, 360);

% Generate patterns for unique items (for display/mean offset calculation)
[~, uniqueHues1] = makeNoisyPattern(V, uniqueHue1, noiseLevel, P);
[~, uniqueHues2] = makeNoisyPattern(V, uniqueHue2, noiseLevel, P);
% Generate one sample for redundant items (for mean offset display only)
[~, repHuesSample] = makeNoisyPattern(V, baseHue, noiseLevel, P);

targetDegs = [baseHue, uniqueHue1, baseHue, uniqueHue2];
meanOffsets = [calculateMeanOffset(repHuesSample, baseHue), ...
               calculateMeanOffset(uniqueHues1, uniqueHue1), ...
               calculateMeanOffset(repHuesSample, baseHue), ...
               calculateMeanOffset(uniqueHues2, uniqueHue2)];
targetOffset = {targetDegs, meanOffsets};
% Store for stage_four_with_replicas to use (only target hues, not patterns)
storedStimData.baseHue = baseHue;
storedStimData.uniqueHue1 = uniqueHue1;
storedStimData.uniqueHues1 = uniqueHues1;
storedStimData.uniqueHue2 = uniqueHue2;
storedStimData.uniqueHues2 = uniqueHues2;
storedStimData.meanOffsets = meanOffsets;
end


function tileRects = buildTileRects(outerRect, B, tilePx)
% Returns 4×(B*B) rects for Screen('FillRect', window, colors, rects)
x0 = outerRect(1); y0 = outerRect(2); x1 = outerRect(3); y1 = outerRect(4);
side = min(x1 - x0, y1 - y0);

tilePx = floor(min(tilePx, side / B));
pad    = (side - B*tilePx) / 2;
x0     = x0 + pad;  y0 = y0 + pad;

tileRects = zeros(4, B*B);
k = 1;
for r = 0:B-1
    for c = 0:B-1
        xL = round(x0 + c*tilePx);
        yT = round(y0 + r*tilePx);
        tileRects(:,k) = [xL; yT; xL + tilePx; yT + tilePx];
        k = k + 1;
    end
end
end


function rgb01 = wheelRGB01_fromDegrees(deg, cMap360_255)
% deg: 1×N or N×1 degrees 0..359
idx = round(mod(deg, 360)); idx(idx==0) = 360;   % map 0→360th row
rgb01 = double(cMap360_255(idx, :)) / 255;       % N×3 in [0,1]
end

function huesDeg = sampleVonMisesQuantiles(muDeg, kappa, n)
% Sample from Von Mises distribution using quantile-based inverse transform sampling
% This ensures consistent variance across trials and eliminates rejection sampling inefficiency
% 
% METHOD: Quantile-Based Inverse Transform Sampling
% 1. Generate n uniform quantiles: [0.5/n, 1.5/n, 2.5/n, ..., (n-0.5)/n]
% 2. Map each quantile to an angle using inverse Von Mises CDF
% 3. Shuffle to avoid spatial clustering in the grid
%
% IMPORTANT: The sampling method is IDENTICAL for all noise levels.
%            The ONLY difference is the kappa parameter, which controls distribution width.
%            - High kappa (low noise): narrow distribution → fewer histogram bins populated
%            - Low kappa (high noise): wide distribution → more histogram bins populated
%            This is EXPECTED behavior reflecting the true distribution difference.
%
% Inputs:
%   muDeg: target hue in degrees (0-360)
%   kappa: concentration parameter (high = narrow distribution)
%          - kappa → 0: uniform distribution
%          - kappa → ∞: delta function (all samples = muDeg)
%   n: number of samples to generate
%
% Output:
%   huesDeg: n×1 vector of hue values in degrees (0-360)
%            Distribution has consistent variance determined by kappa

if kappa < 1e-8
    % Effectively uniform: sample uniformly around circle
    huesDeg = mod(muDeg + (rand(1,n) - 0.5) * 360, 360);
    return;
end

% Generate uniform quantiles (centered quantiles for better coverage)
quantiles = ((1:n) - 0.5) / n;  % [0.5/n, 1.5/n, ..., (n-0.5)/n]

% Map quantiles to angles using inverse Von Mises CDF
% Von Mises CDF: F(θ) = ∫[0 to θ] f(φ) dφ where f is Von Mises PDF
% We use numerical inversion via interpolation of precomputed CDF
huesDeg = vonMisesQuantile(muDeg, kappa, quantiles);

% Shuffle to avoid spatial clustering in grid
huesDeg = huesDeg(randperm(n));
end

function anglesDeg = vonMisesQuantile(muDeg, kappa, quantiles)
% Compute quantiles of Von Mises distribution using inverse CDF
% Uses precomputed CDF table for efficiency
%
% Inputs:
%   muDeg: mean direction in degrees (0-360)
%   kappa: concentration parameter
%   quantiles: vector of quantile values in [0, 1]
%
% Output:
%   anglesDeg: quantile angles in degrees (0-360)

persistent cdfTable kappaTable angleRangeTable

% Precompute CDF table if not already done (cached for performance)
if isempty(cdfTable) || isempty(kappaTable)
    % Build CDF lookup table for common kappa values
    % We'll compute CDF for angles from -180° to +180° relative to mean
    nAngles = 2000;  % Resolution: 0.18° per bin (higher resolution for accuracy)
    angleRangeRad = linspace(-pi, pi, nAngles);
    kappaList = [0.5, 1, 2, 3, 5, 10, 20, 30, 50, 100];  % Common kappa values
    
    kappaTable = kappaList;
    cdfTable = zeros(length(kappaList), nAngles);
    angleRangeTable = rad2deg(angleRangeRad);
    
    for ki = 1:length(kappaList)
        k = kappaList(ki);
        % Compute CDF: F(θ) = ∫[-π to θ] f(φ) dφ
        % Von Mises PDF: f(θ) = exp(κ*cos(θ)) / (2π*I₀(κ))
        % Note: Von Mises is symmetric, so we integrate from -π to θ
        I0 = besseli(0, k);
        pdfVals = exp(k * cos(angleRangeRad)) / (2*pi*I0);
        
        % Numerically integrate PDF to get CDF
        % Use trapezoidal rule for better accuracy
        dTheta = angleRangeRad(2) - angleRangeRad(1);
        cdfVals = zeros(size(pdfVals));
        cdfVals(1) = 0;  % CDF at -π is 0
        for i = 2:nAngles
            % Trapezoidal integration: ∫[θᵢ₋₁ to θᵢ] ≈ (f(θᵢ₋₁) + f(θᵢ))/2 * dθ
            cdfVals(i) = cdfVals(i-1) + (pdfVals(i-1) + pdfVals(i))/2 * dTheta;
        end
        % Normalize to [0,1] (CDF at +π should be 1)
        cdfVals = cdfVals / cdfVals(end);
        cdfTable(ki, :) = cdfVals;
    end
end

% Find closest kappa in table
if kappa <= kappaTable(1)
    ki = 1;
elseif kappa >= kappaTable(end)
    ki = length(kappaTable);
else
    [~, ki] = min(abs(kappaTable - kappa));
end

% Get CDF for this kappa
cdfVals = cdfTable(ki, :);
angleRange = angleRangeTable;

% For each quantile, find corresponding angle via inverse CDF (interpolate for accuracy)
anglesDeg = zeros(size(quantiles));
for i = 1:length(quantiles)
    q = quantiles(i);
    % Find indices where CDF brackets the quantile
    idx = find(cdfVals >= q, 1, 'first');
    if isempty(idx)
        % Quantile is at or beyond maximum (shouldn't happen, but handle gracefully)
        anglesDeg(i) = angleRange(end);
    elseif idx == 1
        % Quantile is at or below minimum
        anglesDeg(i) = angleRange(1);
    else
        % Linear interpolation between bracketing CDF values
        qLow = cdfVals(idx-1);
        qHigh = cdfVals(idx);
        if abs(qHigh - qLow) < 1e-10
            anglesDeg(i) = angleRange(idx);
        else
            t = (q - qLow) / (qHigh - qLow);
            anglesDeg(i) = angleRange(idx-1) + t * (angleRange(idx) - angleRange(idx-1));
        end
    end
end

% Convert to absolute angles and wrap to [0, 360)
anglesDeg = mod(muDeg + anglesDeg, 360);
end

function huesDeg = sampleVonMisesDegrees(muDeg, kappa, n)
% Sample from von Mises distribution using rejection sampling
% Best-effort rejection sampler (Best & Fisher, 1979)
% 
% Inputs:
%   muDeg: mean direction in degrees (0-360)
%   kappa: concentration parameter (0 = uniform, higher = more concentrated)
%   n: number of samples
%
% Output:
%   huesDeg: n×1 vector of hue values in degrees (0-360)

mu = deg2rad(muDeg);
if kappa < 1e-8
    % Effectively uniform
    huesDeg = rand(1,n) * 360;
    return;
end

% Best & Fisher (1979) rejection sampler parameters
a = 1 + sqrt(1 + 4*kappa^2);
b = (a - sqrt(2*a)) / (2*kappa);
r = (1 + b^2) / (2*b);

out = zeros(1,n);
i = 1;
attempts = 0;
maxAttempts = 2000;

while i <= n
    U1 = rand;
    z = cos(pi*U1);
    f = (1 + r*z) / (r + z);
    c = kappa * (r - f);
    U2 = rand;
    attempts = attempts + 1;
    
    if attempts > maxAttempts
        % Fallback to uniform sample around mean if rejection keeps failing
        logMsg(sprintf('VonMises sampler fallback triggered (kappa=%.2f)', kappa));
        out(i) = mu + (rand*2*pi - pi);
        i = i + 1;
        attempts = 0;
        continue;
    end
    
    if U2 < c*(2 - c) || U2 <= c*exp(1 - c)
        U3 = rand;
        f = max(min(f, 1), -1);  % numerical guard
        theta = acos(f);
        if U3 > 0.5
            theta = -theta;
        end
        out(i) = mu + theta;
        i = i + 1;
        attempts = 0;
    end
end

% Wrap to [0, 360) degrees
out = angle(exp(1i*out));                 % wrap to (-pi,pi]
huesDeg = mod(rad2deg(out), 360);        % 0..360
end


function DrawCenteredText(win, msg, pts, col01)
% Draw centered text with color format handling
global V
if isfield(V, 'useFloat') && V.useFloat
    % Floating point mode: use normalized colors as-is
    textCol = col01;
else
    % Standard mode: convert normalized to 0-255 if needed
    if max(col01) <= 1
        textCol = col01 * 255;
    else
        textCol = col01; % Already in 0-255 format
    end
end
Screen('TextSize', win, pts);
DrawFormattedText(win, msg, 'center', 'center', textCol);
end

function FillBG(V)
% Fill background with appropriate color format based on window mode
% Ensure V.bg01 exists (defensive programming)
if ~isfield(V, 'bg01')
    V.bg01 = [0.5 0.5 0.5]; % Default normalized gray
end
if ~isfield(V, 'patch') || ~isfield(V.patch, 'bg')
    V.patch.bg = 0.5 * 255; % Default 0-255 gray
end

if isfield(V, 'useFloat') && V.useFloat
    % Floating point mode: use normalized 0-1 colors
    bgColor = V.bg01;
else
    % Standard mode: use 0-255 colors
    bgColor = [V.patch.bg V.patch.bg V.patch.bg];
end
Screen('FillRect', V.window, bgColor);
end

function r = WaitForMouseClickOrEsc()
r = 0;
while any(GetMouseButtons()), WaitSecs(0.01); end
while true
    [~,~,b] = GetMouse;
    if b(1), r = 1; break; end
    [down,~,kc] = KbCheck;
    if down && kc(KbName('ESCAPE')), r = -1; break; end
    WaitSecs(0.01);
end
WaitForMouseRelease();
end

function WaitForMouseRelease()
while any(GetMouseButtons()), WaitSecs(0.01); end
end

function b = GetMouseButtons()
[~,~,b] = GetMouse;
end

function drawFixation(V, lineCol, innerCol)
% Draw fixation cross with colors that work in both float and standard modes
% lineCol and innerCol are expected in normalized 0-1 format
len = 10;  lw = 2;
xy  = [-len, len, 0, 0; 0, 0, -len, len];

% Convert normalized colors if in standard mode
if ~(isfield(V, 'useFloat') && V.useFloat)
    lineCol = lineCol * 255;
    innerCol = innerCol * 255;
end

Screen('DrawLines', V.window, xy, lw, lineCol, [V.centerX, V.centerY]);
r1 = CenterRectOnPointd([0 0 len*2 len*2], V.centerX, V.centerY);
Screen('FrameOval', V.window, lineCol, r1, lw);
r2 = CenterRectOnPointd([0 0 4 4], V.centerX, V.centerY);
Screen('FrameOval', V.window, innerCol, r2, lw);
end

function cleanup()
logMsg('Cleanup called');
sca; disp('Demo ended.');
end

%================Base Helpers============================

function v = initiate() %Global variable with hard-coded defaults.

sca;                   
Screen('CloseAll');    
WaitSecs(0.5);

% Background color: store both 0-255 and 0-1 formats for compatibility
v.patch.bg = 0.5 * 255; % Background gray (0-255 range)
v.bg01 = [0.5 0.5 0.5]; % Normalized background (0-1 range) for floating point mode

Screen('Preference', 'SkipSyncTests', 1);
Screen('Preference', 'VisualDebugLevel', 0); % Minimal feedback
PsychDefaultSetup(2);

% Try floating point mode, fall back gracefully if it fails
try
    PsychImaging('PrepareConfiguration');
    PsychImaging('AddTask','General','FloatingPoint32BitIfPossible'); % 16/32-bit FB
    PsychImaging('AddTask','General','EnableNative10BitFramebuffer'); % if GPU/OS/display allow
    [v.window, v.windowRect] = PsychImaging('OpenWindow', max(Screen('Screens')), v.bg01);
    v.useFloat = true; % Flag to remember we're in float mode
catch ME
    % Fallback to standard 8-bit mode
    warning('Floating point mode failed, using standard 8-bit: %s', ME.message);
    [v.window, v.windowRect] = Screen('OpenWindow', max(Screen('Screens')), [v.patch.bg v.patch.bg v.patch.bg]);
    v.useFloat = false;
end

Screen('BlendFunction', v.window, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
Screen('Flip', v.window);
[v.centerX, v.centerY] = RectCenter(v.windowRect);

% Warm-up background flip
if v.useFloat
    Screen('FillRect', v.window, v.bg01);
else
    Screen('FillRect', v.window, [v.patch.bg v.patch.bg v.patch.bg]);
end
Screen('Flip', v.window);
WaitSecs(0.1);

    % Warm-up font engine (PTB loads fonts lazily)
    Screen('TextSize', v.window, 36);
    DrawFormattedText(v.window, '.', 'center', 'center', [255 255 255]);
    Screen('Flip', v.window);
    WaitSecs(0.1);

    % Optional: preload inter-trial texture (if available now)
    % This avoids lag at first display
    % You can skip this here if texture generation is not yet possible
    % feedbackTex = GenerateFeedbackTexture(...);
    % Screen('DrawTexture', V.window, feedbackTex);
    % Screen('Flip', V.window);
    % WaitSecs(0.1);

    % Flush input buffers
    FlushEvents('keyDown');
    FlushMouseEvents();

useCIE_LABcolorwheel = false; % if false, use OK_LAB Color wheel.

if useCIE_LABcolorwheel
    % This LAB color wheel was selected by Yi and Paul 16/04/2025
    %    using the LABolorspaceSelection.m code which accompanies
    %    this experiment code. Selection was based for the perception
    %    of relatively comparable color-zones around the wheel, however,
    %    this was a subjective assessment at the time based on a specific
    %    testing monitor. Color perceptions are subject to change.
    v.color.L = 65;
    v.color.a = 20;
    v.color.b = 0;
    v.color.radius = 70;
    v.color.incriments = 360 * 5;

    v.color.angles = 0:2*pi/v.color.incriments:2*pi;
    v.color.map(:,2:3) = v.color.radius*[cos(v.color.angles') sin(v.color.angles')];
    v.color.map(:,1) = v.color.L;
    v.color.map(:,2) = v.color.map(:,2) + v.color.a;
    v.color.map(:,3) = v.color.map(:,3) + v.color.b;
    v.color.map(end,:) = [];
    v.color.angles = v.color.angles(1:end-1);
    v.color.labmap = v.color.map;

    cform = makecform('lab2srgb');
    v.color.map = applycform(v.color.map, cform) * 255;
else

    % This is the OKlab color space selected by Paul on the 06/05/2025
    % following Hang (Allen) Qian's suggested usage. This is a perceptually
    % smoother color wheel based in LAB space, which should suit our
    % purposes.
    v.color.L          = 0.85;            % lightness (0–1, 1 = D65 white)
    v.color.radius     = 0.23;            % chroma radius
    v.color.increments = 360 * 7;         % spokes

    v.color.angles = 0 : 2*pi/v.color.increments : 2*pi;
    v.color.map    = zeros(numel(v.color.angles), 3);      % pre-allocate
    
    % a- and b- coordinates around the circle
    v.color.map(:,2:3) = v.color.radius * [cos(v.color.angles')  sin(v.color.angles')];
    v.color.map(:,1)   = v.color.L;                      % column 1 = L
    v.color.map(end,:) = [];                             % remove duplicate 0/2π sample
    v.color.angles     = v.color.angles(1:end-1);
    rgbLin             = okLab2linSRGB(v.color.map);     % linear sRGB (0–1)
    rgb                = lin2srgb(rgbLin);               % γ-encoded sRGB
    rgb                = max(min(rgb,1),0);              % hard-clip gamut
    v.color.map        = rgb * 255;                      % match your LAB wheel

end

v.color.rotation = randi([0, 359]);
v = StimulusDurations(v);
v.Keys = ResponseKeys();
end

% Screen Calibration Credit Card Trick (Ok)
function fiveDegVA_in_pixels = calibrateMonitor()
    global V

    % check calibration exists
    currentConfig.pcName = getenv('COMPUTERNAME');
    currentConfig.monitorPositions = get(0, 'MonitorPositions');
    calibFilename = 'screenCalibration.mat';

    if exist(calibFilename, 'file')
        S = load(calibFilename, 'savedConfig', 'calibrationData');
        if ~isequal(S.savedConfig, currentConfig)
            runCalibration = true;
        else
            runCalibration = false;
            fiveDegVA_in_pixels = S.calibrationData;
        end
    else
        runCalibration = true;
    end

    if runCalibration

        DrawFormattedText(V.window, ...
            ['Align these two lines with the edges of your credit card.\n\nUse LEFT/RIGHT ' ...
            'arrow keys to move each line.\nUse UP/DOWN arrow keys to choose which line' ...
            ' moves.\nPress ENTER when done.'], ...
            'center', 'center', [1 1 1]);
        Screen('Flip', V.window);
        WaitSecs(1);
        blank(0);
    
        leftLineX = V.centerX - V.centerX * .33;
        rightLineX = V.centerX + V.centerX * .33;
        currentLine = 'left';
    
        done = false;
        moveStep = 1; % 1 pixel for precision
        while ~done
            [keyIsDown, ~, keyCode] = KbCheck;
            if keyIsDown
                if keyIsDown && keyCode(V.Keys.ctrlKey) && keyCode(V.Keys.quitKey)
                    disp('Quit Buttons Pressed. Erroring Out Of The Experiment...');
                    QuitButtonsPressed;
                end
                if keyCode(KbName('LeftArrow'))
                    if strcmp(currentLine, 'left')
                        leftLineX = leftLineX - moveStep;
                    else
                        rightLineX = rightLineX - moveStep;
                    end
                elseif keyCode(KbName('RightArrow'))
                    if strcmp(currentLine, 'left')
                        leftLineX = leftLineX + moveStep;
                    else
                        rightLineX = rightLineX + moveStep;
                    end
                elseif keyCode(KbName('UpArrow')) || keyCode(KbName('DownArrow'))
                    if strcmp(currentLine, 'left')
                        currentLine = 'right';
                    else
                        currentLine = 'left';
                    end
                    WaitSecs(0.1);
                elseif keyCode(KbName('Return'))
                    done = true;
                end
                blank(0);
            end
            
            if strcmp(currentLine, 'left')
                lineIndicatorLeft = [1 1 1];   % maybe the same color, or highlight
                lineIndicatorRight = [0 0 0];  % dim color for non-selected
            else
                lineIndicatorLeft = [0 0 0];
                lineIndicatorRight = [1 1 1];
            end
    
            Screen('DrawLine', V.window, lineIndicatorLeft, ...
                leftLineX, 0, leftLineX, V.windowRect(4), 2);
            Screen('DrawLine', V.window, lineIndicatorRight, ...
                rightLineX, 0, rightLineX, V.windowRect(4), 2);
            DrawFormattedText(V.window, ...
                'Use arrow keys to move lines. Press ENTER when done.', ...
                'center', 50, [1 1 1]);
            Screen('Flip', V.window);
            WaitSecs(0.01);
    
        end
        blank(0);
        measured = rightLineX - leftLineX;
        CreditCardWith = 85.60;
        pixelsPerMm = measured / CreditCardWith;
        viewingdistance = 600; % 60cm
        desiredAngleDeg = 5; % 5 degree visual angle
        stim_in_mm = 2 * viewingdistance * tan((desiredAngleDeg / 2) * (pi/180));
        fiveDegVA_in_pixels = round( stim_in_mm * pixelsPerMm );
        % also get a pixel per degree value for square stimuli
        V.pxPerDeg =  fiveDegVA_in_pixels/5;

        savedConfig = currentConfig; 
        calibrationData = fiveDegVA_in_pixels; 
        save('screenCalibration.mat', 'savedConfig', 'calibrationData');
    end
end

function [] = adjustSquareStim(VA5deg)
% ADJUSTSQUARESTIM  VA-based geometry for upright square stimuli.
% - Squares are axis-aligned (no rotation).
% - Stimulus CENTERS lie on the 5° circle (radius = VA5deg/2).

global V

% ---- Validate inputs ----
if ~isfield(V,'window') || isempty(V.window) || ~Screen('WindowKind', V.window)
    error('adjustSquareStim:InvalidWindow','V.window is not a valid PTB window.');
end
if ~isscalar(VA5deg) || ~isfinite(VA5deg) || VA5deg<=0
    error('adjustSquareStim:InvalidVA5','VA5deg must be a positive finite scalar (pixels).');
end

% ---- px/deg & the center-path radius (5° circle) ----
V.pxPerDeg               = VA5deg / 5;                  % px per 1°
V.layout.centerRadiusPx  = max(1, round(VA5deg/2));     % = 2.5° in px

% ---- Derive other geometry (scaled from your originals) ----
degpx = V.pxPerDeg;
V.feedback.linewidth   = max(1, round(degpx * .08));
V.feedback.ticklength  = round(degpx * .50);

V.annulus.radiusOuter  = round(degpx * 4.75);
V.annulus.radiusInner  = round(degpx * 4.25);

V.stim.positionradius  = round(degpx * 1.82);   % legacy ring (unused here but kept)

% ---- Square stimulus spec (upright) ----
V.square.R_deg         = 0.80;      % inscribing circle radius in deg (≈ your 0.8° size)
V.square.coverage_c    = 1.00;      % 1.00 => corners touch the inscribing circle
V.square.B             = 8;        % B×B tiles

side_deg_full          = V.square.coverage_c * sqrt(2) * V.square.R_deg;
side_px_full           = max(V.square.B, round(side_deg_full * V.pxPerDeg));
side_px_full           = side_px_full - mod(side_px_full, V.square.B);  % divisible by B
V.square.side_px_full  = max(V.square.B, side_px_full);
V.square.tile_px       = V.square.side_px_full / V.square.B;

% ---- Optional preview: draw 5° circle & square centers (only if rect is valid) ----
% Build rect and clamp to window bounds to avoid out-of-range errors.
fiveDegCirc = round([V.centerX - VA5deg/2, V.centerY - VA5deg/2, ...
                     V.centerX + VA5deg/2, V.centerY + VA5deg/2]);

% Ensure rect is sane (left<right, top<bottom, inside window)
winRect = V.windowRect;
fiveDegCirc(1) = max(fiveDegCirc(1), winRect(1));
fiveDegCirc(2) = max(fiveDegCirc(2), winRect(2));
fiveDegCirc(3) = min(fiveDegCirc(3), winRect(3));
fiveDegCirc(4) = min(fiveDegCirc(4), winRect(4));
if fiveDegCirc(3) > fiveDegCirc(1) && fiveDegCirc(4) > fiveDegCirc(2)
    % Draw preview only if rect is valid
    Screen('FillRect', V.window, V.bg01);
    Screen('FrameOval', V.window, [0.6 0.6 0.6], fiveDegCirc, 2);
    DrawFormattedText(V.window, '5° circle = center path for stimuli', ...
        'center', V.windowRect(4)*0.08, [1 1 1]);

    % Also preview 6 centers evenly spaced
    previewAnglesDeg = (0:5) * (360/6);
    s = V.square.side_px_full;
    for a = previewAnglesDeg
        th = deg2rad(a);
        cx = V.centerX + V.layout.centerRadiusPx * cos(th);
        cy = V.centerY + V.layout.centerRadiusPx * sin(th);
        rect = CenterRectOnPointd([0 0 s s], cx, cy);
        Screen('FrameRect', V.window, [1 1 1], rect, 2);
    end
    Screen('Flip', V.window);
    WaitSecs(0.4);
else
    % If invalid, skip preview rather than erroring out
    % (Everything else can still proceed with geometry set.)
end
end


function FlushMouseEvents()
    % Continuously check the mouse status and only exit when no buttons are pressed
    while any(GetMouseButtons())
        % Wait briefly to avoid overloading the CPU
        WaitSecs(0.01);
    end
end

function linRGB = okLab2linSRGB(okLab)
% okLab2linSRGB  Convert OKLab to linear sRGB (0–1)
%
% Reference: Björn Ottosson’s OKLab specification, Nov-2020
%
L = okLab(:,1);   a = okLab(:,2);   b = okLab(:,3);

l_ = L + 0.3963377774*a + 0.2158037573*b;
m_ = L - 0.1055613458*a - 0.0638541728*b;
s_ = L - 0.0894841775*a - 1.2914855480*b;

LMS = [l_.^3, m_.^3, s_.^3]; % undo cube root

M = [ 4.0767416621, -3.3077115913,  0.2309699292;
     -1.2684380046,  2.6097574011, -0.3413193965;
     -0.0041960863, -0.7034186147,  1.7076147010];
linRGB = LMS * M.';
end

function srgb = lin2srgb(linRGB)
% lin2srgb  Linear sRGB (0–1) → γ-encoded sRGB (0–1)
th = 0.0031308;
srgb            = zeros(size(linRGB));
mask            = linRGB <= th;
srgb(mask)      = 12.92 * linRGB(mask);
srgb(~mask)     = 1.055 * linRGB(~mask).^(1/2.4) - 0.055;
end

function v = StimulusDurations(v)
% ALL timing parameters in V.Durations.*
% If you call it with V only, it keeps whatever is already there.
% If you pass new vectors, they overwrite the lists.

% single-value legacy fields (kept for old helpers that expect them)
v.Durations.FixationDuration       = 1.000;
%V.Durations.PreCueDuration         = 0.30;
v.Durations.StimulusDuration       = [0.10 0.15 0.20 0.25 0.30 0.35];
v.Durations.MaskDuration           = 0.750;
v.Durations.FeedbackDuration       = 0.750;
v.Durations.FeedbackPenaltyDuration= 2.00;
v.Durations.ResponseDuration       = 10.0;
v.Durations.TrialTooSlow           = 3000;  % ms
v.Durations.RetinalColorReset      = 0.005;
end

function v = ResponseKeys()
    v.ctrlKey = KbName('LeftControl');  
    v.quitKey = KbName('l');
end

function drawHUD(V, msg)
% Draw HUD text near the bottom with proper color format
Screen('TextSize', V.window, 26);
if isfield(V, 'useFloat') && V.useFloat
    hudCol = [1 1 1]; % Normalized for float mode
else
    hudCol = [255 255 255]; % 0-255 for standard mode
end
DrawFormattedText(V.window, msg, 'center', V.windowRect(4)*0.90, hudCol); % 90% down
end

function drawStageInfo(V, msg)
if isempty(msg)
    return;
end
Screen('TextSize', V.window, 24);
if isfield(V, 'useFloat') && V.useFloat
    infoCol = [1 1 1];
else
    infoCol = [255 255 255];
end
DrawFormattedText(V.window, msg, 50, 50, infoCol);
end

function ensureDir(d)
if ~exist(d,'dir'), mkdir(d); end
end

function logMsg(msg)
persistent fid
try
    if isempty(fid) || fid == -1
        fid = fopen('SqNoisyDemo.log','a');
        if fid == -1
            return;
        end
    end
    fprintf(fid, '[%s] %s\n', datestr(now,'yyyy-mm-dd HH:MM:SS.FFF'), msg);
    fflush(fid);
catch
    % swallow logging errors to avoid impacting experiment
end
end

function [] = blank(duration)
% Blank screen with optional wait duration
global V
Screen('FillRect', V.window, V.bg01);
Screen('Flip', V.window);
if nargin > 0 && duration > 0
    WaitSecs(duration);
end
end

function [] = QuitButtonsPressed()
% Clean exit handler when Ctrl+L is pressed
global V
try
    sca;
    Screen('CloseAll');
catch
end
disp('Experiment terminated by user.');
error('Experiment terminated by user (Ctrl+L).');
end

function drawDistributionViz(V, huesDeg, targetHueDeg, noiseLevel, P)
% Draw distribution histogram and statistics on screen
% Shows hue distribution around target with variance statistics
%
% Inputs:
%   V: global visual structure
%   huesDeg: vector of sampled hue values (degrees, 0-360)
%   targetHueDeg: target hue (degrees, 0-360)
%   noiseLevel: 'low' or 'high'
%   P: parameter structure

% Get kappa for this noise level
if strcmpi(noiseLevel, 'low')
    kappa = P.K_LowNoise;
else
    kappa = P.K_HighNoise;
end

% Calculate statistics
offsets = mod(huesDeg - targetHueDeg + 180, 360) - 180;  % Signed offsets in [-180, 180]
meanOffset = mean(offsets);
stdOffset = std(offsets);
circularStd = sqrt(mean(offsets.^2));  % Circular standard deviation approximation

% Calculate effective range (95% of samples within this range)
sortedOffsets = sort(abs(offsets));
percentile95Idx = round(0.95 * length(sortedOffsets));
effectiveRange95 = sortedOffsets(percentile95Idx);

% Count how many bins have non-zero counts (for diagnostic)
% Change nBins to adjust histogram resolution (bins will cover whole circle)
nBins = 36; 
binEdges = linspace(-180, 180, nBins+1);
counts = histcounts(offsets, binEdges);
nPopulatedBins = sum(counts > 0);

% Position: top-right corner
winRect = V.windowRect;
vizX = winRect(3) - 300;  % 300px from right edge
vizY = 50;  % 50px from top
vizW = 280;
vizH = 220;  % Increased height to accommodate diagnostic info

% Background box
bgRect = [vizX-10, vizY-10, vizX+vizW+10, vizY+vizH+10];
if isfield(V, 'useFloat') && V.useFloat
    bgCol = [0.1 0.1 0.1 0.8];  % Semi-transparent dark
    textCol = [1 1 1];
else
    bgCol = [25 25 25];
    textCol = [255 255 255];
end
Screen('FillRect', V.window, bgCol, bgRect);
Screen('FrameRect', V.window, textCol, bgRect, 2);

% Draw histogram (using precomputed binEdges and counts from above)
binCenters = (binEdges(1:end-1) + binEdges(2:end)) / 2;
maxCount = max(counts);
if maxCount > 0
    counts = counts / maxCount;  % Normalize to [0,1]
end

histX = vizX + 20;
histY = vizY + 70;  % Moved up slightly to accommodate more text
histW = vizW - 40;
histH = 80;

% Draw histogram bars
for i = 1:nBins
    barH = counts(i) * histH;
    barX = histX + (i-1) * histW / nBins;
    barW = histW / nBins - 1;
    barRect = [barX, histY + histH - barH, barX + barW, histY + histH];
    if isfield(V, 'useFloat') && V.useFloat
        barCol = [0.3 0.6 1.0];  % Blue bars
    else
        barCol = [77 153 255];
    end
    Screen('FillRect', V.window, barCol, barRect);
end

% Draw target line (at 0 offset)
targetX = histX + histW/2;
Screen('DrawLine', V.window, textCol, targetX, histY, targetX, histY+histH, 2);

% Draw mean offset line
if abs(meanOffset) > 0.1
    meanX = histX + (meanOffset + 180) / 360 * histW;
    if meanX >= histX && meanX <= histX + histW
        Screen('DrawLine', V.window, [1 0.5 0.5], meanX, histY, meanX, histY+histH, 1);
    end
end

% Draw title
Screen('TextSize', V.window, 16);
titleText = sprintf('%s Noise Distribution', [upper(noiseLevel(1)) noiseLevel(2:end)]);
DrawFormattedText(V.window, titleText, vizX+10, vizY+10, textCol);

% Draw statistics text
Screen('TextSize', V.window, 14);
statsText = sprintf('K=%.1f | Mean: %.1f° | Std: %.1f°', kappa, meanOffset, stdOffset);
DrawFormattedText(V.window, statsText, vizX+10, vizY+30, textCol);

% Draw additional diagnostic info
Screen('TextSize', V.window, 12);
rangeText = sprintf('95%% range: ±%.1f° | Active bins: %d/%d', effectiveRange95, nPopulatedBins, nBins);
DrawFormattedText(V.window, rangeText, vizX+10, vizY+50, textCol);

% Draw axis labels
Screen('TextSize', V.window, 12);
DrawFormattedText(V.window, '-180', histX-25, histY+histH+5, textCol);
DrawFormattedText(V.window, '0', histX+histW/2-5, histY+histH+5, textCol);
DrawFormattedText(V.window, '+180', histX+histW-25, histY+histH+5, textCol);
end
