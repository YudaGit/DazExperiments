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

% ---------- design spec (as in Enc_smallN_2nd) --------------------------
% Adjust trial construction here. Timing is set in StimulusDurations below.
design.SeedHues     = 0:10:350; % nominal labels; 0 is equivalent to 360
design.PracticeTrialN = 5;   % total practice trials
design.MainTrialN     = 540;  % total main trials
design.DecayEnabled = true;     % false: stable target; true: pixel removal

config.Timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS-FFF');
config.ParticipantID = participantID;
config.SessionN = sessionN;
config.InitialRNG = rng;
scriptDir = fileparts(mfilename('fullpath'));
saveDir = fullfile(scriptDir, 'MappingData');
if ~exist(saveDir, 'dir'), mkdir(saveDir); end
savePath = fullfile(saveDir, sprintf('mapping_%s_s%d_%s.mat', ...
    participantID, sessionN, config.Timestamp));
[practiceTrials, expTrials] = TrialMatrix(design);
global V
V = struct();
sessionComplete = false;
try
    InitializeMatlabOpenGL;
    AssertOpenGL;
    V = initiate();
    adjustStim(calibrateMonitor());
    V.FrameInterval = Screen('GetFlipInterval', V.window);
    assert(isfinite(V.FrameInterval) && V.FrameInterval > 0, ...
        'Mapping:InvalidFrameInterval', 'Display frame interval is invalid.');
    config.Design = design;
    config.Display = V; % apparatus/colour map once, not repeated trial columns
    config.Source = fileread(fullfile(scriptDir, [mfilename '.m']));
    config.TrialMatrixSource = fileread(fullfile(scriptDir, 'TrialMatrix.m'));
    wheelTexture = DrawWheel();
    neutralTexture = DrawNeutralWheel();
    saveMapping(savePath, practiceTrials, expTrials, config, false);
    message = ['A single colour and the response wheel appear together.\n\n' ...
        'Match the target colour by moving the mouse to the wheel.\n' ...
        'Your response ends when the cursor reaches the wheel.\n' ...
        sprintf('Respond accurately and promptly, within %g seconds.\n', V.Durations.ResponseDuration)];
    if design.DecayEnabled
        message = [message 'The target gradually loses pixels.\n'];
    end
    showMessage([message '\nPractice block']);
    for phase = 1:2
        if phase == 1
            trials = practiceTrials;
        else
            showMessage('Practice complete.\n\nMain block');
            trials = expTrials;
        end
        for ii = 1:height(trials)
            Screen('FillRect', V.window, V.patch.bg);
            fixation(V.Durations.FixationDuration);
            trials(ii,:) = mappingResponse(trials(ii,:), wheelTexture, design);
            if phase == 1, practiceTrials = trials; else, expTrials = trials; end
            % Save every completed trial; interrupted/unfinished rows stay uncompleted.
            saveMapping(savePath, practiceTrials, expTrials, config, false);
            mappingFeedback(trials(ii,:), wheelTexture);
            % Original Study 2 progress display and participant-paced rest.
            feedbackTrials = table(trials.SignedErrorDeg(1:ii), ...
                'VariableNames', {'Precision'});
            if phase == 1
                Screen('DrawTexture', V.window, neutralTexture);
                fixation(0);
                Screen('Flip', V.window);
                WaitSecs(V.Durations.RetinalColorReset); % Study 2 practice reset
            end
            DrawIntertrialFeedbackFast(feedbackTrials, V.window, V.windowRect, height(trials));
        end
    end
    saveMapping(savePath, practiceTrials, expTrials, config, true);
    sessionComplete = true;
    showMessage('Session complete. Thank you!');
    Screen('CloseAll'); ShowCursor;
catch ME
    % Cleanup/checkpoint errors must never replace the original diagnostic.
    try, Screen('CloseAll'); catch, end
    try, ShowCursor; catch, end
    config.LastError = getReport(ME, 'extended', 'hyperlinks', 'off');
    try
        saveMapping(savePath, practiceTrials, expTrials, config, sessionComplete);
    catch saveError
        warning('Mapping:RecoverySaveFailed', '%s', saveError.message);
    end
    rethrow(ME);
