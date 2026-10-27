function TSE_Demo_281025
%======================================================================
% TSE_Demo_281025.m  (Time-shaped evidence demo)
% Minimal demo that reuses your lab's pipeline for window, color wheel,
% fixation, size/positions. Shows Gaussian temporal envelopes of saturation.
%
% Controls:
%   - Click: play/replay current stage ramp
%   - F: next stage
%   - B: previous stage
%   - ESC: quit
%======================================================================

% --- Clean start
clear; close all; clc;
sca; Screen('CloseAll');
KbName('UnifyKeyNames');

try
    %% -------------------- STAGE SETTINGS --------------------
    % Each stage: FWHMms, totalDurMs, setSize, hueMode, peakAlign
    % hueMode: 'same' (all items use same hue) or 'spaced' (evenly spaced hues)
    stages = [
        stageDef(  60, 300, 1, 'same',   'middle')   % narrow, 1 item
        stageDef( 180, 300, 1, 'same',   'middle')   % wide,   1 item
        stageDef(  60, 300, 4, 'spaced', 'middle')   % narrow, 4 items
        stageDef( 180, 300, 4, 'spaced', 'middle')   % wide,   4 items
    ];

    RandomizeHuePerStage = true;   % if false, use FixedBaseHueDeg
    FixedBaseHueDeg      = 30;     % only used when above is false
    gammaExp             = 1.0;    % S^gamma transducer (keep 1.0 initially)

    %% -------------------- INIT PIPELINE ---------------------
    global V
    V = initiate();                 % your existing helper (opens window, builds V.color.map, etc.)
    win = V.window;

    % (Optional) calibration / sizes identical to your experiment:
    VA5deg = calibrateMonitor();    % uses existing helper you pasted
    adjustStim(VA5deg);

    % Short instructions
    DrawCenterText(win, 'Time-shaped evidence demo\n\nClick to begin', 50);
    WaitForMouseClick();

    DrawCenterText(win, ['Fixation + rings will appear.\n' ...
                         'Click to play the ramp.\n\n' ...
                         'After the ramp:\nClick = replay | F = forward | B = back | ESC = quit'], 36);
    WaitForMouseClick();

    ifi = Screen('GetFlipInterval', win);
    [cx, cy] = RectCenter(V.windowRect);

    %% -------------------- MAIN DEMO LOOP --------------------
    stageIdx = 1; nStages = numel(stages);
    while true
        st = stages(stageIdx);

        % Choose base hue for this stage
        if RandomizeHuePerStage
            baseHueDeg = rand()*360;
        else
            baseHueDeg = FixedBaseHueDeg;
        end

        % Per-frame saturation envelope S[n] in [0,1]
        S = buildGaussianEnvelope(st.FWHMms, st.totalDurMs, gammaExp, ifi, st.peakAlign);

        % Compute item locations (your radii/centers from V)
        locAnglesDeg = evenlySpacedAngles(st.setSize);  % for ring positions & (optional) hue spacing

        % Show fixation + rings (your ring renderer)
        Screen('FillRect', win, [V.patch.bg V.patch.bg V.patch.bg]);
        fixation(0);
        drawRings_demo(locAnglesDeg);   % uses V.stim.positionradius & V.stim.pedestalradius
        Screen('Flip', win);

        % Wait for click to play ramp
        WaitForMouseClick();

        % Play the ramp once
        playRamp(win, S, baseHueDeg, st.setSize, locAnglesDeg, st.hueMode);

        % After ramp: allow replay or stage nav
        while true
            [down, ~, kc] = KbCheck;
            if down
                if kc(KbName('ESCAPE'))
                    ExperimentEnd(false);  % neat shutdown using your helper
                    return
                elseif kc(KbName('f')) || kc(KbName('F'))
                    stageIdx = min(stageIdx+1, nStages);
                    break
                elseif kc(KbName('b')) || kc(KbName('B'))
                    stageIdx = max(stageIdx-1, 1);
                    break
                end
            end
            if MouseClicked()
                playRamp(win, S, baseHueDeg, st.setSize, locAnglesDeg, st.hueMode);
            end

            % keep fixation + rings visible while waiting
            Screen('FillRect', win, [V.patch.bg V.patch.bg V.patch.bg]);
            fixation(0);
            drawRings_demo(locAnglesDeg);
            Screen('Flip', win);
            WaitSecs(0.01);
        end
    end

