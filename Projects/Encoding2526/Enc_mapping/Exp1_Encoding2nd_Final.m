% Exp3 additional single-target colour mapping session (Psychtoolbox).
% Run from this folder. Response is first cursor crossing of inner wheel edge.
clear; close all; clc;
KbName('UnifyKeyNames');
rng('shuffle');
participantID = strtrim(input('Enter Participant ID: ', 's'));
sessionN = str2double(input('Enter mapping session number: ', 's'));
assert(~isempty(regexp(participantID, '^[A-Za-z0-9_-]+$', 'once')), ...
    'Use letters, numbers, underscore or hyphen for participant ID.');
assert(isfinite(sessionN) && sessionN >= 1 && sessionN == floor(sessionN), ...
    'Session number must be a positive integer.');

% Pilot settings: stable comparison uses DecayEnabled = false.
config.DecayEnabled = true;
config.DecayDuration = 3.0; % seconds to remove every target pixel, linear
config.ResponseDeadline = 5.0; % seconds from target + wheel onset
config.SeedHues = 0:10:350; % degrees, hue zero is first colour-map entry
config.MainReps = 15;
config.PracticeReps = 1; % one presentation of each seed (36 practice trials)
config.CheckpointEvery = 36;
config.FixationDuration = 1.0;
config.FeedbackDuration = 0.75;
config.TimeoutPenaltyDuration = 2.0;
config.Timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS-FFF');
config.ParticipantID = participantID;
config.SessionN = sessionN;
config.InitialRNG = rng;
scriptDir = fileparts(mfilename('fullpath'));
saveDir = fullfile(scriptDir, 'MappingData');
if ~exist(saveDir, 'dir'), mkdir(saveDir); end
savePath = fullfile(saveDir, sprintf('mapping_%s_s%d_%s.mat', ...
    participantID, sessionN, config.Timestamp));
[practiceTrials, expTrials] = TrialMatrix(config);
global V
V = struct();
try
    InitializeMatlabOpenGL;
    AssertOpenGL;
    V = initiate();
    adjustStim(calibrateMonitor());
    config.FrameInterval = Screen('GetFlipInterval', V.window);
    config.Display = V; % apparatus/colour map once, not repeated trial columns
    config.Source = fileread(mfilename('fullpath'));
    config.TrialMatrixSource = fileread(fullfile(scriptDir, 'TrialMatrix.m'));
    wheelTexture = DrawWheel();
    saveMapping(savePath, practiceTrials, expTrials, config, false);
    message = ['A single colour and the response wheel appear together.\n\n' ...
        'Match the target colour by moving the mouse to the wheel.\n' ...
        'Your response ends when the cursor reaches the wheel.\n' ...
        'Respond accurately and promptly, within 5 seconds.\n'];
    if config.DecayEnabled
        message = [message 'The target gradually loses pixels.\n'];
    end
    showMessage([message '\nPress SPACE for practice.']);
    for phase = 1:2
        if phase == 1
            trials = practiceTrials;
        else
            showMessage('Practice complete.\n\nPress SPACE to start the main session.');
            trials = expTrials;
        end
        for ii = 1:height(trials)
            Screen('FillRect', V.window, V.patch.bg);
            fixation(config.FixationDuration);
            trials(ii,:) = mappingResponse(trials(ii,:), wheelTexture, config);
            if phase == 1, practiceTrials = trials; else, expTrials = trials; end
            % Save every completed trial; interrupted/unfinished rows stay uncompleted.
            saveMapping(savePath, practiceTrials, expTrials, config, false);
            mappingFeedback(trials(ii,:), wheelTexture, config);
            if mod(ii, config.CheckpointEvery) == 0 && ii < height(trials)
                showMessage(sprintf('%d / %d trials complete.\n\nTake a break. Press SPACE to continue.', ...
                    ii, height(trials)));
            end
        end
    end
    saveMapping(savePath, practiceTrials, expTrials, config, true);
    showMessage('Session complete. Thank you!\n\nPress SPACE to finish.');
    Screen('CloseAll'); ShowCursor;
catch ME
    Screen('CloseAll'); ShowCursor;
    config.LastError = getReport(ME, 'extended', 'hyperlinks', 'off');
    saveMapping(savePath, practiceTrials, expTrials, config, false);
    rethrow(ME);
end
fprintf('Saved mapping session: %s\n', savePath);