end
fprintf('Saved mapping session: %s\n', savePath);

function trial = mappingResponse(trial, wheelTexture, design)
global V
% Decay uses an integer-centred pixel disk; stable mode uses the original oval.
r = V.stim.radius;
[x, y] = meshgrid(-r:r, -r:r);
inside = x.^2 + y.^2 <= r^2;
pixels = [x(inside)'; y(inside)'];
oldRng = rng;
rng(trial.DecaySeed, 'twister');
pixels = pixels(:, randperm(size(pixels,2)));
rng(oldRng);
center = [V.centerX; V.centerY] + V.stim.positionradius * ...
    [cosd(trial.TargetLocationDeg); sind(trial.TargetLocationDeg)];
if design.DecayEnabled, center = round(center); end
trial.TargetX = center(1); trial.TargetY = center(2);
pixels = pixels + center;
% Preserve DrawStimulus's exact one-based Study 2 palette lookup.
cMap = V.color.map(1:size(V.color.map,1)/360:size(V.color.map,1), :);
colorLabel = mod(trial.TargetHueDeg - 1, 360) + 1;
rgb = cMap(colorLabel,:);
trial.TargetRGBHueDeg = colorLabel - 1;
SetMouse(V.centerX, V.centerY, V.window);
ShowCursor('Arrow');
drawFrame(0);
onset = Screen('Flip', V.window);
trial.OnsetSecs = onset;
vbl = onset;
removed = 0;
lastMouseCheck = onset;
firstMouseCheck = true;
FlushEvents('keyDown');
while true
    checkAbort();
    elapsed = GetSecs - onset;
    if elapsed >= V.Durations.ResponseDuration
        trial.TimedOut = true;
        trial.ResponseTimeMs = V.Durations.ResponseDuration * 1000;
        break
    end
    if firstMouseCheck || (GetSecs - lastMouseCheck)*1000 > 10
        firstMouseCheck = false;
        lastMouseCheck = GetSecs;
        responseTimeMs = (GetSecs - onset)*1000;
        [~, ~, responseAngle, distance] = TrackMouse();
    end
    if distance > V.annulus.radiusInner
        trial.ResponseTimeMs = responseTimeMs;
        trial.ResponseScreenAngleDeg = responseAngle;
        trial.ResponseHueDeg = mod(trial.ResponseScreenAngleDeg - trial.WheelRotationDeg,360);
        % Keep original Exp3 sign convention: target minus response.
        trial.SignedErrorDeg = trial.TargetHueDeg - trial.ResponseHueDeg;
        if trial.SignedErrorDeg < -180, trial.SignedErrorDeg = trial.SignedErrorDeg + 360; end
        if trial.SignedErrorDeg > 180, trial.SignedErrorDeg = trial.SignedErrorDeg - 360; end
        break
    end
    % Stable mode retains Study 2's static display and 10-ms mouse polling.
    if ~design.DecayEnabled, continue; end
    % Decay requires refresh-driven redraws; sampling can be delayed by Flip.
    nextElapsed = max(GetSecs, vbl + V.FrameInterval) - onset;
    fraction = 0;
    if design.DecayEnabled, fraction = min(1, nextElapsed/V.Durations.DecayDuration); end
    nextRemoved = floor(fraction * size(pixels,2));
    drawFrame(nextRemoved);
    [vbl, ~, ~, missed] = Screen('Flip', V.window, vbl + 0.5*V.FrameInterval);
    trial.MissedFrames = trial.MissedFrames + double(missed > 0);
    removed = nextRemoved;