catch ME
    % clean exit on error
    try, ExperimentEnd(false); catch, sca; end
    rethrow(ME);
end
end

%% ===================== STAGE DEF ==============================
function s = stageDef(FWHMms, totalDurMs, setSize, hueMode, peakAlign)
s.FWHMms     = FWHMms;
s.totalDurMs = totalDurMs;
s.setSize    = setSize;
s.hueMode    = hueMode;     % 'same' | 'spaced'
s.peakAlign  = peakAlign;   % 'early' | 'middle' | 'late'
end

%% ===================== ENVELOPE ===============================
function S = buildGaussianEnvelope(FWHMms, totalDurMs, gammaExp, ifi, align)
sigma = (FWHMms/1000) / (2*sqrt(2*log(2)));
T = max(1, round((totalDurMs/1000)/ifi));
t = ((1:T) - 0.5) * ifi;
Ttot = T*ifi;
switch lower(align)
    case 'early',  t0 = 0.30*Ttot;
    case 'late',   t0 = 0.70*Ttot;
    otherwise,     t0 = 0.50*Ttot;  % middle
end
S = exp(-0.5*((t - t0)/sigma).^2);
S = S.^gammaExp;
S = min(max(S,0),1);
end

%% ===================== GEOMETRY HELPERS =======================
function angs = evenlySpacedAngles(N)
if N==1
    angs = 90;   % up
else
    angs = linspace(0,360,N+1); angs(end)=[];
end
end

%% ===================== DRAW RINGS (matching your style) =======
function drawRings_demo(locsDeg)
global V
for j = 1:numel(locsDeg)
    th = deg2rad(locsDeg(j));
    x  = V.centerX + V.stim.positionradius * cos(th);
    y  = V.centerY - V.stim.positionradius * sin(th);
    sq = [-V.stim.pedestalradius, -V.stim.pedestalradius, ...
           V.stim.pedestalradius,  V.stim.pedestalradius];
    ringRect = CenterRectOnPointd(sq, x, y);
    Screen('FrameOval', V.window, [255 255 255], ringRect, 1);
end
end

%% ===================== PLAY RAMP ==============================
function playRamp(win, S, baseHueDeg, setSize, locAnglesDeg, hueMode)
global V

% Pick hues for items
switch lower(hueMode)
    case 'same'
        huesDeg = repmat(baseHueDeg, 1, setSize);
    otherwise % 'spaced'
        step = 360 / max(setSize,1);
        huesDeg = mod(baseHueDeg + (0:setSize-1)*step, 360);
end

% Precompute base RGB for each item from your color wheel
cMap360 = V.color.map(round(linspace(1,size(V.color.map,1),360)), :); % 360x3, 0..255
baseRGB = zeros(setSize,3,'double');
for i = 1:setSize
    idx = mod(round(huesDeg(i)), 360); if idx==0, idx=360; end
    baseRGB(i,:) = double(cMap360(idx,:)); % 0..255
end
bg = double([V.patch.bg V.patch.bg V.patch.bg]); % 0..255

% For each frame, mix toward background by saturation S(f)
nF = numel(S);
for f = 1:nF
    Screen('FillRect', win, [V.patch.bg V.patch.bg V.patch.bg]);

    % draw items
    for i = 1:setSize
        sat = S(f);                 % 0..1
        rgb = (1 - sat)*bg + sat*baseRGB(i,:);   % simple saturation ramp by blending to gray
        rgb = uint8(round(rgb));

        th = deg2rad(locAnglesDeg(i));
        x  = V.centerX + V.stim.positionradius * cos(th);
        y  = V.centerY - V.stim.positionradius * sin(th);
        sq = [-V.stim.radius, -V.stim.radius, V.stim.radius, V.stim.radius];
        rect = CenterRectOnPointd(sq, x, y);

        % black pedestal (matching your DrawStimulusSegment style)
        ped = [-V.stim.pedestalradius, -V.stim.pedestalradius, ...
                V.stim.pedestalradius,  V.stim.pedestalradius];
        pedRect = CenterRectOnPointd(ped, x, y);
        Screen('FillOval', win, V.cue.Bgcolor, pedRect);

        Screen('FillOval', win, rgb, rect);
    end

    % fixation + static rings on top (matching your flow)
    fixation(0);
    drawRings_demo(locAnglesDeg);

    Screen('Flip', win);
