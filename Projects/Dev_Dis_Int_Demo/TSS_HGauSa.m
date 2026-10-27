function TSS_HGauSa
% Time-shaped evidence demo (CDF/half-Gaussian version)
% Controls: Click=replay | F=next | B=back | ESC=quit

clear; clc; sca; Screen('CloseAll'); KbName('UnifyKeyNames');

try
    %% -------------------- STAGE SETTINGS --------------------
    % Fields: type, setSize, hueMode, totalDurMs, env, FWHMms, peakAlign,
    %         nSeqRamps, FWHMms2, ISIms
    % env: 'cdf' for cumulative Gaussian (half-Gaussian rise, then vanish)
    stages = [
        stageDef('single', 1, 'same',   250, 'cdf',  60, 'middle', 1, NaN,  NaN)  % narrow, single ramp
        stageDef('single', 1, 'same',   250, 'cdf', 180, 'middle', 1, NaN,  NaN)  % wide, single ramp
        stageDef('single', 4, 'spaced', 250, 'cdf',  60, 'middle', 1, NaN,  NaN)  % narrow, 4 items
        stageDef('single', 4, 'spaced', 250, 'cdf', 180, 'middle', 1, NaN,  NaN)  % wide, 4 items
        stageDef('seq2',   1, 'same',   250, 'cdf',  80, 'middle', 2, 160, 150)   % NEW: 2 sequential ramps (80ms then 160ms), 150ms ISI
    ];

    RandomizeHuePerStage = true;  % random base hue per stage
    FixedBaseHueDeg      = 30;    % if RandomizeHuePerStage=false
    gammaExp             = 1.2;   % keep linear for now
    showPedestal         = false; % (1) remove black ring: do NOT draw pedestal

    %% -------------------- INIT PIPELINE ---------------------
    global V
    V = initiate();
    win = V.window;
    VA5deg = calibrateMonitor();
    adjustStim(VA5deg);

    

    DrawCenterText(win, 'Time-shaped evidence demo (CDF/half-Gauss)\n\nClick to begin', 50);
    WaitForMouseClick();
    DrawCenterText(win, 'Fixation + rings → Click to play\nClick=replay | F=next | B=back | ESC=quit', 36);
    WaitForMouseClick();

    ifi = Screen('GetFlipInterval', win);
    [cx, cy] = RectCenter(V.windowRect); 

    %% -------------------- MAIN LOOP -------------------------
    stageIdx = 1; nStages = numel(stages);
    while true
        st = stages(stageIdx);
        baseHueDeg = RandomizeHuePerStage * 360 * rand + (~RandomizeHuePerStage) * FixedBaseHueDeg;

        % Build envelopes
        S1 = buildEnvelope(st.env, st.FWHMms, st.totalDurMs, gammaExp, ifi, st.peakAlign);
        if st.nSeqRamps == 2
            S2 = buildEnvelope(st.env, st.FWHMms2, st.totalDurMs, gammaExp, ifi, st.peakAlign);
        else
            S2 = [];
        end

        % Item positions and hues
        locAnglesDeg = evenlySpacedAngles(st.setSize);
        huesDeg = makeHues(baseHueDeg, st.setSize, st.hueMode);

        % Fixation + rings + overlay
        Screen('FillRect', win, bgCol01());
        fixation(0);
        drawRings_demo(locAnglesDeg);
        drawOverlay(win, stageIdx, nStages, st);
        Screen('Flip', win);
        WaitForMouseClick();

        % Play single or sequential ramps
        if st.nSeqRamps == 1
            playRamp(win, S1, huesDeg, locAnglesDeg, showPedestal);
        else
            playRamp(win, S1, huesDeg, locAnglesDeg, showPedestal);
            % ISI (blank with fixation/rings + overlay)
            ISIwait(win, st.ISIms, locAnglesDeg, @() drawOverlay(win, stageIdx, nStages, st));
            playRamp(win, S2, huesDeg, locAnglesDeg, showPedestal);
        end

        % Wait for replay/nav
        while true
            [down,~,kc] = KbCheck;
            if down
                if kc(KbName('ESCAPE')), ExperimentEnd(false); return
                elseif kc(KbName('f')) || kc(KbName('F')), stageIdx = min(stageIdx+1, nStages); break
                elseif kc(KbName('b')) || kc(KbName('B')), stageIdx = max(stageIdx-1, 1);     break
            end
            if MouseClicked()
                % Replay current stage
                if st.nSeqRamps == 1
                    playRamp(win, S1, huesDeg, locAnglesDeg, showPedestal);
                else
                    playRamp(win, S1, huesDeg, locAnglesDeg, showPedestal);
                    ISIwait(win, st.ISIms, locAnglesDeg, @() drawOverlay(win, stageIdx, nStages, st));
                    playRamp(win, S2, huesDeg, locAnglesDeg, showPedestal);
                end
            end
            % keep fixation + rings + overlay visible
            Screen('FillRect', win, bgCol01());
            fixation(0);
            drawRings_demo(locAnglesDeg);
            drawOverlay(win, stageIdx, nStages, st);
            Screen('Flip', win);
            WaitSecs(0.01);
        end
        end
    end



    catch ME
        try, ExperimentEnd(false); catch, sca; end
        rethrow(ME);

    end