end
trial.VisibleFraction = 1 - removed / size(pixels,2);
trial.Completed = true;
HideCursor;

    function drawFrame(nRemoved)
        Screen('FillRect', V.window, V.patch.bg);
        Screen('DrawTexture', V.window, wheelTexture, [], [], trial.WheelRotationDeg);
        fixation(0);
        % Draw all surviving pixels in one batch: removed pixels never return.
        if ~design.DecayEnabled
            % Exact Study 2 oval primitive and unrounded polar position.
            rect = CenterRectOnPointd([-r -r r r], center(1), center(2));
            Screen('FillOval', V.window, rgb, rect);
        elseif nRemoved < size(pixels,2)
            Screen('DrawDots', V.window, pixels(:, nRemoved+1:end), 1, rgb, [], 0);
        end
    end
end

function mappingFeedback(trial, wheelTexture)
global V
Screen('FillRect', V.window, V.patch.bg);
Screen('DrawTexture', V.window, wheelTexture, [], [], trial.WheelRotationDeg);
targetAngle = deg2rad(mod(trial.TargetHueDeg + trial.WheelRotationDeg, 360));
arcRadius = V.annulus.radiusOuter * 1.1;
if ~trial.TimedOut
    rspAngle = deg2rad(trial.ResponseScreenAngleDeg);
    drawLineMarker(V.centerX + arcRadius*cos(rspAngle), ...
        V.centerY + arcRadius*sin(rspAngle), rspAngle, [255, 0, 0]);
end
drawLineMarker(V.centerX + arcRadius*cos(targetAngle), ...
    V.centerY + arcRadius*sin(targetAngle), targetAngle, [0, 255, 0]);
if ~trial.TimedOut
    drawShortestArc(rspAngle, targetAngle);
end
fixation(0);
if trial.TimedOut
    Screen('TextSize', V.window, 40);
    DrawFormattedText(V.window, 'Response Too Slow', ...
        'center', V.windowRect(4)/2, [255, 0, 0]);
    duration = V.Durations.FeedbackPenaltyDuration;
else
    duration = V.Durations.FeedbackDuration;
end
Screen('Flip', V.window);
responsiveWait(duration);
end

function drawLineMarker(centerX, centerY, angle, color)
    global V
    % Calculate the start and end points of the line based on the angle
    xStart = centerX - (V.feedback.ticklength / 2) * cos(angle);
    yStart = centerY - (V.feedback.ticklength / 2) * sin(angle);
    xEnd = centerX + (V.feedback.ticklength / 2) * cos(angle);
    yEnd = centerY + (V.feedback.ticklength / 2) * sin(angle);
    Screen('DrawLine', V.window, color, xStart, yStart, xEnd, yEnd, V.feedback.linewidth);
end

% ──────────────────────────────────────────────────────────────────────────
function drawShortestArc(startAngle, endAngle)
    global V
    arcRadius = V.annulus.radiusOuter * 1.1;
    numSegments = 90;
    clockwiseDistance = mod(endAngle - startAngle, 2 * pi);
    counterClockwiseDistance = mod(startAngle - endAngle, 2 * pi);
    if clockwiseDistance <= counterClockwiseDistance
        arcExtent = clockwiseDistance;
        direction = 1;  % Clockwise
    else
        arcExtent = counterClockwiseDistance;
        direction = -1;  % Counterclockwise
    end
    angleIncrement = arcExtent / numSegments;
    for ii = 1:numSegments
        currentAngle = startAngle + direction * (ii - 1) * angleIncrement;
        nextAngle = startAngle + direction * ii * angleIncrement;

        % Calculate the positions of the current and next points on the arc
        x1 = V.centerX + arcRadius * cos(currentAngle);
        y1 = V.centerY + arcRadius * sin(currentAngle);
        x2 = V.centerX + arcRadius * cos(nextAngle);
        y2 = V.centerY + arcRadius * sin(nextAngle);

        % Draw a line between the current point and the next point
        Screen('DrawLine', V.window, [0, 255, 0], x1, y1, x2, y2, V.feedback.linewidth);
    end
end