end
end

%% ===================== UI HELPERS =============================
function DrawCenterText(win, msg, pts)
Screen('FillRect', win, 0.5*WhiteIndex(win));
Screen('TextSize', win, pts);
DrawFormattedText(win, msg, 'center', 'center', WhiteIndex(win));
Screen('Flip', win);
end

function WaitForMouseClick()
% non-blocking, debounced click
buttons = 1;
while any(buttons), [~,~,buttons] = GetMouse; WaitSecs(0.01); end
while true
    [~,~,buttons] = GetMouse;
    if any(buttons), break; end
    WaitSecs(0.01);
end
while any(buttons), [~,~,buttons] = GetMouse; WaitSecs(0.01); end
end

function tf = MouseClicked()
[~,~,buttons] = GetMouse; tf = any(buttons);
end

function v = initiate() %Global variable with hard-coded defaults.

sca;                   
Screen('CloseAll');    
WaitSecs(0.5);

v.patch.bg = .5 * 255; % Background gray
Screen('Preference', 'SkipSyncTests', 1);
Screen('Preference', 'VisualDebugLevel', 0); % Minimal feedback
[v.window, v.windowRect] = Screen('OpenWindow', max(Screen('Screens')), [v.patch.bg, v.patch.bg, v.patch.bg]);
Screen('BlendFunction', v.window, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA); % can use alpha values
Screen('Flip', v.window);
[v.centerX, v.centerY] = RectCenter(v.windowRect);

 % Warm-up background flip
    Screen('FillRect', v.window, [v.patch.bg, v.patch.bg, v.patch.bg]);
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

function FlushMouseEvents()
    % Continuously check the mouse status and only exit when no buttons are pressed
    while any(GetMouseButtons())
        % Wait briefly to avoid overloading the CPU
        WaitSecs(0.01);
    end
end

function buttons = GetMouseButtons()
    % Helper function to return the mouse button status
    [~, ~, buttons] = GetMouse;
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

function fiveDegVA_in_pixels = calibrateMonitor()
    global V

    % check calibration exists
    currentConfig.pcName = getenv('COMPUTERNAME');
    currentConfig.monitorPositions = get(0, 'MonitorPositions');
    calibFilename = 'screenCalibration.mat';

    if exist(calibFilename, 'file')
        loadedData = load(calibFilename, 'savedConfig', 'calibrationData');
        if ~isequal(loadedData.savedConfig, currentConfig)
            runCalibration = true;
        else
            runCalibration = false;
            fiveDegVA_in_pixels = loadedData.calibrationData;
        end
    else
        runCalibration = true;
    end

    if runCalibration

        DrawFormattedText(V.window, ...
            ['Align these two lines with the edges of your credit card.\n\nUse LEFT/RIGHT ' ...
            'arrow keys to move each line.\nUse UP/DOWN arrow keys to choose which line' ...
            ' moves.\nPress ENTER when done.'], ...
            'center', 'center', [255 255 255]);
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
                lineIndicatorLeft = [255 255 255];   % maybe the same color, or highlight
                lineIndicatorRight = [0 0 0];  % dim color for non-selected
            else
                lineIndicatorLeft = [0 0 0];
                lineIndicatorRight = [255 255 255];
            end
    
            Screen('DrawLine', V.window, lineIndicatorLeft, ...
                leftLineX, 0, leftLineX, V.windowRect(4), 2);
            Screen('DrawLine', V.window, lineIndicatorRight, ...
                rightLineX, 0, rightLineX, V.windowRect(4), 2);
            DrawFormattedText(V.window, ...
                'Use arrow keys to move lines. Press ENTER when done.', ...
                'center', 50, [255 255 255]);
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

        savedConfig = currentConfig; 
        calibrationData = fiveDegVA_in_pixels; 
        save('screenCalibration.mat', 'savedConfig', 'calibrationData');
    end

end

function [] = blank(duration)
    global V
    Screen('FillRect', V.window, [V.patch.bg, V.patch.bg, V.patch.bg]);
    Screen('Flip', V.window);
    if duration > 0
        WaitSecs(duration);
    end
end

