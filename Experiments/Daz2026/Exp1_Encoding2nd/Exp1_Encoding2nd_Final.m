%======================================================================
% Exp1_Encoding2nd_Final.m   (Continuous colour-report)
% Daz Liu 2025 PhD Experiment 1, Redundancy and Encoding
%
% Continuous colour-report task manipulating probe and encoding durations
% Display arrays vary in set-size and redundancy.  Baseline arrays contain
% only unique colours and retain the legacy 'NR' cue-type label.
% Probe: whether a redundant or non-redundant item was cued.
% for report.
% Encoding duration: 50 or 250 ms.
% Response precision and RT were recorded for analyses and modelling.
%======================================================================

clear; close all; clc;
sca; Screen('CloseALL');
format shortg;
InitializeMatlabOpenGL;   % ensure the OpenGL runtime is fully upys
AssertOpenGL;              
KbName('UnifyKeyNames'); % Recognise Keyboard types

timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS'); % Time of current session
participantID = input('Enter Participant ID: ', 's');
sessionN = str2double(input('Enter Session Number (1 - 10): ', 's'));
age = str2double(input('Enter Age Number (17 - 99): ', 's'));
gender = str2double(input('Enter Gender (0 = M, 1 = W, 2 = O): ', 's'));

if isnan(gender) || isnan(age) || isnan(sessionN) || ...
        isempty(participantID) || (gender > 2 || gender < 0) || ...
        (age < 17 || age > 99) || (sessionN < 0 || sessionN > 10)
    fprintf('\nERROR: Enter correct participant details.\n\n')
    ExperimentEnd(false);
end

global V
V = initiate();
win = V.window;
V.PrintScreens = false; % true for stim saving only.

% ---------- design spec ----------------------------------------------
% Each row is a valid ItemN/RedundantN/CueType combination.  Baseline
% arrays have RedundantN = 0 and use the legacy 'NR' label.
design.ConditionSpec = table( ...
    [2; 4; 6; 4; 4; 6; 6], ...
    [0; 0; 0; 3; 3; 3; 3], ...
    {'NR'; 'NR'; 'NR'; 'R'; 'NR'; 'R'; 'NR'}, ...
    'VariableNames', {'ItemN','RedundantN','CueType'});
design.presDurList  = [0.05 0.25];
design.PracticePresDurList = [0.05 0.25];
design.retDurList   = 0.75;
design.PracticeReps = 1;                 % reps *per cell* in practice
design.MainReps     = 35;                % reps *per cell* in main
checkpointEvery      = 35;                % save a recovery copy each block

[pracTrials, expTrials] = TrialMatrix(design, ...
                         sessionN, participantID, age, timestamp);

%----------------------check table output
disp(tabulate(pracTrials.RedundantN)); 
disp(tabulate(expTrials.RedundantN));
%----------------------check table output

VA5deg = calibrateMonitor();
adjustStim(VA5deg);
wheelTexture = DrawWheel();
orientationTexture = DrawOrientationWheel();
neutralTexture     = DrawNeutralWheel();