% ──────────────────────────────────────────────────────────────────────────
function showMessage(message)
global V
% Study 2 instruction layout; wording alone describes the mapping task.
Screen('FillRect', V.window, V.patch.bg);
Screen('TextSize', V.window, 50);
DrawFormattedText(V.window, message, 'center', V.windowRect(4) * .25, [255 255 255]);
DrawFormattedText(V.window, 'Press The Left Mouse Button To Continue', ...
    'center', V.windowRect(4) * .95, [255 255 255]);
Screen('Flip', V.window);
WaitForMouseClick();
end

function checkAbort()
global V
% Like Study 2's mouse wait, service PTB's native Windows events.
GetMouse;
[down, ~, keys] = KbCheck;
if down && keys(V.Keys.ctrlKey) && keys(V.Keys.quitKey)
    error('Mapping:Aborted', 'Experiment aborted with Ctrl+L.');
end
end

function [] = WaitForMouseClick()
    global V
    valid = false;

    % Flush mouse and keyboard events
    FlushMouseEvents();  % Flush any existing mouse clicks
    FlushEvents('keyDown');  % Flush any existing keydown events

    while ~valid
        [~, ~, buttons] = GetMouse;
        [keyIsDown, ~, keyCode] = KbCheck;
        
        if buttons(1)  % Check for left mouse click
            valid = true; 
        end
        
        if keyIsDown && keyCode(V.Keys.ctrlKey) && keyCode(V.Keys.quitKey)
            disp('Quit Buttons Pressed. Erroring Out Of The Experiment...');
            error('Mapping:Aborted', 'Experiment aborted with Ctrl+L.');
        end
        
        WaitSecs(0.008);  % check each frame, 0.008 for 120hz, 0.016 for 60hz
    end
end

% ──────────────────────────────────────────────────────────────────────────
function responsiveWait(duration)
% Keep static displays responsive and allow Ctrl+L throughout each wait.
finish = GetSecs + duration;
while GetSecs < finish
    checkAbort();
    WaitSecs('YieldSecs', min(0.01, max(0, finish - GetSecs)));
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
        responsiveWait(duration);
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
        % V is not assigned until initiate returns; use local key names here.
        drawnow limitrate;
        [down, ~, keys] = KbCheck;
        if down && keys(KbName('LeftControl')) && keys(KbName('l'))
            error('Mapping:Aborted', 'Experiment aborted with Ctrl+L.');
        end
        % Wait briefly to avoid overloading the CPU
        WaitSecs('YieldSecs', 0.01);
    end
end

% ──────────────────────────────────────────────────────────────────────────

function buttons = GetMouseButtons()
    % Helper function to return the mouse button status
    [~, ~, buttons] = GetMouse;
end

% ──────────────────────────────────────────────────────────────────────────

function v = StimulusDurations(v)
% Store timing parameters in V.Durations.*, as in Enc_smallN_2nd.
% All values are seconds. Only mapping-task durations are included.
v.Durations.FixationDuration        = 1.000;
v.Durations.FeedbackDuration        = 0.750;
v.Durations.FeedbackPenaltyDuration = 2.000;
v.Durations.ResponseDuration        = 5.000; % simultaneous target/wheel deadline
v.Durations.RetinalColorReset       = 0.005; % practice only, as in Study 2
v.Durations.DecayDuration           = 3.000; % mapping: complete pixel removal
end

function v = initiate() %Global variable with hard-coded defaults.

sca;                   
Screen('CloseAll');    
WaitSecs(0.5);