function [] = adjustStim(VA5deg)
    global V
    fiveDegCirc = [V.centerX - VA5deg/2, V.centerY - VA5deg/2, V.centerX + VA5deg/2, V.centerY + VA5deg/2];
    Screen('FillOval', V.window, [255 255 255], fiveDegCirc);
    DrawFormattedText(V.window, ...
        '5 Degrees VA Calibrated @ 60cm\nRecalibrate if incorrect.', ...
        'center', 'center', [0, 0, 0]);
    Screen('Flip', V.window);
    WaitSecs(0.5);
    deg = VA5deg / 5;
    
    V.feedback.linewidth = round(deg * .08);
    V.feedback.ticklength = round(deg * .5);

    V.annulus.radiusOuter = round(deg * 4.75);
    V.annulus.radiusInner = round(deg * 4.25);

    V.stim.positionradius = round(deg * 1.82);
    % Visual.stim.triAngles = [36, 72, 72];
    % Visual.stim.base = round(deg * .75);
    % Visual.stim.height = round(Visual.stim.base / (2 * tand(Visual.stim.triAngles(1)/2)));
    % Visual.stim.triArea = Visual.stim.height * Visual.stim.base * .5;
    
    V.stim.radius = round(deg * .56);
    V.stim.orientedlinewidth = round(deg * .12);
    V.stim.pedestalradius = V.stim.radius * 1.3; 
    V.stim.pedestalcolor = [0, 0, 0];

    V.mouseinit.radius = round(deg * .4);
    V.mouseinit.radiusWidth = round(deg * .03);
    V.mouseinit.color = [85, 85, 85];
    % Note this is the mouse timing 
    V.mouseinit.toofast = 200;
    V.mouseinit.tooslow = 50000;

    % Changed color cues to sin wave cues.
    %Visual.cue.borderwidth = round(deg * .1);
    %Visual.cue.Colcolor = [0, 0, 255];
    %Visual.cue.Oricolor = [0, 255, 0];
    %Visual.cue.Neutcolor = [255, 255, 255] * .75;
    V.cue.Bgcolor = [0, 0, 0];
    V.cue.PedestalMultiplier = 1.1;
    V.cue.radius = V.stim.pedestalradius * V.cue.PedestalMultiplier;
    V.cue.ringArea = pi * (V.cue.radius^2 - V.stim.pedestalradius^2);
    V.cue.gentleFreq = 8;
    V.cue.spikyFreq  = 36;
    V.cue.Ravg = (V.stim.pedestalradius + V.cue.radius)/2; % imaginary midpoint of the osilations
    % Integral calculations for gentle and spiky waves.
    %   Compute once at start of code to calc the correct values
    %   and then use throughout the experiment.
    % V.cue.gentleAmp = SolveWaveAmplitude(V.cue.ringArea, V.stim.pedestalradius, V.cue.Ravg, V.cue.gentleFreq);
    % V.cue.spikyAmp  = SolveWaveAmplitude(V.cue.ringArea, V.stim.pedestalradius, V.cue.Ravg, V.cue.spikyFreq);
end

function [] = fixation(duration)
    global V
    fixCrossDimPix = 10;
    xCoords = [-fixCrossDimPix, fixCrossDimPix, 0, 0];
    yCoords = [0, 0, -fixCrossDimPix, fixCrossDimPix];
    allCoords = [xCoords; yCoords];
    lineWidthPix = 2;
    Screen('DrawLines', V.window, allCoords, lineWidthPix, repmat(255*.25,1,3), [V.centerX, V.centerY]);
    circleRadius = fixCrossDimPix; % Radius of the circle
    circleRect = [0, 0, circleRadius * 2, circleRadius * 2];
    circleRect = CenterRectOnPointd(circleRect, V.centerX, V.centerY);
    Screen('FrameOval', V.window, repmat(255*.25,1,3), circleRect, lineWidthPix);
    circleRadius = 2; % Radius of the circle
    circleRect = [0, 0, circleRadius * 2, circleRadius * 2];
    circleRect = CenterRectOnPointd(circleRect, V.centerX, V.centerY);
    Screen('FrameOval', V.window, repmat(255*.75,1,3), circleRect, lineWidthPix);
    rect = [V.centerX - V.mouseinit.radius, V.centerY - V.mouseinit.radius, ...
            V.centerX + V.mouseinit.radius, V.centerY + V.mouseinit.radius];
    Screen('FrameOval', V.window, V.mouseinit.color, rect, V.mouseinit.radiusWidth);
    if duration > 0
        Screen('Flip', V.window);
        WaitSecs(duration);
    end
end