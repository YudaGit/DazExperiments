function SqNoisy_NoiseDemo
% ------------------------------------------------------------
% Demo: Low vs High noise color square stimuli (B×B tiles)
% Stages:
% 1) single low-noise @ 12 o'clock (click to replay; F next; B back)
% 2) single high-noise @ 12 o'clock
% 3) 4 items (R,U,L,D), LOW noise; R & L are exact replicas
% 4) 4 items (R,U,L,D), HIGH noise; R & L are exact replicas
% 5) 2-interval same location (LOW noise): replica after 300 ms ISI
% 6) 2-interval diff location (LOW noise): replica at a different angle
%
% Now backed up on Github
% Testing branch
% ------------------------------------------------------------

% ---------- Setup ----------
clear; close all; clc;
sca; Screen('CloseAll');
KbName('UnifyKeyNames');
PsychDefaultSetup(2);
Screen('Preference','SkipSyncTests',1);
Screen('Preference','VisualDebugLevel',1);

global V
V = initiate();
win = V.window;

VA5deg = calibrateMonitor();
adjustSquareStim(VA5deg);   % sets V.square.*, V.layout.centerRadiusPx, etc.

ifi = Screen('GetFlipInterval', win);
fprintf('Refresh: %.2f Hz (%.3f ms/frame)\n', 1/ifi, ifi*1000);

% ---------- Parameters ----------
P.kappaLowNoise  = 12;       % narrow VM (high evidence)
P.kappaHighNoise =  2;       % wide VM (low evidence)
P.limitDeg       = 10;       % clamp VM samples to ±10°
P.durMs          = 400;      % per-stim duration
P.ISI            = 0.300;    % seconds, stages 5/6
P.angles4        = [0 90 180 270];  % R,U,L,D (deg)

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
    switch stage
        case 1
            action = stage_click_to_repeat(win, @() stage_single(V, 90,  P.kappaLowNoise,  P));
        case 2
            action = stage_click_to_repeat(win, @() stage_single(V, 90,  P.kappaHighNoise, P));
        case 3
            action = stage_click_to_repeat(win, @() stage_four_with_replicas(V, P, P.kappaLowNoise));
        case 4
            action = stage_click_to_repeat(win, @() stage_four_with_replicas(V, P, P.kappaHighNoise));
        case 5
            action = stage_click_to_repeat(win, @() stage_two_interval_same_loc(V, 90, P.kappaLowNoise, P));
        case 6
            action = stage_click_to_repeat(win, @() stage_two_interval_diff_loc(V, 90, 270, P.kappaLowNoise, P));
        otherwise
            action = 'quit';
    end

    switch action
        case 'next', stage = min(stage+1, 6);
        case 'prev', stage = max(stage-1, 1);
        case 'again' % do nothing; user can click again in same stage
        case 'quit', keepGoing = false;
    end
end

cleanup();
end % ------------------------------- end main function -------------------------------


% ===================== Stage bodies ======================

function stage_single(V, angleDeg, kappa, P)
targetHueDeg = randi([0 359]);
presentNoisySquareAt(V, targetHueDeg, kappa, angleDeg, P.durMs, P.limitDeg, P.cMap360_255, []);
end

function stage_four_with_replicas(V, P, kappa)
angles = P.angles4;                         % [R U L D]
baseHue    = randi([0 359]);                % hue used for replicas
uniqueHue1 = mod(baseHue + 60,  360);
uniqueHue2 = mod(baseHue + 180, 360);

repPattern = makeNoisyPattern(V, baseHue, kappa, P.limitDeg, P.cMap360_255);

FillBG(V); drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
presentNoisySquareAt(V, baseHue,    kappa, angles(1), P.durMs, P.limitDeg, P.cMap360_255, repPattern, true); % R replica
presentNoisySquareAt(V, uniqueHue1, kappa, angles(2), P.durMs, P.limitDeg, P.cMap360_255, [],         true); % U new
presentNoisySquareAt(V, baseHue,    kappa, angles(3), P.durMs, P.limitDeg, P.cMap360_255, repPattern, true); % L replica
presentNoisySquareAt(V, uniqueHue2, kappa, angles(4), P.durMs, P.limitDeg, P.cMap360_255, [],         true); % D new
Screen('Flip', V.window);
WaitSecs(P.durMs/1000);
end

function stage_two_interval_same_loc(V, angleDeg, kappa, P)
hue = randi([0 359]);
pat = makeNoisyPattern(V, hue, kappa, P.limitDeg, P.cMap360_255);