v.patch.bg = .5 * 255; % Background gray
% Preserve the existing lab workaround and record it in saved config.
% Bypassing sync tests does not establish accurate display timing.
v.SkipSyncTests = 1; % Existing Study 2 lab setting; 0 enables sync validation.
Screen('Preference', 'SkipSyncTests', v.SkipSyncTests);
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
        if ~isfield(loadedData, 'savedConfig') || ...
                ~isfield(loadedData, 'calibrationData') || ...
                ~isnumeric(loadedData.calibrationData) || ...
                ~isscalar(loadedData.calibrationData) || ...
                ~isfinite(loadedData.calibrationData) || loadedData.calibrationData <= 0 || ...
                ~isequal(loadedData.savedConfig, currentConfig)
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
            checkAbort();
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
            WaitSecs('YieldSecs', 0.01);
    
        end
        blank(0);
        measured = rightLineX - leftLineX;
        assert(measured > 0, 'Mapping:InvalidCalibration', ...
            'The right calibration line must be to the right of the left line.');
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
    assert(isnumeric(VA5deg) && isscalar(VA5deg) && isfinite(VA5deg) && VA5deg > 0, ...
        'Mapping:InvalidCalibration', 'Calibration must be a positive finite pixel size.');
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
    assert(V.mouseinit.radiusWidth >= 1 && V.feedback.linewidth >= 1, ...
        'Mapping:InvalidCalibration', 'Calibration produces subpixel line widths; recalibrate.');

end

% ──────────────────────────────────────────────────────────────────────────

function [] = blank(duration)
    global V
    Screen('FillRect', V.window, [V.patch.bg, V.patch.bg, V.patch.bg]);
    Screen('Flip', V.window);
    if duration > 0
        responsiveWait(duration);
    end
end

% ──────────────────────────────────────────────────────────────────────────

function DrawIntertrialFeedbackFast(trialsSoFar, winPtr, winRect, nTotal)
    % Draws a precision-per-trial bar plot with PTB drawing only, plus persisted fixation.
    % trialsSoFar: table with field Precision (deg error)
    % winPtr, winRect = Psychtoolbox window pointer & rect
    % nTotal = total number of trials in the experiment

    if nargin < 4
        error('DrawIntertrialFeedbackFast: must supply total trial count as fourth argument');
    end
    nDone = height(trialsSoFar);
    if nDone == 0, return; end

    % PARAMETERS
    barW      = 1;              % px bar width
    spaceW    = 1;              % px spacing between bars
    plotH     = 220;            % px plot height
    bottomY   = winRect(4) * 0.92; % baseline Y-coordinate
    barColor  = [129 199 212];  % RGB color for all bars
    white     = [255 255 255];  % text & axis color

    % CALCULATE HORIZONTAL MARGINS FOR CENTERING
    totalW = nTotal * (barW + spaceW);
    leftMargin = round((winRect(3) - totalW) / 2);

    % DRAW BACKGROUND
    Screen('FillRect', winPtr, [128 128 128]);

    % DRAW FIXATION USING EXISTING FUNCTION
    fixation(0);

    % DRAW BARS
    for i = 1:nDone
        err   = abs(trialsSoFar.Precision(i));
        if ~isfinite(err), continue; end % Timeout has no precision bar.
        score = 1 - min(err / 180, 1);    % normalized 0..1
        hPx   = round(score * plotH);
        xLeft = leftMargin + (i) * (barW + spaceW);
        rect  = [xLeft, bottomY - hPx, xLeft + barW, bottomY];
        Screen('FillRect', winPtr, barColor, rect);
    end

    % DRAW AXES
    axisX0 = leftMargin;
    axisX1 = leftMargin + totalW;
    axisY0 = bottomY;
    axisY1 = bottomY - plotH;
    Screen('DrawLine', winPtr, white, axisX0, axisY0, axisX1, axisY0, 2);
    Screen('DrawLine', winPtr, white, axisX0, axisY0, axisX0, axisY1, 2);

    % DRAW Y-TICKS & LABELS
    Screen('TextSize', winPtr, 14);
    yTicks = 0:2:10;
    for yt = yTicks
        yPx = bottomY - (yt / 10) * plotH;
        Screen('DrawLine', winPtr, white, axisX0 - 5, yPx, axisX0, yPx, 1);
        label = sprintf('%d', yt);
        Screen('DrawText', winPtr, label, axisX0 - 30, yPx - 7, white);
    end

    % AXIS TITLES
    Screen('TextSize', winPtr, 18);
    Screen('DrawText', winPtr, 'Precision Score', axisX0 - 20, axisY1 - 30, white);
    Screen('DrawText', winPtr, 'Trial', axisX0 + totalW/2 - 10, axisY0 + 20, white);

    % DRAW FINISH LINE at last trial
    xFinish = leftMargin + (nTotal) * (barW + spaceW) + barW/2;
    Screen('DrawLine', winPtr, white, xFinish, axisY0, xFinish, axisY1, 2);

    % DISPLAY MESSAGES
    infoTxt1 = sprintf('Completed Trial %d of %d', nDone, nTotal);
    Screen('TextSize', winPtr, 24);
    DrawFormattedText(winPtr, infoTxt1, 'center', winRect(4) * 0.37, white);
    DrawFormattedText(winPtr, 'Click to continue', 'center', winRect(4) * 0.4, white);

    % FINAL FLIP
    Screen('Flip', winPtr);
    WaitForMouseClick();