function trial = mappingResponse(trial, wheelTexture, config)
global V
% Integer-centred disk: one fixed random removal ordering per trial.
r = V.stim.radius;
[x, y] = meshgrid(-r:r, -r:r);
inside = x.^2 + y.^2 <= r^2;
pixels = [x(inside)'; y(inside)'];
oldRng = rng;
rng(trial.DecaySeed, 'twister');
pixels = pixels(:, randperm(size(pixels,2)));
rng(oldRng);
center = round([V.centerX; V.centerY] + V.stim.positionradius * ...
    [cosd(trial.TargetLocationDeg); sind(trial.TargetLocationDeg)]);
trial.TargetX = center(1); trial.TargetY = center(2);
pixels = pixels + center;
mapIndex = 1 + round(trial.TargetHueDeg / 360 * size(V.color.map,1));
rgb = V.color.map(mapIndex,:);
SetMouse(V.centerX, V.centerY, V.window);
ShowCursor('Arrow');
drawFrame(0);
onset = Screen('Flip', V.window);
trial.OnsetSecs = onset;
vbl = onset;
removed = 0;
while true
    checkAbort();
    [mx, my] = GetMouse(V.window);
    elapsed = GetSecs - onset;
    if elapsed >= config.ResponseDeadline
        trial.TimedOut = true;
        trial.ResponseTimeMs = config.ResponseDeadline * 1000;
        break
    end
    if hypot(mx - V.centerX, my - V.centerY) > V.annulus.radiusInner
        trial.ResponseTimeMs = elapsed * 1000;
        trial.ResponseScreenAngleDeg = mod(atan2d(my-V.centerY, mx-V.centerX),360);
        trial.ResponseHueDeg = mod(trial.ResponseScreenAngleDeg - trial.WheelRotationDeg,360);
        % Keep original Exp3 sign convention: target minus response.
        trial.SignedErrorDeg = mod(trial.TargetHueDeg-trial.ResponseHueDeg+180,360)-180;
        break
    end
    % Render for the next refresh, not for a frame count-dependent decay.
    nextElapsed = max(0, vbl + config.FrameInterval - onset);
    fraction = 0;
    if config.DecayEnabled, fraction = min(1, nextElapsed/config.DecayDuration); end
    nextRemoved = floor(fraction * size(pixels,2));
    drawFrame(nextRemoved);
    [vbl, ~, ~, missed] = Screen('Flip', V.window, vbl + 0.5*config.FrameInterval);
    trial.MissedFrames = trial.MissedFrames + double(missed > 0);
    removed = nextRemoved;
end
trial.VisibleFraction = 1 - removed / size(pixels,2);
trial.Completed = true;
HideCursor;

    function drawFrame(nRemoved)
        Screen('DrawTexture', V.window, wheelTexture, [], [], trial.WheelRotationDeg);
        fixation(0);
        % Draw all surviving pixels in one batch: removed pixels never return.
        if nRemoved < size(pixels,2)
            Screen('DrawDots', V.window, pixels(:, nRemoved+1:end), 1, rgb, [], 0);
        end
    end
end

function mappingFeedback(trial, wheelTexture, config)
global V
Screen('FillRect', V.window, V.patch.bg);
if trial.TimedOut
    DrawFormattedText(V.window, 'Too slow! Respond within 5 seconds.', ...
        'center', 'center', [255 255 255]);
    duration = config.TimeoutPenaltyDuration;
else
    Screen('DrawTexture', V.window, wheelTexture, [], [], trial.WheelRotationDeg);
    targetAngle = trial.TargetHueDeg + trial.WheelRotationDeg;
    for angle = [targetAngle, trial.ResponseScreenAngleDeg]
        if angle == targetAngle, color = [255 255 255]; else, color = [0 0 0]; end
        rr = [V.annulus.radiusInner-10, V.annulus.radiusOuter+10];
        Screen('DrawLine', V.window, color, ...
            V.centerX+rr(1)*cosd(angle), V.centerY+rr(1)*sind(angle), ...
            V.centerX+rr(2)*cosd(angle), V.centerY+rr(2)*sind(angle), 2);
    end
    duration = config.FeedbackDuration;
end
Screen('Flip', V.window);
WaitSecs(duration);
end

function showMessage(message)
global V
Screen('FillRect', V.window, V.patch.bg);
DrawFormattedText(V.window, message, 'center', 'center', [255 255 255]);
Screen('Flip', V.window);
KbReleaseWait;
while true
    checkAbort();
    [down, ~, keys] = KbCheck;
    if down && keys(KbName('space')), break; end
    WaitSecs(0.01);
end
KbReleaseWait;
end

function checkAbort()
global V
[down, ~, keys] = KbCheck;
if down && keys(V.Keys.ctrlKey) && keys(V.Keys.quitKey)
    error('Mapping:Aborted', 'Experiment aborted with Ctrl+L.');