try
    % frontload the feedback creation texture
    % DrawIntertrialFeedback(expTrials,1, false);
    % blank(0);
    % feedbackTex = GenerateFeedbackTexture(expTrials(1:ii,:), V.window, size(expTrials,1));
    % Create the cue sin wave functions
    CueCreation(false); % flase = don't display them on screen
    
    instructions(1);
    % Practice Loop
    for ii = 1:size(pracTrials,1)
        if ii == 1
            instructions(2)
        end

        % s = [pracTrials(ii,:).CueOrder{1}, '_', pracTrials(ii,:).CuedFeature{1}, '_', num2str(pracTrials(ii,:).ItemN), '_'];

        s = [pracTrials(ii,:).CuedFeature{1}, '_', num2str(pracTrials(ii,:).ItemN), '_'];
        fixation(V.Durations.FixationDuration);
        printScreen([s,'fixation'], V.window);
    
        DrawStimulus(pracTrials(ii,:));
        Screen('Flip', V.window);
        printScreen([s,'Stimulus'], V.window);
        WaitSecs(pracTrials.PresDur(ii));

        Mask(pracTrials(ii,:));
        printScreen([s,'Mask'], V.window);
        WaitSecs(V.Durations.MaskDuration);
        
        [pracTrials.MouseX{ii}, ...
             pracTrials.MouseY{ii}, ... 
             pracTrials.MouseAngles{ii}, ...
             pracTrials.MouseDistances{ii}, ...
             pracTrials.MouseTime{ii}, ...
             pracTrials.ResponseTime(ii), ... 
             pracTrials.ResponseAngle(ii), ...
             pracTrials.DerotatedResponseAngle(ii), ...
             pracTrials.Precision(ii)] = GetResponse(pracTrials(ii,:), wheelTexture, orientationTexture);
        printScreen([s,'Response'], V.window);
    
        [pracTrials.MouseInitTooSlow(ii), pracTrials.MouseInitTooFast(ii), pracTrials.TrialTooSlow(ii)] = speedCheck(pracTrials(ii,:));
        DrawWheelFeedback(pracTrials(ii,:), wheelTexture, orientationTexture);
        printScreen([s,'Feedback'], V.window);
        
        if pracTrials.TrialTooSlow(ii) || pracTrials.MouseInitTooSlow(ii) || pracTrials.MouseInitTooFast(ii)
            WaitSecs(V.Durations.FeedbackPenaltyDuration);
        else
            WaitSecs(V.Durations.FeedbackDuration);
        end

        Screen('DrawTexture', V.window, neutralTexture);
        fixation(0);
        Screen('Flip', V.window);
        WaitSecs(V.Durations.RetinalColorReset);
        
        DrawIntertrialFeedbackFast(pracTrials(1:ii,:), V.window, V.windowRect,size(pracTrials,1));
        % feedbackTex = GenerateFeedbackTexture(pracTrials(1:ii,:), V.window, size(pracTrials,1));
        % DisplayFeedbackTexture(feedbackTex, V.window, V.windowRect, ii, size(pracTrials,1));
        % Screen('Close', feedbackTex);

        printScreen([s,'ITI'], V.window);

    end

    % Main Experimental Loop
    for ii = 1:size(expTrials,1)
        if ii == 1
            instructions(3)
        end

        fixation(V.Durations.FixationDuration);

        DrawStimulus(expTrials(ii,:));
        Screen('Flip', V.window);
        WaitSecs(expTrials.PresDur(ii));

        Mask(expTrials(ii,:));
        WaitSecs(V.Durations.MaskDuration);
        
        [expTrials.MouseX{ii}, ...
             expTrials.MouseY{ii}, ... 
             expTrials.MouseAngles{ii}, ...
             expTrials.MouseDistances{ii}, ...
             expTrials.MouseTime{ii}, ...
             expTrials.ResponseTime(ii), ... 
             expTrials.ResponseAngle(ii), ...
             expTrials.DerotatedResponseAngle(ii), ...
             expTrials.Precision(ii)] = GetResponse(expTrials(ii,:), wheelTexture, orientationTexture);
    
        [expTrials.MouseInitTooSlow(ii), expTrials.MouseInitTooFast(ii), expTrials.TrialTooSlow(ii)] = speedCheck(expTrials(ii,:));
        DrawWheelFeedback(expTrials(ii,:), wheelTexture, orientationTexture);
        
        if expTrials.TrialTooSlow(ii) || expTrials.MouseInitTooSlow(ii) || expTrials.MouseInitTooFast(ii)
            WaitSecs(V.Durations.FeedbackPenaltyDuration);
        else
            WaitSecs(V.Durations.FeedbackDuration);
        end

        DrawIntertrialFeedbackFast(expTrials(1:ii,:), V.window, V.windowRect,size(expTrials,1));
        % feedbackTex = GenerateFeedbackTexture(expTrials(1:ii,:), V.window, size(expTrials,1));
        % DisplayFeedbackTexture(feedbackTex, V.window, V.windowRect, ii, size(expTrials,1));
        % Screen('Close', feedbackTex);

        if mod(ii, checkpointEvery) == 0
            SaveCheckpoint(expTrials, sessionN, participantID, timestamp);
        end

    end
    SaveData(expTrials, sessionN, participantID, timestamp)
    ExperimentEnd(true);