end

% ──────────────────────────────────────────────────────────────────────────

function [relativeX, relativeY, angle, distance] = TrackMouse()
    global V
    % Get the current mouse position
    [mouseX, mouseY] = GetMouse(V.window);
    
    % Calculate the relative position from the center of the screen
    relativeX = mouseX - V.centerX;
    relativeY = mouseY - V.centerY;
    
    % Calculate the angle (in degrees) relative to the center
    angle = atan2d(relativeY, relativeX);
    if angle < 0
        angle = angle + 360; % Ensure the angle is between 0 and 359.99 degrees
    end
    
    % Calculate the distance from the center
    distance = sqrt(relativeX^2 + relativeY^2);
end

% ──────────────────────────────────────────────────────────────────────────

function texture = DrawNeutralWheel()
    global V
    
    offScreenWindow = Screen('OpenOffscreenWindow', ...
                 V.window, V.patch.bg, V.windowRect);
    width = V.feedback.linewidth * 2;
    blending = [128,128,128,255*.25];
    diam  = 2*V.annulus.radiusOuter;
    diamI = 2*V.annulus.radiusInner + width;
    radIn  = V.annulus.radiusInner;
    radOut = V.annulus.radiusOuter;
    
    noise  = uint8((rand(diam,diam) - 0.5) * 255 + 127.5);
    [x, y] = meshgrid(-radOut+0.5 : radOut-0.5, -radOut+0.5 : radOut-0.5);
    r      = hypot(x, y);
    alpha  = uint8(255 * (r >= radIn & r <= radOut)); 
    
    imgRGBA         = uint8(zeros(diam, diam, 4));
    imgRGBA(:,:,1)  = noise;           % R
    imgRGBA(:,:,2)  = noise;           % G
    imgRGBA(:,:,3)  = noise;           % B
    imgRGBA(:,:,4)  = alpha;           % α
    
    Screen('BlendFunction', offScreenWindow, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
    noiseTex = Screen('MakeTexture', V.window, imgRGBA, [], 1); % keep 8-bit α
    dstRect  = CenterRectOnPointd([0 0 diam diam], ...
                                 V.centerX, V.centerY);
    dstRectI = CenterRectOnPointd([0 0 diamI diamI], ...
                                 V.centerX, V.centerY);
    Screen('DrawTexture', offScreenWindow, noiseTex, [], dstRect);
    
    Screen('FrameOval', offScreenWindow, blending, dstRect, width);
    Screen('FrameOval', offScreenWindow, blending, dstRectI, width);
    
    rect = [V.centerX - V.mouseinit.radius, ...
            V.centerY - V.mouseinit.radius, ...
            V.centerX + V.mouseinit.radius, ...
            V.centerY + V.mouseinit.radius];
    Screen('FrameOval', offScreenWindow, V.mouseinit.color, ...
           rect, V.mouseinit.radiusWidth);
    
    texture = Screen('MakeTexture', V.window, Screen('GetImage', offScreenWindow));
    Screen('Close', offScreenWindow);
    Screen('Close', noiseTex);
end

% ──────────────────────────────────────────────────────────────────────────