end
end

function saveMapping(path, practiceTrials, expTrials, config, sessionComplete)
% Replace checkpoint only after a complete temporary MAT file is written.
temporary = [path '.tmp.mat'];
save(temporary, 'practiceTrials', 'expTrials', 'config', 'sessionComplete');
[ok, message] = movefile(temporary, path, 'f');
assert(ok, 'Mapping:SaveFailed', '%s', message);
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

% ──────────────────────────────────────────────────────────────────────────

function texture = DrawWheel()
    global V
    offScreenWindow = Screen('OpenOffscreenWindow', V.window, V.patch.bg, V.windowRect);
    % Draw the color wheel onto the screen
    for ii = 1:length(V.color.angles)
        % Calculate the endpoint of each line in the annulus
        xStart = V.centerX + V.annulus.radiusInner * cos(V.color.angles(ii));
        yStart = V.centerY + V.annulus.radiusInner * sin(V.color.angles(ii));
        xEnd = V.centerX + V.annulus.radiusOuter * cos(V.color.angles(ii));
        yEnd = V.centerY + V.annulus.radiusOuter * sin(V.color.angles(ii));
        Screen('DrawLine', offScreenWindow, V.color.map(ii, :), xStart, yStart, xEnd, yEnd, 2);
    end
    
    rect = [V.centerX - V.mouseinit.radius, V.centerY - V.mouseinit.radius, ...
            V.centerX + V.mouseinit.radius, V.centerY + V.mouseinit.radius];
    Screen('FrameOval', offScreenWindow, V.mouseinit.color, rect, V.mouseinit.radiusWidth);
    
    % Save the current screen content as a texture
    texture = Screen('MakeTexture', V.window, Screen('GetImage', offScreenWindow));
    Screen('Close', offScreenWindow);
end

% ──────────────────────────────────────────────────────────────────────────

function FlushMouseEvents()
    % Continuously check the mouse status and only exit when no buttons are pressed
    while any(GetMouseButtons())
        % Wait briefly to avoid overloading the CPU
        WaitSecs(0.01);
    end
end

% ──────────────────────────────────────────────────────────────────────────

function buttons = GetMouseButtons()
    % Helper function to return the mouse button status
    [~, ~, buttons] = GetMouse;
end

% ──────────────────────────────────────────────────────────────────────────

function v = initiate() %Global variable with hard-coded defaults.

sca;                   
Screen('CloseAll');    
WaitSecs(0.5);

v.patch.bg = .5 * 255; % Background gray
% The lab PC's Windows DWM setup fails PTB's sync validation despite a
% stable 60 Hz display.  Match the proven lab setup by bypassing that test.
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

v.Keys.ctrlKey = KbName('LeftControl');
v.Keys.quitKey = KbName('l');
end

% ──────────────────────────────────────────────────────────────────────────

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

% ──────────────────────────────────────────────────────────────────────────

function srgb = lin2srgb(linRGB)
% lin2srgb  Linear sRGB (0–1) → γ-encoded sRGB (0–1)
th = 0.0031308;
srgb            = zeros(size(linRGB));
mask            = linRGB <= th;
srgb(mask)      = 12.92 * linRGB(mask);
srgb(~mask)     = 1.055 * linRGB(~mask).^(1/2.4) - 0.055;
end

% ──────────────────────────────────────────────────────────────────────────

function fiveDegVA_in_pixels = calibrateMonitor()
    global V

    % check calibration exists
    currentConfig.pcName = getenv('COMPUTERNAME');
    currentConfig.monitorPositions = get(0, 'MonitorPositions');
    calibFilename = fullfile(fileparts(mfilename('fullpath')), 'screenCalibration.mat');

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
            'Align these two lines with the edges of your credit card.\n\nUse LEFT/RIGHT arrow keys to move each line.\nUse UP/DOWN arrow keys to choose which line moves.\nPress ENTER when done.', ...
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
                    error('Mapping:Aborted', 'Experiment aborted by operator.');
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
        save(calibFilename, 'savedConfig', 'calibrationData');
    end

end

% ──────────────────────────────────────────────────────────────────────────

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
    V.mouseinit.radius = round(deg * .4);
    V.mouseinit.radiusWidth = round(deg * .03);
    V.mouseinit.color = [85, 85, 85];

end

% ──────────────────────────────────────────────────────────────────────────

function [] = blank(duration)
    global V
    Screen('FillRect', V.window, [V.patch.bg, V.patch.bg, V.patch.bg]);
    Screen('Flip', V.window);
    if duration > 0
        WaitSecs(duration);
    end
end

% ──────────────────────────────────────────────────────────────────────────
