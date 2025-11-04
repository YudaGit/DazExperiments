function SqNoisyStim_Demo1

% ------------------------------------------------------------
% Demo: Low vs High noise color square stimuli (B×B tiles)
% Also have updated basic helper functions as of 04/11/2025:
% - initiate()
% - screenCalibration()
% Stages controlled with mouse/F/B as specified by user.
% Requires: initiate(), calibrateMonitor(), adjustSquareStim()
% PTB R2024b + classic Psychtoolbox.
% Stages:
% 1) single low-noise @ 12 o'clock (click to replay; F next; B back)
% 2) single high-noise @ 12 o'clock
% 3) 4 items (R,U,L,D), LOW noise; R & L are exact replicas
% 4) 4 items (R,U,L,D), HIGH noise; R & L are exact replicas
% 5) 2-interval same location (LOW noise): replica after 300 ms ISI
% 6) 2-interval diff location (LOW noise): replica at a different angle
% ------------------------------------------------------------

% ---------- Setup ----------
clear; close all; clc;
sca; Screen('CloseAll');
KbName('UnifyKeyNames');
PsychDefaultSetup(2);
Screen('Preference', 'SkipSyncTests', 1);
Screen('Preference', 'VisualDebugLevel', 1);

global V
V = initiate();
win = V.window;

VA5deg = calibrateMonitor();
adjustSquareStim(VA5deg);      % sets V.square.*, V.layout.centerRadiusPx, etc.

ifi = Screen('GetFlipInterval', win);
fprintf('Refresh: %.2f Hz (%.3f ms/frame)\n', 1/ifi, ifi*1000);

% ---------- Parameters ----------
params.kappaLowNoise  = 12;   % "low noise" = narrow VM (higher evidence)
params.kappaHighNoise =  2;   % "high noise" = wide VM  (lower evidence)
params.limitDeg       = 10;   % clamp samples to ±10° around target
params.durMs          = 150;  % stimulus duration
params.ISI            = 0.300; % seconds (stage 5/6)
params.angles4        = [0 90 180 270];  % right, up, left, down (deg)

% A wheel sampled to 360 (0..255), then normalized to 0..1 at draw time:
params.cMap360_255 = V.color.map(round(linspace(1, size(V.color.map,1), 360)), :);

% duration to show (ms)
stim.durMs      = 150;    % try 150 ms for a quick pop

% ---------- Intro ----------
FillBG(V);
drawFixation(V, [0.25 0.25 0.25], [0.75 0.75 0.75]);
DrawCenteredText(win, 'Demo for low and high noise level color square stimuli\n\nClick mouse to proceed', 36, [1 1 1]);
Screen('Flip', win);
if WaitForMouseClickOrEsc() < 0, cleanup(); return; end

% ---------- Stage loop ----------
stage = 1;
keepGoing = true;
while keepGoing
    switch stage
        case 1
            % Stage 1: single LOW noise at 12 o'clock (i.e., angle 90° "up")
            keepGoing = stage_click_to_repeat(win, @() ...
                stage_single(V, 90, params.kappaLowNoise, params), ...
                @() advance('F'), @() advance('B'));
            if ~keepGoing, break; end
            stage = nav(stage);

        case 2
            % Stage 2: single HIGH noise same position
            keepGoing = stage_click_to_repeat(win, @() ...
                stage_single(V, 90, params.kappaHighNoise, params), ...
                @() advance('F'), @() advance('B'));
            if ~keepGoing, break; end
            stage = nav(stage);

        case 3
            % Stage 3: 4 items (U/D/L/R) all LOW noise;
            % two are exact replicas (same noisy pattern), other two unique colors.
            keepGoing = stage_click_to_repeat(win, @() ...
                stage_four_low_with_replicas(V, params), ...
                @() advance('F'), @() advance('B'));
            if ~keepGoing, break; end
            stage = nav(stage);

        case 4
            % Stage 4: same as 3 but all HIGH noise
            keepGoing = stage_click_to_repeat(win, @() ...
                stage_four_high_with_replicas(V, params), ...
                @() advance('F'), @() advance('B'));
            if ~keepGoing, break; end
            stage = nav(stage);

        case 5
            % Stage 5: one LOW noise at 12 o'clock, ISI 300ms, exact replica at same location
            keepGoing = stage_click_to_repeat(win, @() ...
                stage_two_interval_same_loc(V, 90, params.kappaLowNoise, params), ...
                @() advance('F'), @() advance('B'));
            if ~keepGoing, break; end
            stage = nav(stage);

        case 6
            % Stage 6: same as 5 but second interval at different location (e.g., 270° "down")
            keepGoing = stage_click_to_repeat(win, @() ...
                stage_two_interval_diff_loc(V, 90, 270, params.kappaLowNoise, params), ...
                @() advance('F'), @() advance('B'));
            if ~keepGoing, break; end
            stage = nav(stage);

        otherwise
            keepGoing = false;
    end