end



%% ===================== STAGE DEF ==============================
function s = stageDef(type, setSize, hueMode, totalDurMs, env, FWHMms, peakAlign, nSeqRamps, FWHMms2, ISIms)
s.type       = type;        % 'single' | 'seq2'
s.setSize    = setSize;
s.hueMode    = hueMode;     % 'same' | 'spaced'
s.totalDurMs = totalDurMs;  % now fixed at 250ms per your request
s.env        = env;         % 'cdf'
s.FWHMms     = FWHMms;
s.peakAlign  = peakAlign;   % 'early'|'middle'|'late'
s.nSeqRamps  = nSeqRamps;   % 1 or 2
s.FWHMms2    = FWHMms2;     % only used if nSeqRamps==2
s.ISIms      = ISIms;       % only used if nSeqRamps==2
end

%% ===================== ENVELOPES ==============================
function S = buildEnvelope(env, FWHMms, totalDurMs, gammaExp, ifi, align)
% 'cdf' = cumulative Gaussian (half-Gaussian rise, then vanish at asymptote)
sigma = (FWHMms/1000) / (2*sqrt(2*log(2)));
T = max(1, round((totalDurMs/1000)/ifi));
t = ((1:T) - 0.5) * ifi;
Ttot = T*ifi;

switch lower(align)
    case 'early',  t0 = 0.30*Ttot;
    case 'late',   t0 = 0.70*Ttot;
    otherwise,     t0 = 0.50*Ttot;  % middle
end

switch lower(env)
    case 'cdf'
        % 1) Raw cumulative Gaussian in [0,1]
        S_lin = 0.5 * (1 + erf((t - t0) / (sigma*sqrt(2))));
        % 2) Perceptual easing (cosine-in)
        S_eased = 0.5 - 0.5 * cos(pi * S_lin);
        % 3) Optional nonlinearity
        S = S_eased .^ gammaExp;

        % 4) Vanish after reaching near-asymptote
        thr = 0.995;
        firstAsym = find(S >= thr, 1, 'first');
        if ~isempty(firstAsym) && firstAsym < numel(S)
            S(firstAsym)   = 1;      % clean peak
            S(firstAsym+1:end) = 0;  % then disappear
        end

    otherwise
        % Fallback: symmetric Gaussian pulse (not used in your current stages)
        S = exp(-0.5*((t - t0)/sigma).^2);
        S = S .^ gammaExp;
end

% Clamp numerical noise
S = min(max(S,0),1);
end

%% ===================== HUES / POSITIONS =======================
function angs = evenlySpacedAngles(N)
if N==1, angs = 90; else, angs = linspace(0,360,N+1); angs(end)=[]; end
end

function huesDeg = makeHues(baseHueDeg, setSize, hueMode)
switch lower(hueMode)
    case 'same'
        huesDeg = repmat(mod(baseHueDeg,360), 1, setSize);
    otherwise % 'spaced'
        step = 360 / max(setSize,1);
        huesDeg = mod(baseHueDeg + (0:setSize-1)*step, 360);
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
    Screen('FrameOval', V.window, [1 1 1], ringRect, 1);
end
end

%% ===================== PLAY RAMP ==============================
function playRamp(win, S, huesDeg, locAnglesDeg, showPedestal)
% playRamp  Draw a time-shaped saturation ramp with 0–1 color values.
% Works for both 8-bit and floating-point/10-bit framebuffers.

global V

% --- 1) Color wheel: convert to 0..1 once ---
cMap360_255 = V.color.map(round(linspace(1, size(V.color.map,1), 360)), :);  % 360x3 (0..255)
cMap360     = max(min(double(cMap360_255) / 255, 1), 0);                      % -> 0..1