catch ME
    disp('An error occurred:');
    disp(ME.message);
    if exist('expTrials', 'var')
        SaveCheckpoint(expTrials, sessionN, participantID, timestamp);
    end
    ExperimentEnd(false);
end


%% Display Functions
%=========================================================================
% ──────────────────────────────Instruction──────────────────────────────
function [] = instructions(n)
% Display of multiple instructions (n), Next = Mouse Click (L)
% Can set position and text size
    global V
    m = .25;
    if n == 1
        inst = ['Welcome to the colour-report task.\n\n\n' ...
                    'In each trial, the screen will show colored circles.\n' ...
                    'Please try to remember all colors.\n' ...
                    'Report the color of the cued target \n' ...
                    'using the mouse and the response color wheel'];
    elseif n == 2
        inst = ['Practice block:\n\n\n' ...
            'You can experience random stimulus display durations\n' ...
            'with these practice trials.\n\n' ...
            'You can choose to go without practice trials in later sessions\n' ...
            'by informing the experimenter.\n\n' ...
            'Practice data will not contribute to main data']; 
    elseif n == 3
        inst =['Main block:\n\n' ...
            'These are the main experimental trials. \n\n' ...
            'There will be a between-trial feedback plot. \n' ...
            'It visualises your performance and overall progress \n' ...
            'You can rest and refocus during these feedback displays.\n\n\n'];
    elseif n == 4
        inst = ['444'];
    elseif n == 5
        inst =['555'];
    end
    Screen('TextSize', V.window, 50);
    DrawFormattedText(V.window, inst, 'center', V.windowRect(4) * m, [255, 255, 255]);
    DrawFormattedText(V.window, 'Press The Left Mouse Button To Continue', 'center', V.windowRect(4) * .95, [255, 255, 255]);
    Screen('Flip', V.window);
    WaitForMouseClick(); 
end

% ─────────────────────────── Inter-trial feedback ────────────────────────────
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
function [] = DrawWheelFeedback(trial, wheelTexture, orientationTexture)
    global V
    if trial.CuedFeature_i == 0 %color
        Screen('DrawTexture', V.window, wheelTexture, [], [], V.color.rotation);
        rspAngle = deg2rad(mod(trial.ResponseAngle + V.color.rotation, 360));
        targetAngle = deg2rad(mod(trial.Colors{1}(trial.Target) + V.color.rotation, 360));

        rspX =  V.centerX + V.annulus.radiusOuter * 1.1 * cos(rspAngle);
        rspY =  V.centerY + V.annulus.radiusOuter * 1.1 * sin(rspAngle);
        tarX =  V.centerX + V.annulus.radiusOuter * 1.1 * cos(targetAngle);
        tarY =  V.centerY + V.annulus.radiusOuter * 1.1 * sin(targetAngle);
        drawLineMarker(rspX, rspY, rspAngle, [255, 0, 0]);  % Red for response angle
        drawLineMarker(tarX, tarY, targetAngle, [0, 255, 0]);  % Green for target angle
    
    else % orientation
        Screen('DrawTexture', V.window, orientationTexture);
        rspAngle = deg2rad(mod(trial.ResponseAngle - 90, 360));
        targetAngle = deg2rad(mod(trial.Orientations{1}(trial.Target) - 90, 360));

        rspX =  V.centerX + V.annulus.radiusOuter * 1.1 * cos(rspAngle);
        rspY =  V.centerY + V.annulus.radiusOuter * 1.1 * sin(rspAngle);
        tarX =  V.centerX + V.annulus.radiusOuter * 1.1 * cos(targetAngle);
        tarY =  V.centerY + V.annulus.radiusOuter * 1.1 * sin(targetAngle);
        drawLineMarker(rspX, rspY, rspAngle, [255, 0, 0]);  % Red for response angle
        drawLineMarker(tarX, tarY, targetAngle, [0, 255, 0]);  % Green for target angle
    end
    drawShortestArc(rspAngle, targetAngle);
    fixation(0);
    if trial.TrialTooSlow
        feedback = 'Response Too Slow'; 
    elseif trial.MouseInitTooSlow
        feedback = 'Initial Mouse Movement Too Slow'; 
    elseif trial.MouseInitTooFast
        feedback = 'Initial Mouse Movement Too Fast'; 
    end
    if trial.TrialTooSlow || trial.MouseInitTooSlow || trial.MouseInitTooFast
        Screen('TextSize', V.window, 40);
        DrawFormattedText(V.window, feedback, 'center', V.windowRect(4)/2, [255, 0, 0]);
    end
    Screen('Flip', V.window);
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
function v = StimulusDurations(v)
% StimulusDurations  – store ALL timing parameters in V.Durations.*
%
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