end

cleanup();
end


% ---------------------------------------------HELPERS-----------------------------------------

function DrawCenteredText(win, msg, pts, col01)
Screen('TextSize', win, pts);
DrawFormattedText(win, msg, 'center', 'center', col01);
end

function btn = WaitForMouseClickOrEsc()
% returns 1 for left-click, -1 for ESC
btn = 0;
% Debounce: wait until no button is down
while any(GetMouseButtons()), WaitSecs(0.01); end
while true
    [~,~,buttons] = GetMouse;
    if buttons(1), btn = 1; break; end
    [down,~,kc] = KbCheck;
    if down && (kc(KbName('ESCAPE')) || (kc(KbName('LeftControl')) && kc(KbName('l'))))
        btn = -1; break;
    end
    WaitSecs(0.01);
end
% Wait for release
while any(GetMouseButtons()), WaitSecs(0.01); end
end

function b = GetMouseButtons()
[~,~,b] = GetMouse;
end

function drawFixation(V, lineCol, innerCol)
% small cross + two circles (all 0..1 colors)
len = 10;  lw = 2;
xy  = [-len, len, 0, 0; 0, 0, -len, len];
Screen('DrawLines', V.window, xy, lw, lineCol, [V.centerX, V.centerY]);

r1 = [0 0 len*2 len*2]; r1 = CenterRectOnPointd(r1, V.centerX, V.centerY);
Screen('FrameOval', V.window, lineCol, r1, lw);

r2 = [0 0 4 4];         r2 = CenterRectOnPointd(r2, V.centerX, V.centerY);
Screen('FrameOval', V.window, innerCol, r2, lw);
end

function presentSquare(V, ~)
% Present one centered square for fixed duration using calibrated size.

side_px = V.square.side_px_full;
rect    = CenterRectOnPointd([0 0 side_px side_px], V.centerX, V.centerY);

ifi = Screen('GetFlipInterval', V.window);
durMs = 150;                                % or pass in if you prefer
nF  = max(1, round((durMs/1000)/ifi));

FillBG(V);
Screen('FillRect', V.window, [0.7 0.7 0.7], rect);
drawFixation(V, [0.25 0.25 0.25], [0.75 0.75 0.75]);
vbl = Screen('Flip', V.window);
for f = 2:nF
    Screen('Flip', V.window, vbl + (f-1)*ifi);
end
end

function keepGoing = waitReplayOrQuit(V)
keepGoing = true;
while true
    [down,~,kc] = KbCheck;
    if down
        if kc(KbName('ESCAPE')), keepGoing = false; return; end
        if kc(KbName('f')) || kc(KbName('F')), return; end % placeholder for "next"
        if kc(KbName('b')) || kc(KbName('B')), return; end % placeholder for "prev"
    end
    [~,~,buttons] = GetMouse;
    if buttons(1), return; end     % replay on click
    % keep a stable blank with fixation:
    FillBG(V); drawFixation(V, [0.25 0.25 0.25], [0.75 0.75 0.75]); Screen('Flip', V.win);
    WaitSecs(0.01);
end
end

%================Base Helpers============================