K = numel(huesDeg);
baseRGB = zeros(K, 3);
for i = 1:K
    idx = mod(round(huesDeg(i)), 360); if idx == 0, idx = 360; end
    baseRGB(i, :) = cMap360(idx, :);   % 0..1
end

% --- 2) Background gray as 0..1 ---
bg01 = max(min(double([V.patch.bg V.patch.bg V.patch.bg]) / 255, 1), 0);
pedestalCol = bg01; % if pedestal enabled, match bg to avoid a ring

% --- 3) Draw frames ---
nF = numel(S);
for f = 1:nF
    Screen('FillRect', win, bg01);

    for i = 1:K
        sat = S(f);                                  % 0..1
        rgb = (1 - sat) * bg01 + sat * baseRGB(i,:); % 0..1 blend

        th = deg2rad(locAnglesDeg(i));
        x  = V.centerX + V.stim.positionradius * cos(th);
        y  = V.centerY - V.stim.positionradius * sin(th);

        if showPedestal
            ped = [-V.stim.pedestalradius, -V.stim.pedestalradius, ...
                    V.stim.pedestalradius,  V.stim.pedestalradius];
            pedRect = CenterRectOnPointd(ped, x, y);
            Screen('FillOval', win, pedestalCol, pedRect);
        end

        sq   = [-V.stim.radius, -V.stim.radius, V.stim.radius, V.stim.radius];
        rect = CenterRectOnPointd(sq, x, y);
        Screen('FillOval', win, rgb, rect);
    end

    % NOTE: If you're in 10-bit/float mode, consider changing any other
    % drawing that uses [255 255 255] to 0..1 as well. For example:
    % - drawRings_demo(...): use [1 1 1] instead of [255 255 255].
    % - fixation(...): use 0..1 colors.
    fixation(0);
    drawRings_demo(locAnglesDeg);

    Screen('Flip', win);
end
end


%% ===================== ISI WAIT (with overlay) ================
function ISIwait(win, ISIms, locAnglesDeg, overlayFcn)
global V
tEnd = GetSecs + ISIms/1000;
while GetSecs < tEnd
    Screen('FillRect', win, bgCol01());
    fixation(0);
    drawRings_demo(locAnglesDeg);
    if nargin>=3 && ~isempty(overlayFcn), overlayFcn(); end
    Screen('Flip', win);
    WaitSecs(0.005);
end
end

%% ===================== OVERLAY TEXT ===========================
function drawOverlay(win, idx, nStages, st)
col = [250 250 250];
Screen('TextSize', win, 16);
txt = sprintf(['Stage %d/%d\n' ...
               'Type: %s | SetSize: %d | Hue: %s\n' ...
               'Env: %s | Dur: %d ms | FWHM: %s\n' ...
               '%s'], ...
               idx, nStages, st.type, st.setSize, st.hueMode, ...
               st.env, st.totalDurMs, num2str(st.FWHMms), ...
               extraLine(st));
DrawFormattedText(win, txt, 20, 20, col);
end

function s = extraLine(st)
if st.nSeqRamps==2
    s = sprintf('Seq: 2 ramps | FWHM2=%d ms | ISI=%d ms', st.FWHMms2, st.ISIms);
else
    s = 'Seq: 1 ramp';
end
end

%% ===================== SMALL UI HELPERS =======================
function DrawCenterText(win, msg, pts)
Screen('FillRect', win, 0.5*WhiteIndex(win));
Screen('TextSize', win, pts);
DrawFormattedText(win, msg, 'center', 'center', WhiteIndex(win));
Screen('Flip', win);
end

function WaitForMouseClick()
buttons = 1; while any(buttons), [~,~,buttons]=GetMouse; WaitSecs(0.01); end
while true, [~,~,buttons]=GetMouse; if any(buttons), break; end, WaitSecs(0.01); end
while any(buttons), [~,~,buttons]=GetMouse; WaitSecs(0.01); end
end

function tf = MouseClicked()
[~,~,buttons]=GetMouse; tf = any(buttons);
end


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
    V.bg01 = repmat(max(min(double(V.patch.bg)/255, 1), 0), 1, 3);
    Screen('FillRect', V.window, V.bg01);
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

function col = bgCol01()
    global V
    % Convert your V.patch.bg (0–255) to a 0–1 RGB triplet
    g = max(min(double(V.patch.bg)/255,1),0);
    col = [g g g];
end