% interval 1
FillBG(V); drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
presentNoisySquareAt(V, hue, kappa, angleDeg, P.durMs, P.limitDeg, P.cMap360_255, pat, true);
Screen('Flip', V.window); WaitSecs(P.durMs/1000);

% ISI
FillBG(V); drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
Screen('Flip', V.window); WaitSecs(P.ISI);

% interval 2 (replica)
FillBG(V); drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
presentNoisySquareAt(V, hue, kappa, angleDeg, P.durMs, P.limitDeg, P.cMap360_255, pat, true);
Screen('Flip', V.window); WaitSecs(P.durMs/1000);
end

function stage_two_interval_diff_loc(V, angle1, angle2, kappa, P)
hue = randi([0 359]);
pat = makeNoisyPattern(V, hue, kappa, P.limitDeg, P.cMap360_255);

% interval 1
FillBG(V); drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
presentNoisySquareAt(V, hue, kappa, angle1, P.durMs, P.limitDeg, P.cMap360_255, pat, true);
Screen('Flip', V.window); WaitSecs(P.durMs/1000);

% ISI
FillBG(V); drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
Screen('Flip', V.window); WaitSecs(P.ISI);

% interval 2 at different angle (replica)
FillBG(V); drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
presentNoisySquareAt(V, hue, kappa, angle2, P.durMs, P.limitDeg, P.cMap360_255, pat, true);
Screen('Flip', V.window); WaitSecs(P.durMs/1000);
end


% ===================== Stage driver / UI ======================

function action = stage_click_to_repeat(win, doOnceFcn)
% Returns one of: 'next' | 'prev' | 'quit' | 'again'
% - Click: run doOnceFcn() then return 'again'
% - F:     return 'next'
% - B:     return 'prev'
% - ESC:   return 'quit'
global V
action = 'again';

% Debounce: wait until no mouse button is down
while any(GetMouseButtons()), WaitSecs(0.01); end

while true
    FillBG(V);
    drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
    drawHUD(V, 'Click = show  |  F = next  |  B = back  |  ESC = quit');
    Screen('Flip', win);

    % Keyboard first so F/B don't also click
    [down,~,kc] = KbCheck;
    if down
        if kc(KbName('ESCAPE')), action = 'quit'; return; end
        if kc(KbName('f')) || kc(KbName('F')), action = 'next'; WaitKeyRelease(); return; end
        if kc(KbName('b')) || kc(KbName('B')), action = 'prev'; WaitKeyRelease(); return; end
    end

    % Mouse: show once then return
    [~,~,buttons] = GetMouse;
    if buttons(1)
        doOnceFcn();
        WaitForMouseRelease();
        action = 'again';
        return;
    end

    WaitSecs(0.01);
end
end

function WaitKeyRelease()
% simple key debounce
while KbCheck, WaitSecs(0.01); end
end

function newStage = update_stage(curStage)
[down,~,kc] = KbCheck;
if down && (kc(KbName('b')) || kc(KbName('B')))
    newStage = max(1, curStage - 1);
elseif down && (kc(KbName('f')) || kc(KbName('F')))
    newStage = curStage + 1;
else
    newStage = curStage;
end
end


% ===================== Drawing helpers ======================

function presentNoisySquareAt(V, hueDeg, kappa, angleDeg, durMs, limitDeg, cMap360_255, prePattern)
% Draw one B×B noisy square centered on the 5° circle at angleDeg.
% - hueDeg: target hue (0..359)
% - kappa:  VM concentration (larger = narrower = "low noise")
% - durMs:  on-screen duration in milliseconds
% - prePattern: optional nTiles×3 (0..1) RGB to reuse (replicas)

% --- center on 5° circle (90° = up) ---
th = deg2rad(angleDeg);
cx = V.centerX + V.layout.centerRadiusPx * cos(th);
cy = V.centerY - V.layout.centerRadiusPx * sin(th);   % NOTE the minus sign (screen y down)

% --- geometry ---
side   = V.square.side_px_full;
B      = V.square.B;
tilePx = V.square.tile_px;
outer  = CenterRectOnPointd([0 0 side side], cx, cy);
tileRects = buildTileRects(outer, B, tilePx);

% --- per-tile colors ---
if nargin >= 8 && ~isempty(prePattern)
    rgb01 = prePattern;                         % nTiles×3 (0..1)
else
    rgb01 = makeNoisyPattern(V, hueDeg, kappa, limitDeg, cMap360_255);  % nTiles×3
end
% PTB expects colors as 3×N
rgb3xN = permute(rgb01, [2 1]);                 % 3×nTiles

% --- duration control ---
ifi = Screen('GetFlipInterval', V.window);
nF  = max(1, round((durMs/1000) / ifi));