function v = initiate()
% INITIATE  Open PTB window with float/10-bit if possible, 0–1 color path.

    % Start clean
    sca; WaitSecs(0.2);

    % Legacy-compatible storage + normalized draw color
    v = struct();
    v.patch.bg = 0.5 * 255;                 % keep as 0..255 for legacy
    v.bg01     = repmat(v.patch.bg/255,1,3);% normalized 0..1 triplet

    screenId = max(Screen('Screens'));

    % --- Try float/10-bit. If anything fails, fall back to standard 8-bit.
    triedFloat = false; opened = false;
    try
        triedFloat = true;
        PsychImaging('PrepareConfiguration');
        PsychImaging('AddTask','General','FloatingPoint32BitIfPossible');
        PsychImaging('AddTask','General','EnableNative10BitFramebuffer');
        [v.window, v.windowRect] = PsychImaging('OpenWindow', screenId, v.bg01);
        opened = true;
    catch ME1
        warning('Float/10-bit path failed: %s', ME1.message);
        opened = false;
    end
    if ~opened
        % Fallback path (standard 8-bit)
        [v.window, v.windowRect] = Screen('OpenWindow', screenId, v.bg01);
        opened = true;
    end

    % Safety: assert we actually have a window now
    if ~opened || isempty(v) || ~isfield(v,'window') || isempty(v.window)
        error('initiate:FailedOpen','Failed to open a PTB window.');
    end

    % Now safe to set blend mode
    Screen('BlendFunction', v.window, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    % Centers
    [v.centerX, v.centerY] = RectCenter(v.windowRect);
    % Aliases so older helpers work without edits:
    v.win = v.window;
    v.cx  = v.centerX;
    v.cy  = v.centerY;

    % Gentle warm-ups (all 0–1 colors)
    Screen('FillRect', v.win, v.bg01);  Screen('Flip', v.window); WaitSecs(0.10);
    Screen('TextSize', v.win, 36);
    DrawFormattedText(v.win, '.', 'center', 'center', [1 1 1]);
    Screen('Flip', v.win);              WaitSecs(0.10);

    % Input buffers
    FlushEvents('keyDown');
    FlushMouseEvents;

    % Minimal keys (if you rely on them later)
    v.Keys = struct();
    v.Keys.ctrlKey = KbName('LeftControl');
    v.Keys.quitKey = KbName('l');
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
    
        leftLineX = V.cx - V.cx * .33;
        rightLineX = V.cx + V.cx * .33;
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

% ---- px/deg + center radius set to 5° circle ----
V.pxPerDeg             = VA5deg / 5;        % px per 1°
V.layout.centerRadiusPx= round(VA5deg/2);   % radius for item centers = 2.5°

% ---- show the 5° circle (for sanity check) ----
fiveDegCirc = [V.cx - VA5deg/2, V.cy - VA5deg/2, ...
               V.cx + VA5deg/2, V.cy + VA5deg/2];
Screen('FillRect', V.win, V.bg01);
Screen('FrameOval', V.win, [1 1 1]*0.6, fiveDegCirc, 2);
DrawFormattedText(V.win, '5° circle = center path for stimuli', ...
    'center', V.windowRect(4)*0.08, [1 1 1]);
Screen('Flip', V.win); WaitSecs(0.4);

% --- Feedback & annulus params (scaled from your originals) ------
degpx = V.pxPerDeg; % 1° in px
V.feedback.linewidth  = round(degpx * .08);
V.feedback.ticklength = round(degpx * .50);

V.annulus.radiusOuter   = round(degpx * 4.75);
V.annulus.radiusInner   = round(degpx * 4.25);

V.stim.positionradius   = round(degpx * 1.82);   % item centers on annulus

% ---- SQUARE stimulus spec (upright) ----
    V.square.R_deg      = 0.50;     % inscribing circle radius at full scale (deg)
    V.square.coverage_c = 1.00;     % 1.00 => corners touch that inscribing circle
    V.square.B          = 12;       % B×B superpixel tiles
    % target side length in degrees:
    V.square.side_deg_full = 0.80;   % <<< set your desired stimulus size here

    % convert to px, force divisible by B
    side_px_full = round(V.square.side_deg_full * V.pxPerDeg);
    side_px_full = side_px_full - mod(side_px_full, V.square.B);
    side_px_full = max(side_px_full, V.square.B);
    V.square.side_px_full = side_px_full;
    V.square.tile_px      = side_px_full / V.square.B;

    % ---- mouse init ring (unchanged semantics) ----
    V.mouseinit.radius      = round(degpx * .40);
    V.mouseinit.radiusWidth = round(degpx * .03);
    V.mouseinit.color       = [0.33 0.33 0.33];
    V.mouseinit.toofast     = 200;
    V.mouseinit.tooslow     = 50000;

    % ---- optional preview: centers on 5° circle, squares upright ----
    Screen('FillRect', V.window, V.bg01);
    Screen('FrameOval', V.window, [1 1 1]*0.6, fiveDegCirc, 2);

    % sample 6 evenly spaced angles just for preview (your trials can use any set)
    previewAnglesDeg = (0:5) * (360/6);
    for a = previewAnglesDeg
        th = deg2rad(a);
        cx = V.cx + V.layout.centerRadiusPx * cos(th);
        cy = V.cy + V.layout.centerRadiusPx * sin(th);

        % upright (axis-aligned) square rect centered at (cx,cy)
        s  = V.square.side_px_full;
        rect = CenterRectOnPointd([0 0 s s], cx, cy);
        Screen('FrameRect', V.window, [1 1 1], rect, 2);
    end

    DrawFormattedText(V.window, ...
    sprintf('Centers constrained to 5° circle (%.0f px radius)\nSquares upright; side=%d px (%.2f°); tiles=%dx%d', ...
        V.layout.centerRadiusPx, V.square.side_px_full, ...
        V.square.side_px_full / V.pxPerDeg, V.square.B, V.square.B), ...
    'center', V.windowRect(4)*0.92, [1 1 1]);
    Screen('Flip', V.win); WaitSecs(0.6);
end


function FlushMouseEvents()
    % Continuously check the mouse status and only exit when no buttons are pressed
    while any(GetMouseButtons())
        % Wait briefly to avoid overloading the CPU
        WaitSecs(0.01);
    end
end

function FillBG(V)
% Fill the background with your calibrated gray (0..1)
Screen('FillRect', V.window, V.bg01);
end

function blank(duration)
% Background flip with optional wait
global V
Screen('FillRect', V.window, V.bg01);
Screen('Flip', V.window);
if nargin>0 && duration>0, WaitSecs(duration); end
end

% ===================== Stage bodies ======================

function stage_single(V, angleDeg, kappa, P)
% Show ONE noisy square at given angle for P.durMs.
targetHueDeg = randi([0 359]);
presentNoisySquareAt(V, targetHueDeg, kappa, angleDeg, P.durMs, P.limitDeg, P.cMap360_255, []);
end

function stage_four_low_with_replicas(V, P)
% 4 items (R,U,L,D): low noise; two are exact replicas; the other two unique colors.
angles = P.angles4;
% pick three target hues (two positions share the same hue+pattern):
baseHue    = randi([0 359]);
uniqueHue1 = mod(baseHue + 60, 360);
uniqueHue2 = mod(baseHue + 180, 360);

% Build one replica pattern once (for baseHue)
patternReplica = makeNoisyPattern(V, baseHue, P.kappaLowNoise, P.limitDeg, P.cMap360_255);

% Map positions: [R,U,L,D]
% Let R and L be replicas; U and D unique
FillBG(V);
drawFixation(V, [0.25 0.25 0.25], [0.75 0.75 0.75]);

presentNoisySquareAt(V, baseHue,     P.kappaLowNoise, angles(1), P.durMs, P.limitDeg, P.cMap360_255, patternReplica, true);
presentNoisySquareAt(V, uniqueHue1,  P.kappaLowNoise, angles(2), P.durMs, P.limitDeg, P.cMap360_255, [],             true);
presentNoisySquareAt(V, baseHue,     P.kappaLowNoise, angles(3), P.durMs, P.limitDeg, P.cMap360_255, patternReplica, true);
presentNoisySquareAt(V, uniqueHue2,  P.kappaLowNoise, angles(4), P.durMs, P.limitDeg, P.cMap360_255, [],             true);

Screen('Flip', V.window);  % one flip for the whole frame
WaitSecs(P.durMs/1000);
end

function stage_four_high_with_replicas(V, P)
% Same as stage_three but with high noise
angles = P.angles4;
baseHue    = randi([0 359]);
uniqueHue1 = mod(baseHue + 60, 360);
uniqueHue2 = mod(baseHue + 180, 360);

patternReplica = makeNoisyPattern(V, baseHue, P.kappaHighNoise, P.limitDeg, P.cMap360_255);

FillBG(V);
drawFixation(V, [0.25 0.25 0.25], [0.75 0.75 0.75]);

presentNoisySquareAt(V, baseHue,     P.kappaHighNoise, angles(1), P.durMs, P.limitDeg, P.cMap360_255, patternReplica, true);
presentNoisySquareAt(V, uniqueHue1,  P.kappaHighNoise, angles(2), P.durMs, P.limitDeg, P.cMap360_255, [],             true);
presentNoisySquareAt(V, baseHue,     P.kappaHighNoise, angles(3), P.durMs, P.limitDeg, P.cMap360_255, patternReplica, true);
presentNoisySquareAt(V, uniqueHue2,  P.kappaHighNoise, angles(4), P.durMs, P.limitDeg, P.cMap360_255, [],             true);

Screen('Flip', V.window);
WaitSecs(P.durMs/1000);
end

function stage_two_interval_same_loc(V, angleDeg, kappa, P)
% One stimulus, ISI, exact replica at same location (low noise)
hue = randi([0 359]);
pattern = makeNoisyPattern(V, hue, kappa, P.limitDeg, P.cMap360_255);

% Interval 1
FillBG(V); drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
presentNoisySquareAt(V, hue, kappa, angleDeg, P.durMs, P.limitDeg, P.cMap360_255, pattern, true);
Screen('Flip', V.window);
WaitSecs(P.durMs/1000);

% ISI
FillBG(V); drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
Screen('Flip', V.window);
WaitSecs(P.ISI);

% Interval 2 (replica)
FillBG(V); drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
presentNoisySquareAt(V, hue, kappa, angleDeg, P.durMs, P.limitDeg, P.cMap360_255, pattern, true);
Screen('Flip', V.window);
WaitSecs(P.durMs/1000);
end

function stage_two_interval_diff_loc(V, angle1Deg, angle2Deg, kappa, P)
% Same as above but second interval at a different location (still low noise)
hue = randi([0 359]);
pattern = makeNoisyPattern(V, hue, kappa, P.limitDeg, P.cMap360_255);

% Interval 1
FillBG(V); drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
presentNoisySquareAt(V, hue, kappa, angle1Deg, P.durMs, P.limitDeg, P.cMap360_255, pattern, true);
Screen('Flip', V.window);
WaitSecs(P.durMs/1000);

% ISI
FillBG(V); drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
Screen('Flip', V.window);
WaitSecs(P.ISI);

% Interval 2 at different angle (replica)
FillBG(V); drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
presentNoisySquareAt(V, hue, kappa, angle2Deg, P.durMs, P.limitDeg, P.cMap360_255, pattern, true);
Screen('Flip', V.window);
WaitSecs(P.durMs/1000);
end

% ===================== Stage driver ======================

function keepGoing = stage_click_to_repeat(win, doOnceFcn, onF, onB)
% Shows fixation; on left-click: run doOnceFcn; repeat on further clicks.
% F advances; B goes back; ESC quits.
global V
keepGoing = true;
while true
    FillBG(V); drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
    DrawCenteredText(win, 'Click = show\nF = next stage | B = previous | ESC = quit', 28, [1 1 1]);
    Screen('Flip', win);

    [down,~,kc] = KbCheck;
    if down
        if kc(KbName('ESCAPE')), keepGoing = false; return; end
        if kc(KbName('f')) || kc(KbName('F')), onF(); return;
        if kc(KbName('b')) || kc(KbName('B')), onB(); return;
    end

    [~,~,buttons] = GetMouse;
    if buttons(1)
        % run the stage action
        doOnceFcn();
        % Debounce mouse up before waiting for next input
        WaitForMouseRelease();
    end
    WaitSecs(0.01);
end
end

function s = advance(which)
% marker used by nav(); no-op (handled by key check in stage_click_to_repeat)
s = which; 
end

function newStage = nav(curStage)
[down,~,kc] = KbCheck;
if down && (kc(KbName('b')) || kc(KbName('B')))
    newStage = max(1, curStage - 1);
elseif down && (kc(KbName('f')) || kc(KbName('F')))
    newStage = curStage + 1;
else
    newStage = curStage;  % if user clicked, stay; keys handled above
end
end

% ===================== Drawing helpers ======================

function presentNoisySquareAt(V, hueDeg, kappa, angleDeg, durMs, limitDeg, cMap360_255, prePattern, deferFlip)
% Draw one B×B noisy square at a given polar angle on the 5° circle.
% If prePattern is provided, reuse it (for replicas). If deferFlip=true, do not flip.

if nargin < 9 || isempty(deferFlip), deferFlip = false; end

% center position on your 5° circle
th = deg2rad(angleDeg);
cx = V.centerX + V.layout.centerRadiusPx * cos(th);
cy = V.centerY + V.layout.centerRadiusPx * sin(th);

side   = V.square.side_px_full;
B      = V.square.B;
tilePx = V.square.tile_px;
rect   = CenterRectOnPointd([0 0 side side], cx, cy);
tileRects = buildTileRects(rect, B, tilePx);

if isempty(prePattern)
    rgb01 = makeNoisyPattern(V, hueDeg, kappa, limitDeg, cMap360_255);
else
    rgb01 = prePattern;  % reuse exact tiles/colors
end

Screen('FillRect', V.window, rgb01', tileRects);

if ~deferFlip
    ifi = Screen('GetFlipInterval', V.window);
    nF  = max(1, round((durMs/1000)/ifi));
    drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
    vbl = Screen('Flip', V.window);
    for f=2:nF, Screen('Flip', V.window, vbl + (f-1)*ifi); end
end
end

function rgb01 = makeNoisyPattern(V, hueDeg, kappa, limitDeg, cMap360_255)
% Build an nTiles×3 array of 0..1 RGB for a single noisy square
B      = V.square.B;
nTiles = B * B;
hues   = sampleVonMisesDegrees(hueDeg, kappa, nTiles);
if ~isempty(limitDeg) && limitDeg > 0
    hues = circClipToWindow(hues, hueDeg, limitDeg);
end
rgb01  = wheelRGB01_fromDegrees(hues, cMap360_255);  % n×3 in 0..1
end

function tileRects = buildTileRects(outerRect, B, tilePx)
x0 = outerRect(1); y0 = outerRect(2); x1 = outerRect(3); y1 = outerRect(4);
side = min(x1-x0, y1-y0);
tilePx = floor(min(tilePx, side / B));
x0 = x0 + (side - B*tilePx)/2; y0 = y0 + (side - B*tilePx)/2;
tileRects = zeros(4, B*B);
k = 1;
for r = 0:B-1
    for c = 0:B-1
        xL = x0 + c*tilePx;  yT = y0 + r*tilePx;
        tileRects(:,k) = [xL; yT; xL+tilePx; yT+tilePx];
        k = k + 1;
    end
end
end

function rgb01 = wheelRGB01_fromDegrees(deg, cMap360_255)
idx = round(mod(deg, 360)); idx(idx==0) = 360;
rgb01 = double(cMap360_255(idx,:)) / 255;
end

function huesDeg = sampleVonMisesDegrees(muDeg, kappa, n)
mu = deg2rad(muDeg);
if kappa < 1e-8
    huesDeg = rand(1,n)*360;
    return;
end
a = 1 + sqrt(1 + 4*(kappa^2));
b = (a - sqrt(2*a)) / (2*kappa);
r = (1 + b^2) / (2*b);

out = zeros(1,n);
i = 1;
while i <= n
    U1 = rand;  z  = cos(pi*U1);
    f  = (1 + r*z) / (r + z);
    c  = kappa * (r - f);
    U2 = rand;
    if U2 < c*(2 - c) || U2 <= c*exp(1 - c)
        U3 = rand;
        theta = acos(f);
        if U3 > 0.5, theta = -theta; end
        out(i) = mu + theta;
        i = i + 1;
    end
end
out = angle(exp(1i*out));           % wrap to (-pi,pi]
huesDeg = mod(rad2deg(out), 360);
end

function huesClipped = circClipToWindow(hues, muDeg, limitDeg)
d = mod(hues - muDeg + 180, 360) - 180;  % signed shortest diff
d = max(min(d, limitDeg), -limitDeg);
huesClipped = mod(muDeg + d, 360);
end

% ===================== UI/utility helpers ======================

function DrawCenteredText(win, msg, pts, col01)
Screen('TextSize', win, pts);
DrawFormattedText(win, msg, 'center', 'center', col01);
end

function FillBG(V)
Screen('FillRect', V.window, V.bg01);
end

function r = WaitForMouseClickOrEsc()
% return +1 for click, -1 for ESC
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
len = 10;  lw = 2;
xy  = [-len, len, 0, 0; 0, 0, -len, len];
Screen('DrawLines', V.window, xy, lw, lineCol, [V.centerX, V.centerY]);

r1 = [0 0 len*2 len*2]; r1 = CenterRectOnPointd(r1, V.centerX, V.centerY);
Screen('FrameOval', V.window, lineCol, r1, lw);

r2 = [0 0 4 4];         r2 = CenterRectOnPointd(r2, V.centerX, V.centerY);
Screen('FrameOval', V.window, innerCol, r2, lw);
end

function cleanup()
sca; disp('Demo ended.');
end