% ──────────────────────────────────────────────────────────────────────────
function TargetCue(trial, refresh)
    global V
    if ~exist('refresh', 'var')
        refresh = true;
    end
    for ii = 1:trial.ItemN
        theta = deg2rad(trial.StimulusLocations{1}(ii));
        centerX = round(V.centerX + V.stim.positionradius * cos(theta));
        centerY = round(V.centerY + V.stim.positionradius * sin(theta));
        basePedestal = [0, 0, V.stim.pedestalradius * 2, V.stim.pedestalradius * 2];
        centeredPedestal = CenterRectOnPointd(basePedestal, centerX, centerY);
        if (ii == trial.Target)
            % if trial.CuedFeature_i == 0
            %     %Screen('FrameOval', Visual.window, Visual.cue.Oricolor, centeredPedestal, Visual.cue.borderwidth);
            %     waveCoords = BuildWaveCoords( ...
            %         centerX, centerY, ...
            %         Visual.cue.Ravg, ...
            %         Visual.cue.gentleAmp, ...
            %         Visual.cue.gentleFreq);
            %     Screen('FillPoly', Visual.window, [255 255 255], waveCoords)
            % elseif trial.CuedFeature_i == 1
            %      %Screen('FrameOval', Visual.window, Visual.cue.Colcolor, centeredPedestal, Visual.cue.borderwidth);
            %      waveCoords = BuildWaveCoords( ...
            %         centerX, centerY, ...
            %         Visual.cue.Ravg, ...
            %         Visual.cue.spikyAmp, ...
            %         Visual.cue.spikyFreq);
            %     Screen('FillPoly', Visual.window, [255 255 255], waveCoords)
            % end
            cueSurface = [0, 0, V.cue.radius * 2, V.cue.radius * 2];
            centeredCue = CenterRectOnPointd(cueSurface, centerX, centerY);
            Screen('FillOval', V.window, [255 255 255], centeredCue);
        end
        Screen('FillOval', V.window, V.cue.Bgcolor, centeredPedestal);
    end
    fixation(0);
    if refresh
        Screen('Flip', V.window);
    end
end