% Draw & hold for nF frames
% Frame 1
FillBG(V);
drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
Screen('FillRect', V.window, rgb3xN, tileRects);
vbl = Screen('Flip', V.window);

% Frames 2..nF (redraw same content each refresh)
for f = 2:nF
    FillBG(V);
    drawFixation(V,[.25 .25 .25],[.75 .75 .75]);
    Screen('FillRect', V.window, rgb3xN, tileRects);
    vbl = Screen('Flip', V.window, vbl + 0.5*ifi);   % keep cadence
end
end


function rgb01 = makeNoisyPattern(V, hueDeg, kappa, limitDeg, cMap360_255)
% Returns nTiles×3 double in [0,1]
B      = V.square.B;
nTiles = B * B;

% Sample hues around target with VM
huesDeg = sampleVonMisesDegrees(hueDeg, kappa, nTiles);

% Optional clamp to ±limitDeg around target
if ~isempty(limitDeg) && isfinite(limitDeg) && limitDeg > 0
    huesDeg = circClipToWindow(huesDeg, hueDeg, limitDeg);
end

% Convert each hue to RGB from your wheel
rgb01 = wheelRGB01_fromDegrees(huesDeg, cMap360_255);   % n×3, 0..1
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

function huesDeg = sampleVonMisesDegrees(muDeg, kappa, n)
% Best-effort rejection sampler (fast enough for n<=few thousand)
mu = deg2rad(muDeg);
if kappa < 1e-8
    huesDeg = rand(1,n) * 360; return;
end

a = 1 + sqrt(1 + 4*kappa^2);
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
out = angle(exp(1i*out));                 % wrap to (-pi,pi]
huesDeg = mod(rad2deg(out), 360);         % 0..360
end

function huesClipped = circClipToWindow(hues, muDeg, limitDeg)
% Move any sample outside ±limitDeg back to that window, circularly
d = mod(hues - muDeg + 180, 360) - 180;               % signed shortest diff (-180..180]
d = max(min(d, limitDeg), -limitDeg);                 % clamp
huesClipped = mod(muDeg + d, 360);
end


function DrawCenteredText(win, msg, pts, col01)
Screen('TextSize', win, pts);
DrawFormattedText(win, msg, 'center', 'center', col01);
end

function FillBG(V)
Screen('FillRect', V.window, V.bg01);
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
len = 10;  lw = 2;
xy  = [-len, len, 0, 0; 0, 0, -len, len];
Screen('DrawLines', V.window, xy, lw, lineCol, [V.centerX, V.centerY]);
r1 = CenterRectOnPointd([0 0 len*2 len*2], V.centerX, V.centerY);
Screen('FrameOval', V.window, lineCol, r1, lw);
r2 = CenterRectOnPointd([0 0 4 4], V.centerX, V.centerY);
Screen('FrameOval', V.window, innerCol, r2, lw);
end

function cleanup()
sca; disp('Demo ended.');
end

%================Base Helpers============================

function v = initiate() %Global variable with hard-coded defaults.

sca;                   
Screen('CloseAll');    
WaitSecs(0.5);

v.patch.bg = .5 * 255; % Background gray
Screen('Preference', 'SkipSyncTests', 1);
Screen('Preference', 'VisualDebugLevel', 0); % Minimal feedback
PsychDefaultSetup(2);
PsychImaging('PrepareConfiguration');
PsychImaging('AddTask','General','FloatingPoint32BitIfPossible'); % 16/32-bit FB
PsychImaging('AddTask','General','EnableNative10BitFramebuffer'); % if GPU/OS/display allow
% [v.window, v.windowRect] = PsychImaging('OpenWindow', max(Screen('Screens')), [v.patch.bg v.patch.bg v.patch.bg]);
% Screen('BlendFunction', v.window, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA); % can use alpha values
[v.window, v.windowRect] = PsychImaging('OpenWindow', max(Screen('Screens')), [v.patch.bg v.patch.bg v.patch.bg]);
Screen('BlendFunction', v.window, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
Screen('Flip', v.window);
[v.centerX, v.centerY] = RectCenter(v.windowRect);

 % Warm-up background flip
    v.bg01 = repmat(max(min(double(v.patch.bg)/255, 1), 0), 1, 3);
    Screen('FillRect', v.window, v.bg01);
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
V.square.B             = 12;        % B×B tiles

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
% Draw HUD text near the bottom (or top if you prefer)
Screen('TextSize', V.window, 26);
DrawFormattedText(V.window, msg, 'center', V.windowRect(4)*0.90, [1 1 1]); % 90% down
end