% ──────────────────────────────────────────────────────────────────────────
function texture = DrawOrientationWheel()
    global V
    spokeWidth = V.feedback.linewidth;

    offScreenWindow = Screen('OpenOffscreenWindow', V.window, V.patch.bg, V.windowRect);
    Screen('FrameOval', offScreenWindow, [255, 255, 255], ...
           [V.centerX - V.annulus.radiusOuter, V.centerY - V.annulus.radiusOuter, ...
            V.centerX + V.annulus.radiusOuter, V.centerY + V.annulus.radiusOuter], ...
           V.annulus.radiusOuter - V.annulus.radiusInner);
    
    lineLength = V.annulus.radiusOuter - V.annulus.radiusInner;
    r0         = V.annulus.radiusOuter;          % start at rim
    r1         = r0 + lineLength;                     % end outside rim

    angles = (0:45:315) * pi/180;
    x0     = V.centerX + r0*cos(angles);
    y0     = V.centerY + r0*sin(angles);
    x1     = V.centerX + r1*cos(angles);
    y1     = V.centerY + r1*sin(angles);

    for k = 1:numel(angles)
        Screen('DrawLine', offScreenWindow, [0 0 0], x0(k), y0(k), x1(k), y1(k), spokeWidth);
    end

    lineLength = lineLength / 2;
    r0         = V.annulus.radiusOuter;          % start at rim
    r1         = r0 + lineLength;                     % end outside rim

    angels2 = sort(reshape([0:7]' .* 45 + 45/2, 1, [])) * pi/180;
    
    x0     = V.centerX + r0*cos(angels2);
    y0     = V.centerY + r0*sin(angels2);
    x1     = V.centerX + r1*cos(angels2);
    y1     = V.centerY + r1*sin(angels2);

    for k = 1:numel(angels2)
        Screen('DrawLine', offScreenWindow, [0 0 0], x0(k), y0(k), x1(k), y1(k), spokeWidth);
    end

    % Add the mouse initiate ring
    rect = [V.centerX - V.mouseinit.radius, V.centerY - V.mouseinit.radius, ...
            V.centerX + V.mouseinit.radius, V.centerY + V.mouseinit.radius];
    Screen('FrameOval', offScreenWindow, V.mouseinit.color, rect, V.mouseinit.radiusWidth);
    % Create a texture from the offscreen window content
    texture = Screen('MakeTexture', V.window, Screen('GetImage', offScreenWindow));
    Screen('Close', offScreenWindow);
end

% ──────────────────────────────────────────────────────────────────────────
function noiseMaskTex = GaussianTexture()
    global V
    patchSize = round(V.stim.pedestalradius * 2);
    meanGray  = round(255/2);
    noiseAmp  = round(255/4);
    sigma     = round(patchSize * .25);
    noise2D = (rand(patchSize) * 2 - 1)*noiseAmp + meanGray;
    noise2D = max(0, min(noise2D, 255));
    [x, y] = meshgrid( ...
        linspace(-patchSize/2, +patchSize/2, patchSize), ...
        linspace(-patchSize/2, +patchSize/2, patchSize) );
    distFromCenter = sqrt(x.^2 + y.^2);
    circleMask = (distFromCenter <= V.stim.pedestalradius);
    gauss2D    = exp( -(distFromCenter.^2) / (2*sigma^2) );
    alpha2D = gauss2D .* circleMask;
    noiseImage = zeros(patchSize, patchSize, 4, 'uint8');
    noiseImage(:,:,1) = uint8(noise2D);                 % R
    noiseImage(:,:,2) = uint8(noise2D);                 % G
    noiseImage(:,:,3) = uint8(noise2D);                 % B
    noiseImage(:,:,4) = uint8(alpha2D * 255);           % alpha
    noiseMaskTex = Screen('MakeTexture', V.window, noiseImage);
end

% ──────────────────────────────────────────────────────────────────────────
function Mask(trial)
    global V
    for ii = 1:trial.ItemN
        noiseMaskTex = GaussianTexture;
        theta = deg2rad(trial.StimulusLocations{1}(ii));
        centerX = V.centerX + V.stim.positionradius * cos(theta);
        centerY = V.centerY + V.stim.positionradius * sin(theta);
        basePedestal = [0, 0, V.stim.pedestalradius * 2, V.stim.pedestalradius * 2];
        centeredPedestal = CenterRectOnPointd(basePedestal, centerX, centerY);
        Screen('FillOval', V.window, V.cue.Bgcolor, centeredPedestal);
        Screen('DrawTexture', V.window, noiseMaskTex, [], centeredPedestal);
        Screen('Close', noiseMaskTex);
    end
    fixation(0);
    Screen('Flip', V.window);
end

% ──────────────────────────────────────────────────────────────────────────
function DrawStimulus(trial)
global V                 % uses V.window, V.stim.* and V.color.map

% colour map: 360 × 3 uint8, one row per wheel index
cMap = V.color.map(1 : size(V.color.map,1)/360 : size(V.color.map,1), :);

fixation(0);             % keeps your existing fixation routine

dotR   = V.stim.radius;          % dot (disc) radius  [px]
ringR  = V.stim.positionradius;  % distance from centre [px]
baseRect = [-dotR -dotR  dotR dotR];   % template bounding box

for ii = 1:trial.ItemN
    % ----- polar → screen coordinates ---------------------------------
    theta   = deg2rad(trial.StimulusLocations{1}(ii));
    centerX = V.centerX + ringR * cos(theta);
    centerY = V.centerY + ringR * sin(theta);

    % ----- RGB from wheel index ---------------------------------------
    rgb = cMap(trial.Colors{1}(ii), :);

    % ----- draw coloured disc -----------------------------------------
    rect = CenterRectOnPointd(baseRect, centerX, centerY);
    Screen('FillOval', V.window, rgb, rect);
end
end

% ──────────────────────────────────────────────────────────────────────────
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
function CueCreation(display)
    global V
    theta = deg2rad(1);
    centerX = V.centerX + V.stim.positionradius * cos(theta);
    centerY = V.centerY + V.stim.positionradius * sin(theta);
    basePedestal = [0, 0, V.stim.pedestalradius * 2, V.stim.pedestalradius * 2];
    centeredPedestal = CenterRectOnPointd(basePedestal, centerX, centerY);

    if display
        for cues = 1:3

            if cues == 2
                % Add gentle wave
                %Screen('FrameOval', Visual.window, Visual.cue.Oricolor, centeredPedestal, Visual.cue.borderwidth);
                waveCoords = BuildWaveCoords( ...
                    centerX, centerY, ...
                    V.cue.Ravg, ...
                    V.cue.gentleAmp, ...
                    V.cue.gentleFreq);
                Screen('FillPoly', V.window, [255 255 255], waveCoords)

            elseif cues == 3
                % Add spiky wave
                %Screen('FrameOval', Visual.window, Visual.cue.Colcolor, centeredPedestal, Visual.cue.borderwidth);
                waveCoords = BuildWaveCoords( ...
                    centerX, centerY, ...
                    V.cue.Ravg, ...
                    V.cue.spikyAmp, ...
                    V.cue.spikyFreq);
                Screen('FillPoly', V.window, [255 255 255], waveCoords)
            elseif cues == 1
                % Add smooth boarder, of equal area to waves.
                %Screen('FrameOval', Visual.window, Visual.cue.Neutcolor, centeredPedestal, Visual.cue.borderwidth);
                cueSurface = [0, 0, V.cue.radius * 2, V.cue.radius * 2];
                centeredCue = CenterRectOnPointd(cueSurface, centerX, centerY);
                Screen('FillOval', V.window, [255 255 255], centeredCue);
            end

            % Add black pedestal overlay
            Screen('FillOval', V.window, V.cue.Bgcolor, centeredPedestal);

            fixation(0);
            Screen('Flip', V.window);
            WaitSecs(1);
        end
    end
end

%% Response Functions
%=========================================================================

% ──────────────────────────────────────────────────────────────────────────
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
            QuitButtonsPressed;
        end
        
        WaitSecs(0.008);  % check each frame, 0.008 for 120hz, 0.016 for 60hz
    end
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
function [x, y, angles, distances, mousetime, rt, responseangle, derotatedAngle, precision] = GetResponse(trial, wheelTexture, orientationTexture)
    global V
    Screen('FillRect', V.window, [V.patch.bg, V.patch.bg, V.patch.bg]);
    if trial.CuedFeature_i == false
        Screen('DrawTexture', V.window, wheelTexture, [], [], V.color.rotation);
    else
        Screen('DrawTexture', V.window, orientationTexture);
    end
    fixation(0);
    %Cue(trial, true, false, false)
    TargetCue(trial, false);
    Screen('Flip', V.window);
    looptime = GetSecs;
    starttime = looptime;
    checkmousetime = 10; %ms 
    Run = true;
    initiate = true;
    x = [];
    y = [];
    angles = [];
    distances = [];
    mousetime = [];
    SetMouse(V.centerX, V.centerY, V.window);
    ShowCursor('Arrow');
    FlushEvents('keyDown'); 
    while Run
        checktime = GetSecs;
        [keyIsDown, ~, keyCode] = KbCheck;
        if keyIsDown && keyCode(V.Keys.ctrlKey) && keyCode(V.Keys.quitKey)
            disp('Quit Buttons Pressed. Erroring Out Of The Experiment...');
            QuitButtonsPressed;
        end
        if ((checktime - looptime) * 1000) > checkmousetime | initiate
            initiate = false;
            looptime = GetSecs();
            mousetime = [mousetime, (GetSecs() - starttime) * 1000];
            [relativeX, relativeY, angle, distance] = TrackMouse();
            x = [x, relativeX];
            y = [y, relativeY];
            angles = [angles, angle];
            distances = [distances, distance];
        end

        if distance > V.annulus.radiusInner 
            
            Run = false;
            rt = mousetime(end);

            if trial.CuedFeature_i == true
                responseangle = mod(angles(end) + 90, 360);
                derotatedAngle = angles(end);
                precision = trial.Orientations{1}(trial.Target) - responseangle;
                if precision < -180; precision = precision + 360; end
                if precision > 180; precision = precisiopositionradiusn - 360; end

            else
                responseangle = mod(angles(end) - V.color.rotation, 360);
                derotatedAngle = mod( responseangle - trial.WheelRotation, 360 );
                precision = trial.Colors{1}(trial.Target) - responseangle;
                if precision < -180; precision = precision + 360; end
                if precision > 180; precision = precision - 360; end
            end
            %fprintf('Finish Angle: %f', responseangle);
            
        end

        if (GetSecs() - starttime) > V.Durations.ResponseDuration
            rt = V.Durations.ResponseDuration * 1000;
            responseangle = nan;
            derotatedAngle = nan;
            precision = nan;
            Run = false;
        end 
    end
    HideCursor();
end

% ──────────────────────────────────────────────────────────────────────────
function [MouseTooSlow, MouseTooFast, TrialTooSlow] = speedCheck(trial)
    global V
    MouseTooSlow = false; 
    MouseTooFast = false; 
    TrialTooSlow = false;
    LeaveCenterRT = trial.MouseTime{1}(find(trial.MouseDistances{1} >= V.mouseinit.radius, 1));

    if LeaveCenterRT > V.mouseinit.tooslow
        MouseTooSlow = true;
    end
    if LeaveCenterRT < V.mouseinit.toofast
        MouseTooFast = true;
    end
    if trial.ResponseTime > V.Durations.TrialTooSlow
        TrialTooSlow = true;
    end
end

% ──────────────────────────────────────────────────────────────────────────
function v = ResponseKeys()
    v.ctrlKey = KbName('LeftControl');  
    v.quitKey = KbName('l');
end

% Design and Data Functions
% ──────────────────────────────────────────────────────────────────────────
function d = minCircularDistance(angle, angles)
    diff = abs(angle - angles);
    d = min(diff, 360 - diff);
end

% ──────────────────────────────────────────────────────────────────────────
function x = randColors(n)
    minDist = 15;
    maxloop = 20;
    loopcount = 0;
    x = randi([1, 360]);
    if n > 1
        while length(x) < n
            if loopcount == maxloop
                x = randi([1, 360]);
            end
            xi = randi([1, 360]);
            if all(minCircularDistance(x, xi) > minDist)
                x = [x,xi];
            else 
                loopcount = loopcount + 1;
            end
        end
    end
end

% ──────────────────────────────────────────────────────────────────────────
function [] = SaveData(expTrials, sessionN, participantID, timestamp)
% Save completed-session data alongside the experiment script.
    global V
    saveDir = DataSaveDirectory();
    fname = sprintf('EncodingData_%s_sess%d_%s.mat', ...
                    participantID, sessionN, timestamp);
    fullpath = fullfile(saveDir, fname);
    try
        if ~isfolder(saveDir)
            mkdir(saveDir);
            disp(['Save Data Directory Created: ', saveDir]);
        end
        save(fullpath, 'expTrials', 'V');
        fprintf('✔ Data saved to:\n  %s\n', fullpath);
    catch ME
        warning('Failed to save data: %s\nError message:\n%s', ...
                fullpath, ME.message);
    end
end

function [] = SaveCheckpoint(expTrials, sessionN, participantID, timestamp)
% Overwrite one recoverable partial-session file at regular intervals.
    global V
    saveDir = DataSaveDirectory();
    fname = sprintf('EncodingData_%s_sess%d_%s_checkpoint.mat', ...
                    participantID, sessionN, timestamp);
    fullpath = fullfile(saveDir, fname);
    try
        if ~isfolder(saveDir)
            mkdir(saveDir);
        end
        save(fullpath, 'expTrials', 'V');
        fprintf('Checkpoint saved after %d completed trials.\n', ...
                sum(~isnan(expTrials.ResponseTime)));
    catch ME
        warning('Failed to save checkpoint: %s\nError message:\n%s', ...
                fullpath, ME.message);
    end
end

function saveDir = DataSaveDirectory()
% Always save beside this experiment script, regardless of MATLAB's pwd.
    scriptDir = fileparts(mfilename('fullpath'));
    if isempty(scriptDir)
        scriptDir = pwd;
    end
    saveDir = fullfile(scriptDir, 'Daz25EncodingData');
end


% Global Functions
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
v = StimulusDurations(v);
v.Keys = ResponseKeys();
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
    V.stim.orientedlinewidth = round(deg * .12);
    V.stim.pedestalradius = V.stim.radius * 1.3; 
    V.stim.pedestalcolor = [0, 0, 0];

    V.mouseinit.radius = round(deg * .4);
    V.mouseinit.radiusWidth = round(deg * .03);
    V.mouseinit.color = [85, 85, 85];
    % Note this is the mouse timing 
    V.mouseinit.toofast = 150;
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
function x = randOrientations(n)
    minDist = 30;
    maxloop = 20;
    loopcount = 0;
    x = randi([0, 179]);
    if n > 1
        while length(x) < n
            if loopcount == maxloop
                x = randi([0, 179]);
            end
            xi = randi([0, 179]);
            if all(minCircularDistance(x, xi) > minDist)
                x = [x,xi];
            else 
                loopcount = loopcount + 1;
            end
        end
    end
end

% ──────────────────────────────────────────────────────────────────────────
function [] = ExperimentEnd(Finished)
    global V
    if Finished
        Screen('TextSize', V.window, 50);
        DrawFormattedText(V.window, 'Experiment Complete!\n\nThank you for your participation.', 'center', V.windowRect(4)/2, [255, 255, 255]);
        Screen('Flip', V.window);
        WaitSecs(4);
    else
        Screen('TextSize', V.window, 50);
        DrawFormattedText(V.window, 'Terminating Experiment.', 'center', V.windowRect(4)/2, [255, 255, 255]);
        Screen('Flip', V.window);
        WaitSecs(1);
    end
    close all;
    sca; %Screen('CloseAll');
    disp('Experiment Code Finished');
end

% ──────────────────────────────────────────────────────────────────────────
function [] = printScreen(filename, window)
    global V
    if V.PrintScreens
        saveDir = 'PrintScreen';
        if ~isfolder(saveDir)
            mkdir(saveDir);
        end
        if ~contains(filename,'.')
            filename = [filename '.png'];
        end
        img = Screen('GetImage', window);
        filename = fullfile(saveDir, filename);
        imwrite(img, filename);
    end
end

% ──────────────────────────────────────────────────────────────────────────
